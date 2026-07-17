//
//  AliyunASRBridge.m
//  Perapera
//
//  fun-asr SDK (nuisdk.framework) 的 block-based 桥接实现
//

#import "AliyunASRBridge.h"
#import <nuisdk/NeoNui.h>

@interface AliyunASRBridge () <NeoNuiSdkDelegate>

@property (nonatomic, strong) NeoNui *neoNui;
@property (nonatomic, assign) BOOL isInitialized;
@property (nonatomic, copy) AliyunASREventCallback currentCallback;
@property (nonatomic, copy) NSString *currentTaskId;

@end

@implementation AliyunASRBridge

+ (instancetype)shared {
    static AliyunASRBridge *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[AliyunASRBridge alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isInitialized = NO;
    }
    return self;
}

- (BOOL)initializeWithApiKey:(NSString *)apiKey deviceId:(NSString *)deviceId {
    if (self.isInitialized) {
        NSLog(@"⚠️ AliyunASRBridge: SDK 已初始化，先释放再重新初始化");
        [self releaseSDK];
    }

    if (!apiKey || apiKey.length == 0) {
        NSLog(@"❌ AliyunASRBridge: API Key 为空");
        return NO;
    }

    // 获取 NeoNui 单例
    self.neoNui = [NeoNui get_instance];
    self.neoNui.delegate = self;

    // 构建初始化参数
    NSDictionary *params = @{
        @"url": @"wss://dashscope.aliyuncs.com/api-ws/v1/inference",
        @"apikey": apiKey,
        @"device_id": deviceId ?: [[NSUUID UUID] UUIDString],
        @"service_mode": @"1"
    };

    NSError *jsonError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:params options:0 error:&jsonError];
    if (jsonError) {
        NSLog(@"❌ AliyunASRBridge: 参数 JSON 序列化失败: %@", jsonError);
        return NO;
    }

    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

    // 初始化 SDK
    NuiResultCode ret = [self.neoNui nui_initialize:[jsonString UTF8String]
                                           logLevel:NUI_LOG_LEVEL_INFO
                                            saveLog:NO];

    if (ret == SUCCESS) {
        self.isInitialized = YES;
        NSLog(@"✅ AliyunASRBridge: fun-asr SDK 初始化成功");
        return YES;
    } else {
        NSLog(@"❌ AliyunASRBridge: fun-asr SDK 初始化失败, ret=%d", ret);
        return NO;
    }
}

- (void)startFileTranscriptionWithURL:(NSString *)fileURL
                             callback:(AliyunASREventCallback)callback {
    if (!self.isInitialized) {
        NSLog(@"❌ AliyunASRBridge: SDK 未初始化");
        if (callback) {
            callback(AliyunASREventASRError, nil, nil, YES, -1);
        }
        return;
    }

    self.currentCallback = [callback copy];

    // 构建转录参数
    NSDictionary *nlsConfig = @{
        @"model": @"fun-asr",
        @"diarization_enabled": @(NO),
        @"parameters": @{
            @"speech_noise_threshold": @(0.0)
        }
    };

    NSDictionary *params = @{
        @"file_urls": @[fileURL ?: @""],
        @"async_request": @(YES),  // 使用异步模式，通过轮询获取结果
        @"nls_config": nlsConfig
    };

    NSError *jsonError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:params options:0 error:&jsonError];
    if (jsonError) {
        NSLog(@"❌ AliyunASRBridge: 参数 JSON 序列化失败: %@", jsonError);
        if (callback) {
            callback(AliyunASREventASRError, nil, nil, YES, -2);
        }
        return;
    }

    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

    // 启动转录
    char taskIdBuffer[128] = {0};
    NuiResultCode ret = [self.neoNui nui_file_trans_start:[jsonString UTF8String]
                                                   taskId:taskIdBuffer];

    if (ret == SUCCESS) {
        self.currentTaskId = [NSString stringWithUTF8String:taskIdBuffer];
        NSLog(@"✅ AliyunASRBridge: 转录任务已启动, taskId=%@", self.currentTaskId);
    } else {
        NSLog(@"❌ AliyunASRBridge: 转录任务启动失败, ret=%d", ret);
        if (callback) {
            callback(AliyunASREventASRError, nil, nil, YES, ret);
        }
    }
}

- (void)queryTaskStatus:(NSString *)taskId {
    if (!taskId) return;
    [self.neoNui nui_file_trans_query:[taskId UTF8String]];
}

- (void)cancelTask:(NSString *)taskId {
    if (!taskId) return;
    [self.neoNui nui_file_trans_cancel:[taskId UTF8String]];
}

- (void)releaseSDK {
    if (self.neoNui) {
        [self.neoNui nui_release];
    }
    self.isInitialized = NO;
    self.currentCallback = nil;
    self.currentTaskId = nil;
    self.neoNui = nil;
    NSLog(@"✅ AliyunASRBridge: SDK 已释放");
}

- (void)dealloc {
    [self releaseSDK];
}

#pragma mark - NeoNuiSdkDelegate

- (void)onFileTransEventCallback:(NuiCallbackEvent)nuiEvent
                       asrResult:(const char *)asr_result
                          taskId:(const char *)task_id
                        ifFinish:(BOOL)finish
                         retCode:(int)code {

    NSString *resultStr = asr_result ? [NSString stringWithUTF8String:asr_result] : nil;
    NSString *taskIdStr = task_id ? [NSString stringWithUTF8String:task_id] : nil;

    // 映射 NuiCallbackEvent → AliyunASREvent
    AliyunASREvent event;
    switch (nuiEvent) {
        case EVENT_FILE_TRANS_CONNECTED:
            event = AliyunASREventFileTransConnected;
            NSLog(@"🔗 AliyunASRBridge: WebSocket 已连接");
            break;
        case EVENT_FILE_TRANS_UPLOADED:
            event = AliyunASREventFileTransUploaded;
            NSLog(@"📤 AliyunASRBridge: 文件已上传");
            break;
        case EVENT_FILE_TRANS_RESULT:
            event = AliyunASREventFileTransResult;
            NSLog(@"✅ AliyunASRBridge: 识别结果: %@", resultStr);
            break;
        case EVENT_FILE_TRANS_UPLOAD_PROGRESS:
            event = AliyunASREventFileTransUploadProgress;
            break;
        case EVENT_FILE_TRANS_QUERY_RESULT:
            event = AliyunASREventFileTransQueryResult;
            break;
        case EVENT_ASR_ERROR:
            event = AliyunASREventASRError;
            NSLog(@"❌ AliyunASRBridge: ASR 错误, code=%d", code);
            break;
        default:
            event = AliyunASREventASRError;
            break;
    }

    if (self.currentCallback) {
        self.currentCallback(event, resultStr, taskIdStr, finish, code);
    }
}

@end

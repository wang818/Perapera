//
//  AliyunASRBridge.h
//  Perapera
//
//  fun-asr SDK (nuisdk.framework) 的 block-based 桥接层
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - 回调事件类型（与 nuisdk NuiCallbackEvent 对齐）

typedef NS_ENUM(NSInteger, AliyunASREvent) {
    AliyunASREventFileTransConnected      = 28, // EVENT_FILE_TRANS_CONNECTED
    AliyunASREventFileTransUploaded       = 29, // EVENT_FILE_TRANS_UPLOADED
    AliyunASREventFileTransResult         = 30, // EVENT_FILE_TRANS_RESULT
    AliyunASREventFileTransUploadProgress = 31, // EVENT_FILE_TRANS_UPLOAD_PROGRESS
    AliyunASREventFileTransQueryResult    = 34, // EVENT_FILE_TRANS_QUERY_RESULT
    AliyunASREventASRError                = 10, // EVENT_ASR_ERROR
};

#pragma mark - 回调 Block 定义

/// 文件转录事件回调
typedef void (^AliyunASREventCallback)(AliyunASREvent event,
                                       NSString * _Nullable asrResult,
                                       NSString * _Nullable taskId,
                                       BOOL isFinished,
                                       int errorCode);

#pragma mark - AliyunASRBridge

/// fun-asr SDK 的 block-based 桥接类
/// 封装 nuisdk.framework 的 NeoNui API
@interface AliyunASRBridge : NSObject

/// 单例
+ (instancetype)shared;

/// 初始化 fun-asr SDK
/// @param apiKey DashScope API Key
/// @param deviceId 设备标识
/// @return YES 初始化成功，NO 失败
- (BOOL)initializeWithApiKey:(NSString *)apiKey deviceId:(NSString *)deviceId;

/// 启动文件转录任务（同步模式，结果通过 callback 返回）
/// @param fileURL 音频文件 URL
/// @param callback 识别事件回调
- (void)startFileTranscriptionWithURL:(NSString *)fileURL
                             callback:(AliyunASREventCallback)callback;

/// 查询异步转录任务状态
/// @param taskId 任务 ID
- (void)queryTaskStatus:(NSString *)taskId;

/// 取消转录任务
/// @param taskId 任务 ID
- (void)cancelTask:(NSString *)taskId;

/// 释放 SDK 资源
- (void)releaseSDK;

/// SDK 是否已初始化
@property (nonatomic, readonly) BOOL isInitialized;

@end

NS_ASSUME_NONNULL_END

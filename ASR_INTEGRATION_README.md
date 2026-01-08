# 腾讯云语音识别 API 集成文档

## 概述
已成功集成腾讯云录音文件识别 API，实现音频文件上传后自动进行语音转文字识别。

## 功能流程

1. **用户选择音频文件** → 支持 opus、mp3、wav、m4a 等格式
2. **上传到腾讯云 COS** → 显示上传进度
3. **自动创建识别任务** → 调用腾讯云 ASR API
4. **轮询查询识别结果** → 每 5 秒查询一次，最多 5 分钟
5. **显示识别文本** → 可复制结果

## 文件结构

```
Perapera/Services/
├── COSConfig.swift          # COS 配置
├── COSUploadManager.swift   # COS 上传管理器
├── ASRConfig.swift          # 语音识别配置
└── ASRManager.swift         # 语音识别管理器

Perapera/Views/HomeView/
└── HomeView.swift           # 集成了完整流程的主界面
```

## API 说明

### 1. 创建识别任务 (CreateRecTask)

**接口**: `https://asr.tencentcloudapi.com/`

**请求参数**:
- `EngineModelType`: 引擎模型类型（默认：16k_zh）
- `ChannelNum`: 声道数（默认：1）
- `ResTextFormat`: 结果文本格式（默认：0 UTF-8）
- `SourceType`: 音频来源（0: URL, 1: Base64）
- `Url`: 音频文件 URL（COS 地址）
- `FilterDirty`: 是否过滤脏词
- `FilterModal`: 是否过滤语气词
- `FilterPunc`: 是否过滤标点符号
- `ConvertNumMode`: 数字转换模式

**响应**:
```json
{
  "Response": {
    "RequestId": "xxx",
    "Data": {
      "TaskId": 1234567
    }
  }
}
```

### 2. 查询识别结果 (DescribeTaskStatus)

**请求参数**:
- `TaskId`: 任务 ID

**响应**:
```json
{
  "Response": {
    "Data": {
      "TaskId": 1234567,
      "Status": 2,
      "StatusStr": "success",
      "Result": "识别出的文本内容",
      "AudioDuration": 120
    }
  }
}
```

**状态码**:
- `0`: 任务等待
- `1`: 任务执行中
- `2`: 任务成功
- `3`: 任务失败

## 配置说明

### ASRConfig.swift

```swift
// 引擎模型类型
static let engineModelType = "16k_zh"  // 16k 中文普通话

// 其他可选模型：
// "16k_zh_video" - 音视频领域
// "16k_en" - 英语
// "16k_ca" - 粤语
```

### 认证方式

使用腾讯云 API 签名 V3 算法：
1. 拼接规范请求串
2. 拼接待签名字符串
3. 计算签名（HMAC-SHA256）
4. 拼接 Authorization 头

**注意**: 使用与 COS 相同的 SecretId 和 SecretKey

## 使用示例

### 在 HomeView 中的集成

```swift
// 1. 上传文件到 COS
COSUploadManager.shared.uploadFile(fileURL: url) { result in
    switch result {
    case .success(let cosURL):
        // 2. 创建语音识别任务
        ASRManager.shared.createRecognitionTask(audioURL: cosURL) { result in
            switch result {
            case .success(let taskId):
                // 3. 轮询查询结果
                pollRecognitionResult(taskId: taskId)
            case .failure(let error):
                print("创建任务失败: \(error)")
            }
        }
    case .failure(let error):
        print("上传失败: \(error)")
    }
}
```

### 轮询查询结果

```swift
private func pollRecognitionResult(taskId: Int, retryCount: Int = 0) {
    ASRManager.shared.queryRecognitionResult(taskId: taskId) { result in
        switch result {
        case .success(let taskResult):
            if taskResult.Status == 2 {
                // 识别成功
                print("识别结果: \(taskResult.Result ?? "")")
            } else if taskResult.Status == 0 || taskResult.Status == 1 {
                // 继续轮询
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    pollRecognitionResult(taskId: taskId, retryCount: retryCount + 1)
                }
            }
        case .failure(let error):
            print("查询失败: \(error)")
        }
    }
}
```

## UI 状态

### 1. 上传状态
- 显示上传进度条
- 显示百分比

### 2. 识别状态
- 显示加载动画
- 显示任务 ID

### 3. 结果显示
- 显示识别文本
- 提供复制功能
- 可关闭结果面板

## 支持的音频格式

- **wav**: PCM 格式，推荐采样率 16kHz
- **mp3**: 常见音频格式
- **m4a**: Apple 音频格式
- **opus**: 高质量音频编码
- **flv**: Flash 视频音频
- **mp4**: 视频音频
- **wma**: Windows Media Audio
- **3gp**: 移动设备音频
- **aac**: 高级音频编码
- **ogg-opus**: Ogg 容器的 Opus
- **flac**: 无损音频

## 限制说明

### API 限制
- **频率限制**: 20次/秒（仅限任务提交）
- **音频时长**: URL 方式最长 5 小时
- **文件大小**: URL 方式最大 1GB，本地文件最大 5MB
- **结果保存**: 识别结果在服务端保存 24 小时

### 返回时效
- **最长时间**: 3 小时
- **一般情况**: 1 小时音频 1-3 分钟完成

## 计费说明

语音识别按照音频时长计费，详见：
- [腾讯云语音识别计费概述](https://cloud.tencent.com/document/product/1093/35686)

**建议**: 
- 使用腾讯云 COS 存储音频可节省流量费用
- 合理设置轮询间隔，避免频繁查询

## 错误处理

### 常见错误

1. **签名错误**
   - 检查 SecretId 和 SecretKey 是否正确
   - 确认时间戳是否准确

2. **音频格式不支持**
   - 确认音频格式在支持列表中
   - 检查采样率是否符合要求

3. **URL 无法访问**
   - 确认 COS URL 可公开访问
   - 检查 URL 是否有效

4. **识别超时**
   - 检查音频文件是否过大
   - 确认网络连接正常

## 优化建议

### 1. 性能优化
- 使用 COS 预签名 URL 避免公开访问
- 合理设置轮询间隔（建议 5-10 秒）
- 实现任务队列管理多个识别任务

### 2. 用户体验
- 显示识别进度提示
- 提供取消识别功能
- 保存历史识别记录

### 3. 成本优化
- 使用热词表提高识别准确率
- 合理选择引擎模型类型
- 批量处理音频文件

## 相关文档

- [录音文件识别请求 API](https://cloud.tencent.com/document/product/1093/37823)
- [录音文件识别结果查询 API](https://cloud.tencent.com/document/product/1093/37822)
- [腾讯云 API 签名 V3](https://cloud.tencent.com/document/api/1093/35640)
- [语音识别产品文档](https://cloud.tencent.com/document/product/1093)

## 测试建议

1. 准备不同格式的测试音频文件
2. 测试不同时长的音频（短、中、长）
3. 测试网络异常情况下的重试机制
4. 验证识别结果的准确性
5. 测试并发上传和识别场景

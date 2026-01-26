# 📹 视频上传完整工作流程

## 概述

视频上传后会自动执行完整的处理流程：转换音频 → 上传 COS → 语音识别 → 显示结果

## 🎯 完整流程

```
用户选择视频
    ↓
保存到视频列表
    ↓
【步骤 1】转换为 Opus 音频 (显示进度)
    ↓
保存音频到 Documents 目录
    ↓
更新 VideoStorage (audioURL)
    ↓
【步骤 2】上传音频到腾讯云 COS (显示进度)
    ↓
【步骤 3】创建语音识别任务
    ↓
【步骤 4】轮询查询识别结果
    ↓
显示识别文本
```

## 📱 用户界面

### 上传入口

用户可以通过以下方式上传视频：

1. **YouTube 链接** (第一个按钮)
   - 图标: 📷 photo
   - 功能: 输入 YouTube 视频链接
   - 操作: 打开输入框

2. **视频上传** (第二个按钮) ✅
   - 图标: 📤 arrow.up.doc
   - 功能: 选择本地视频文件上传
   - 操作: 打开文件选择器
   - 支持格式: .mp4, .mov, .avi, .opus 等

3. **Network Test** (第三个按钮)
   - 图标: 🌐 network
   - 功能: 测试网络连接
   - 操作: 测试 API

4. **相册视频** (第四个按钮)
   - 图标: 📄 doc
   - 功能: 从相册选择视频
   - 操作: 打开相册选择器

### 进度显示

#### 1. 转换进度
```
┌─────────────────────────────┐
│  ████████████░░░░░░░░░░░░  │
│  转换音频中... 60%          │
│  正在将视频转换为 Opus 格式  │
└─────────────────────────────┘
```

#### 2. 上传进度
```
┌─────────────────────────────┐
│  ██████████████░░░░░░░░░░  │
│  上传中... 70%              │
└─────────────────────────────┘
```

#### 3. 识别进度
```
┌─────────────────────────────┐
│  ⏳ 正在加载...             │
│  语音识别中...              │
│  任务ID: 12345              │
└─────────────────────────────┘
```

#### 4. 识别结果
```
┌─────────────────────────────┐
│  识别结果              [×]  │
│  ─────────────────────────  │
│  这是识别出的文本内容...    │
│  可以滚动查看更多内容       │
│  ─────────────────────────  │
│  [📋 复制文本]              │
└─────────────────────────────┘
```

## 🔧 技术实现

### 1. 文件选择

```swift
.fileImporter(
    isPresented: $showingFileImporter,
    allowedContentTypes: [.audio, .movie, UTType(filenameExtension: "opus")].compactMap { $0 },
    allowsMultipleSelection: false
) { result in
    // 处理选择的文件
}
```

### 2. 保存视频信息

```swift
VideoStorageManager.shared.addVideo(
    name: videoName,
    posterImage: UIImage(systemName: "video.fill"),
    videoURL: url.path,
    audioURL: nil  // 初始为 nil
)
```

### 3. 转换音频

```swift
AudioConverter.shared.convertVideoToOpusWithProgress(
    inputURL: videoURL,
    bitrate: "64k",
    sampleRate: 48000,
    progress: { progress in
        conversionProgress = progress  // 更新进度
    },
    completion: { result in
        // 处理转换结果
    }
)
```

### 4. 更新音频路径

```swift
VideoStorageManager.shared.updateVideoAudioURL(
    id: videoId,
    audioURL: audioURL.path
)
```

### 5. 上传到 COS

```swift
COSUploadManager.shared.uploadFile(
    fileURL: audioURL,
    progress: { progress in
        uploadProgress = progress  // 更新进度
    },
    completion: { result in
        // 处理上传结果
    }
)
```

### 6. 创建识别任务

```swift
ASRManager.shared.createRecognitionTask(audioURL: cosURL) { result in
    switch result {
    case .success(let taskId):
        // 开始轮询
        pollRecognitionResult(taskId: taskId)
    case .failure(let error):
        // 处理错误
    }
}
```

### 7. 轮询识别结果

```swift
func pollRecognitionResult(taskId: Int, retryCount: Int = 0) {
    ASRManager.shared.queryRecognitionResult(taskId: taskId) { result in
        switch result {
        case .success(let taskResult):
            switch taskResult.Status {
            case 2: // 成功
                recognitionText = taskResult.Result
            case 3: // 失败
                print("识别失败")
            case 0, 1: // 等待中或执行中
                // 5 秒后继续轮询
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    pollRecognitionResult(taskId: taskId, retryCount: retryCount + 1)
                }
            }
        }
    }
}
```

## 📊 状态管理

### State 变量

```swift
@State private var videos: [VideoItem] = []              // 视频列表
@State private var isConverting: Bool = false            // 是否正在转换
@State private var conversionProgress: Double = 0.0     // 转换进度
@State private var isUploading: Bool = false             // 是否正在上传
@State private var uploadProgress: Double = 0.0         // 上传进度
@State private var isRecognizing: Bool = false           // 是否正在识别
@State private var asrTaskId: Int?                       // 识别任务 ID
@State private var recognitionText: String = ""          // 识别结果
@State private var currentConvertingVideoId: String?     // 当前转换的视频 ID
```

## ⏱️ 时间估算

| 步骤 | 时间 | 说明 |
|------|------|------|
| 选择视频 | 即时 | 用户操作 |
| 保存信息 | < 1秒 | 本地存储 |
| 转换音频 | 5-10秒/分钟 | 取决于视频长度 |
| 上传 COS | 2-5秒 | 取决于网络速度 |
| 创建任务 | < 1秒 | API 调用 |
| 语音识别 | 10-30秒 | 取决于音频长度 |
| **总计** | **约 20-50秒** | 1分钟视频 |

## 🎨 UI 状态

### 转换中
- 显示转换进度条
- 显示百分比
- 禁用其他操作

### 上传中
- 显示上传进度条
- 显示百分比
- 可以取消（TODO）

### 识别中
- 显示加载动画
- 显示任务 ID
- 显示提示信息

### 完成
- 显示识别结果弹窗
- 提供复制功能
- 可以关闭

## 🐛 错误处理

### 转换失败
```swift
case .failure(let error):
    print("❌ 音频转换失败: \(error.localizedDescription)")
    // TODO: 显示错误提示给用户
```

### 上传失败
```swift
case .failure(let error):
    print("❌ 音频上传失败: \(error.localizedDescription)")
    // TODO: 显示错误提示给用户
```

### 识别失败
```swift
case .failure(let error):
    print("❌ 创建语音识别任务失败: \(error.localizedDescription)")
    isRecognizing = false
```

### 识别超时
```swift
guard retryCount < maxRetries else {
    print("❌ 语音识别超时")
    isRecognizing = false
    return
}
```

## 📁 文件存储

### 视频文件
- 位置: 用户选择的原始位置
- 格式: .mp4, .mov, .avi 等

### 音频文件
- 位置: `Documents/{原文件名}_{时间戳}.opus`
- 格式: Opus
- 比特率: 64k
- 采样率: 48000 Hz

### 数据存储
- 位置: UserDefaults
- 键名: `saved_video_list`
- 格式: JSON

## 🔍 调试信息

### 控制台输出

```
📥 输入: my_video.mp4
📤 输出: my_video_1706000000.opus
🎬 开始转换视频到 Opus 音频（带进度）...
进度: 10%
进度: 20%
...
进度: 100%
✅ 转换成功!
📁 文件路径: /Documents/my_video_1706000000.opus
📊 文件大小: 2.4 MB
✅ 已更新视频的音频路径
上传进度: 10%
上传进度: 20%
...
上传进度: 100%
✅ 音频上传成功!
COS访问地址: https://...
✅ 语音识别任务创建成功! TaskId: 12345
📊 识别状态: 执行中
📊 识别状态: 执行中
✅ 识别成功!
识别结果: 这是识别出的文本内容...
```

## ✅ 功能清单

- [x] 视频文件选择
- [x] 视频信息保存
- [x] 自动转换音频
- [x] 转换进度显示
- [x] 音频路径保存
- [x] 自动上传 COS
- [x] 上传进度显示
- [x] 自动创建识别任务
- [x] 轮询识别结果
- [x] 显示识别文本
- [x] 复制识别结果
- [x] 错误处理
- [ ] 取消操作（TODO）
- [ ] 错误提示 UI（TODO）

## 🎉 完成

视频上传后会自动执行完整的处理流程，无需手动操作！

---

**更新时间**: 2026-01-24  
**版本**: 1.0.0  
**状态**: ✅ 已实现

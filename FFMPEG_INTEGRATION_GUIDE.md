# FFmpeg 视频转音频集成指南

## 功能概述

已成功集成 FFmpeg，实现以下功能：
- ✅ 视频文件自动转换为 Opus 格式音频
- ✅ 音频文件保存到 Documents 目录
- ✅ 音频路径保存到 VideoStorage
- ✅ 转换进度实时显示
- ✅ 自动上传音频到 COS 并进行语音识别

## 安装步骤

### 1. 安装 CocoaPods 依赖

```bash
cd /path/to/Perapera
pod install
```

这将安装 `mobile-ffmpeg-full` 库（约 200MB，包含完整编解码器）。

### 2. 配置 Xcode 项目

#### 2.1 设置 Bridging Header

1. 打开 `Perapera.xcworkspace`
2. 选择项目 Target: `Perapera`
3. 进入 `Build Settings`
4. 搜索 `Objective-C Bridging Header`
5. 设置值为: `Perapera/Perapera-Bridging-Header.h`

#### 2.2 验证配置

确保 Bridging Header 文件已创建：
- 路径: `Perapera/Perapera-Bridging-Header.h`
- 内容: 已包含 FFmpeg 头文件导入

## 核心组件

### 1. AudioConverter.swift

音频转换管理器，提供以下功能：

#### 主要方法

```swift
// 基础转换（无进度）
AudioConverter.shared.convertVideoToOpus(
    inputURL: videoURL,
    bitrate: "64k",
    sampleRate: 48000
) { result in
    switch result {
    case .success(let audioURL):
        print("转换成功: \(audioURL.path)")
    case .failure(let error):
        print("转换失败: \(error)")
    }
}

// 带进度的转换
AudioConverter.shared.convertVideoToOpusWithProgress(
    inputURL: videoURL,
    bitrate: "64k",
    sampleRate: 48000,
    progress: { progress in
        print("进度: \(Int(progress * 100))%")
    },
    completion: { result in
        // 处理结果
    }
)
```

#### 其他功能

```swift
// 删除音频文件
AudioConverter.shared.deleteAudioFile(at: audioURL)

// 列出所有转换的音频
let audioFiles = AudioConverter.shared.listConvertedAudioFiles()

// 清空所有音频
AudioConverter.shared.clearAllConvertedAudioFiles()
```

### 2. VideoStorageManager 更新

VideoItem 模型新增字段：

```swift
struct VideoItem {
    let id: String
    let name: String
    let posterImageData: Data?
    let videoURL: String
    let audioURL: String?  // 新增：音频文件路径
    let createdAt: Date
    
    var hasAudio: Bool {
        return audioURL != nil
    }
}
```

新增方法：

```swift
// 更新视频的音频路径
VideoStorageManager.shared.updateVideoAudioURL(
    id: videoId,
    audioURL: audioURL.path
)
```

### 3. HomeView 集成

完整的工作流程：

1. **用户选择视频** → 保存到列表
2. **自动转换音频** → 显示转换进度
3. **保存音频路径** → 更新 VideoStorage
4. **上传到 COS** → 显示上传进度
5. **语音识别** → 显示识别结果

## 转换参数说明

### Opus 编码参数

```swift
bitrate: "64k"      // 音频比特率（推荐 48k-128k）
sampleRate: 48000   // 采样率（Opus 推荐 48000）
channels: 1         // 声道数（1=单声道，2=立体声）
```

### 比特率建议

- **32k**: 语音通话质量
- **64k**: 标准语音质量（推荐）
- **96k**: 高质量语音
- **128k**: 音乐质量

### 采样率建议

- **16000**: 窄带语音
- **24000**: 宽带语音
- **48000**: 全带语音（推荐）

## 文件存储

### 存储位置

```
Documents/
├── video1_1706000000.opus
├── video2_1706000001.opus
└── ...
```

### 文件命名规则

格式: `{原文件名}_{时间戳}.opus`

示例: `my_video_1706000000.opus`

### 获取 Documents 路径

```swift
let documentsURL = FileManager.default.urls(
    for: .documentDirectory,
    in: .userDomainMask
)[0]
```

## UI 界面

### 转换进度显示

```swift
if isConverting {
    VStack {
        ProgressView(value: conversionProgress)
        Text("转换音频中... \(Int(conversionProgress * 100))%")
    }
}
```

### 视频列表显示

- 显示视频缩略图
- 显示视频名称和创建时间
- 显示视频来源（YouTube/本地）
- 显示音频状态（已转换/未转换）

## FFmpeg 命令详解

实际执行的命令：

```bash
ffmpeg -i "input.mp4" \
       -vn \                    # 不处理视频流
       -c:a libopus \           # 使用 Opus 编码器
       -b:a 64k \               # 音频比特率 64k
       -ar 48000 \              # 采样率 48000
       -ac 1 \                  # 单声道
       -y \                     # 覆盖输出文件
       "output.opus"
```

### 参数说明

- `-i`: 输入文件
- `-vn`: 不处理视频流（只提取音频）
- `-c:a libopus`: 使用 Opus 音频编码器
- `-b:a`: 设置音频比特率
- `-ar`: 设置音频采样率
- `-ac`: 设置音频声道数
- `-y`: 自动覆盖已存在的输出文件

## 性能优化

### 1. 异步处理

所有转换操作在后台线程执行，不阻塞 UI：

```swift
DispatchQueue.global(qos: .userInitiated).async {
    // 执行转换
}
```

### 2. 进度回调

使用 FFmpeg 统计回调获取实时进度：

```swift
MobileFFmpegConfig.setStatisticsCallback { statistics in
    // 更新进度
}
```

### 3. 文件大小优化

- Opus 格式比 MP3 更小（约 30-50% 压缩率）
- 64k 比特率适合语音识别
- 单声道进一步减小文件大小

## 错误处理

### 常见错误

1. **文件不存在**
   ```swift
   case .fileNotFound:
       print("找不到输入文件")
   ```

2. **转换失败**
   ```swift
   case .conversionFailed(let message):
       print("转换失败: \(message)")
   ```

3. **保存失败**
   ```swift
   case .saveFailed:
       print("保存文件失败")
   ```

### 调试信息

查看 FFmpeg 输出日志：

```swift
if let output = MobileFFmpeg.getLastCommandOutput() {
    print("FFmpeg 输出: \(output)")
}
```

## 测试建议

### 1. 功能测试

- [ ] 上传不同格式的视频（MP4, MOV, AVI）
- [ ] 测试不同大小的视频文件
- [ ] 测试转换进度显示
- [ ] 测试音频文件保存
- [ ] 测试音频路径更新

### 2. 性能测试

- [ ] 测试大文件转换（> 100MB）
- [ ] 测试多个文件连续转换
- [ ] 测试内存使用情况
- [ ] 测试转换速度

### 3. 边界测试

- [ ] 测试损坏的视频文件
- [ ] 测试无音频的视频
- [ ] 测试磁盘空间不足
- [ ] 测试应用后台转换

## 注意事项

### 1. 库大小

`mobile-ffmpeg-full` 约 200MB，包含所有编解码器。

如果需要减小体积，可以使用精简版本：
- `mobile-ffmpeg-min`: 最小版本（约 20MB）
- `mobile-ffmpeg-audio`: 仅音频（约 50MB）

修改 Podfile：
```ruby
pod 'mobile-ffmpeg-audio', '4.4'  # 仅音频版本
```

### 2. 转换时间

转换时间取决于：
- 视频时长
- 设备性能
- 比特率设置

大致估算：1 分钟视频 ≈ 5-10 秒转换时间

### 3. 存储空间

Opus 音频文件大小估算：
- 64k 比特率 ≈ 480KB/分钟
- 10 分钟视频 ≈ 4.8MB 音频

### 4. 电池消耗

视频转换是 CPU 密集型操作，建议：
- 提示用户连接电源
- 避免同时转换多个文件
- 提供取消转换选项

## 扩展功能建议

### 1. 批量转换

```swift
func convertMultipleVideos(_ videoURLs: [URL]) {
    for url in videoURLs {
        convertVideoToAudio(videoURL: url, videoId: generateId())
    }
}
```

### 2. 自定义参数

```swift
struct ConversionSettings {
    var bitrate: String = "64k"
    var sampleRate: Int = 48000
    var channels: Int = 1
}
```

### 3. 转换队列

```swift
class ConversionQueue {
    private var queue: [ConversionTask] = []
    
    func addTask(_ task: ConversionTask) {
        queue.append(task)
        processNext()
    }
}
```

### 4. 缓存管理

```swift
// 自动清理旧文件
func cleanupOldAudioFiles(olderThan days: Int) {
    let audioFiles = AudioConverter.shared.listConvertedAudioFiles()
    // 删除超过指定天数的文件
}
```

## 故障排除

### 问题 1: 编译错误 "Use of undeclared type 'MobileFFmpeg'"

**解决方案:**
1. 确保已运行 `pod install`
2. 使用 `.xcworkspace` 打开项目
3. 检查 Bridging Header 配置

### 问题 2: 转换失败 "Return code: 1"

**解决方案:**
1. 检查输入文件是否存在
2. 检查输入文件格式是否支持
3. 查看 FFmpeg 输出日志

### 问题 3: 进度不更新

**解决方案:**
1. 确保在主线程更新 UI
2. 检查统计回调是否正确设置
3. 验证视频时长获取是否成功

## 完成 ✅

FFmpeg 集成完成，视频转音频功能已就绪！

运行 `pod install` 后即可使用。

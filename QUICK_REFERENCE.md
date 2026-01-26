# FFmpeg 快速参考

## 🚀 快速开始

### 1. 安装
```bash
./install_ffmpeg.sh
```

### 2. 配置 Xcode
```
Build Settings → Objective-C Bridging Header
设置为: Perapera/Perapera-Bridging-Header.h
```

### 3. 使用
```swift
AudioConverter.shared.convertVideoToOpus(inputURL: videoURL) { result in
    // 处理结果
}
```

## 📋 常用 API

### 转换视频
```swift
// 简单转换
AudioConverter.shared.convertVideoToOpus(
    inputURL: videoURL,
    completion: { result in }
)

// 带进度
AudioConverter.shared.convertVideoToOpusWithProgress(
    inputURL: videoURL,
    progress: { progress in },
    completion: { result in }
)
```

### 文件管理
```swift
// 列出所有音频
let files = AudioConverter.shared.listConvertedAudioFiles()

// 删除音频
AudioConverter.shared.deleteAudioFile(at: url)

// 清空所有
AudioConverter.shared.clearAllConvertedAudioFiles()
```

### 视频存储
```swift
// 添加视频（带音频路径）
VideoStorageManager.shared.addVideo(
    name: "视频名称",
    posterImage: image,
    videoURL: videoPath,
    audioURL: audioPath
)

// 更新音频路径
VideoStorageManager.shared.updateVideoAudioURL(
    id: videoId,
    audioURL: audioPath
)

// 检查是否有音频
if video.hasAudio {
    print("已转换音频")
}
```

## ⚙️ 转换参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| bitrate | 64k | 音频比特率 |
| sampleRate | 48000 | 采样率 |
| channels | 1 | 声道数 |

### 比特率建议
- 32k - 语音通话
- 64k - 标准语音（推荐）
- 96k - 高质量语音
- 128k - 音乐质量

## 📁 文件路径

### Documents 目录
```swift
let documentsURL = FileManager.default.urls(
    for: .documentDirectory,
    in: .userDomainMask
)[0]
```

### 音频文件命名
```
{原文件名}_{时间戳}.opus
例: my_video_1706000000.opus
```

## 🎯 完整工作流

```swift
// 1. 选择视频
let videoURL = ...

// 2. 保存视频信息
VideoStorageManager.shared.addVideo(
    name: "视频名称",
    posterImage: thumbnail,
    videoURL: videoURL.path
)

// 3. 转换音频
AudioConverter.shared.convertVideoToOpusWithProgress(
    inputURL: videoURL,
    progress: { progress in
        print("进度: \(Int(progress * 100))%")
    },
    completion: { result in
        switch result {
        case .success(let audioURL):
            // 4. 更新音频路径
            VideoStorageManager.shared.updateVideoAudioURL(
                id: videoId,
                audioURL: audioURL.path
            )
            
            // 5. 上传到 COS
            COSUploadManager.shared.uploadFile(...)
            
        case .failure(let error):
            print("转换失败: \(error)")
        }
    }
)
```

## ⚠️ 常见问题

### Q: 编译错误 "Use of undeclared type 'MobileFFmpeg'"
A: 
1. 运行 `pod install`
2. 使用 `.xcworkspace` 打开项目
3. 配置 Bridging Header

### Q: 转换失败
A: 检查：
- 输入文件是否存在
- 磁盘空间是否充足
- 查看 FFmpeg 日志

### Q: 进度不更新
A: 确保在主线程更新 UI

## 📊 性能指标

| 指标 | 数值 |
|------|------|
| 转换速度 | 1分钟视频 ≈ 5-10秒 |
| 文件大小 | 64k ≈ 480KB/分钟 |
| 库大小 | 约 200MB |

## 🔗 相关文档

- [完整集成指南](FFMPEG_INTEGRATION_GUIDE.md)
- [使用示例](FFMPEG_USAGE_EXAMPLE.md)
- [设置完成](FFMPEG_SETUP_COMPLETE.md)
- [视频存储指南](VIDEO_STORAGE_GUIDE.md)

## ✅ 检查清单

- [ ] 运行 `pod install`
- [ ] 配置 Bridging Header
- [ ] 编译成功
- [ ] 测试转换功能
- [ ] 验证文件保存
- [ ] 测试删除功能

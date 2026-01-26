# FFmpeg 使用示例

## 快速开始

### 1. 基础转换示例

```swift
import UIKit

class VideoConverterExample {
    
    // 示例 1: 简单转换
    func simpleConversion() {
        guard let videoURL = Bundle.main.url(forResource: "sample", withExtension: "mp4") else {
            print("找不到视频文件")
            return
        }
        
        AudioConverter.shared.convertVideoToOpus(inputURL: videoURL) { result in
            switch result {
            case .success(let audioURL):
                print("✅ 转换成功!")
                print("音频路径: \(audioURL.path)")
                
                // 保存到 VideoStorage
                VideoStorageManager.shared.updateVideoAudioURL(
                    id: "your-video-id",
                    audioURL: audioURL.path
                )
                
            case .failure(let error):
                print("❌ 转换失败: \(error.localizedDescription)")
            }
        }
    }
    
    // 示例 2: 带进度的转换
    func conversionWithProgress() {
        guard let videoURL = Bundle.main.url(forResource: "sample", withExtension: "mp4") else {
            return
        }
        
        AudioConverter.shared.convertVideoToOpusWithProgress(
            inputURL: videoURL,
            bitrate: "64k",
            sampleRate: 48000,
            progress: { progress in
                print("转换进度: \(Int(progress * 100))%")
                // 更新 UI 进度条
                DispatchQueue.main.async {
                    // self.progressView.progress = Float(progress)
                }
            },
            completion: { result in
                switch result {
                case .success(let audioURL):
                    print("✅ 转换完成: \(audioURL.lastPathComponent)")
                case .failure(let error):
                    print("❌ 转换失败: \(error.localizedDescription)")
                }
            }
        )
    }
    
    // 示例 3: 自定义参数转换
    func customConversion() {
        guard let videoURL = Bundle.main.url(forResource: "sample", withExtension: "mp4") else {
            return
        }
        
        // 高质量音频设置
        AudioConverter.shared.convertVideoToOpus(
            inputURL: videoURL,
            bitrate: "128k",      // 高比特率
            sampleRate: 48000,    // 标准采样率
            completion: { result in
                // 处理结果
            }
        )
    }
}
```

### 2. SwiftUI 集成示例

```swift
import SwiftUI

struct VideoConverterView: View {
    @State private var isConverting = false
    @State private var progress: Double = 0.0
    @State private var resultMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            if isConverting {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                
                Text("转换中... \(Int(progress * 100))%")
                    .font(.headline)
            }
            
            Button("开始转换") {
                startConversion()
            }
            .disabled(isConverting)
            
            Text(resultMessage)
                .foregroundColor(.green)
        }
        .padding()
    }
    
    func startConversion() {
        guard let videoURL = getVideoURL() else { return }
        
        isConverting = true
        progress = 0.0
        
        AudioConverter.shared.convertVideoToOpusWithProgress(
            inputURL: videoURL,
            progress: { prog in
                progress = prog
            },
            completion: { result in
                isConverting = false
                
                switch result {
                case .success(let audioURL):
                    resultMessage = "转换成功: \(audioURL.lastPathComponent)"
                case .failure(let error):
                    resultMessage = "转换失败: \(error.localizedDescription)"
                }
            }
        )
    }
    
    func getVideoURL() -> URL? {
        // 返回视频 URL
        return nil
    }
}
```

### 3. 完整工作流示例

```swift
class VideoProcessingWorkflow {
    
    func processVideo(videoURL: URL, videoName: String) {
        // 步骤 1: 生成缩略图
        let thumbnail = generateThumbnail(from: videoURL)
        
        // 步骤 2: 保存视频信息
        VideoStorageManager.shared.addVideo(
            name: videoName,
            posterImage: thumbnail,
            videoURL: videoURL.path,
            audioURL: nil
        )
        
        // 获取视频 ID
        let videos = VideoStorageManager.shared.loadVideos()
        guard let videoId = videos.first?.id else { return }
        
        // 步骤 3: 转换音频
        convertToAudio(videoURL: videoURL, videoId: videoId)
    }
    
    func convertToAudio(videoURL: URL, videoId: String) {
        AudioConverter.shared.convertVideoToOpusWithProgress(
            inputURL: videoURL,
            progress: { progress in
                print("转换进度: \(Int(progress * 100))%")
            },
            completion: { [weak self] result in
                switch result {
                case .success(let audioURL):
                    // 步骤 4: 更新音频路径
                    VideoStorageManager.shared.updateVideoAudioURL(
                        id: videoId,
                        audioURL: audioURL.path
                    )
                    
                    // 步骤 5: 上传到 COS
                    self?.uploadToCOS(audioURL: audioURL)
                    
                case .failure(let error):
                    print("转换失败: \(error)")
                }
            }
        )
    }
    
    func uploadToCOS(audioURL: URL) {
        COSUploadManager.shared.uploadFile(
            fileURL: audioURL,
            progress: { progress in
                print("上传进度: \(Int(progress * 100))%")
            },
            completion: { result in
                switch result {
                case .success(let cosURL):
                    print("上传成功: \(cosURL)")
                    // 步骤 6: 语音识别
                    self.startASR(audioURL: cosURL)
                    
                case .failure(let error):
                    print("上传失败: \(error)")
                }
            }
        )
    }
    
    func startASR(audioURL: String) {
        ASRManager.shared.createRecognitionTask(audioURL: audioURL) { result in
            switch result {
            case .success(let taskId):
                print("识别任务创建成功: \(taskId)")
            case .failure(let error):
                print("识别失败: \(error)")
            }
        }
    }
    
    func generateThumbnail(from url: URL) -> UIImage? {
        // 生成缩略图逻辑
        return nil
    }
}
```

### 4. 文件管理示例

```swift
class AudioFileManager {
    
    // 列出所有音频文件
    func listAllAudioFiles() {
        let audioFiles = AudioConverter.shared.listConvertedAudioFiles()
        
        print("📁 共有 \(audioFiles.count) 个音频文件:")
        for (index, fileURL) in audioFiles.enumerated() {
            print("\(index + 1). \(fileURL.lastPathComponent)")
            
            // 获取文件大小
            if let fileSize = getFileSize(url: fileURL) {
                print("   大小: \(fileSize)")
            }
        }
    }
    
    // 删除指定音频文件
    func deleteAudioFile(at url: URL) {
        let success = AudioConverter.shared.deleteAudioFile(at: url)
        if success {
            print("✅ 删除成功")
        } else {
            print("❌ 删除失败")
        }
    }
    
    // 清空所有音频文件
    func clearAllAudioFiles() {
        AudioConverter.shared.clearAllConvertedAudioFiles()
        print("🗑️ 已清空所有音频文件")
    }
    
    // 获取文件大小
    func getFileSize(url: URL) -> String? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? Int64 {
                let formatter = ByteCountFormatter()
                formatter.allowedUnits = [.useKB, .useMB]
                formatter.countStyle = .file
                return formatter.string(fromByteCount: fileSize)
            }
        } catch {
            print("获取文件大小失败: \(error)")
        }
        return nil
    }
}
```

### 5. 错误处理示例

```swift
class ErrorHandlingExample {
    
    func convertWithErrorHandling(videoURL: URL) {
        // 检查文件是否存在
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            showError("视频文件不存在")
            return
        }
        
        // 检查磁盘空间
        guard hasEnoughDiskSpace() else {
            showError("磁盘空间不足")
            return
        }
        
        // 开始转换
        AudioConverter.shared.convertVideoToOpus(inputURL: videoURL) { result in
            switch result {
            case .success(let audioURL):
                self.handleSuccess(audioURL: audioURL)
                
            case .failure(let error):
                self.handleError(error: error)
            }
        }
    }
    
    func handleSuccess(audioURL: URL) {
        print("✅ 转换成功")
        
        // 验证输出文件
        if FileManager.default.fileExists(atPath: audioURL.path) {
            print("✅ 音频文件已保存")
        } else {
            print("⚠️ 音频文件未找到")
        }
    }
    
    func handleError(error: Error) {
        if let conversionError = error as? AudioConverter.ConversionError {
            switch conversionError {
            case .invalidInputURL:
                showError("无效的视频文件")
            case .conversionFailed(let message):
                showError("转换失败: \(message)")
            case .fileNotFound:
                showError("找不到视频文件")
            case .saveFailed:
                showError("保存音频文件失败")
            }
        } else {
            showError("未知错误: \(error.localizedDescription)")
        }
    }
    
    func hasEnoughDiskSpace() -> Bool {
        // 检查磁盘空间逻辑
        return true
    }
    
    func showError(_ message: String) {
        print("❌ \(message)")
        // 显示错误提示给用户
    }
}
```

### 6. 批量转换示例

```swift
class BatchConversionExample {
    
    private var conversionQueue: [URL] = []
    private var isProcessing = false
    
    func addToQueue(videoURLs: [URL]) {
        conversionQueue.append(contentsOf: videoURLs)
        processNext()
    }
    
    func processNext() {
        guard !isProcessing, !conversionQueue.isEmpty else { return }
        
        isProcessing = true
        let videoURL = conversionQueue.removeFirst()
        
        print("🎬 开始转换: \(videoURL.lastPathComponent)")
        print("📊 队列剩余: \(conversionQueue.count)")
        
        AudioConverter.shared.convertVideoToOpus(inputURL: videoURL) { [weak self] result in
            self?.isProcessing = false
            
            switch result {
            case .success(let audioURL):
                print("✅ 转换完成: \(audioURL.lastPathComponent)")
            case .failure(let error):
                print("❌ 转换失败: \(error)")
            }
            
            // 处理下一个
            self?.processNext()
        }
    }
    
    func cancelAll() {
        conversionQueue.removeAll()
        print("🛑 已取消所有待转换任务")
    }
}
```

## 测试代码

```swift
// 在 ViewController 或 View 中测试

func testFFmpegIntegration() {
    // 测试 1: 简单转换
    testSimpleConversion()
    
    // 测试 2: 带进度转换
    testProgressConversion()
    
    // 测试 3: 文件管理
    testFileManagement()
}

func testSimpleConversion() {
    print("🧪 测试简单转换...")
    
    guard let videoURL = getTestVideoURL() else {
        print("❌ 找不到测试视频")
        return
    }
    
    AudioConverter.shared.convertVideoToOpus(inputURL: videoURL) { result in
        switch result {
        case .success(let audioURL):
            print("✅ 测试通过: \(audioURL.lastPathComponent)")
        case .failure(let error):
            print("❌ 测试失败: \(error)")
        }
    }
}

func testProgressConversion() {
    print("🧪 测试进度转换...")
    
    guard let videoURL = getTestVideoURL() else { return }
    
    AudioConverter.shared.convertVideoToOpusWithProgress(
        inputURL: videoURL,
        progress: { progress in
            print("进度: \(Int(progress * 100))%")
        },
        completion: { result in
            switch result {
            case .success:
                print("✅ 进度测试通过")
            case .failure(let error):
                print("❌ 进度测试失败: \(error)")
            }
        }
    )
}

func testFileManagement() {
    print("🧪 测试文件管理...")
    
    let audioFiles = AudioConverter.shared.listConvertedAudioFiles()
    print("✅ 找到 \(audioFiles.count) 个音频文件")
    
    for file in audioFiles {
        print("  - \(file.lastPathComponent)")
    }
}

func getTestVideoURL() -> URL? {
    // 返回测试视频 URL
    // 可以使用 Bundle 中的视频或临时视频
    return Bundle.main.url(forResource: "test", withExtension: "mp4")
}
```

## 常见问题

### Q: 如何选择合适的比特率？

A: 根据用途选择：
- 语音识别: 48k-64k
- 语音通话: 32k-64k
- 音乐播放: 96k-128k

### Q: 转换需要多长时间？

A: 大致估算：
- 1 分钟视频 ≈ 5-10 秒
- 10 分钟视频 ≈ 1-2 分钟
- 实际时间取决于设备性能

### Q: 如何减小音频文件大小？

A: 三种方法：
1. 降低比特率（32k-48k）
2. 使用单声道（-ac 1）
3. 降低采样率（24000）

### Q: 转换失败怎么办？

A: 检查以下几点：
1. 输入文件是否存在
2. 输入文件格式是否支持
3. 磁盘空间是否充足
4. 查看 FFmpeg 输出日志

## 完成 ✅

现在你可以开始使用 FFmpeg 进行视频转音频了！

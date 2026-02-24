import Foundation
import ffmpegkit

// MARK: - Audio Converter Manager
class AudioConverter {
    static let shared = AudioConverter()
    
    private init() {}
    
    // MARK: - 转换结果
    enum ConversionResult {
        case success(outputURL: URL)
        case failure(error: Error)
    }
    
    enum ConversionError: LocalizedError {
        case invalidInputURL
        case conversionFailed(message: String)
        case fileNotFound
        case saveFailed
        
        var errorDescription: String? {
            switch self {
            case .invalidInputURL:
                return "无效的输入文件路径"
            case .conversionFailed(let message):
                return "转换失败: \(message)"
            case .fileNotFound:
                return "找不到输入文件"
            case .saveFailed:
                return "保存文件失败"
            }
        }
    }
    
    // MARK: - 获取 Documents 目录
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    // MARK: - 生成输出文件路径
    private func generateOutputPath(for inputURL: URL) -> URL {
        let fileName = inputURL.deletingPathExtension().lastPathComponent
        let timestamp = Int(Date().timeIntervalSince1970)
        let outputFileName = "\(fileName)_\(timestamp).opus"
        return getDocumentsDirectory().appendingPathComponent(outputFileName)
    }
    
    // MARK: - 视频转 Opus 音频
    /// 将视频文件转换为 Opus 格式音频
    /// - Parameters:
    ///   - inputURL: 输入视频文件 URL
    ///   - bitrate: 音频比特率（默认 64k）
    ///   - sampleRate: 采样率（默认 48000）
    ///   - completion: 完成回调
    func convertVideoToOpus(
        inputURL: URL,
        bitrate: String = "64k",
        sampleRate: Int = 48000,
        completion: @escaping (ConversionResult) -> Void
    ) {
        // 检查输入文件是否存在
        guard FileManager.default.fileExists(atPath: inputURL.path) else {
            completion(.failure(error: ConversionError.fileNotFound))
            return
        }
        
        // 生成输出文件路径
        let outputURL = generateOutputPath(for: inputURL)
        
        // 如果输出文件已存在，先删除
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }
        
        // 构建 FFmpeg 命令
        let command = "-i \"\(inputURL.path)\" -vn -c:a libopus -b:a \(bitrate) -ar \(sampleRate) -ac 1 -y \"\(outputURL.path)\""
        
        print("🎬 开始转换视频到 Opus 音频...")
        print("📥 输入: \(inputURL.lastPathComponent)")
        print("📤 输出: \(outputURL.lastPathComponent)")
        print("⚙️ 命令: \(command)")
        
        // 异步执行转换
        DispatchQueue.global(qos: .userInitiated).async {
            FFmpegKit.executeAsync(command) { session in
                guard let session = session else {
                    DispatchQueue.main.async {
                        completion(.failure(error: ConversionError.conversionFailed(message: "Session is nil")))
                    }
                    return
                }
                
                let returnCode = session.getReturnCode()
                
                DispatchQueue.main.async {
                    if ReturnCode.isSuccess(returnCode) {
                        // 检查输出文件是否存在
                        if FileManager.default.fileExists(atPath: outputURL.path) {
                            print("✅ 转换成功!")
                            print("📁 文件路径: \(outputURL.path)")
                            
                            // 获取文件大小
                            if let fileSize = self.getFileSize(url: outputURL) {
                                print("📊 文件大小: \(fileSize)")
                            }
                            
                            completion(.success(outputURL: outputURL))
                        } else {
                            completion(.failure(error: ConversionError.saveFailed))
                        }
                    } else {
                        let errorMessage = "Return code: \(String(describing: returnCode))"
                        print("❌ 转换失败: \(errorMessage)")
                        
                        // 获取详细错误信息
                        if let output = session.getOutput() {
                            print("📋 FFmpeg 输出: \(output)")
                        }
                        
                        completion(.failure(error: ConversionError.conversionFailed(message: errorMessage)))
                    }
                }
            }
        }
    }
    
    // MARK: - 视频转 Opus 音频（带进度）
    /// 将视频文件转换为 Opus 格式音频（带进度回调）
    /// - Parameters:
    ///   - inputURL: 输入视频文件 URL
    ///   - bitrate: 音频比特率（默认 64k）
    ///   - sampleRate: 采样率（默认 48000）
    ///   - progress: 进度回调（0.0 - 1.0）
    ///   - completion: 完成回调
    func convertVideoToOpusWithProgress(
        inputURL: URL,
        bitrate: String = "64k",
        sampleRate: Int = 48000,
        progress: @escaping (Double) -> Void,
        completion: @escaping (ConversionResult) -> Void
    ) {
        // 检查输入文件是否存在
        guard FileManager.default.fileExists(atPath: inputURL.path) else {
            completion(.failure(error: ConversionError.fileNotFound))
            return
        }
        
        // 生成输出文件路径
        let outputURL = generateOutputPath(for: inputURL)
        
        // 如果输出文件已存在，先删除
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }
        
        // 构建 FFmpeg 命令
        let command = "-i \"\(inputURL.path)\" -vn -c:a libopus -b:a \(bitrate) -ar \(sampleRate) -ac 1 -y \"\(outputURL.path)\""
        
        print("🎬 开始转换视频到 Opus 音频（带进度）...")
        print("📥 输入: \(inputURL.lastPathComponent)")
        print("📤 输出: \(outputURL.lastPathComponent)")
        
        // 获取视频时长
        let duration = getVideoDuration(url: inputURL)
        
        // 异步执行转换
        DispatchQueue.global(qos: .userInitiated).async {
            FFmpegKit.executeAsync(command, withCompleteCallback: { session in
                guard let session = session else {
                    DispatchQueue.main.async {
                        completion(.failure(error: ConversionError.conversionFailed(message: "Session is nil")))
                    }
                    return
                }
                
                let returnCode = session.getReturnCode()
                
                DispatchQueue.main.async {
                    if ReturnCode.isSuccess(returnCode) {
                        if FileManager.default.fileExists(atPath: outputURL.path) {
                            print("✅ 转换成功!")
                            print("📁 文件路径: \(outputURL.path)")
                            
                            if let fileSize = self.getFileSize(url: outputURL) {
                                print("📊 文件大小: \(fileSize)")
                            }
                            
                            completion(.success(outputURL: outputURL))
                        } else {
                            completion(.failure(error: ConversionError.saveFailed))
                        }
                    } else {
                        let errorMessage = "Return code: \(String(describing: returnCode))"
                        print("❌ 转换失败: \(errorMessage)")
                        
                        if let output = session.getOutput() {
                            print("📋 FFmpeg 输出: \(output)")
                        }
                        
                        completion(.failure(error: ConversionError.conversionFailed(message: errorMessage)))
                    }
                }
            }, withLogCallback: nil, withStatisticsCallback: { statistics in
                guard let statistics = statistics else { return }
                
                // 计算进度（基于时间）
                let time = statistics.getTime()
                
                if duration > 0 {
                    let progressValue = min(Double(time) / (duration * 1000.0), 1.0)
                    DispatchQueue.main.async {
                        progress(progressValue)
                    }
                }
            })
        }
    }
    
    // MARK: - 获取视频时长
    private func getVideoDuration(url: URL) -> Double {
        let session = FFprobeKit.getMediaInformation(url.path)
        if let mediaInfo = session?.getMediaInformation() {
            if let durationString = mediaInfo.getDuration() {
                return Double(durationString) ?? 0
            }
        }
        return 0
    }
    
    // MARK: - 获取文件大小
    private func getFileSize(url: URL) -> String? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? Int64 {
                return formatFileSize(bytes: fileSize)
            }
        } catch {
            print("获取文件大小失败: \(error)")
        }
        return nil
    }
    
    // MARK: - 格式化文件大小
    private func formatFileSize(bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    // MARK: - 删除音频文件
    func deleteAudioFile(at url: URL) -> Bool {
        do {
            try FileManager.default.removeItem(at: url)
            print("🗑️ 已删除音频文件: \(url.lastPathComponent)")
            return true
        } catch {
            print("❌ 删除文件失败: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - 列出所有已转换的音频文件
    func listConvertedAudioFiles() -> [URL] {
        let documentsURL = getDocumentsDirectory()
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: documentsURL,
                includingPropertiesForKeys: [.creationDateKey],
                options: .skipsHiddenFiles
            )
            
            // 筛选 .opus 文件
            let opusFiles = fileURLs.filter { $0.pathExtension == "opus" }
            
            // 按创建时间排序
            let sortedFiles = opusFiles.sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                return date1 > date2
            }
            
            return sortedFiles
        } catch {
            print("❌ 列出文件失败: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - 清空所有转换的音频文件
    func clearAllConvertedAudioFiles() {
        let audioFiles = listConvertedAudioFiles()
        
        for fileURL in audioFiles {
            _ = deleteAudioFile(at: fileURL)
        }
        
        print("🗑️ 已清空所有转换的音频文件，共 \(audioFiles.count) 个")
    }
}

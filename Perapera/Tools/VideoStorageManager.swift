import Foundation
import UIKit
import AVFoundation

// MARK: - Video Model
struct VideoItem: Codable, Identifiable {
    let id: String
    let name: String
    let posterImageData: Data? // 海报图片的 Data
    let videoURL: String // 视频地址（本地路径或远程URL）
    let createdAt: Date
    let isYouTube: Bool // 是否是 YouTube 视频
    let duration: Double? // 视频时长（秒）
    
    init(id: String? = nil, name: String, posterImageData: Data?, videoURL: String, createdAt: Date? = nil, isYouTube: Bool = false, duration: Double? = nil) {
        if let id = id {
            self.id = id
        } else {
            let timestamp = Int(Date().timeIntervalSince1970)
            self.id = "\(UUID().uuidString)-\(timestamp)"
        }
        
        self.name = name
        self.posterImageData = posterImageData
        self.videoURL = videoURL
        self.createdAt = createdAt ?? Date()
        self.isYouTube = isYouTube
        self.duration = duration
    }
    
    // 自定义解码，处理旧数据兼容性
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        posterImageData = try container.decodeIfPresent(Data.self, forKey: .posterImageData)
        videoURL = try container.decode(String.self, forKey: .videoURL)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        duration = try container.decodeIfPresent(Double.self, forKey: .duration)
        
        // 兼容旧数据：如果没有 isYouTube 字段，根据 URL 判断
        if let isYouTube = try? container.decode(Bool.self, forKey: .isYouTube) {
            self.isYouTube = isYouTube
        } else {
            // 旧数据：根据 URL 判断是否是 YouTube
            self.isYouTube = videoURL.contains("youtube") || videoURL.contains("youtu.be")
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, name, posterImageData, videoURL, createdAt, isYouTube, duration
    }
    
    // 获取海报图片
    var posterImage: UIImage? {
        guard let data = posterImageData else { return nil }
        return UIImage(data: data)
    }
    
    // 获取 Documents 目录
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    // 本地视频文件路径
    var localVideoURL: URL {
        documentsDirectory.appendingPathComponent("\(id).mp4")
    }
    
    // 音频文件路径
    var audioURL: URL {
        documentsDirectory.appendingPathComponent("\(id).opus")
    }
    
    // 识别结果文件路径
    var recognitionURL: URL {
        documentsDirectory.appendingPathComponent("\(id).json")
    }
    
    // 翻译结果文件路径
    var translationURL: URL {
        documentsDirectory.appendingPathComponent("\(id)_translation.txt")
    }
    
    // 是否已转换音频
    var hasAudio: Bool {
        FileManager.default.fileExists(atPath: audioURL.path)
    }
    
    // 是否已识别
    var hasRecognition: Bool {
        FileManager.default.fileExists(atPath: recognitionURL.path)
    }
    
    // 是否已翻译
    var hasTranslation: Bool {
        FileManager.default.fileExists(atPath: translationURL.path)
    }
    
    // 获取实际的视频 URL（YouTube 返回原 URL，本地视频返回 Documents 路径）
    var actualVideoURL: URL {
        if isYouTube {
            return URL(string: videoURL) ?? localVideoURL
        } else {
            // 对于旧数据，如果 videoURL 不为空且文件存在，使用旧路径
            if !videoURL.isEmpty && FileManager.default.fileExists(atPath: videoURL) {
                return URL(fileURLWithPath: videoURL)
            }
            // 否则使用新的 Documents 路径
            return localVideoURL
        }
    }
}

// MARK: - Video Storage Manager
class VideoStorageManager {
    static let shared = VideoStorageManager()
    
    private let userDefaultsKey = "saved_video_list"
    private let maxImageSize: CGFloat = 300 // 压缩图片最大尺寸
    
    private init() {}
    
    // MARK: - 保存视频列表
    func saveVideos(_ videos: [VideoItem]) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(videos)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            print("✅ 视频列表保存成功，共 \(videos.count) 个视频")
        } catch {
            print("❌ 保存视频列表失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 读取视频列表
    func loadVideos() -> [VideoItem] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            print("📭 没有保存的视频列表")
            return []
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let videos = try decoder.decode([VideoItem].self, from: data)
            print("✅ 读取视频列表成功，共 \(videos.count) 个视频")
            return videos
        } catch {
            print("❌ 读取视频列表失败: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - 添加单个视频
    func addVideo(name: String, posterImage: UIImage?, videoURL: String, isYouTube: Bool = false, duration: Double? = nil) -> VideoItem {
        var videos = loadVideos()
        
        // 压缩图片
        let compressedImageData = compressImage(posterImage)
        
        let newVideo = VideoItem(
            name: name,
            posterImageData: compressedImageData,
            videoURL: videoURL,
            isYouTube: isYouTube,
            duration: duration
        )
        
        videos.insert(newVideo, at: 0) // 插入到最前面
        saveVideos(videos)
        
        return newVideo
    }
    
    // MARK: - 添加本地视频（复制到 Documents）
    func addLocalVideo(name: String, posterImage: UIImage?, sourceURL: URL) -> VideoItem? {
        var videos = loadVideos()
        
        // 压缩图片
        let compressedImageData = compressImage(posterImage)
        
        // 获取视频时长
        let asset = AVURLAsset(url: sourceURL)
        let duration = CMTimeGetSeconds(asset.duration)
        let durationSeconds = duration.isNaN ? nil : duration
        
        let newVideo = VideoItem(
            name: name,
            posterImageData: compressedImageData,
            videoURL: "", // 本地视频不需要存储原始 URL
            isYouTube: false,
            duration: durationSeconds
        )
        
        // 复制视频文件到 Documents 目录
        do {
            // 如果目标文件已存在，先删除
            if FileManager.default.fileExists(atPath: newVideo.localVideoURL.path) {
                try FileManager.default.removeItem(at: newVideo.localVideoURL)
            }
            
            // 复制文件
            try FileManager.default.copyItem(at: sourceURL, to: newVideo.localVideoURL)
            
            print("✅ 视频文件已复制到 Documents")
            print("📂 源路径: \(sourceURL.path)")
            print("📂 目标路径: \(newVideo.localVideoURL.path)")
            
            // 获取文件大小
            if let fileSize = try? FileManager.default.attributesOfItem(atPath: newVideo.localVideoURL.path)[.size] as? Int64 {
                let formatter = ByteCountFormatter()
                formatter.allowedUnits = [.useKB, .useMB, .useGB]
                formatter.countStyle = .file
                print("📊 文件大小: \(formatter.string(fromByteCount: fileSize))")
            }
            
            videos.insert(newVideo, at: 0)
            saveVideos(videos)
            
            return newVideo
            
        } catch {
            print("❌ 复制视频文件失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - 删除视频
    func deleteVideo(id: String) {
        var videos = loadVideos()
        
        // 查找要删除的视频
        if let video = videos.first(where: { $0.id == id }) {
            // 删除关联的本地视频文件
            if !video.isYouTube {
                try? FileManager.default.removeItem(at: video.localVideoURL)
                print("🗑️ 已删除关联的视频文件")
            }
            
            // 删除关联的音频文件
            try? FileManager.default.removeItem(at: video.audioURL)
            print("🗑️ 已删除关联的音频文件")
            
            // 删除关联的识别结果文件
            try? FileManager.default.removeItem(at: video.recognitionURL)
            print("🗑️ 已删除关联的识别结果文件")
            
            // 删除关联的翻译结果文件
            try? FileManager.default.removeItem(at: video.translationURL)
            print("🗑️ 已删除关联的翻译结果文件")
        }
        
        videos.removeAll { $0.id == id }
        saveVideos(videos)
    }
    
    // MARK: - 更新视频
    func updateVideo(id: String, name: String? = nil, posterImage: UIImage? = nil, videoURL: String? = nil) {
        var videos = loadVideos()
        
        guard let index = videos.firstIndex(where: { $0.id == id }) else {
            print("❌ 未找到ID为 \(id) 的视频")
            return
        }
        
        let oldVideo = videos[index]
        let compressedImageData = posterImage != nil ? compressImage(posterImage) : oldVideo.posterImageData
        
        let updatedVideo = VideoItem(
            id: oldVideo.id,
            name: name ?? oldVideo.name,
            posterImageData: compressedImageData,
            videoURL: videoURL ?? oldVideo.videoURL,
            isYouTube: oldVideo.isYouTube,
            duration: oldVideo.duration
        )
        
        videos[index] = updatedVideo
        saveVideos(videos)
    }
    
    // MARK: - 刷新视频时长（针对旧数据）
    @discardableResult
    func refreshVideoDurations() -> Bool {
        var videos = loadVideos()
        var hasChanges = false
        
        for i in 0..<videos.count {
            let video = videos[i]
            if video.duration == nil && !video.isYouTube {
                // 如果是本地视频，尝试获取时长
                let asset = AVURLAsset(url: video.actualVideoURL)
                let duration = CMTimeGetSeconds(asset.duration)
                
                if !duration.isNaN && duration > 0 {
                    let updatedVideo = VideoItem(
                        id: video.id,
                        name: video.name,
                        posterImageData: video.posterImageData,
                        videoURL: video.videoURL,
                        createdAt: video.createdAt,
                        isYouTube: video.isYouTube,
                        duration: duration
                    )
                    videos[i] = updatedVideo
                    hasChanges = true
                    print("✅ 已更新视频时长: \(video.name) - \(duration)s")
                }
            }
        }
        
        if hasChanges {
            saveVideos(videos)
        }
        
        return hasChanges
    }
    
    // MARK: - 清空所有视频
    func clearAllVideos() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        print("🗑️ 已清空所有视频")
    }
    
    // MARK: - 压缩图片
    private func compressImage(_ image: UIImage?) -> Data? {
        guard let image = image else { return nil }
        
        // 调整图片尺寸
        let resizedImage = resizeImage(image, maxSize: maxImageSize)
        
        // 压缩为 JPEG，质量 0.7
        return resizedImage.jpegData(compressionQuality: 0.7)
    }
    
    // MARK: - 调整图片尺寸
    private func resizeImage(_ image: UIImage, maxSize: CGFloat) -> UIImage {
        let size = image.size
        
        // 如果图片已经小于最大尺寸，直接返回
        if size.width <= maxSize && size.height <= maxSize {
            return image
        }
        
        // 计算缩放比例
        let ratio = min(maxSize / size.width, maxSize / size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        // 创建新图片
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage ?? image
    }
}

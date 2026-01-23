import Foundation
import UIKit

// MARK: - Video Model
struct VideoItem: Codable, Identifiable {
    let id: String
    let name: String
    let posterImageData: Data? // 海报图片的 Data
    let videoURL: String // 视频地址（本地路径或远程URL）
    let createdAt: Date
    
    init(name: String, posterImageData: Data?, videoURL: String) {
        self.id = UUID().uuidString
        self.name = name
        self.posterImageData = posterImageData
        self.videoURL = videoURL
        self.createdAt = Date()
    }
    
    // 获取海报图片
    var posterImage: UIImage? {
        guard let data = posterImageData else { return nil }
        return UIImage(data: data)
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
    func addVideo(name: String, posterImage: UIImage?, videoURL: String) {
        var videos = loadVideos()
        
        // 压缩图片
        let compressedImageData = compressImage(posterImage)
        
        let newVideo = VideoItem(
            name: name,
            posterImageData: compressedImageData,
            videoURL: videoURL
        )
        
        videos.insert(newVideo, at: 0) // 插入到最前面
        saveVideos(videos)
    }
    
    // MARK: - 删除视频
    func deleteVideo(id: String) {
        var videos = loadVideos()
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
            name: name ?? oldVideo.name,
            posterImageData: compressedImageData,
            videoURL: videoURL ?? oldVideo.videoURL
        )
        
        videos[index] = updatedVideo
        saveVideos(videos)
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

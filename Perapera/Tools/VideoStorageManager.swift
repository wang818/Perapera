import Foundation
import UIKit
import AVFoundation

// MARK: - Video Model
struct VideoItem: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let posterImageData: Data? // 海报图片的 Data
    let videoURL: String // 视频地址（本地路径或远程URL）
    let createdAt: Date
    let isYouTube: Bool // 是否是 YouTube 视频
    let duration: Double? // 视频时长（秒）

    // YouTube 元信息（仅 isYouTube == true 时使用）
    let youtubeVideoID: String?
    let author: String?
    let numberOfViews: String?
    let videoDescription: String?
    let channelID: String?
    let category: String?
    let publishedTime: String?
    let keywords: [String]?
    let thumbnailURL: String?

    init(id: String? = nil, name: String, posterImageData: Data?, videoURL: String, createdAt: Date? = nil, isYouTube: Bool = false, duration: Double? = nil, youtubeVideoID: String? = nil, author: String? = nil, numberOfViews: String? = nil, videoDescription: String? = nil, channelID: String? = nil, category: String? = nil, publishedTime: String? = nil, keywords: [String]? = nil, thumbnailURL: String? = nil) {
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
        self.youtubeVideoID = youtubeVideoID
        self.author = author
        self.numberOfViews = numberOfViews
        self.videoDescription = videoDescription
        self.channelID = channelID
        self.category = category
        self.publishedTime = publishedTime
        self.keywords = keywords
        self.thumbnailURL = thumbnailURL
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

        // YouTube 元信息（旧数据可能没有 → 解码失败时给 nil）
        self.youtubeVideoID = try? container.decodeIfPresent(String.self, forKey: .youtubeVideoID)
        self.author = try? container.decodeIfPresent(String.self, forKey: .author)
        self.numberOfViews = try? container.decodeIfPresent(String.self, forKey: .numberOfViews)
        self.videoDescription = try? container.decodeIfPresent(String.self, forKey: .videoDescription)
        self.channelID = try? container.decodeIfPresent(String.self, forKey: .channelID)
        self.category = try? container.decodeIfPresent(String.self, forKey: .category)
        self.publishedTime = try? container.decodeIfPresent(String.self, forKey: .publishedTime)
        self.keywords = try? container.decodeIfPresent([String].self, forKey: .keywords)
        self.thumbnailURL = try? container.decodeIfPresent(String.self, forKey: .thumbnailURL)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, posterImageData, videoURL, createdAt, isYouTube, duration
        case youtubeVideoID, author, numberOfViews, videoDescription, channelID, category, publishedTime, keywords, thumbnailURL
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

    /// 返回一个仅替换了「时长」字段的新实例（其余字段原样保留）。
    func withDuration(_ seconds: Double) -> VideoItem {
        VideoItem(
            id: id,
            name: name,
            posterImageData: posterImageData,
            videoURL: videoURL,
            createdAt: createdAt,
            isYouTube: isYouTube,
            duration: seconds,
            youtubeVideoID: youtubeVideoID,
            author: author,
            numberOfViews: numberOfViews,
            videoDescription: videoDescription,
            channelID: channelID,
            category: category,
            publishedTime: publishedTime,
            keywords: keywords,
            thumbnailURL: thumbnailURL
        )
    }
}

// MARK: - 媒体时长读取
enum MediaDurationLoader {
    /// 可靠地异步读取媒体文件时长（三级兜底）。
    ///
    /// 为什么不能直接用 `AVURLAsset.duration`：这个同步属性已废弃，当 mp4 的 `moov`
    /// 元数据位于文件末尾（许多录制/下载/转码工具会这样写）、文件较大或需要异步加载时，
    /// 它会直接返回 `.indefinite`（即 NaN），导致时长读成 nil。
    ///
    /// 读取顺序：
    /// 1. `AVURLAsset` + `loadValuesAsynchronously(forKeys:)`（官方推荐，覆盖绝大多数文件）
    /// 2. FFprobe 解析容器元数据
    /// 3. 纯 Swift 解析 MP4/MOV 的 `moov → mvhd` box（不依赖任何第三方库）
    /// - Parameters:
    ///   - url: 本地媒体文件 URL
    ///   - completion: 主线程回调；读取失败或时长非法时返回 nil
    static func load(of url: URL, completion: @escaping (Double?) -> Void) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            DispatchQueue.main.async { completion(nil) }
            return
        }

        // 要求精确时长，避免只拿到估算值
        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        asset.loadValuesAsynchronously(forKeys: ["duration"]) {
            var error: NSError?
            let status = asset.statusOfValue(forKey: "duration", error: &error)

            if status == .loaded {
                let value = CMTimeGetSeconds(asset.duration)
                if value.isFinite && value > 0 {
                    DispatchQueue.main.async { completion(value) }
                    return
                }
            }

            // 兜底 2：FFprobe 解析容器元数据（同步阻塞，此时已在后台队列，可接受）
            print("⚠️ AVAsset 读取时长失败(\(status.rawValue))，改用 FFprobe: \(url.lastPathComponent) \(error?.localizedDescription ?? "")")
            let probed = AudioConverter.shared.getMediaDurationSeconds(url: url)
            if probed > 0 {
                DispatchQueue.main.async { completion(probed) }
                return
            }

            // 兜底 3：直接解析 mp4/mov 的 mvhd box（纯 Swift，无任何依赖）
            print("⚠️ FFprobe 也读不到时长，改用 mvhd 解析: \(url.lastPathComponent)")
            let parsed = mp4Duration(of: url)
            DispatchQueue.main.async { completion(parsed) }
        }
    }

    /// 纯 Swift 解析 MP4/MOV 容器时长：读取顶层 `moov` box 内的 `mvhd` box。
    ///
    /// `mvhd` 中保存了 `timescale`（每秒刻度数）与 `duration`（刻度数），
    /// 二者相除即秒数。该方式不依赖 AVFoundation / FFmpeg，对 `moov` 位于文件末尾的
    /// 文件同样有效（按 box 头顺序 seek，不会整文件读入内存）。
    /// - Returns: 秒数（> 0），解析失败返回 nil
    static func mp4Duration(of url: URL) -> Double? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let totalSize = (attrs[.size] as? NSNumber)?.uint64Value, totalSize > 0 else {
            return nil
        }

        /// 在 [start, end) 范围内顺序扫描 box，返回指定 type 的「载荷区间」
        func findBox(_ type: String, in start: UInt64, to end: UInt64) -> (offset: UInt64, size: UInt64)? {
            var cursor = start
            while cursor + 8 <= end {
                handle.seek(toFileOffset: cursor)
                let header = handle.readData(ofLength: 8)
                guard header.count == 8 else { return nil }

                var boxSize = UInt64(header.beUInt32(at: 0))
                let boxType = header.beString(at: 4, length: 4)
                var headerSize: UInt64 = 8

                if boxSize == 1 {
                    // 64 位 largesize
                    let ext = handle.readData(ofLength: 8)
                    guard ext.count == 8 else { return nil }
                    boxSize = ext.beUInt64(at: 0)
                    headerSize = 16
                } else if boxSize == 0 {
                    // 延伸到文件末尾
                    boxSize = end - cursor
                }

                guard boxSize >= headerSize, cursor + boxSize <= end else { return nil }

                if boxType == type {
                    return (cursor + headerSize, boxSize - headerSize)
                }
                cursor += boxSize
            }
            return nil
        }

        guard let moov = findBox("moov", in: 0, to: totalSize) else { return nil }
        guard let mvhd = findBox("mvhd", in: moov.offset, to: moov.offset + moov.size) else { return nil }

        handle.seek(toFileOffset: mvhd.offset)
        let payload = handle.readData(ofLength: 32)
        guard payload.count >= 20 else { return nil }

        let version = payload[0]
        let timescale: UInt32
        let duration: UInt64

        if version == 1 {
            // version 1：creation(8) modification(8) timescale(4) duration(8)
            guard payload.count >= 32 else { return nil }
            timescale = payload.beUInt32(at: 20)
            duration = payload.beUInt64(at: 24)
        } else {
            // version 0：creation(4) modification(4) timescale(4) duration(4)
            timescale = payload.beUInt32(at: 12)
            duration = UInt64(payload.beUInt32(at: 16))
        }

        guard timescale > 0, duration > 0 else { return nil }

        let seconds = Double(duration) / Double(timescale)
        return (seconds.isFinite && seconds > 0) ? seconds : nil
    }
}

// MARK: - 大端读取辅助
private extension Data {
    func beUInt32(at offset: Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        let base = startIndex + offset
        return (UInt32(self[base]) << 24)
            | (UInt32(self[base + 1]) << 16)
            | (UInt32(self[base + 2]) << 8)
            | UInt32(self[base + 3])
    }

    func beUInt64(at offset: Int) -> UInt64 {
        guard offset + 8 <= count else { return 0 }
        let base = startIndex + offset
        var value: UInt64 = 0
        for i in 0..<8 {
            value = (value << 8) | UInt64(self[base + i])
        }
        return value
    }

    func beString(at offset: Int, length: Int) -> String {
        guard offset + length <= count else { return "" }
        let base = startIndex + offset
        return String(bytes: self[base..<(base + length)], encoding: .ascii) ?? ""
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
    func addVideo(name: String, posterImage: UIImage?, videoURL: String, isYouTube: Bool = false, duration: Double? = nil, youtubeVideoID: String? = nil, author: String? = nil, numberOfViews: String? = nil, videoDescription: String? = nil, channelID: String? = nil, category: String? = nil, publishedTime: String? = nil, keywords: [String]? = nil, thumbnailURL: String? = nil) -> VideoItem {
        var videos = loadVideos()

        // 压缩图片
        let compressedImageData = compressImage(posterImage)

        let newVideo = VideoItem(
            name: name,
            posterImageData: compressedImageData,
            videoURL: videoURL,
            isYouTube: isYouTube,
            duration: duration,
            youtubeVideoID: youtubeVideoID,
            author: author,
            numberOfViews: numberOfViews,
            videoDescription: videoDescription,
            channelID: channelID,
            category: category,
            publishedTime: publishedTime,
            keywords: keywords,
            thumbnailURL: thumbnailURL
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
        
        let newVideo = VideoItem(
            name: name,
            posterImageData: compressedImageData,
            videoURL: "", // 本地视频不需要存储原始 URL
            isYouTube: false,
            duration: nil // 时长稍后从已落盘的本地文件异步补全
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
            
            // 从已落盘的本地文件异步读取时长：
            // 源 URL（相册 / 文件 App 的临时文件）常常无法同步取到时长，落盘后再读最稳。
            MediaDurationLoader.load(of: newVideo.localVideoURL) { [weak self] seconds in
                guard let self = self, let seconds = seconds else { return }
                self.updateVideoDuration(id: newVideo.id, duration: seconds)
                NotificationCenter.default.post(name: NSNotification.Name("HomeViewShouldRefreshVideos"), object: nil)
            }
            
            return newVideo
            
        } catch {
            print("❌ 复制视频文件失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - 补全/更新单个视频的时长
    func updateVideoDuration(id: String, duration: Double) {
        guard duration.isFinite, duration > 0 else { return }
        
        var videos = loadVideos()
        guard let index = videos.firstIndex(where: { $0.id == id }) else { return }
        
        let video = videos[index]
        // 已有合法时长则不重复写入
        if let existing = video.duration, existing > 0 { return }
        
        videos[index] = video.withDuration(duration)
        saveVideos(videos)
        print("✅ 已补全视频时长: \(video.name) - \(duration)s")
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
    func updateVideo(id: String, name: String? = nil, posterImage: UIImage? = nil, videoURL: String? = nil, youtubeVideoID: String? = nil, author: String? = nil, numberOfViews: String? = nil, videoDescription: String? = nil, channelID: String? = nil, category: String? = nil, publishedTime: String? = nil, keywords: [String]? = nil, thumbnailURL: String? = nil) {
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
            createdAt: oldVideo.createdAt,
            isYouTube: oldVideo.isYouTube,
            duration: oldVideo.duration,
            youtubeVideoID: youtubeVideoID ?? oldVideo.youtubeVideoID,
            author: author ?? oldVideo.author,
            numberOfViews: numberOfViews ?? oldVideo.numberOfViews,
            videoDescription: videoDescription ?? oldVideo.videoDescription,
            channelID: channelID ?? oldVideo.channelID,
            category: category ?? oldVideo.category,
            publishedTime: publishedTime ?? oldVideo.publishedTime,
            keywords: keywords ?? oldVideo.keywords,
            thumbnailURL: thumbnailURL ?? oldVideo.thumbnailURL
        )

        videos[index] = updatedVideo
        saveVideos(videos)
    }
    
    // MARK: - 刷新视频时长（针对旧数据 / 之前未能读到的记录）
    /// 异步逐个补全「缺失或为 0」的视频时长，完成后在主线程回调是否有变更。
    ///
    /// 关键点：不再使用已废弃的同步 `AVURLAsset.duration`（对 moov 在文件末尾等
    /// 场景恒返回 NaN），统一走 `MediaDurationLoader` 的异步加载。
    func refreshVideoDurations(completion: ((Bool) -> Void)? = nil) {
        DispatchQueue.global(qos: .userInitiated).async {
            var videos = self.loadVideos()
            let indices = videos.indices.filter { (videos[$0].duration ?? 0) <= 0 }
            guard !indices.isEmpty else {
                DispatchQueue.main.async { completion?(false) }
                return
            }

            var hasChanges = false

            func process(_ cursor: Int) {
                guard cursor < indices.count else {
                    DispatchQueue.main.async {
                        if hasChanges { self.saveVideos(videos) }
                        completion?(hasChanges)
                    }
                    return
                }

                let index = indices[cursor]
                let video = videos[index]

                MediaDurationLoader.load(of: video.actualVideoURL) { seconds in
                    if let seconds = seconds, seconds > 0 {
                        videos[index] = video.withDuration(seconds)
                        hasChanges = true
                        print("✅ 已更新视频时长: \(video.name) - \(seconds)s")
                    }
                    process(cursor + 1)
                }
            }

            process(0)
        }
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

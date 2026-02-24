import Foundation

// MARK: - 字幕项
struct SubtitleItem: Codable, Identifiable {
    let id: String
    let startTime: Double      // 开始时间（秒）
    let endTime: Double        // 结束时间（秒）
    let originalText: String   // 原文（ASR 识别的文本）
    let translatedText: String // 译文（日文翻译）
    
    init(id: String = UUID().uuidString, startTime: Double, endTime: Double, originalText: String, translatedText: String = "") {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.originalText = originalText
        self.translatedText = translatedText
    }
    
    // 判断当前时间是否在字幕时间范围内
    func isActive(at currentTime: Double) -> Bool {
        return currentTime >= startTime && currentTime <= endTime
    }
}

// MARK: - 字幕数据
struct SubtitleData: Codable {
    let videoId: String
    var subtitles: [SubtitleItem]
    
    init(videoId: String, subtitles: [SubtitleItem] = []) {
        self.videoId = videoId
        self.subtitles = subtitles
    }
}

// MARK: - 字幕管理器
class SubtitleManager {
    static let shared = SubtitleManager()
    
    private let userDefaultsKey = "video_subtitles"
    
    private init() {}
    
    // MARK: - 保存字幕
    func saveSubtitles(_ subtitleData: SubtitleData) {
        var allSubtitles = loadAllSubtitles()
        
        // 移除旧的字幕数据
        allSubtitles.removeAll { $0.videoId == subtitleData.videoId }
        
        // 添加新的字幕数据
        allSubtitles.append(subtitleData)
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(allSubtitles)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            print("✅ 字幕保存成功，视频ID: \(subtitleData.videoId)")
        } catch {
            print("❌ 保存字幕失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 读取所有字幕
    func loadAllSubtitles() -> [SubtitleData] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return []
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let subtitles = try decoder.decode([SubtitleData].self, from: data)
            return subtitles
        } catch {
            print("❌ 读取字幕失败: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - 读取指定视频的字幕
    func loadSubtitles(for videoId: String) -> SubtitleData? {
        let allSubtitles = loadAllSubtitles()
        return allSubtitles.first { $0.videoId == videoId }
    }
    
    // MARK: - 删除字幕
    func deleteSubtitles(for videoId: String) {
        var allSubtitles = loadAllSubtitles()
        allSubtitles.removeAll { $0.videoId == videoId }
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(allSubtitles)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            print("🗑️ 已删除视频 \(videoId) 的字幕")
        } catch {
            print("❌ 删除字幕失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 从 ASR 结果生成字幕
    /// 从 ASR 识别结果生成字幕（简单分段）
    func generateSubtitlesFromASR(text: String, videoDuration: Double) -> [SubtitleItem] {
        // 按句子分割文本
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: "。！？.!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        guard !sentences.isEmpty else { return [] }
        
        // 计算每个句子的时间
        let timePerSentence = videoDuration / Double(sentences.count)
        
        var subtitles: [SubtitleItem] = []
        for (index, sentence) in sentences.enumerated() {
            let startTime = Double(index) * timePerSentence
            let endTime = startTime + timePerSentence
            
            let subtitle = SubtitleItem(
                startTime: startTime,
                endTime: endTime,
                originalText: sentence,
                translatedText: "" // 待翻译
            )
            subtitles.append(subtitle)
        }
        
        return subtitles
    }
    
    // MARK: - 获取当前时间的字幕
    func getCurrentSubtitle(subtitles: [SubtitleItem], at currentTime: Double) -> SubtitleItem? {
        return subtitles.first { $0.isActive(at: currentTime) }
    }
}

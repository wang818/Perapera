import Foundation

// MARK: - ASR 识别结果模型
struct ASRResponse: Codable {
    let Response: ASRResponseData
}

struct ASRResponseData: Codable {
    let RequestId: String?
    let Data: ASRData?
}

struct ASRData: Codable {
    let TaskId: Int?
    let Status: Int?
    let StatusStr: String?
    let AudioDuration: Double?
    let Result: String?
    let ResultDetail: [ASRResultDetail]?
}

struct ASRResultDetail: Codable {
    let FinalSentence: String
    let StartMs: Int
    let EndMs: Int
    let Words: [ASRWord]?
}

struct ASRWord: Codable {
    let Word: String
    let OffsetStartMs: Int
    let OffsetEndMs: Int
}

// MARK: - 字幕项
struct SubtitleItem: Codable, Identifiable {
    let id: String
    let startTime: Double      // 开始时间（秒）
    let endTime: Double        // 结束时间（秒）
    let originalText: String   // 原文（ASR 识别的文本）
    let translatedText: String // 译文（日文翻译）
    let words: [WordTiming]?   // 词级别的时间信息
    
    init(id: String = UUID().uuidString, startTime: Double, endTime: Double, originalText: String, translatedText: String = "", words: [WordTiming]? = nil) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.originalText = originalText
        self.translatedText = translatedText
        self.words = words
    }
    
    // 判断当前时间是否在字幕时间范围内
    func isActive(at currentTime: Double) -> Bool {
        return currentTime >= startTime && currentTime <= endTime
    }
}

// MARK: - 词级别时间信息
struct WordTiming: Codable {
    let word: String
    let startTime: Double
    let endTime: Double
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
    
    // MARK: - 从 ASR JSON 文件加载字幕
    func loadSubtitlesFromASRFile(videoId: String) -> [SubtitleItem]? {
        // 构建 JSON 文件路径
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let jsonFilePath = documentsPath.appendingPathComponent("\(videoId).json")
        
        print("🔍 尝试加载 ASR 文件: \(jsonFilePath.path)")
        
        // 检查文件是否存在
        guard FileManager.default.fileExists(atPath: jsonFilePath.path) else {
            print("❌ ASR 文件不存在: \(jsonFilePath.path)")
            return nil
        }
        
        do {
            // 读取 JSON 文件
            let jsonData = try Data(contentsOf: jsonFilePath)
            let decoder = JSONDecoder()
            let asrResponse = try decoder.decode(ASRResponse.self, from: jsonData)
            
            // 解析字幕
            guard let resultDetails = asrResponse.Response.Data?.ResultDetail else {
                print("❌ ASR 结果为空")
                return nil
            }
            
            var allSubtitles: [SubtitleItem] = []
            
            // 遍历每个大段，为每个大段创建一个字幕项
            for detail in resultDetails {
                guard let words = detail.Words, !words.isEmpty else {
                    // 如果没有词级别信息，使用整段作为一个字幕
                    let startTime = Double(detail.StartMs) / 1000.0
                    let endTime = Double(detail.EndMs) / 1000.0
                    let subtitle = SubtitleItem(
                        startTime: startTime,
                        endTime: endTime,
                        originalText: detail.FinalSentence,
                        translatedText: ""
                    )
                    allSubtitles.append(subtitle)
                    continue
                }
                
                // 创建词时间信息数组
                let wordTimings = words.map { word in
                    WordTiming(
                        word: word.Word,
                        startTime: Double(word.OffsetStartMs) / 1000.0,
                        endTime: Double(word.OffsetEndMs) / 1000.0
                    )
                }
                
                // 为整个大段创建一个字幕项
                let startTime = Double(detail.StartMs) / 1000.0
                let endTime = Double(detail.EndMs) / 1000.0
                
                let subtitle = SubtitleItem(
                    startTime: startTime,
                    endTime: endTime,
                    originalText: detail.FinalSentence,
                    translatedText: "",
                    words: wordTimings
                )
                
                allSubtitles.append(subtitle)
            }
            
            print("✅ 从 ASR 文件加载字幕成功，共 \(allSubtitles.count) 条")
            return allSubtitles
            
        } catch {
            print("❌ 解析 ASR 文件失败: \(error.localizedDescription)")
            return nil
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

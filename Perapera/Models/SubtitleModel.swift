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

/// 整句读音（来自 /reading 服务或本地转换）
struct ASRFurigana: Codable {
    let hiragana: String?    // 平假名（播放界面显示用）
    let katakana: String?    // 片假名
    let romaji: String?      // 罗马音
}

struct ASRResultDetail: Codable {
    let FinalSentence: String
    let SliceSentence: String?
    let StartMs: Int
    let EndMs: Int
    let Words: [ASRWord]?
    let SpeechSpeed: Double?
    let WordsNum: Int?
    var TranslatedText: String?  // 整句翻译结果（Tencent MT）
    var furigana: ASRFurigana?   // 整句读音
}

struct ASRWord: Codable {
    let Word: String
    let OffsetStartMs: Int
    let OffsetEndMs: Int
    var Translation: String?   // 翻译结果
    var Reading: String?       // 罗马音（romaji）
    var Furigana: String?      // 假名读音
}

// MARK: - 字幕项
struct SubtitleItem: Codable, Identifiable {
    let id: String
    let startTime: Double      // 开始时间（秒）
    let endTime: Double        // 结束时间（秒）
    let originalText: String   // 原文（ASR 识别的文本）
    let translatedText: String // 译文（中文翻译）
    let words: [WordTiming]?   // 词级别的时间信息（原文）
    let translatedWords: [WordTiming]?  // 词级别的时间信息（译文）
    let hiragana: String?      // 整句平假名（显示在译文上方）
    let romaji: String?        // 整句罗马音（显示在译文下方）
    
    init(id: String = UUID().uuidString, startTime: Double, endTime: Double, originalText: String, translatedText: String = "", words: [WordTiming]? = nil, translatedWords: [WordTiming]? = nil, hiragana: String? = nil, romaji: String? = nil) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.originalText = originalText
        self.translatedText = translatedText
        self.words = words
        self.translatedWords = translatedWords
        self.hiragana = hiragana
        self.romaji = romaji
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
    var translation: String?   // 翻译结果
    var reading: String?       // 罗马音（romaji）
    var furigana: String?      // 假名读音
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
    
    /// 本次启动已用 /reading 刷新过读音的视频（避免每次播放都重复请求）
    private var refreshedVideoIDs = Set<String>()
    private let refreshedLock = NSLock()
    
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
            var jsonData = try Data(contentsOf: jsonFilePath)

            // 本次启动内用 /reading 刷新一次该视频 JSON 的读音（整句 furigana + 词级 Furigana/Reading），并写回文件
            refreshedLock.lock()
            let needsRefresh = !refreshedVideoIDs.contains(videoId)
            if needsRefresh { refreshedVideoIDs.insert(videoId) }
            refreshedLock.unlock()
            if needsRefresh {
                if refreshReadingsInASRFile(jsonFilePath: jsonFilePath) {
                    jsonData = try Data(contentsOf: jsonFilePath) // 读取刷新后的最新数据
                }
            }

            // 词级读音修正：用整句（正确）读音替换词级（可能错误的）读音。
            // 离线锚点+空隙切分后仍未匹配的汉字词，交给腾讯云大模型在整句 hiragana 中兜底定位。
            // 每次加载都执行（幂等，已正确的词不会被改动），修正后写回文件。
            if fixWordReadingsInASRFile(jsonFilePath: jsonFilePath) {
                jsonData = try Data(contentsOf: jsonFilePath)
            }

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
                        translatedText: "",
                        hiragana: detail.furigana?.hiragana,
                        romaji: detail.furigana?.romaji
                    )
                    allSubtitles.append(subtitle)
                    continue
                }
                
                // 创建词时间信息数组
                let wordTimings = words.map { word in
                    WordTiming(
                        word: word.Word,
                        startTime: Double(word.OffsetStartMs) / 1000.0,
                        endTime: Double(word.OffsetEndMs) / 1000.0,
                        translation: word.Translation,
                        reading: word.Reading,
                        furigana: word.Furigana
                    )
                }
                
                // 为整个大段创建一个字幕项
                let startTime = Double(detail.StartMs) / 1000.0
                let endTime = Double(detail.EndMs) / 1000.0
                
                let subtitle = SubtitleItem(
                    startTime: startTime,
                    endTime: endTime,
                    originalText: detail.FinalSentence,
                    translatedText: detail.TranslatedText ?? "",
                    words: wordTimings,
                    hiragana: detail.furigana?.hiragana,
                    romaji: detail.furigana?.romaji
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
    
    // MARK: - 用 /reading 刷新 ASR JSON 读音

    /// 用 /reading 服务刷新 ASR JSON 文件中的读音并写回文件：
    /// 1. 整句：用返回的 hiragana/katakana/romaji 替换该句 `furigana` 下的三个字段；
    /// 2. 词级：按当前句子 `words` 下的 `Word` 匹配 /reading 词级读音，写入该词的 Furigana/Reading。
    /// 连续 3 次失败会快速降级停止（避免每句都等待超时）。
    /// - Parameter jsonFilePath: `documents/<videoId>.json`
    /// - Returns: 是否成功刷新并写回
    @discardableResult
    func refreshReadingsInASRFile(jsonFilePath: URL) -> Bool {
        guard let jsonData = try? Data(contentsOf: jsonFilePath),
              var jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              var response = jsonObject["Response"] as? [String: Any],
              var data = response["Data"] as? [String: Any],
              var resultDetail = data["ResultDetail"] as? [[String: Any]] else {
            print("❌ 刷新读音：无法解析 ASR JSON")
            return false
        }

        var changedAny = false
        var consecutiveFailures = 0
        let maxConsecutiveFailures = 3

        for (sIdx, var detail) in resultDetail.enumerated() {
            let sliceText = (detail["SliceSentence"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                ?? (detail["FinalSentence"] as? String) ?? ""
            guard !sliceText.isEmpty else { continue }

            // 调 /reading 获取整句与词级读音（同步）
            guard let reading = ReadingAPIClient.shared.fetchReadingSync(text: sliceText) else {
                consecutiveFailures += 1
                print("  ⚠️ 刷新读音：第 \(sIdx) 句 /reading 失败（连续 \(consecutiveFailures) 次），保持原值")
                if consecutiveFailures >= maxConsecutiveFailures {
                    print("  ⛔ 刷新读音：连续失败 \(maxConsecutiveFailures) 次，快速降级停止")
                    break
                }
                continue
            }
            consecutiveFailures = 0

            // 1) 整句 furigana 替换（hiragana/katakana/romaji 均来自 /reading）
            detail["furigana"] = [
                "hiragana": reading.hiragana,
                "katakana": reading.katakana,
                "romaji": reading.romaji
            ]

            // 2) 词级：按 words 下的 Word 匹配 /reading 词级读音（时间轴仍以原文件为准）
            if var words = detail["Words"] as? [[String: Any]], !words.isEmpty {
                let wordItems = words.map { w -> ASRWordItem in
                    ASRWordItem(
                        Word: w["Word"] as? String ?? "",
                        OffsetStartMs: w["OffsetStartMs"] as? Int ?? 0,
                        OffsetEndMs: w["OffsetEndMs"] as? Int ?? 0
                    )
                }
                let aligned = ReadingAPIClient.alignToAliyunWords(
                    readingWords: reading.words,
                    aliyunWords: wordItems
                )
                for (wIdx, var w) in words.enumerated() {
                    if wIdx < aligned.count,
                       let hiragana = aligned[wIdx].hiragana,
                       let romaji = aligned[wIdx].romaji {
                        w["Furigana"] = hiragana
                        w["Reading"] = romaji
                    }
                    words[wIdx] = w
                }
                detail["Words"] = words
            }

            resultDetail[sIdx] = detail
            changedAny = true
        }

        guard changedAny else {
            print("❌ 刷新读音：没有句子被成功刷新")
            return false
        }

        data["ResultDetail"] = resultDetail
        response["Data"] = data
        jsonObject["Response"] = response
        guard let finalData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted) else {
            print("❌ 刷新读音：序列化失败")
            return false
        }

        do {
            try finalData.write(to: jsonFilePath)
            print("✅ 刷新读音完成，已写回 \(jsonFilePath.lastPathComponent)，共 \(resultDetail.count) 句")
            return true
        } catch {
            print("❌ 刷新读音：写回文件失败 \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - 词级读音修正（用整句正确读音替换错误词级读音）

    /// 用整句（正确）的 hiragana/romaji 修正 ASR JSON 文件中的词级 Furigana/Reading 并写回。
    /// 词级读音错误常见于汉字词（旧值来自本地机械转换，如把汉字原样当作假名）。
    /// 修正以整句读音为权威：
    /// 1) 把可信词（纯假名 ≥2 字符的 surface 或旧 Furigana）在整句平假名串中按序定位为锚点；
    /// 2) 锚点之间的空隙切分给未定位词：唯一未匹配词时整段归属；多个时让纯假名词先占位，
    ///    剩余段归最后一个未分配词；
    /// 3) 罗马音优先取整句罗马音空隙，不可用时对空隙平假名做本地转换（假名→罗马音基本无歧义）。
    /// 幂等：已正确的词不会被改动。
    @discardableResult
    /// 词级读音修正（文件级）：锚点定位 + 空隙切分 + 腾讯云大模型兜底。
    /// 离线修正（整句读音权威）完成后，仍无法可靠定位的词（汉字词等）按句批量交给大模型，
    /// 在整句 hiragana 中查找对应的平假名片段（强校验子串），罗马音用本地假名转换。
    /// - Parameter jsonFilePath: ASR JSON 文件路径
    /// - Returns: 是否有任何词被修正
    func fixWordReadingsInASRFile(jsonFilePath: URL, useLLMFallback: Bool = true) -> Bool {
        guard let jsonData = try? Data(contentsOf: jsonFilePath),
              var jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              var response = jsonObject["Response"] as? [String: Any],
              var data = response["Data"] as? [String: Any],
              var resultDetail = data["ResultDetail"] as? [[String: Any]] else {
            print("❌ 词级读音修正：无法解析 ASR JSON")
            return false
        }

        var changedAny = false
        // 大模型兜底任务：每句一个（该句内所有未匹配的汉字词批量一次请求）
        var llmTasks: [(sentenceIdx: Int, hiragana: String, pending: [(index: Int, word: String)])] = []

        for (sIdx, var detail) in resultDetail.enumerated() {
            var pending: [(index: Int, word: String)] = []
            if SubtitleManager.fixWordReadingsInDetail(&detail, llmPending: &pending) {
                changedAny = true
            }
            resultDetail[sIdx] = detail
            if useLLMFallback, !pending.isEmpty {
                let h = (detail["furigana"] as? [String: Any])?["hiragana"] as? String ?? ""
                if !h.isEmpty {
                    llmTasks.append((sentenceIdx: sIdx, hiragana: h, pending: pending))
                }
            }
        }

        // 大模型兜底：在整句 hiragana 中查找未匹配词的平假名（同步等待，带总超时）
        if !llmTasks.isEmpty {
            let fixes = runLLMFuriganaFallback(tasks: llmTasks)
            if !fixes.isEmpty {
                for fix in fixes {
                    guard fix.sentenceIdx < resultDetail.count,
                          var words = resultDetail[fix.sentenceIdx]["Words"] as? [[String: Any]],
                          fix.wordIdx < words.count else { continue }
                    var w = words[fix.wordIdx]
                    if (w["Furigana"] as? String) != fix.furigana {
                        w["Furigana"] = fix.furigana
                        changedAny = true
                    }
                    let romaji = JapaneseTextConverter.shared.toRomaji(fix.furigana)
                    if !romaji.isEmpty, (w["Reading"] as? String) != romaji {
                        w["Reading"] = romaji
                        changedAny = true
                    }
                    words[fix.wordIdx] = w
                    resultDetail[fix.sentenceIdx]["Words"] = words
                }
            }
        }

        guard changedAny else { return false }

        data["ResultDetail"] = resultDetail
        response["Data"] = data
        jsonObject["Response"] = response
        guard let finalData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted) else {
            print("❌ 词级读音修正：序列化失败")
            return false
        }
        do {
            try finalData.write(to: jsonFilePath)
            print("✅ 词级读音修正完成（含大模型兜底），已写回 \(jsonFilePath.lastPathComponent)")
            return true
        } catch {
            print("❌ 词级读音修正：写回失败 \(error.localizedDescription)")
            return false
        }
    }

    /// 大模型兜底（同步等待）：对每句一次调用，让模型在整句 hiragana 中为未匹配词定位平假名片段。
    /// 并发上限 4，总等待上限 60s（超时部分放弃，保持旧值）。
    private func runLLMFuriganaFallback(
        tasks: [(sentenceIdx: Int, hiragana: String, pending: [(index: Int, word: String)])]
    ) -> [(sentenceIdx: Int, wordIdx: Int, furigana: String)] {
        guard !tasks.isEmpty else { return [] }

        let maxConcurrent = 4
        let semaphore = DispatchSemaphore(value: maxConcurrent)
        let lock = NSLock()
        var collected: [(sentenceIdx: Int, wordIdx: Int, furigana: String)] = []
        var completed = 0
        let total = tasks.count
        let done = DispatchSemaphore(value: 0)

        for task in tasks {
            semaphore.wait()
            HunyuanManager.shared.lookupFuriganaInHiragana(
                sentenceHiragana: task.hiragana,
                words: task.pending
            ) { result in
                switch result {
                case .success(let dict):
                    lock.lock()
                    for (wordIdx, f) in dict {
                        collected.append((task.sentenceIdx, wordIdx, f))
                    }
                    lock.unlock()
                case .failure(let error):
                    print("⚠️ 大模型读音兜底失败: \(error.localizedDescription)")
                }
                semaphore.signal()
                lock.lock()
                completed += 1
                let allDone = completed == total
                lock.unlock()
                if allDone { done.signal() }
            }
        }

        _ = done.wait(timeout: .now() + 60)
        lock.lock()
        let result = collected
        lock.unlock()
        return result
    }

    /// 单句修正：用整句 hiragana/romaji 修正 Words[] 的 Furigana/Reading。
    /// 离线（锚点定位 + 空隙切分）无法可靠处理的词会收集到 llmPending，由调用方交给大模型在整句 hiragana 中兜底查找。
    /// - Parameters:
    ///   - detail: 单个 ResultDetail 字典（含 furigana 与 Words）
    ///   - llmPending: 输出参数，收集「未定位且旧读音为空或含汉字」的词（index 为词在句内下标）
    /// - Returns: 是否修正了任何词
    @discardableResult
    static func fixWordReadingsInDetail(_ detail: inout [String: Any],
                                        llmPending: inout [(index: Int, word: String)]) -> Bool {
        guard let furiganaDict = detail["furigana"] as? [String: Any],
              let h = furiganaDict["hiragana"] as? String, !h.isEmpty,
              var words = detail["Words"] as? [[String: Any]], !words.isEmpty else {
            return false
        }
        let r = (furiganaDict["romaji"] as? String) ?? ""
        let n = words.count

        var located = [Bool](repeating: false, count: n)
        var fNew = [String?](repeating: nil, count: n)
        var rNew = [String?](repeating: nil, count: n)
        var startH = [Int](repeating: 0, count: n)
        var endH = [Int](repeating: 0, count: n)
        var startR = [Int](repeating: 0, count: n)
        var endR = [Int](repeating: 0, count: n)
        var posH = 0
        var posR = 0

        // 第一遍：锚点定位（纯假名 ≥2 字符的 surface 或旧 Furigana，在整句平假名串中按序查找）
        for i in 0..<n {
            let surface = words[i]["Word"] as? String ?? ""
            let oldF = words[i]["Furigana"] as? String
            let oldR = words[i]["Reading"] as? String

            var cand: String?
            if isHiraganaOnly(surface), surface.count >= 2 {
                cand = surface
            } else if isKatakanaOnly(surface), surface.count >= 2 {
                cand = ReadingAPIClient.katakanaToHiragana(surface)
            } else if let f = oldF, isHiraganaOnly(f), f.count >= 2 {
                cand = f
            }
            guard let c = cand else { continue }
            guard let off = find(in: h, from: posH, target: c) else { continue }

            fNew[i] = c
            located[i] = true
            startH[i] = off
            posH = off + c.count
            endH[i] = posH

            // 罗马音：旧 Reading 若为罗马音（无空格）且在整句罗马音串中是完整 token，则定位
            if let oR = oldR, isRomajiOnly(oR), !oR.isEmpty,
               !oR.contains(where: { $0.isWhitespace }),
               let rOff = findToken(in: r, from: posR, target: oR) {
                rNew[i] = oR
                startR[i] = rOff
                posR = rOff + oR.count
                endR[i] = posR
            }
        }

        // 第二遍：空隙切分
        var i = 0
        while i < n {
            if located[i] { i += 1; continue }
            var j = i
            while j < n && !located[j] { j += 1 }
            let cnt = j - i

            // 收集大模型兜底候选：未定位 且 旧读音可疑的词（离线无法可靠处理）。
            // 判定：旧值为空/含汉字 → 错误；旧值为纯假名但整句 hiragana 中不存在（如「びみ」）→ 错误音读，也需兜底。
            for t in i..<j {
                let oldF = words[t]["Furigana"] as? String
                if let f = oldF, !f.isEmpty {
                    if (isHiraganaOnly(f) || isKatakanaOnly(f)) && h.contains(f) {
                        continue // 纯假名且在整句中真实存在：大概率正确（如送假名残留「し」、句尾「の」），不兜底
                    }
                }
                let wText = words[t]["Word"] as? String ?? ""
                if !wText.isEmpty {
                    llmPending.append((index: t, word: wText))
                }
            }

            // 空隙的 H 边界（前后最近锚点）
            var leftH = 0
            var k = i - 1
            while k >= 0 && !located[k] { k -= 1 }
            if k >= 0 { leftH = endH[k] }
            var rightH = h.count
            if j < n { rightH = startH[j] }
            guard rightH > leftH else { i = j; continue }

            // 空隙的 R 边界（前后最近"R 定位成功"的锚点）
            var leftR = 0
            var leftROk = false
            k = i - 1
            while k >= 0, rNew[k] == nil { k -= 1 }
            if k >= 0 { leftR = endR[k]; leftROk = true }
            var rightR = r.count
            var rightROk = false
            var m = j
            while m < n, rNew[m] == nil { m += 1 }
            if m < n { rightR = startR[m]; rightROk = true }

            let gapHRaw = String(h.dropFirst(leftH).prefix(rightH - leftH))

            if cnt == 1 {
                // 唯一未匹配词：整段空隙归属
                let oldF = words[i]["Furigana"] as? String
                if let f = oldF, isHiraganaOnly(f) || isKatakanaOnly(f) {
                    // 旧值已是纯假名：大概率正确，保持不动（如句尾「の」不应被句号空隙污染）
                } else if !gapHRaw.isEmpty {
                    fNew[i] = gapHRaw
                    rNew[i] = gapRomaji(r, leftR: leftR, rightR: rightR,
                                        leftROk: leftROk, rightROk: rightROk,
                                        hiragana: gapHRaw)
                }
            } else {
                // 多个未匹配词：
                // - 旧 Furigana 为纯假名的词（本地兜底输出已是假名，大概率正确，如送假名残留「し」）→ 保持不动；
                // - 旧 Furigana 为空或含汉字的词（真正错误）→ 参与空隙分配。
                var needFix = [Int]()
                for t in i..<j {
                    let oldF = words[t]["Furigana"] as? String
                    if let f = oldF, isHiraganaOnly(f) || isKatakanaOnly(f) {
                        continue // 纯假名旧值保持
                    }
                    needFix.append(t)
                }
                // 恰好 1 个真正错误的词：整段空隙归属
                if needFix.count == 1 {
                    let t = needFix[0]
                    if !gapHRaw.isEmpty {
                        fNew[t] = gapHRaw
                        rNew[t] = gapRomaji(r, leftR: leftR, rightR: rightR,
                                           leftROk: leftROk, rightROk: rightROk,
                                           hiragana: gapHRaw)
                    }
                }
                // 多个真正错误的词：无法可靠切分，放弃（保持现状）
            }
            i = j
        }

        // 写回变化的词
        var changed = false
        for i in 0..<n {
            var w = words[i]
            if let f = fNew[i], f != (w["Furigana"] as? String) {
                w["Furigana"] = f
                changed = true
            }
            if let rr = rNew[i], rr != (w["Reading"] as? String) {
                w["Reading"] = rr
                changed = true
            }
            words[i] = w
        }
        if changed { detail["Words"] = words }
        return changed
    }

    /// 罗马音：优先取整句罗马音空隙（前后锚点 R 均定位时），否则对空隙平假名做本地转换
    private static func gapRomaji(_ r: String, leftR: Int, rightR: Int,
                                  leftROk: Bool, rightROk: Bool, hiragana: String) -> String? {
        if leftROk && rightROk && rightR > leftR {
            let gapR = String(r.dropFirst(leftR).prefix(rightR - leftR))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !gapR.isEmpty { return gapR }
        }
        let converted = JapaneseTextConverter.shared.toRomaji(hiragana)
        return converted.isEmpty ? nil : converted
    }

    // MARK: - 读音修正辅助

    /// 是否全部为平假名
    private static func isHiraganaOnly(_ s: String) -> Bool {
        !s.isEmpty && s.unicodeScalars.allSatisfy { (0x3040...0x309F).contains($0.value) }
    }

    /// 是否全部为片假名（含长音符）
    private static func isKatakanaOnly(_ s: String) -> Bool {
        !s.isEmpty && s.unicodeScalars.allSatisfy { (0x30A0...0x30FF).contains($0.value) }
    }

    /// 是否全部为罗马音（ASCII 字母/空格）
    private static func isRomajiOnly(_ s: String) -> Bool {
        !s.isEmpty && s.allSatisfy { $0.isASCII && ($0.isLetter || $0.isWhitespace) }
    }

    /// 在字符串中从指定偏移起查找第一次出现，返回绝对偏移
    private static func find(in s: String, from offset: Int, target: String) -> Int? {
        guard offset <= s.count else { return nil }
        let start = s.index(s.startIndex, offsetBy: offset)
        let sub = s[start...]
        guard let range = sub.range(of: target) else { return nil }
        return offset + sub.distance(from: sub.startIndex, to: range.lowerBound)
    }

    /// 在 [left, right) 区间内查找最后一次出现，返回绝对偏移
    private static func findLast(in s: String, from left: Int, to right: Int, target: String) -> Int? {
        guard left <= right, right <= s.count else { return nil }
        let start = s.index(s.startIndex, offsetBy: left)
        let end = s.index(s.startIndex, offsetBy: right)
        let sub = s[start..<end]
        guard let range = sub.range(of: target, options: .backwards) else { return nil }
        return left + sub.distance(from: sub.startIndex, to: range.lowerBound)
    }

    /// 在罗马音串中从指定偏移起查找"完整 token"（前后为空格/标点/边界）出现的位置
    private static func findToken(in s: String, from offset: Int, target: String) -> Int? {
        guard offset <= s.count else { return nil }
        let start = s.index(s.startIndex, offsetBy: offset)
        var idx = start
        var tokenStart = start
        while idx < s.endIndex {
            let ch = s[idx]
            if ch.isWhitespace || "、。，．!?！？,.".contains(ch) {
                if tokenStart < idx {
                    let tk = String(s[tokenStart..<idx])
                    if tk == target {
                        return offset + s.distance(from: start, to: tokenStart)
                    }
                }
                idx = s.index(after: idx)
                tokenStart = idx
            } else {
                idx = s.index(after: idx)
            }
        }
        if tokenStart < s.endIndex {
            let tk = String(s[tokenStart..<s.endIndex])
            if tk == target {
                return offset + s.distance(from: start, to: tokenStart)
            }
        }
        return nil
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

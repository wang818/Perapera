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
    /// 从 ASR JSON 文件加载字幕（两阶段，字幕先显示、读音后台补）。
    /// 阶段一：立即本地解析并回调（无任何网络请求，字幕秒开）；
    /// 阶段二：后台依次 /reading 刷新读音 → 词级读音修正（大模型整句对齐）→ 重新解析并再次回调，
    /// 调用方据第二次回调更新界面注音。completion 可能被调用两次。
    /// 所有网络请求均在后台线程进行，主线程不会被阻塞。
    /// - Parameters:
    ///   - videoId: 视频 ID（对应 documents/<videoId>.json）
    ///   - completion: 主线程回调（可能两次），成功返回字幕数组，失败/无文件返回 nil
    func loadSubtitlesFromASRFileAsync(videoId: String, completion: @escaping ([SubtitleItem]?) -> Void) {
        // 构建 JSON 文件路径
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let jsonFilePath = documentsPath.appendingPathComponent("\(videoId).json")

        print("🔍 尝试异步加载 ASR 文件: \(jsonFilePath.path)")

        // 检查文件是否存在
        guard FileManager.default.fileExists(atPath: jsonFilePath.path) else {
            print("❌ ASR 文件不存在: \(jsonFilePath.path)")
            DispatchQueue.main.async { completion(nil) }
            return
        }

        // 阶段一：先本地解析并立即回调，字幕不等任何网络请求
        parseSubtitlesFromASRFile(jsonFilePath: jsonFilePath) { firstPass in
            completion(firstPass)
        }

        // 本次启动内用 /reading 刷新一次该视频 JSON 的读音（整句 furigana + 词级 Furigana/Reading），并写回文件
        refreshedLock.lock()
        let needsRefresh = !refreshedVideoIDs.contains(videoId)
        if needsRefresh { refreshedVideoIDs.insert(videoId) }
        refreshedLock.unlock()

        // 阶段二：后台刷新读音 + 词级修正（LLM 对齐的 semaphore 等待也在此后台线程，不阻塞主线程）
        let proceedToFix: () -> Void = {
            // 词级读音修正：用整句（正确）读音替换词级（可能错误的）读音。
            // 离线锚点+空隙切分后，词级拼接与整句 hiragana/romaji 不一致的句子，
            // 把整句原文 + 全部词 + 整句注音交给腾讯云大模型做整句对齐（拼接必须完全一致，不多字不少字）。
            // 每次加载都执行（幂等，已正确的词不会被改动），修正后写回文件。
            DispatchQueue.global(qos: .userInitiated).async {
                self.fixWordReadingsInASRFile(jsonFilePath: jsonFilePath) { _ in
                    DispatchQueue.global(qos: .userInitiated).async {
                        self.parseSubtitlesFromASRFile(jsonFilePath: jsonFilePath, completion: completion)
                    }
                }
            }
        }

        if needsRefresh {
            refreshReadingsInASRFile(jsonFilePath: jsonFilePath) { _ in
                proceedToFix()
            }
        } else {
            proceedToFix()
        }
    }

    /// 读取并解析 ASR JSON 文件为字幕数组（同步、纯本地计算，无网络请求）。
    private func parseSubtitlesFromASRFile(jsonFilePath: URL, completion: @escaping ([SubtitleItem]?) -> Void) {
        do {
            let jsonData = try Data(contentsOf: jsonFilePath)
            let decoder = JSONDecoder()
            let asrResponse = try decoder.decode(ASRResponse.self, from: jsonData)

            // 解析字幕
            guard let resultDetails = asrResponse.Response.Data?.ResultDetail else {
                print("❌ ASR 结果为空")
                DispatchQueue.main.async { completion(nil) }
                return
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
            DispatchQueue.main.async { completion(allSubtitles) }

        } catch {
            print("❌ 解析 ASR 文件失败: \(error.localizedDescription)")
            DispatchQueue.main.async { completion(nil) }
        }
    }
    
    // MARK: - 用 /reading 刷新 ASR JSON 读音

    /// 刷新读音（异步、不阻塞调用线程）：逐句调用 /reading 获取整句与词级读音并写回文件。
    /// 任一句子 /reading 失败则保持原值（连续失败达上限快速降级）。
    /// - Parameters:
    ///   - jsonFilePath: ASR JSON 文件路径
    ///   - completion: 主线程回调，参数表示是否有任何句被刷新
    func refreshReadingsInASRFile(
        jsonFilePath: URL,
        completion: @escaping (Bool) -> Void
    ) {
        guard let jsonData = try? Data(contentsOf: jsonFilePath),
              var jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              var response = jsonObject["Response"] as? [String: Any],
              var data = response["Data"] as? [String: Any],
              var resultDetail = data["ResultDetail"] as? [[String: Any]] else {
            print("❌ 刷新读音：无法解析 ASR JSON")
            DispatchQueue.main.async { completion(false) }
            return
        }

        let total = resultDetail.count
        let lock = NSLock()
        var changedAny = false
        var consecutiveFailures = 0
        let maxConsecutiveFailures = 3
        // 串行派发：nextIndex 记录下一个待请求句子；stopped 表示已降级停止，不再发起/处理后续请求
        var nextIndex = 0
        var stopped = false

        // 没有句子需要刷新
        guard total > 0 else {
            DispatchQueue.main.async { completion(false) }
            return
        }

        let finish: (Bool) -> Void = { changed in
            guard changed else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            data["ResultDetail"] = resultDetail
            response["Data"] = data
            jsonObject["Response"] = response
            guard let finalData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted) else {
                print("❌ 刷新读音：序列化失败")
                DispatchQueue.main.async { completion(false) }
                return
            }
            do {
                try finalData.write(to: jsonFilePath)
                print("✅ 刷新读音完成，已写回 \(jsonFilePath.lastPathComponent)，共 \(total) 句")
                DispatchQueue.main.async { completion(true) }
            } catch {
                print("❌ 刷新读音：写回文件失败 \(error.localizedDescription)")
                DispatchQueue.main.async { completion(false) }
            }
        }

        // 串行派发：逐句请求，任一句成功才继续下一句；连续失败达上限立即停止，
        // 不再发起剩余句子的请求（避免刷屏，也避免并发请求打满后端引发 502）
        func requestNext() {
            // 所有句子处理完毕（含降级停止时已处理的部分）→ 结束
            if nextIndex >= total {
                finish(changedAny)
                return
            }
            let sIdx = nextIndex
            nextIndex += 1

            let detail = resultDetail[sIdx]
            let sliceText = (detail["SliceSentence"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                ?? (detail["FinalSentence"] as? String) ?? ""
            guard !sliceText.isEmpty else {
                // 空句：跳过，继续下一句
                requestNext()
                return
            }

            ReadingAPIClient.shared.fetchReading(text: sliceText) { reading in
                guard !stopped else { return }  // 防御：降级停止后不再处理

                guard let reading = reading else {
                    lock.lock(); consecutiveFailures += 1; let cf = consecutiveFailures
                    if cf >= maxConsecutiveFailures { stopped = true }
                    lock.unlock()
                    if cf < maxConsecutiveFailures {
                        print("  ⚠️ 刷新读音：第 \(sIdx) 句 /reading 失败（连续 \(cf) 次），保持原值")
                        requestNext()
                    } else {
                        print("  ⛔ 刷新读音：连续失败 \(maxConsecutiveFailures) 次，快速降级停止，不再请求后续句子")
                        finish(changedAny)
                    }
                    return
                }
                lock.lock(); consecutiveFailures = 0; lock.unlock()

                var detail = resultDetail[sIdx]
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

                lock.lock()
                resultDetail[sIdx] = detail
                changedAny = true
                lock.unlock()

                // 成功：继续下一句
                requestNext()
            }
        }

        requestNext()
    }

    // MARK: - 词级读音修正（用整句正确读音替换错误词级读音）

    /// 词级读音修正（文件级，异步）：锚点定位 + 空隙切分 + 腾讯云大模型整句对齐。
    /// 离线修正（整句读音权威）完成后，若某句词级 Furigana/Reading 按序拼接与整句 hiragana/romaji 不一致
    /// （说明仍有词级读音错误，如汉字词的错误音读、错切片段），则把该句整句原文 + 全部词 + 整句注音
    /// 交给大模型做整句对齐：模型为每个词匹配平假名与罗马音片段，且所有片段拼接后必须与整句注音
    /// 完全一致（不能多字、不能少字），经代码二次校验通过后才写回。
    /// 大模型请求全部异步进行，**不阻塞调用线程**；处理完毕（或超时）后通过 completion 回调。
    /// - Parameters:
    ///   - jsonFilePath: ASR JSON 文件路径
    ///   - completion: 主线程回调，参数表示是否有任何词被修正
    func fixWordReadingsInASRFile(
        jsonFilePath: URL,
        useLLMFallback: Bool = true,
        completion: @escaping (Bool) -> Void
    ) {
        guard let jsonData = try? Data(contentsOf: jsonFilePath),
              var jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              var response = jsonObject["Response"] as? [String: Any],
              var data = response["Data"] as? [String: Any],
              var resultDetail = data["ResultDetail"] as? [[String: Any]] else {
            print("❌ 词级读音修正：无法解析 ASR JSON")
            DispatchQueue.main.async { completion(false) }
            return
        }

        var changedAny = false
        // 大模型整句对齐任务：离线修正后，词级读音拼接与整句注音不一致的句子（该句全部词一次请求）
        var llmTasks: [(sentenceIdx: Int, slice: String, hiragana: String, romaji: String, words: [(index: Int, text: String)])] = []

        for (sIdx, var detail) in resultDetail.enumerated() {
            if SubtitleManager.fixWordReadingsInDetail(&detail) {
                changedAny = true
            }
            // 拼接一致性检查：词级 Furigana/Reading 按序拼接，必须与整句 hiragana/romaji 完全一致（不多字、不少字）。
            // 不一致说明该句仍有词级读音错误（如汉字词的错误音读、错切片段），交给大模型做整句对齐。
            if useLLMFallback,
               let furiganaDict = detail["furigana"] as? [String: Any],
               let h = furiganaDict["hiragana"] as? String, !h.isEmpty,
               let r = furiganaDict["romaji"] as? String, !r.isEmpty,
               let words = detail["Words"] as? [[String: Any]], !words.isEmpty,
               SubtitleManager.needsWholeSentenceAlignment(words: words, hiragana: h, romaji: r) {
                let slice = (detail["SliceSentence"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                    ?? (detail["FinalSentence"] as? String) ?? ""
                guard !slice.isEmpty else {
                    resultDetail[sIdx] = detail
                    continue
                }
                let allWords = words.enumerated().map { (index: $0.offset, text: $0.element["Word"] as? String ?? "") }
                llmTasks.append((sentenceIdx: sIdx, slice: slice, hiragana: h, romaji: r, words: allWords))
            }
            resultDetail[sIdx] = detail
        }

        // 大模型整句对齐：把整句原文 + 全部词 + 整句 hiragana/romaji 交给大模型，为每个词匹配平假名与罗马音片段。
        // 结果必须通过拼接一致性校验（词级拼接 == 整句注音，不多字、不少字）才会写回；不通过则保持离线修正结果。
        // 异步执行，不阻塞调用线程。
        let writeBackAndComplete: (Bool) -> Void = { success in
            guard success else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            data["ResultDetail"] = resultDetail
            response["Data"] = data
            jsonObject["Response"] = response
            guard let finalData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted) else {
                print("❌ 词级读音修正：序列化失败")
                DispatchQueue.main.async { completion(false) }
                return
            }
            do {
                try finalData.write(to: jsonFilePath)
                print("✅ 词级读音修正完成（含大模型兜底），已写回 \(jsonFilePath.lastPathComponent)")
                DispatchQueue.main.async { completion(true) }
            } catch {
                print("❌ 词级读音修正：写回失败 \(error.localizedDescription)")
                DispatchQueue.main.async { completion(false) }
            }
        }

        if !llmTasks.isEmpty {
            runLLMWordAlignment(tasks: llmTasks) { fixes in
                var changedByLLM = false
                for fix in fixes {
                    guard fix.sentenceIdx < resultDetail.count,
                          var words = resultDetail[fix.sentenceIdx]["Words"] as? [[String: Any]],
                          fix.wordIdx < words.count else { continue }
                    var w = words[fix.wordIdx]
                    if (w["Furigana"] as? String) != fix.furigana {
                        w["Furigana"] = fix.furigana
                        changedByLLM = true
                    }
                    if (w["Reading"] as? String) != fix.romaji {
                        w["Reading"] = fix.romaji
                        changedByLLM = true
                    }
                    words[fix.wordIdx] = w
                    resultDetail[fix.sentenceIdx]["Words"] = words
                }
                writeBackAndComplete(changedAny || changedByLLM)
            }
        } else {
            writeBackAndComplete(changedAny)
        }
    }

    /// 拼接一致性检查：该句所有词 Furigana/Reading 按顺序直接拼接，是否与整句 hiragana/romaji 一致（不多字、不少字）。
    /// 平假名严格相等（整句 hiragana 无空格）；罗马音按「去掉所有空格后相等」判定
    /// （整句 romaji 的空格只是读音单元分隔符，词级 r 用紧凑形式即可，字符不增不减）。
    /// 不一致说明词级读音仍有错误（或整句注音包含词列表之外的标点等），需要交给大模型做整句对齐。
    private static func needsWholeSentenceAlignment(words: [[String: Any]], hiragana: String, romaji: String) -> Bool {
        var fConcat = ""
        var rConcat = ""
        for w in words {
            fConcat += (w["Furigana"] as? String) ?? ""
            rConcat += (w["Reading"] as? String) ?? ""
        }
        return fConcat != hiragana || stripped(rConcat) != stripped(romaji)
    }

    /// 去掉字符串中所有空白字符
    private static func stripped(_ s: String) -> String {
        return s.filter { !$0.isWhitespace }
    }

    /// 大模型整句对齐（异步、不阻塞调用线程）：对每句调用一次，让模型为全部词在整句 hiragana/romaji 中匹配平假名与罗马音片段。
    /// 返回前强制拼接校验：词级 f 拼接 == 整句 hiragana 且词级 r 拼接 == 整句 romaji（不能多字、不能少字），
    /// 校验通过才采纳；不通过则丢弃该句（保持离线修正结果）。
    /// 并发上限 4，单请求 30s、总等待上限 45s（超时部分放弃，保持旧值，避免拖慢播放加载）。
    /// 所有句子处理完毕（或超时）后通过 completion 回调结果，全程不阻塞调用线程。
    private func runLLMWordAlignment(
        tasks: [(sentenceIdx: Int, slice: String, hiragana: String, romaji: String, words: [(index: Int, text: String)])],
        completion: @escaping ([(sentenceIdx: Int, wordIdx: Int, furigana: String, romaji: String)]) -> Void
    ) {
        guard !tasks.isEmpty else { completion([]); return }

        let maxConcurrent = 4
        let semaphore = DispatchSemaphore(value: maxConcurrent)
        let lock = NSLock()
        var collected: [(sentenceIdx: Int, wordIdx: Int, furigana: String, romaji: String)] = []
        var completed = 0
        let total = tasks.count
        var finished = false

        // 总等待上限 45s：超时后强制结束（已收集的结果仍回调，未完成的放弃）
        let timeoutWork = DispatchWorkItem {
            lock.lock()
            if !finished {
                finished = true
                let result = collected
                lock.unlock()
                print("⚠️ 大模型整句对齐总超时(45s)，部分句子放弃，返回已收集结果")
                completion(result)
                return
            }
            lock.unlock()
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 45, execute: timeoutWork)

        for task in tasks {
            semaphore.wait()
            let items = task.words.map { HunyuanManager.WordReadingLookupItem(index: $0.index, text: $0.text) }
            HunyuanManager.shared.lookupWordReadings(
                slice: task.slice,
                hiragana: task.hiragana,
                romaji: task.romaji,
                words: items
            ) { result in
                defer {
                    semaphore.signal()
                    lock.lock()
                    completed += 1
                    let allDone = completed == total
                    let alreadyFinished = finished
                    lock.unlock()
                    if allDone, !alreadyFinished {
                        lock.lock()
                        if !finished {
                            finished = true
                            let result = collected
                            lock.unlock()
                            timeoutWork.cancel()
                            completion(result)
                        } else {
                            lock.unlock()
                        }
                    }
                }
                switch result {
                case .success(let dict):
                    // 拼接校验：全部词的 f/r 按顺序拼接，必须与整句注音一致（不多字、不少字）。
                    // f 严格相等；r 去空格后相等（空格只是罗马音分隔符）。
                    var fConcat = ""
                    var rConcat = ""
                    var ordered: [(wordIdx: Int, f: String, r: String)] = []
                    for item in task.words {
                        let m = dict[item.index]
                        let f = m?.furigana ?? ""
                        let r = m?.romaji ?? ""
                        fConcat += f
                        rConcat += r
                        ordered.append((item.index, f, r))
                    }
                    guard fConcat == task.hiragana, SubtitleManager.stripped(rConcat) == SubtitleManager.stripped(task.romaji) else {
                        print("⚠️ 大模型整句对齐校验失败（词级拼接与整句注音不一致），该句保持离线修正结果")
                        return
                    }
                    lock.lock()
                    for o in ordered {
                        collected.append((task.sentenceIdx, o.wordIdx, o.f, o.r))
                    }
                    lock.unlock()
                case .failure(let error):
                    print("⚠️ 大模型整句对齐失败: \(error.localizedDescription)")
                }
            }
        }
    }

    /// 单句修正：用整句 hiragana/romaji 修正 Words[] 的 Furigana/Reading。
    /// 离线（锚点定位 + 空隙切分）尽可能修正；仍无法可靠处理的句子由调用方通过
    /// 「词级拼接 == 整句注音」的一致性检查识别，再交给大模型做整句对齐。
    /// - Parameter detail: 单个 ResultDetail 字典（含 furigana 与 Words）
    /// - Returns: 是否修正了任何词
    @discardableResult
    static func fixWordReadingsInDetail(_ detail: inout [String: Any]) -> Bool {
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

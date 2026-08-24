
//  ReadingAPI.swift
//  Perapera
//
//  调用自建 /reading 服务（whisper.perapera.cc）为日文句子获取词级假名与罗马音
//  返回数据结构（服务端）：
//  {
//    "text": "あの美味しいミートボール、おことしちゃったの。",
//    "katakana": "'アノ''オイシイ'ミートボール'、'...",
//    "romaji": "'ano' 'oishii' mii tobooru '、'...",
//    "words": [{"surface":"あの","katakana":"'アノ'","romaji":"'ano'"}, ...]
//  }
//

import Foundation

// MARK: - Models

/// /reading 返回的词级读音
struct ReadingWord: Codable {
    let surface: String
    let katakana: String?
    let romaji: String?
}

/// /reading API 响应
struct ReadingResponse: Codable {
    let text: String?
    let katakana: String?
    let romaji: String?
    let words: [ReadingWord]?
}

/// 整句读音结果（引号已清理）
struct ReadingResult {
    let hiragana: String   // katakana → hiragana（播放界面显示平假名）
    let katakana: String
    let romaji: String
    let words: [ReadingWord]
}

// MARK: - Client

/// /reading 服务客户端：为整句生成假名/罗马音，并可将词级读音对齐到阿里云分词
final class ReadingAPIClient {
    static let shared = ReadingAPIClient()
    private init() {}

    private static let endpoint = URL(string: "https://whisper.perapera.cc/reading")!

    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 40
        config.httpMaximumConnectionsPerHost = 4
        return URLSession(configuration: config)
    }()

    // MARK: - 全局熔断（Circuit Breaker）
    // /reading 是辅助服务（失败走本地兜底）。后端故障（如 502）时，若多个解析/刷新实例
    // 各自独立降级，仍会并发打大量请求并刷屏日志。这里做进程级熔断：
    // 连续失败 2 次 → 熔断打开（冷却 60s 起、指数退避、上限 10min），期间所有调用直接
    // 返回 nil（首次跳过打印一行提示，后续静默）；冷却结束后首次调用作为试探，成功则复位。
    private let breakerLock = NSLock()
    private var breakerOpen = false
    private var breakerFailures = 0
    private var breakerOpenUntil: Date?
    private var breakerSkipLogged = false
    private var breakerCooldownExp = 0
    private let breakerMaxFailures = 2
    private let breakerBaseCooldown: TimeInterval = 60
    private let breakerMaxCooldown: TimeInterval = 600

    /// 请求前检查：false 表示熔断冷却中，调用方应直接按失败处理（不发请求）
    private func canRequest() -> Bool {
        breakerLock.lock()
        defer { breakerLock.unlock() }
        if breakerOpen {
            if let until = breakerOpenUntil, Date() >= until {
                // 冷却结束：关闭熔断，放行一次试探请求
                breakerOpen = false
                breakerSkipLogged = false
                return true
            }
            if !breakerSkipLogged {
                breakerSkipLogged = true
                let remain = max(0, Int((breakerOpenUntil ?? Date()).timeIntervalSinceNow))
                print("⏸ ReadingAPI: /reading 熔断冷却中（约剩余 \(remain)s），期间请求直接跳过")
            }
            return false
        }
        return true
    }

    private func recordFailure() {
        breakerLock.lock()
        defer { breakerLock.unlock() }
        breakerFailures += 1
        if breakerFailures >= breakerMaxFailures, !breakerOpen {
            breakerOpen = true
            let cooldown = min(breakerBaseCooldown * pow(2.0, Double(breakerCooldownExp)), breakerMaxCooldown)
            breakerCooldownExp += 1
            breakerOpenUntil = Date().addingTimeInterval(cooldown)
            print("⚠️ ReadingAPI: 连续失败 \(breakerFailures) 次，熔断打开，冷却 \(Int(cooldown))s（期间不再请求 /reading）")
        }
    }

    private func recordSuccess() {
        breakerLock.lock()
        defer { breakerLock.unlock() }
        breakerFailures = 0
        breakerCooldownExp = 0
        breakerOpen = false
        breakerOpenUntil = nil
        breakerSkipLogged = false
    }

    // MARK: - Public

    /// 同步调用 /reading（阻塞调用线程，带超时）。失败/超时/解析失败返回 nil
    /// - Parameter text: 日文整句
    /// - Returns: 整句读音（含词级 words），失败为 nil
    func fetchReadingSync(text: String) -> ReadingResult? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // 熔断冷却中：不发请求，直接按失败处理
        guard canRequest() else { return nil }

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["text": trimmed])

        let semaphore = DispatchSemaphore(value: 0)
        var result: ReadingResult?

        session.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            if let error = error {
                print("❌ ReadingAPI[Sync]: 请求失败 \(error.localizedDescription)")
                self.recordFailure()
                return
            }
            guard let data = data,
                  let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                print("❌ ReadingAPI[Sync]: 非 2xx 响应, HTTP \(code)")
                self.recordFailure()
                return
            }
            guard let resp = try? JSONDecoder().decode(ReadingResponse.self, from: data) else {
                let preview = String(data: data, encoding: .utf8)?.prefix(300) ?? ""
                print("❌ ReadingAPI[Sync]: JSON 解析失败: \(preview)")
                self.recordFailure()
                return
            }
            result = Self.buildResult(resp)
            if result == nil {
                self.recordFailure()
            } else {
                self.recordSuccess()
            }
        }.resume()

        let wait = semaphore.wait(timeout: .now() + 35)
        if wait == .timedOut {
            print("⚠️ ReadingAPI[Sync]: 请求超时(35s), text=\(trimmed.prefix(30))")
            recordFailure()
            return nil
        }
        return result
    }

    /// 异步调用 /reading（不阻塞调用线程）。失败/超时/解析失败在 completion 中返回 nil。
    /// - Parameters:
    ///   - text: 日文整句
    ///   - completion: 主线程回调，成功返回 ReadingResult，失败返回 nil
    func fetchReading(text: String, completion: @escaping (ReadingResult?) -> Void) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        // 熔断冷却中：不发请求，直接按失败处理
        guard canRequest() else {
            DispatchQueue.main.async { completion(nil) }
            return
        }

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["text": trimmed])

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ ReadingAPI[Async]: 请求失败 \(error.localizedDescription)")
                self.recordFailure()
                DispatchQueue.main.async { completion(nil) }
                return
            }
            guard let data = data,
                  let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                print("❌ ReadingAPI[Async]: 非 2xx 响应, HTTP \(code)")
                self.recordFailure()
                DispatchQueue.main.async { completion(nil) }
                return
            }
            guard let resp = try? JSONDecoder().decode(ReadingResponse.self, from: data) else {
                let preview = String(data: data, encoding: .utf8)?.prefix(300) ?? ""
                print("❌ ReadingAPI[Async]: JSON 解析失败: \(preview)")
                self.recordFailure()
                DispatchQueue.main.async { completion(nil) }
                return
            }
            let result = Self.buildResult(resp)
            if result == nil {
                self.recordFailure()
            } else {
                self.recordSuccess()
            }
            DispatchQueue.main.async { completion(result) }
        }.resume()
    }

    // MARK: - 对齐

    /// 将 /reading 的词级读音按「顺序消费 + 原子匹配」对齐到阿里云分词的每个词。
    ///
    /// 匹配规则（避免截断/堆积——吸取此前比例截取的教训）：
    /// 1. 阿里云词文本 == reading word surface（精确命中）→ 取该 reading word 整段读音；
    /// 2. 阿里云词文本是下一个 reading word surface 的**前缀**（如「美味」⊂「美味しい」，
    ///    阿里云错切）→ 取整段 reading word 读音（不截断，宁可多一个音）；
    /// 3. reading word surface 是阿里云词文本的前缀（阿里云合并词）→ 累加多个 reading word 直到拼接相等；
    /// 4. 匹配不到 → nil（交给 MT 阶段大模型/本地兜底），游标不动，留给后续词重新尝试。
    ///
    /// - Parameters:
    ///   - readingWords: /reading 返回的 words（词典分词，读音精确）
    ///   - aliyunWords: 阿里云分词的词（带时间轴，词级时间轴以它为准）
    /// - Returns: 与 aliyunWords 等长的数组，(hiragana, romaji)，匹配不到为 nil
    static func alignToAliyunWords(
        readingWords: [ReadingWord],
        aliyunWords: [ASRWordItem]
    ) -> [(hiragana: String?, romaji: String?)] {
        // 预处理：清理引号、katakana→hiragana
        struct CleanWord {
            let surface: String
            let hiragana: String
            let romaji: String
        }
        let cleaned: [CleanWord] = readingWords.map { w in
            let surface = cleanQuotes(w.surface)
            let katakana = cleanQuotes(w.katakana ?? "")
            return CleanWord(
                surface: surface,
                hiragana: katakanaToHiragana(katakana),
                romaji: cleanQuotes(w.romaji ?? "")
            )
        }

        var results: [(hiragana: String?, romaji: String?)] =
            Array(repeating: (nil, nil), count: aliyunWords.count)
        var cursor = 0  // 下一个可消费的 reading word 索引（单调前进）

        for (i, aliyunWord) in aliyunWords.enumerated() {
            let target = aliyunWord.Word.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !target.isEmpty else {
                // 空词（阿里云 ASR 的词间空格占位符）：不匹配任何读音，保持 nil（不写入 Furigana/Reading）
                results[i] = (nil, nil)
                continue
            }

            var hiragana = ""
            var romaji = ""
            var j = cursor
            var matched = false

            while j < cleaned.count {
                let rw = cleaned[j]
                let surf = rw.surface
                if surf.isEmpty {
                    j += 1
                    continue
                }

                if surf == target {
                    // 规则 1：精确命中单个 reading word
                    hiragana += rw.hiragana
                    romaji += rw.romaji
                    j += 1
                    matched = true
                    break
                } else if surf.hasPrefix(target) {
                    // 规则 2：阿里云词是 reading word 前缀（错切）→ 整段归属，不截断
                    hiragana += rw.hiragana
                    romaji += rw.romaji
                    j += 1
                    matched = true
                    break
                } else if target.hasPrefix(surf) {
                    // 规则 3：reading word 是阿里云词前缀 → 进入累加模式，
                    // 持续累加后续 reading words 直到拼接相等（如 ミートボール = ミート+ボール）
                    var accumulated = ""
                    while j < cleaned.count {
                        let acc = cleaned[j]
                        if acc.surface.isEmpty {
                            j += 1
                            continue
                        }
                        accumulated += acc.surface
                        hiragana += acc.hiragana
                        romaji += acc.romaji
                        j += 1
                        if accumulated == target {
                            matched = true
                            break
                        }
                        if accumulated.count > target.count {
                            // 累加超出仍未精确相等 → 放弃本次（不消费），避免错误归属
                            break
                        }
                    }
                    if !matched {
                        hiragana = ""
                        romaji = ""
                    }
                    break
                } else {
                    // 不匹配 → 放弃
                    break
                }
            }

            if matched {
                results[i] = (hiragana.isEmpty ? nil : hiragana,
                              romaji.isEmpty ? nil : romaji)
                cursor = j
            }
            // 未匹配：cursor 不动，让下一个阿里云词从同一位置重新尝试
        }

        return results
    }


    // MARK: - Helpers

    private static func buildResult(_ resp: ReadingResponse) -> ReadingResult? {
        let katakana = cleanQuotes(resp.katakana ?? "")
        let romaji = cleanQuotes(resp.romaji ?? "")
        guard !katakana.isEmpty || !romaji.isEmpty else { return nil }
        return ReadingResult(
            hiragana: katakanaToHiragana(katakana),
            katakana: katakana,
            romaji: romaji,
            words: resp.words ?? []
        )
    }

    /// 清理服务端返回的 'xxx' 引号包裹（'アノ' → アノ）
    static func cleanQuotes(_ s: String) -> String {
        s.replacingOccurrences(of: "'", with: "")
    }

    /// 片假名 → 平假名（播放界面统一显示平假名）
    static func katakanaToHiragana(_ katakana: String) -> String {
        let mutable = NSMutableString(string: katakana)
        CFStringTransform(mutable, nil, kCFStringTransformHiraganaKatakana, true)
        return mutable as String
    }
}

//
//  HunyuanManager.swift
//  Perapera
//
//  Created by Perapera on 2025.
//

import Foundation
import CommonCrypto

// MARK: - Response Models

/// TokenHub / OpenAI 兼容响应模型
struct OpenAIChatResponse: Codable {
    let id: String?
    let object: String?
    let choices: [OpenAIChoice]?
    let error: OpenAIErrorInfo?

    struct OpenAIChoice: Codable {
        let message: OpenAIMessage?
        let finish_reason: String?
    }

    struct OpenAIMessage: Codable {
        let role: String?
        let content: String?
    }

    struct OpenAIErrorInfo: Codable {
        let message: String
        let type: String?
        let code: String?
    }
}

/// 旧版腾讯云混元响应模型（保留兼容）
struct HunyuanChatResponse: Codable {
    let Response: ResponseData

    struct ResponseData: Codable {
        let RequestId: String?
        let Choices: [Choice]?
        let Created: Int?
        let Usage: Usage?
        let Error: ErrorInfo?
    }

    struct Choice: Codable {
        let Message: Message?
        let FinishReason: String?
    }

    struct Message: Codable {
        let Role: String?
        let Content: String?
    }

    struct Usage: Codable {
        let PromptTokens: Int?
        let CompletionTokens: Int?
        let TotalTokens: Int?
    }

    struct ErrorInfo: Codable {
        let Code: String?
        let Message: String?
    }
}

// MARK: - Translation Models

struct TranslationRequest: Codable {
    let words: [String]
    let targetLanguage: String
}

struct TranslationResponse: Codable {
    let translatedWords: [String]
}

// MARK: - Hunyuan Manager

class HunyuanManager {
    static let shared = HunyuanManager()

    private init() {}

    /// 共享的 URLSession（避免并发时创建大量临时 session）
    private lazy var translationSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 300
        config.httpMaximumConnectionsPerHost = 10
        return URLSession(configuration: config)
    }()

    // MARK: - 读音对齐熔断（Circuit Breaker）
    // lookupWordReadings（播放/加载时的整句读音对齐）是辅助功能：TokenHub 故障时走本地兜底。
    // 为避免 TokenHub 超时/故障期间形成「N 句 × 双端点 × 每次超时 30s」的慢速请求风暴，
    // 这里做进程级熔断：连续 3 次服务级失败（连接错误/超时/429/5xx，解析失败不计入——
    // 服务健康时个别句子的解析失败属正常）→ 熔断打开（冷却 60s 起、指数退避、上限 10min），
    // 期间所有对齐请求直接失败（首次跳过打印一行提示，后续静默）；冷却结束后首次调用作为
    // 试探，成功则复位。只作用于读音对齐路径，不影响翻译主功能。
    private let alignBreakerLock = NSLock()
    private var alignBreakerOpen = false
    private var alignBreakerFailures = 0
    private var alignBreakerOpenUntil: Date?
    private var alignBreakerSkipLogged = false
    private var alignBreakerCooldownExp = 0
    private let alignBreakerMaxFailures = 3
    private let alignBreakerBaseCooldown: TimeInterval = 60
    private let alignBreakerMaxCooldown: TimeInterval = 600

    /// 读音对齐熔断：请求前检查。false = 冷却中，调用方应直接按失败处理（不发请求）
    private func alignBreakerCanRequest() -> Bool {
        alignBreakerLock.lock()
        defer { alignBreakerLock.unlock() }
        if alignBreakerOpen {
            if let until = alignBreakerOpenUntil, Date() >= until {
                // 冷却结束：关闭熔断，放行一次试探请求
                alignBreakerOpen = false
                alignBreakerSkipLogged = false
                return true
            }
            if !alignBreakerSkipLogged {
                alignBreakerSkipLogged = true
                let remain = max(0, Int((alignBreakerOpenUntil ?? Date()).timeIntervalSinceNow))
                print("⏸ TokenHub: 读音对齐熔断冷却中（约剩余 \(remain)s），期间对齐请求直接跳过")
            }
            return false
        }
        return true
    }

    /// 服务级失败（连接错误/超时/429/5xx）计入熔断
    private func alignBreakerRecordFailure() {
        alignBreakerLock.lock()
        defer { alignBreakerLock.unlock() }
        alignBreakerFailures += 1
        if alignBreakerFailures >= alignBreakerMaxFailures, !alignBreakerOpen {
            alignBreakerOpen = true
            let cooldown = min(alignBreakerBaseCooldown * pow(2.0, Double(alignBreakerCooldownExp)), alignBreakerMaxCooldown)
            alignBreakerCooldownExp += 1
            alignBreakerOpenUntil = Date().addingTimeInterval(cooldown)
            print("⚠️ TokenHub: 读音对齐连续失败 \(alignBreakerFailures) 次，熔断打开，冷却 \(Int(cooldown))s（期间不再请求对齐）")
        }
    }

    /// 任一次成功即复位熔断
    private func alignBreakerRecordSuccess() {
        alignBreakerLock.lock()
        defer { alignBreakerLock.unlock() }
        alignBreakerFailures = 0
        alignBreakerCooldownExp = 0
        alignBreakerOpen = false
        alignBreakerOpenUntil = nil
        alignBreakerSkipLogged = false
    }

    // MARK: - Translation Methods
    
    /// 翻译单词数组（公开方法）
    /// - Parameters:
    ///   - words: 要翻译的单词数组
    ///   - completion: 完成回调，返回翻译后的单词数组或错误
    func translateWords(_ words: [String], completion: @escaping (Result<[String], Error>) -> Void) {
        // 如果单词数量较少，直接翻译
        if words.count <= 50 {
            translateWordsInternal(words, completion: completion)
            return
        }
        
        // 如果单词数量较多，分批翻译
        print("📝 单词数量较多(\(words.count))，将分批翻译...")
        
        let batchSize = 50  // 每批翻译 50 个单词
        var allTranslatedWords: [String] = []
        var currentIndex = 0
        
        func translateNextBatch() {
            guard currentIndex < words.count else {
                // 所有批次翻译完成
                print("✅ 所有批次翻译完成，共 \(allTranslatedWords.count) 个单词")
                completion(.success(allTranslatedWords))
                return
            }
            
            let endIndex = min(currentIndex + batchSize, words.count)
            let batch = Array(words[currentIndex..<endIndex])
            let batchNumber = (currentIndex / batchSize) + 1
            let totalBatches = (words.count + batchSize - 1) / batchSize
            
            print("📦 翻译第 \(batchNumber)/\(totalBatches) 批，共 \(batch.count) 个单词...")
            
            translateWordsInternal(batch) { result in
                switch result {
                case .success(let translatedBatch):
                    allTranslatedWords.append(contentsOf: translatedBatch)
                    currentIndex = endIndex
                    
                    // 继续翻译下一批
                    translateNextBatch()
                    
                case .failure(let error):
                    print("❌ 第 \(batchNumber) 批翻译失败: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        }
        
        // 开始翻译第一批
        translateNextBatch()
    }
    
    /// 翻译简单文本
    /// - Parameters:
    ///   - text: 要翻译的文本
    ///   - targetLanguage: 目标语言（如"日文"、"英文"等）
    ///   - completion: 完成回调，返回翻译后的文本或错误
    func translateText(_ text: String, targetLanguage: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = HunyuanConfig.generateRequestURL() else {
            completion(.failure(NSError(domain: "HunyuanManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的 API URL"])))
            return
        }

        let apiKey = HunyuanConfig.apiKey
        guard !apiKey.isEmpty else {
            completion(.failure(NSError(domain: "HunyuanManager", code: -9, userInfo: [NSLocalizedDescriptionKey: "TokenHub API Key 未配置"])))
            return
        }

        let prompt = """
        请将以下中文文本翻译成\(targetLanguage)，保持原文的语气和含义，只返回翻译结果，不要添加任何解释或额外内容。

        原文：
        \(text)
        """

        // OpenAI 兼容格式
        let requestBody: [String: Any] = [
            "model": HunyuanConfig.defaultModel,
            "messages": [["role": "user", "content": prompt]],
            "temperature": 0.3,
            "top_p": 1.0
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            completion(.failure(NSError(domain: "HunyuanManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "无法序列化请求体"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData

        print("🚀 发送文本翻译请求到 TokenHub API...")
        print("📝 原文长度: \(text.count) 字符")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "HunyuanManager", code: -3, userInfo: [NSLocalizedDescriptionKey: "未收到响应数据"])))
                return
            }

            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 API 响应: \(responseString.prefix(500))")
            }

            do {
                let chatResponse = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)

                if let apiError = chatResponse.error {
                    completion(.failure(NSError(domain: "HunyuanManager", code: -4, userInfo: [NSLocalizedDescriptionKey: "API 错误: \(apiError.message)"])))
                    return
                }

                guard let content = chatResponse.choices?.first?.message?.content else {
                    completion(.failure(NSError(domain: "HunyuanManager", code: -5, userInfo: [NSLocalizedDescriptionKey: "响应中没有内容"])))
                    return
                }

                print("✅ 翻译成功")
                completion(.success(content))

            } catch {
                print("❌ JSON 解析失败: \(error)")
                completion(.failure(error))
            }
        }

        task.resume()
    }
    
    /// 翻译 JSON 文件中每个 ResultDetail 的 Words，为每个 Word 添加 Translation 和 Reading
    /// - Parameters:
    ///   - jsonData: ASR 识别结果的 JSON 数据
    ///   - completion: 完成回调，返回翻译后的 JSON 数据或错误
    typealias TranslationProgress = (Int, Int, Int) -> Void

    func translateWordsToJapanese(jsonData: Data, progress: TranslationProgress? = nil, completion: @escaping (Result<Data, Error>) -> Void) {
        // 1. 解析 JSON
        guard var jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              var response = jsonObject["Response"] as? [String: Any],
              var data = response["Data"] as? [String: Any],
              var resultDetail = data["ResultDetail"] as? [[String: Any]] else {
            completion(.failure(NSError(domain: "HunyuanManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法解析 JSON 中的 ResultDetail 数组"])))
            return
        }

        let targetLang = ASRConfig.translationLanguageName
        let totalSentences = resultDetail.count
        print("📝 准备并发翻译 \(totalSentences) 条记录到\(targetLang)（最大 8 并发）...")

        // 2. 并发翻译
        let maxConcurrency = 8
        let semaphore = DispatchSemaphore(value: maxConcurrency)
        let group = DispatchGroup()
        let writeQueue = DispatchQueue(label: "com.perapera.translation.write")
        let progressLock = NSLock()
        var completedCount = 0
        var hadErrors = false
        var failedSentenceIndices: [Int] = []

        for index in 0..<totalSentences {
            let detail = resultDetail[index]
            guard let words = detail["Words"] as? [[String: Any]], !words.isEmpty else {
                // 句子没有词，直接跳过（同时也推进进度）
                progressLock.lock()
                completedCount += 1
                let cnt = completedCount
                progressLock.unlock()
                progress?(cnt, totalSentences, 0)
                continue
            }

            let wordValues = words.compactMap { $0["Word"] as? String }
            let sentenceIndex = index

            group.enter()
            semaphore.wait()

            translateSentenceWordsWithRetry(wordValues) { [weak self] result in
                guard let self = self else {
                    semaphore.signal()
                    group.leave()
                    return
                }

                switch result {
                case .success(let wordResults):
                    // 同步写入避免竞态（写入很快，不阻塞）
                    writeQueue.sync {
                        var updatedWords = words
                        for (i, wordResult) in wordResults.enumerated() {
                            guard i < updatedWords.count else { break }
                            updatedWords[i]["Translation"] = wordResult.translation
                            updatedWords[i]["Reading"] = wordResult.reading
                            updatedWords[i]["Furigana"] = wordResult.furigana
                        }
                        var updatedDetail = detail
                        updatedDetail["Words"] = updatedWords
                        resultDetail[sentenceIndex] = updatedDetail

                        if self.sentenceNeedsRetry(updatedWords) {
                            failedSentenceIndices.append(sentenceIndex)
                        }
                    }
                    print("  ✅ 第 \(sentenceIndex + 1)/\(totalSentences) 句翻译完成")

                case .failure(let error):
                    print("  ⚠️ 第 \(sentenceIndex + 1)/\(totalSentences) 句翻译失败: \(error.localizedDescription)，跳过")
                    hadErrors = true
                    writeQueue.sync {
                        failedSentenceIndices.append(sentenceIndex)
                    }
                }

                progressLock.lock()
                completedCount += 1
                let cnt = completedCount
                progressLock.unlock()
                progress?(cnt, totalSentences, wordValues.count)

                semaphore.signal()
                group.leave()
            }
        }

        // 3. 所有翻译完成后组装最终 JSON
        group.notify(queue: .global()) {
            if hadErrors {
                print("⚠️ 部分句子翻译失败，继续保存已翻译的内容")
            }

            let uniqueFailedSentenceIndices = Array(Set(failedSentenceIndices)).sorted()

            self.retryIncompleteSentences(indices: uniqueFailedSentenceIndices, in: resultDetail) { repairedResultDetail in
                data["ResultDetail"] = repairedResultDetail
                response["Data"] = data
                jsonObject["Response"] = response

                guard let finalData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted) else {
                    completion(.failure(NSError(domain: "HunyuanManager", code: -3, userInfo: [NSLocalizedDescriptionKey: "无法序列化最终 JSON"])))
                    return
                }

                print("✅ 所有 \(totalSentences) 条记录翻译完成（并发模式）")
                completion(.success(finalData))
            }
        }
    }

    private func retryIncompleteSentences(
        indices: [Int],
        in resultDetail: [[String: Any]],
        completion: @escaping ([[String: Any]]) -> Void
    ) {
        guard !indices.isEmpty else {
            completion(resultDetail)
            return
        }

        var mutableResultDetail = resultDetail

        func retry(at position: Int) {
            guard position < indices.count else {
                completion(mutableResultDetail)
                return
            }

            let sentenceIndex = indices[position]
            guard sentenceIndex < mutableResultDetail.count,
                  let words = mutableResultDetail[sentenceIndex]["Words"] as? [[String: Any]],
                  !words.isEmpty else {
                retry(at: position + 1)
                return
            }

            let wordValues = words.compactMap { $0["Word"] as? String }
            print("🔧 补翻第 \(sentenceIndex + 1) 句，共 \(indices.count) 句待补")

            translateSentenceWordsWithRetry(wordValues, maxAttempts: 4) { result in
                switch result {
                case .success(let wordResults):
                    var updatedWords = words
                    for (i, wordResult) in wordResults.enumerated() {
                        guard i < updatedWords.count else { break }
                        updatedWords[i]["Translation"] = wordResult.translation
                        updatedWords[i]["Reading"] = wordResult.reading
                        updatedWords[i]["Furigana"] = wordResult.furigana
                    }

                    if !self.sentenceNeedsRetry(updatedWords) {
                        var updatedDetail = mutableResultDetail[sentenceIndex]
                        updatedDetail["Words"] = updatedWords
                        mutableResultDetail[sentenceIndex] = updatedDetail
                        print("  ✅ 第 \(sentenceIndex + 1) 句补翻完成")
                    } else {
                        print("  ⚠️ 第 \(sentenceIndex + 1) 句补翻后仍不完整")
                    }

                case .failure(let error):
                    print("  ⚠️ 第 \(sentenceIndex + 1) 句补翻失败: \(error.localizedDescription)")
                }

                retry(at: position + 1)
            }
        }

        retry(at: 0)
    }

    private func sentenceNeedsRetry(_ words: [[String: Any]]) -> Bool {
        words.contains { word in
            guard let original = word["Word"] as? String else { return false }
            let trimmedOriginal = original.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedOriginal.isEmpty {
                return false
            }

            let punctuationOnly = trimmedOriginal.trimmingCharacters(
                in: CharacterSet.punctuationCharacters
                    .union(.symbols)
                    .union(.whitespacesAndNewlines)
            ).isEmpty
            if punctuationOnly {
                return false
            }

            let translation = (word["Translation"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let reading = (word["Reading"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let furigana = (word["Furigana"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            return translation.isEmpty || reading.isEmpty || furigana.isEmpty
        }
    }

    // MARK: - TokenHub 双端点容错辅助

    /// 判断是否为连接级错误（设备连不上端点，应切换端点而非重试同一端点）。
    /// 覆盖：超时(-1001)、找不到主机(-1003)、无法连接(-1004)、连接断开(-1005)、
    /// DNS 解析失败(-1006)、无网络连接(-1009)、漫游关闭(-1018)、数据流量受限(-1020)、
    /// 安全连接失败(-1200) 等。典型场景：设备侧连不上国际端点报 -1001/_kCFStreamErrorCodeKey=-2102。
    private static func isConnectionError(_ error: Error) -> Bool {
        let nsError = error as NSError
        switch nsError.code {
        case NSURLErrorTimedOut,                  // -1001
             NSURLErrorCannotFindHost,            // -1003
             NSURLErrorCannotConnectToHost,       // -1004
             NSURLErrorNetworkConnectionLost,     // -1005
             NSURLErrorDNSLookupFailed,           // -1006
             NSURLErrorNotConnectedToInternet,    // -1009
             NSURLErrorInternationalRoamingOff,   // -1018
             NSURLErrorCallIsActive,              // -1019
             NSURLErrorDataNotAllowed,            // -1020
             NSURLErrorSecureConnectionFailed:    // -1200
            return true
        default:
            return false
        }
    }

    /// 判断是否为鉴权/权限错误（TokenHub key 与端点版本不匹配时出现，应切换端点）
    private static func shouldSwitchEndpoint(statusCode: Int) -> Bool {
        return statusCode == 401 || statusCode == 403
    }

    /// 判断是否为可重试的服务端错误（429 限流、5xx 服务端故障）
    private static func isRetryableServerError(statusCode: Int) -> Bool {
        return statusCode == 429 || (statusCode >= 500 && statusCode <= 599)
    }

    /// 从错误中读取 HTTP 状态码（由请求层写入 userInfo["HTTPStatus"]），无则 nil
    private static func httpStatus(of error: Error) -> Int? {
        return (error as NSError).userInfo["HTTPStatus"] as? Int
    }

    /// 按「端点 + 尝试次数」推进策略：返回 nil 表示该错误应切换端点，
    /// 否则返回下一次重试的延迟秒数（nil 时也应切换）。
    /// 连接级错误/401/403 → 切换端点；429/5xx/其他 → 同端点退避重试，耗尽后切换。
    private static func retryPolicy(httpStatus: Int?, isConnection: Bool, attempt: Int, maxAttempts: Int) -> Double? {
        if isConnection || (httpStatus.map(shouldSwitchEndpoint) ?? false) {
            return nil
        }
        guard attempt < maxAttempts else { return nil }
        return Double(attempt)
    }

    private func translateSentenceWordsWithRetry(
        _ words: [String],
        maxAttempts: Int = 3,
        attempt: Int = 1,
        completion: @escaping (Result<[WordTranslationResult], Error>) -> Void
    ) {
        translateSentenceWordsWithRetry(
            words,
            endpointIndex: 0,
            attempt: attempt,
            maxAttempts: maxAttempts,
            lastError: nil,
            completion: completion
        )
    }

    /// 双端点 + 智能重试（内部递归实现）：
    /// 连接级错误/401/403 → 立即切换下一端点（不重试同端点）；
    /// 429/5xx/解析失败 → 同端点退避重试（maxAttempts 次），耗尽再切端点；
    /// 所有端点耗尽 → 返回最后一个错误。
    private func translateSentenceWordsWithRetry(
        _ words: [String],
        endpointIndex: Int,
        attempt: Int,
        maxAttempts: Int,
        lastError: Error?,
        completion: @escaping (Result<[WordTranslationResult], Error>) -> Void
    ) {
        let endpoints = HunyuanConfig.tokenHubEndpoints
        guard endpointIndex < endpoints.count else {
            let err = lastError ?? NSError(domain: "HunyuanManager", code: -12, userInfo: [NSLocalizedDescriptionKey: "TokenHub 所有端点均不可用"])
            print("❌ TokenHub 翻译所有端点均失败: \(err.localizedDescription)")
            completion(.failure(err))
            return
        }
        let baseURL = endpoints[endpointIndex]
        translateSentenceWordsOnce(words, baseURL: baseURL) { [weak self] result in
            switch result {
            case .success(let wordResults):
                completion(.success(wordResults))
            case .failure(let error):
                let status = Self.httpStatus(of: error)
                let conn = Self.isConnectionError(error)
                if let delay = Self.retryPolicy(httpStatus: status, isConnection: conn, attempt: attempt, maxAttempts: maxAttempts) {
                    // 同端点退避重试
                    print("🔁 端点 \(baseURL) 请求失败（\(error.localizedDescription)），\(delay)s 后同端点重试第 \(attempt + 1)/\(maxAttempts) 次")
                    DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                        self?.translateSentenceWordsWithRetry(
                            words,
                            endpointIndex: endpointIndex,
                            attempt: attempt + 1,
                            maxAttempts: maxAttempts,
                            lastError: error,
                            completion: completion
                        )
                    }
                } else {
                    // 切换下一端点
                    print("🔁 端点 \(baseURL) 不可用（\(error.localizedDescription)），切换到下一个端点")
                    self?.translateSentenceWordsWithRetry(
                        words,
                        endpointIndex: endpointIndex + 1,
                        attempt: 1,
                        maxAttempts: maxAttempts,
                        lastError: error,
                        completion: completion
                    )
                }
            }
        }
    }
    
    // MARK: - 翻译单句的所有词（返回翻译 + 读音）
    
    struct WordTranslationResult {
        let translation: String
        let reading: String
        let furigana: String
    }
    
    /// 翻译单句的所有词（入口）：自动携带双端点容错 + 智能重试（连接失败切国内端点）。
    /// 返回翻译 + 读音。
    private func translateSentenceWords(_ words: [String], completion: @escaping (Result<[WordTranslationResult], Error>) -> Void) {
        translateSentenceWordsWithRetry(words, completion: completion)
    }

    /// 翻译单句的所有词（单端点单次请求，由 translateSentenceWordsWithRetry 驱动双端点容错）。
    /// key 按端点取配套 key（国内端点用国内站 key，避免 401002）。
    private func translateSentenceWordsOnce(_ words: [String], baseURL: String, completion: @escaping (Result<[WordTranslationResult], Error>) -> Void) {
        guard let url = HunyuanConfig.generateRequestURL(baseURL: baseURL) else {
            completion(.failure(NSError(domain: "HunyuanManager", code: -4, userInfo: [NSLocalizedDescriptionKey: "无效的 API URL"])))
            return
        }

        let apiKey = HunyuanConfig.apiKey(for: baseURL)
        guard !apiKey.isEmpty else {
            completion(.failure(NSError(domain: "HunyuanManager", code: -9, userInfo: [NSLocalizedDescriptionKey: "TokenHub API Key 未配置，请在 HunyuanConfig.local.swift 中设置 _localApiKey"])))
            return
        }

        let targetLang = ASRConfig.translationLanguageName

        let wordsJSON = words.map { "\"\($0)\"" }.joined(separator: ", ")
        let prompt = """
        请将以下日语单词翻译成\(targetLang)，并给出每个日语单词的假名（furigana）和罗马音（romaji）读音。
        保持原有的顺序，数量必须与输入完全一致（\(words.count)个）。
        标点符号的翻译、假名和读音都保持原样。

        输入单词数组：[\(wordsJSON)]

        请严格以 JSON 格式返回，格式如下：
        {"results": [{"t": "翻译", "f": "ふりがな", "r": "romaji"}, ...]}

        注意：results 数组长度必须是 \(words.count)。
        """

        // OpenAI 兼容格式（小写 key）
        let requestBody: [String: Any] = [
            "model": HunyuanConfig.defaultModel,
            "messages": [["role": "user", "content": prompt]],
            "temperature": 0.3,
            "top_p": 1.0
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            completion(.failure(NSError(domain: "HunyuanManager", code: -5, userInfo: [NSLocalizedDescriptionKey: "无法序列化请求体"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData

        print("🚀 TokenHub 翻译请求: \(words.count) 个词, model=\(HunyuanConfig.defaultModel)")

        let task = translationSession.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard let data = data else {
                completion(.failure(NSError(domain: "HunyuanManager", code: -6, userInfo: [NSLocalizedDescriptionKey: "未收到响应数据"])))
                return
            }

            // 非 2xx 统一为带 HTTPStatus 的错误，由容错层决定重试或切换端点（401/403 切端点、429/5xx 重试）
            guard statusCode >= 200 && statusCode < 300 else {
                completion(.failure(NSError(domain: "HunyuanManager", code: -13, userInfo: [
                    NSLocalizedDescriptionKey: "TokenHub HTTP \(statusCode)",
                    "HTTPStatus": statusCode
                ])))
                return
            }

            // 打印原始响应用于调试
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 TokenHub 响应 HTTP \(statusCode): \(responseString.prefix(500))")
            }

            do {
                let chatResponse = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)

                // 检查 OpenAI 格式错误
                if let apiError = chatResponse.error {
                    completion(.failure(NSError(domain: "HunyuanManager", code: -8, userInfo: [NSLocalizedDescriptionKey: "API 错误: \(apiError.message)"])))
                    return
                }

                guard let content = chatResponse.choices?.first?.message?.content else {
                    completion(.failure(NSError(domain: "HunyuanManager", code: -7, userInfo: [NSLocalizedDescriptionKey: "响应中没有内容"])))
                    return
                }

                let results = self.extractWordTranslationResults(from: content, expectedCount: words.count)
                guard results.count == words.count else {
                    completion(.failure(NSError(
                        domain: "HunyuanManager",
                        code: -10,
                        userInfo: [NSLocalizedDescriptionKey: "翻译结果数量不匹配，期望 \(words.count) 个，实际 \(results.count) 个"]
                    )))
                    return
                }

                let hasMeaningfulContent = results.contains {
                    !$0.translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    !$0.furigana.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    !$0.reading.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
                guard hasMeaningfulContent else {
                    completion(.failure(NSError(
                        domain: "HunyuanManager",
                        code: -11,
                        userInfo: [NSLocalizedDescriptionKey: "翻译结果为空"]
                    )))
                    return
                }

                completion(.success(results))

            } catch {
                print("❌ JSON 解析失败: \(error)")
                completion(.failure(error))
            }
        }

        task.resume()
    }
    
    /// 从 API 响应中提取翻译+读音结果
    private func extractWordTranslationResults(from content: String, expectedCount: Int) -> [WordTranslationResult] {
        print("🔍 解析翻译响应: \(content.prefix(200))...")
        
        // 先尝试直接解析整个 content
        if let data = content.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let results = jsonObject["results"] as? [[String: Any]] {
            return parseResults(results)
        }
        
        // 尝试从 content 中提取 JSON 片段（处理 markdown 代码块等包裹）
        // 找到第一个 { 和最后一个 } 之间的内容
        guard let startIdx = content.firstIndex(of: "{"),
              let endIdx = content.lastIndex(of: "}") else {
            print("⚠️ 响应中没有找到 JSON 对象")
            return []
        }
        
        guard startIdx <= endIdx else {
            print("⚠️ JSON 边界无效")
            return []
        }
        
        let jsonString = String(content[startIdx...endIdx])
        
        if let data = jsonString.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let results = jsonObject["results"] as? [[String: Any]] {
            return parseResults(results)
        }
        
        print("⚠️ 无法解析翻译结果，返回空数组")
        return []
    }
    
    /// 解析 results 数组
    private func parseResults(_ results: [[String: Any]]) -> [WordTranslationResult] {
        return results.map { item in
            WordTranslationResult(
                translation: item["t"] as? String ?? "",
                reading: item["r"] as? String ?? "",
                furigana: item["f"] as? String ?? ""
            )
        }
    }
    
    /// 调用混元 API 翻译单词数组（公开方法，用于简单翻译场景）
    private func translateWordsInternal(_ words: [String], completion: @escaping (Result<[String], Error>) -> Void) {
        translateSentenceWords(words) { result in
            switch result {
            case .success(let wordResults):
                completion(.success(wordResults.map { $0.translation }))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - 读音对齐：大模型整句匹配（词级平假名 + 罗马音）

    /// 单个待对齐词的输入项
    struct WordReadingLookupItem {
        let index: Int
        let text: String
    }

    /// 大模型整句对齐（入口）：把一句话的日文原文、全部词、整句平假名、整句罗马音一起交给大模型，
    /// 让模型在整句注音串中为每个词匹配对应的平假名片段与罗马音片段。
    ///
    /// 提示词要求：所有词的片段按顺序直接拼接后，必须与整句 hiragana/romaji 完全一致（不能多字、不能少字）。
    /// 方法内仅做结构解析与数量校验；「拼接一致性」强校验由调用方在拿到结果后完成（通过才写回）。
    /// 自动携带双端点容错：国际端点连接失败/鉴权失败时切换国内端点。
    ///
    /// - Parameters:
    ///   - slice: 整句原文（日文）
    ///   - hiragana: 整句平假名注音（权威）
    ///   - romaji: 整句罗马音注音（权威）
    ///   - words: 该句全部词（按顺序），附词在句内的下标
    ///   - completion: 结果 [index: (furigana, romaji)]
    func lookupWordReadings(
        slice: String,
        hiragana: String,
        romaji: String,
        words: [WordReadingLookupItem],
        completion: @escaping (Result<[Int: (furigana: String, romaji: String)], Error>) -> Void
    ) {
        guard !words.isEmpty else {
            completion(.success([:]))
            return
        }
        // 读音对齐熔断冷却中：不发请求，直接按失败处理（调用方走本地兜底）
        guard alignBreakerCanRequest() else {
            completion(.failure(NSError(domain: "HunyuanManager", code: -38, userInfo: [NSLocalizedDescriptionKey: "TokenHub 读音对齐熔断冷却中，本次跳过"])))
            return
        }
        // 校验默认（国际站）key 已配置——intl 是首选端点
        let apiKey = HunyuanConfig.apiKey
        guard !apiKey.isEmpty else {
            completion(.failure(NSError(domain: "HunyuanManager", code: -31, userInfo: [NSLocalizedDescriptionKey: "TokenHub API Key 未配置，请在 HunyuanConfig.local.swift 中设置 _localApiKey"])))
            return
        }
        lookupWordReadingsWithRetry(
            slice: slice,
            hiragana: hiragana,
            romaji: romaji,
            words: words,
            endpointIndex: 0,
            attempt: 1,
            lastError: nil,
            completion: completion
        )
    }

    /// 双端点 + 智能重试（内部递归实现，规则同 translateSentenceWordsWithRetry）：
    /// 连接级错误/401/403 → 立即切换下一端点；429/5xx/解析失败 → 同端点退避重试（最多 3 次），耗尽再切端点。
    private func lookupWordReadingsWithRetry(
        slice: String,
        hiragana: String,
        romaji: String,
        words: [WordReadingLookupItem],
        endpointIndex: Int,
        attempt: Int,
        lastError: Error?,
        completion: @escaping (Result<[Int: (furigana: String, romaji: String)], Error>) -> Void
    ) {
        let endpoints = HunyuanConfig.tokenHubEndpoints
        guard endpointIndex < endpoints.count else {
            let err = lastError ?? NSError(domain: "HunyuanManager", code: -37, userInfo: [NSLocalizedDescriptionKey: "TokenHub 所有端点均不可用"])
            print("❌ TokenHub 整句对齐所有端点均失败: \(err.localizedDescription)")
            completion(.failure(err))
            return
        }
        let baseURL = endpoints[endpointIndex]
        lookupWordReadingsOnce(
            slice: slice, hiragana: hiragana, romaji: romaji, words: words, baseURL: baseURL
        ) { [weak self] result in
            switch result {
            case .success(let dict):
                self?.alignBreakerRecordSuccess()
                completion(.success(dict))
            case .failure(let error):
                let status = Self.httpStatus(of: error)
                let conn = Self.isConnectionError(error)
                // 服务级失败（连接错误/超时/429/5xx）计入熔断；解析失败等不计入
                if conn || status.map(Self.isRetryableServerError) ?? false {
                    self?.alignBreakerRecordFailure()
                }
                if let delay = Self.retryPolicy(httpStatus: status, isConnection: conn, attempt: attempt, maxAttempts: 3) {
                    print("🔁 端点 \(baseURL) 请求失败（\(error.localizedDescription)），\(delay)s 后同端点重试第 \(attempt + 1)/3 次")
                    DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                        self?.lookupWordReadingsWithRetry(
                            slice: slice, hiragana: hiragana, romaji: romaji, words: words,
                            endpointIndex: endpointIndex, attempt: attempt + 1, lastError: error, completion: completion
                        )
                    }
                } else {
                    print("🔁 端点 \(baseURL) 不可用（\(error.localizedDescription)），切换到下一个端点")
                    self?.lookupWordReadingsWithRetry(
                        slice: slice, hiragana: hiragana, romaji: romaji, words: words,
                        endpointIndex: endpointIndex + 1, attempt: 1, lastError: error, completion: completion
                    )
                }
            }
        }
    }

    /// 大模型整句对齐（单端点单次请求，由 lookupWordReadingsWithRetry 驱动双端点容错）。
    /// key 按端点取配套 key（国内端点用国内站 key，避免 401002）。
    private func lookupWordReadingsOnce(
        slice: String,
        hiragana: String,
        romaji: String,
        words: [WordReadingLookupItem],
        baseURL: String,
        completion: @escaping (Result<[Int: (furigana: String, romaji: String)], Error>) -> Void
    ) {
        guard let url = HunyuanConfig.generateRequestURL(baseURL: baseURL) else {
            completion(.failure(NSError(domain: "HunyuanManager", code: -30, userInfo: [NSLocalizedDescriptionKey: "无效的 API URL"])))
            return
        }
        let apiKey = HunyuanConfig.apiKey(for: baseURL)

        let itemsJSON = words.map { "{\"i\": \($0.index), \"w\": \"\($0.text)\"}" }.joined(separator: ", ")
        let prompt = """
        你是一名日语读音对齐专家。我会给你一句话的日文原文、按顺序切分的词列表、整句平假名注音和整句罗马音注音。请你为每个词标注它在这句话的注音中对应的平假名片段和罗马音片段。

        说明：
        - 原文（SliceSentence）全部是日文。
        - 词列表是原文按顺序切分的连续片段，所有词拼接起来正好等于原文。
        - 整句平假名（hiragana）和整句罗马音（romaji）是该句的权威注音，包含标点（如「、」「。」）；罗马音中每个读音单元之间用空格分隔。

        对齐规则（必须严格遵守）：
        1. 每个词的平假名片段 f 必须是整句平假名中连续的一段字符；罗马音片段 r 的字符必须来自整句罗马音（不含空格）。
        2. 所有词的 f 按顺序直接拼接，必须与整句平假名完全一致——不能多一个字，也不能少一个字。
        3. 所有词的 r 按顺序直接拼接（不含空格），必须与整句罗马音去掉空格后完全一致——不能多一个字符，也不能少一个字符。标点（如「、」「。」）必须包含在相邻词的 f/r 片段中，确保拼接后完整。
        4. 如果某个词在注音串中没有对应内容（如无法对应的错切片段），f 和 r 都返回空字符串。
        5. 输出前请自查：所有 f 拼接 == 整句平假名；所有 r 拼接去掉空格 == 整句罗马音去掉空格。不满足就修正后再输出。

        示例：
        原文：はあ、もう今日のは美味しそう。
        词列表：[{"i":0,"w":"は"},{"i":1,"w":"あ"},{"i":2,"w":"もう"},{"i":3,"w":"今日"},{"i":4,"w":"のは"},{"i":5,"w":"美味"},{"i":6,"w":"しそ"},{"i":7,"w":"う"}]
        整句平假名：はあ、もうきょうのはおいしそう。
        整句罗马音：haa 、 mou kyou no ha oishi sou 。
        正确输出：{"results":[{"i":0,"f":"は","r":"ha"},{"i":1,"f":"あ、","r":"a、"},{"i":2,"f":"もう","r":"mou"},{"i":3,"f":"きょう","r":"kyou"},{"i":4,"f":"のは","r":"noha"},{"i":5,"f":"おいし","r":"oishi"},{"i":6,"f":"そ","r":"so"},{"i":7,"f":"う。","r":"u。"}]}

        现在处理下面的句子：
        原文：\(slice)
        词列表：[\(itemsJSON)]
        整句平假名：\(hiragana)
        整句罗马音：\(romaji)

        输出格式：{"results":[{"i":0,"f":"...","r":"..."},...]}
        要求：i 必须与词列表一一对应；results 数量必须与词数量一致；只输出 JSON，不要任何解释，不要 markdown 代码块。
        """

        let requestBody: [String: Any] = [
            "model": HunyuanConfig.defaultModel,
            "messages": [["role": "user", "content": prompt]],
            "temperature": 0.1,
            "top_p": 1.0
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            completion(.failure(NSError(domain: "HunyuanManager", code: -32, userInfo: [NSLocalizedDescriptionKey: "无法序列化请求体"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData

        print("🚀 TokenHub 整句读音对齐请求: \(words.count) 个词, 原文=\(slice.prefix(20))")

        let task = translationSession.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard let data = data else {
                completion(.failure(NSError(domain: "HunyuanManager", code: -33, userInfo: [NSLocalizedDescriptionKey: "未收到响应数据"])))
                return
            }
            // 非 2xx 统一为带 HTTPStatus 的错误，由容错层决定重试或切换端点（401/403 切端点、429/5xx 重试）
            guard statusCode >= 200 && statusCode < 300 else {
                completion(.failure(NSError(domain: "HunyuanManager", code: -38, userInfo: [
                    NSLocalizedDescriptionKey: "TokenHub HTTP \(statusCode)",
                    "HTTPStatus": statusCode
                ])))
                return
            }
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 TokenHub 整句读音对齐响应 HTTP \(statusCode): \(responseString.prefix(400))")
            }

            do {
                let chatResponse = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
                if let apiError = chatResponse.error {
                    completion(.failure(NSError(domain: "HunyuanManager", code: -34, userInfo: [NSLocalizedDescriptionKey: "API 错误: \(apiError.message)"])))
                    return
                }
                guard let content = chatResponse.choices?.first?.message?.content else {
                    completion(.failure(NSError(domain: "HunyuanManager", code: -35, userInfo: [NSLocalizedDescriptionKey: "响应中没有内容"])))
                    return
                }

                let raw = Self.extractWordReadingLookupResults(from: content)
                guard raw.count == words.count else {
                    completion(.failure(NSError(domain: "HunyuanManager", code: -36, userInfo: [NSLocalizedDescriptionKey: "对齐结果数量不匹配，期望 \(words.count) 个，实际 \(raw.count) 个"])))
                    return
                }
                print("✅ TokenHub 整句读音对齐完成: \(raw.count) 个词")
                completion(.success(raw))
            } catch {
                print("❌ JSON 解析失败: \(error)")
                completion(.failure(error))
            }
        }
        task.resume()
    }

    /// 从大模型响应中提取整句对齐结果 [index: (furigana, romaji)]（未校验，仅结构化）
    private static func extractWordReadingLookupResults(from content: String) -> [Int: (furigana: String, romaji: String)] {
        var jsonObject: [String: Any]?
        if let data = content.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            jsonObject = obj
        } else if let startIdx = content.firstIndex(of: "{"),
                  let endIdx = content.lastIndex(of: "}"),
                  startIdx <= endIdx,
                  let data = String(content[startIdx...endIdx]).data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            jsonObject = obj
        }
        guard let obj = jsonObject,
              let results = obj["results"] as? [[String: Any]] else {
            print("⚠️ 读音对齐响应中无 results")
            return [:]
        }
        var dict: [Int: (furigana: String, romaji: String)] = [:]
        for item in results {
            guard let i = item["i"] as? Int else { continue }
            let f = item["f"] as? String ?? ""
            let r = item["r"] as? String ?? ""
            dict[i] = (f, r)
        }
        return dict
    }

    // MARK: - Tencent Cloud API V3 Signature
    
    /// 生成腾讯云 API 签名 (V3)
    private func generateSignature(action: String, timestamp: Int, body: String) -> String {
        let secretId = HunyuanConfig.secretId
        let secretKey = HunyuanConfig.secretKey
        
        let date = dateString(from: timestamp)
        let service = HunyuanConfig.service
        
        // 1. 拼接规范请求串
        let httpRequestMethod = "POST"
        let canonicalUri = "/"
        let canonicalQueryString = ""
        let canonicalHeaders = "content-type:application/json; charset=utf-8\nhost:\(HunyuanConfig.apiHost)\n"
        let signedHeaders = "content-type;host"
        let hashedRequestPayload = sha256(body)
        let canonicalRequest = "\(httpRequestMethod)\n\(canonicalUri)\n\(canonicalQueryString)\n\(canonicalHeaders)\n\(signedHeaders)\n\(hashedRequestPayload)"
        
        // 2. 拼接待签名字符串
        let algorithm = "TC3-HMAC-SHA256"
        let credentialScope = "\(date)/\(service)/tc3_request"
        let hashedCanonicalRequest = sha256(canonicalRequest)
        let stringToSign = "\(algorithm)\n\(timestamp)\n\(credentialScope)\n\(hashedCanonicalRequest)"
        
        // 3. 计算签名
        let secretDate = hmacSHA256(key: "TC3\(secretKey)", data: date)
        let secretService = hmacSHA256(key: secretDate, data: service)
        let secretSigning = hmacSHA256(key: secretService, data: "tc3_request")
        let signature = hmacSHA256Hex(key: secretSigning, data: stringToSign)
        
        // 4. 拼接 Authorization
        return "\(algorithm) Credential=\(secretId)/\(credentialScope), SignedHeaders=\(signedHeaders), Signature=\(signature)"
    }
    
    private func dateString(from timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }
    
    private func sha256(_ string: String) -> String {
        guard let data = string.data(using: .utf8) else { return "" }
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    private func hmacSHA256(key: String, data: String) -> Data {
        let keyData = key.data(using: .utf8)!
        let dataData = data.data(using: .utf8)!
        return hmacSHA256(key: keyData, data: dataData)
    }
    
    private func hmacSHA256(key: Data, data: String) -> Data {
        let dataData = data.data(using: .utf8)!
        return hmacSHA256(key: key, data: dataData)
    }
    
    private func hmacSHA256(key: Data, data: Data) -> Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        key.withUnsafeBytes { keyBytes in
            data.withUnsafeBytes { dataBytes in
                CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256), keyBytes.baseAddress, key.count, dataBytes.baseAddress, data.count, &hash)
            }
        }
        return Data(hash)
    }
    
    private func hmacSHA256Hex(key: Data, data: String) -> String {
        let result = hmacSHA256(key: key, data: data)
        return result.map { String(format: "%02x", $0) }.joined()
    }
}

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

            translateSentenceWords(wordValues) { [weak self] result in
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
                    }
                    print("  ✅ 第 \(sentenceIndex + 1)/\(totalSentences) 句翻译完成")

                case .failure(let error):
                    print("  ⚠️ 第 \(sentenceIndex + 1)/\(totalSentences) 句翻译失败: \(error.localizedDescription)，跳过")
                    hadErrors = true
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

            data["ResultDetail"] = resultDetail
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
    
    // MARK: - 翻译单句的所有词（返回翻译 + 读音）
    
    struct WordTranslationResult {
        let translation: String
        let reading: String
        let furigana: String
    }
    
    private func translateSentenceWords(_ words: [String], completion: @escaping (Result<[WordTranslationResult], Error>) -> Void) {
        guard let url = HunyuanConfig.generateRequestURL() else {
            completion(.failure(NSError(domain: "HunyuanManager", code: -4, userInfo: [NSLocalizedDescriptionKey: "无效的 API URL"])))
            return
        }

        let apiKey = HunyuanConfig.apiKey
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

//
//  HunyuanManager.swift
//  Perapera
//
//  Created by Perapera on 2025.
//

import Foundation
import CommonCrypto

// MARK: - Response Models

struct HunyuanChatResponse: Codable {
    let Response: ResponseData
    
    struct ResponseData: Codable {
        let RequestId: String
        let Choices: [Choice]?
        let Created: Int?
        let Usage: Usage?
        let Error: ErrorInfo?
    }
    
    struct Choice: Codable {
        let Message: Message
        let FinishReason: String?
    }
    
    struct Message: Codable {
        let Role: String
        let Content: String
    }
    
    struct Usage: Codable {
        let PromptTokens: Int
        let CompletionTokens: Int
        let TotalTokens: Int
    }
    
    struct ErrorInfo: Codable {
        let Code: String
        let Message: String
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
        
        let timestamp = Int(Date().timeIntervalSince1970)
        
        // 构建提示词
        let prompt = """
        请将以下中文文本翻译成\(targetLanguage)，保持原文的语气和含义，只返回翻译结果，不要添加任何解释或额外内容。
        
        原文：
        \(text)
        """
        
        // 构建请求体
        let requestBody: [String: Any] = [
            "Model": HunyuanConfig.defaultModel,
            "Messages": [
                [
                    "Role": "user",
                    "Content": prompt
                ]
            ],
            "Temperature": 0.3,
            "TopP": 1.0
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            completion(.failure(NSError(domain: "HunyuanManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "无法序列化请求体"])))
            return
        }
        
        // 创建请求
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue(HunyuanConfig.apiVersion, forHTTPHeaderField: "X-TC-Version")
        request.setValue("ChatCompletions", forHTTPHeaderField: "X-TC-Action")
        request.setValue("\(timestamp)", forHTTPHeaderField: "X-TC-Timestamp")
        request.httpBody = jsonData
        
        // 生成签名
        let signature = generateSignature(
            action: "ChatCompletions",
            timestamp: timestamp,
            body: String(data: jsonData, encoding: .utf8) ?? ""
        )
        request.setValue(signature, forHTTPHeaderField: "Authorization")
        
        print("🚀 发送文本翻译请求到混元 API...")
        print("📝 原文长度: \(text.count) 字符")
        
        // 发送请求
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "HunyuanManager", code: -3, userInfo: [NSLocalizedDescriptionKey: "未收到响应数据"])))
                return
            }
            
            // 打印原始响应（用于调试）
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 API 响应: \(responseString)")
            }
            
            // 解析响应
            do {
                let chatResponse = try JSONDecoder().decode(HunyuanChatResponse.self, from: data)
                
                // 检查是否有错误
                if let error = chatResponse.Response.Error {
                    completion(.failure(NSError(domain: "HunyuanManager", code: -4, userInfo: [NSLocalizedDescriptionKey: "API 错误: \(error.Message) (Code: \(error.Code))"])))
                    return
                }
                
                guard let content = chatResponse.Response.Choices?.first?.Message.Content else {
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
    
    /// 翻译 JSON 文件中的 Words 数组为中文
    /// - Parameters:
    ///   - jsonData: 包含 Words 数组的 JSON 数据
    ///   - completion: 完成回调，返回翻译后的 JSON 数据或错误
    func translateWordsToJapanese(jsonData: Data, completion: @escaping (Result<Data, Error>) -> Void) {
        // 1. 解析 JSON 获取所有 ResultDetail 中的 Words 数组
        guard let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let response = jsonObject["Response"] as? [String: Any],
              let data = response["Data"] as? [String: Any],
              let resultDetail = data["ResultDetail"] as? [[String: Any]] else {
            completion(.failure(NSError(domain: "HunyuanManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法解析 JSON 中的 ResultDetail 数组"])))
            return
        }
        
        // 2. 收集所有 Words
        var allWords: [String] = []
        var wordCounts: [Int] = [] // 记录每个 detail 的单词数量
        
        for detail in resultDetail {
            if let words = detail["Words"] as? [[String: Any]] {
                let wordValues = words.compactMap { $0["Word"] as? String }
                allWords.append(contentsOf: wordValues)
                wordCounts.append(wordValues.count)
            } else {
                wordCounts.append(0)
            }
        }
        
        if allWords.isEmpty {
            completion(.failure(NSError(domain: "HunyuanManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "所有 ResultDetail 中的 Words 数组为空"])))
            return
        }
        
        print("📝 准备翻译 \(allWords.count) 个单词到\(ASRConfig.translationLanguageName)（来自 \(resultDetail.count) 条记录）...")
        
        // 3. 调用混元 API 进行翻译
        translateWordsInternal(allWords) { [weak self] result in
            switch result {
            case .success(let translatedWords):
                print("✅ 翻译成功，共 \(translatedWords.count) 个\(ASRConfig.translationLanguageName)单词")
                
                // 打印翻译对照表（简化版，避免格式化问题）
                print("\n" + String(repeating: "=", count: 80))
                print("📋 翻译结果对照表")
                print(String(repeating: "=", count: 80))
                
                for (index, word) in allWords.enumerated() {
                    let japanese = index < translatedWords.count ? translatedWords[index] : "N/A"
                    print("\(index + 1). \(word) → \(japanese)")
                }
                
                print(String(repeating: "=", count: 80))
                print("✅ 总计: \(allWords.count) 个单词已翻译\n")
                
                // 4. 将翻译结果添加到原 JSON 中
                guard let modifiedData = self?.addTranslationToJSON(
                    originalData: jsonData,
                    translatedWords: translatedWords,
                    wordCounts: wordCounts
                ) else {
                    completion(.failure(NSError(domain: "HunyuanManager", code: -3, userInfo: [NSLocalizedDescriptionKey: "无法添加翻译结果到 JSON"])))
                    return
                }
                
                completion(.success(modifiedData))
                
            case .failure(let error):
                print("❌ 翻译失败: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    /// 调用混元 API 翻译单词数组（内部方法）
    private func translateWordsInternal(_ words: [String], completion: @escaping (Result<[String], Error>) -> Void) {
        guard let url = HunyuanConfig.generateRequestURL() else {
            completion(.failure(NSError(domain: "HunyuanManager", code: -4, userInfo: [NSLocalizedDescriptionKey: "无效的 API URL"])))
            return
        }
        
        let timestamp = Int(Date().timeIntervalSince1970)
        
        // 构建提示词
        let wordsJSON = words.map { "\"\($0)\"" }.joined(separator: ", ")
        let targetLang = ASRConfig.translationLanguageName
        let responseKey = ASRConfig.translationResponseKey
        let prompt = """
        请将以下单词翻译成\(targetLang)，保持原有的顺序，只返回翻译后的\(targetLang)单词数组，不要添加任何解释或额外内容。
        
        输入单词数组：[\(wordsJSON)]
        
        请以 JSON 格式返回，格式如下：
        {"\(responseKey)": ["\(targetLang)1", "\(targetLang)2", ...]}
        """
        
        // 构建请求体（使用腾讯云混元 API 格式）
        let requestBody: [String: Any] = [
            "Model": HunyuanConfig.defaultModel,
            "Messages": [
                [
                    "Role": "user",
                    "Content": prompt
                ]
            ],
            "Temperature": 0.3,  // 使用较低的温度以获得更稳定的翻译
            "TopP": 1.0
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            completion(.failure(NSError(domain: "HunyuanManager", code: -5, userInfo: [NSLocalizedDescriptionKey: "无法序列化请求体"])))
            return
        }
        
        // 创建请求
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120  // 设置超时时间为 120 秒
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue(HunyuanConfig.apiVersion, forHTTPHeaderField: "X-TC-Version")
        request.setValue("ChatCompletions", forHTTPHeaderField: "X-TC-Action")
        request.setValue("\(timestamp)", forHTTPHeaderField: "X-TC-Timestamp")
        request.httpBody = jsonData
        
        // 生成签名
        let signature = generateSignature(
            action: "ChatCompletions",
            timestamp: timestamp,
            body: String(data: jsonData, encoding: .utf8) ?? ""
        )
        request.setValue(signature, forHTTPHeaderField: "Authorization")
        
        print("🚀 发送翻译请求到混元 API (共 \(words.count) 个单词)...")
        
        // 创建自定义 URLSession 配置
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 120
        configuration.timeoutIntervalForResource = 300
        let session = URLSession(configuration: configuration)
        
        // 发送请求
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "HunyuanManager", code: -6, userInfo: [NSLocalizedDescriptionKey: "未收到响应数据"])))
                return
            }
            
            // 打印原始响应（用于调试）
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 API 响应: \(responseString)")
            }
            
            // 解析响应
            do {
                let chatResponse = try JSONDecoder().decode(HunyuanChatResponse.self, from: data)
                
                // 检查是否有错误
                if let error = chatResponse.Response.Error {
                    completion(.failure(NSError(domain: "HunyuanManager", code: -8, userInfo: [NSLocalizedDescriptionKey: "API 错误: \(error.Message) (Code: \(error.Code))"])))
                    return
                }
                
                guard let content = chatResponse.Response.Choices?.first?.Message.Content else {
                    completion(.failure(NSError(domain: "HunyuanManager", code: -7, userInfo: [NSLocalizedDescriptionKey: "响应中没有内容"])))
                    return
                }
                
                // 从响应内容中提取 JSON
                let translatedWords = self.extractTranslatedWords(from: content)
                completion(.success(translatedWords))
                
            } catch {
                print("❌ JSON 解析失败: \(error)")
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        print("   缺少键: \(key.stringValue), 路径: \(context.codingPath)")
                    case .typeMismatch(let type, let context):
                        print("   类型不匹配: \(type), 路径: \(context.codingPath)")
                    case .valueNotFound(let type, let context):
                        print("   值不存在: \(type), 路径: \(context.codingPath)")
                    case .dataCorrupted(let context):
                        print("   数据损坏: \(context)")
                    @unknown default:
                        print("   未知错误")
                    }
                }
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    /// 从 API 响应内容中提取翻译后的单词数组
    private func extractTranslatedWords(from content: String) -> [String] {
        print("\n🔍 开始解析 API 响应内容...")
        print("原始响应: \(content)")
        
        // 尝试直接解析 JSON
        let responseKey = ASRConfig.translationResponseKey
        if let jsonData = content.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
           let translatedWords = jsonObject[responseKey] as? [String] {
            print("✅ 成功解析 JSON 格式响应")
            return translatedWords
        }
        
        // 如果直接解析失败，尝试从文本中提取 JSON 部分
        if let jsonStart = content.range(of: "{"),
           let jsonEnd = content.range(of: "}", options: .backwards) {
            let jsonString = String(content[jsonStart.lowerBound...jsonEnd.upperBound])
            print("🔍 尝试提取 JSON 片段: \(jsonString)")
            
            if let jsonData = jsonString.data(using: .utf8),
               let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let translatedWords = jsonObject[responseKey] as? [String] {
                print("✅ 成功从文本中提取 JSON")
                return translatedWords
            }
        }
        
        print("⚠️ 无法从响应中提取翻译结果，返回空数组")
        return []
    }
    
    /// 将翻译结果添加到原始 JSON 数据中
    /// - Parameters:
    ///   - originalData: 原始 JSON 数据
    ///   - translatedWords: 所有翻译后的单词（按顺序）
    ///   - wordCounts: 每个 ResultDetail 的单词数量
    private func addTranslationToJSON(originalData: Data, translatedWords: [String], wordCounts: [Int]) -> Data? {
        guard var jsonObject = try? JSONSerialization.jsonObject(with: originalData) as? [String: Any],
              var response = jsonObject["Response"] as? [String: Any],
              var data = response["Data"] as? [String: Any],
              var resultDetail = data["ResultDetail"] as? [[String: Any]] else {
            return nil
        }
        
        var translatedIndex = 0 // 当前翻译词的索引
        
        // 遍历所有 ResultDetail
        for (detailIndex, wordCount) in wordCounts.enumerated() {
            guard detailIndex < resultDetail.count else { break }
            
            var detail = resultDetail[detailIndex]
            
            // 获取当前 detail 的 Words 数组
            guard let words = detail["Words"] as? [[String: Any]] else {
                continue
            }
            
            // 创建翻译词数组，保持与 Words 相同的结构
            let responseKey = ASRConfig.translationResponseKey
            var translatedWordDicts: [[String: Any]] = []
            
            for wordDict in words {
                var newWordDict = wordDict
                
                // 替换 Word 字段为翻译结果
                if translatedIndex < translatedWords.count {
                    newWordDict["Word"] = translatedWords[translatedIndex]
                    translatedIndex += 1
                } else {
                    newWordDict["Word"] = "N/A"
                }
                
                translatedWordDicts.append(newWordDict)
            }
            
            // 添加翻译词字段到当前 detail
            detail[responseKey] = translatedWordDicts
            resultDetail[detailIndex] = detail
        }
        
        // 更新嵌套结构
        data["ResultDetail"] = resultDetail
        response["Data"] = data
        jsonObject["Response"] = response
        
        // 转换回 JSON 数据
        return try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted)
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

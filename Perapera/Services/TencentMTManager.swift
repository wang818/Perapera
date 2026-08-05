//
//  TencentMTManager.swift
//  Perapera
//
//  Created by Perapera on 2025.
//

import Foundation
import CommonCrypto

// MARK: - Response Models

/// 腾讯云机器翻译 TextTranslateBatch 响应
struct TMTBatchTranslateResponse: Codable {
    let Response: ResponseData

    struct ResponseData: Codable {
        let TargetTextList: [String]?
        let Source: String?
        let Target: String?
        let RequestId: String?
        let Error: ErrorInfo?
    }

    struct ErrorInfo: Codable {
        let Code: String
        let Message: String
    }
}

/// 腾讯云机器翻译 TextTranslate 响应
struct TMTTranslateResponse: Codable {
    let Response: ResponseData

    struct ResponseData: Codable {
        let TargetText: String?
        let Source: String?
        let Target: String?
        let RequestId: String?
        let Error: ErrorInfo?
    }

    struct ErrorInfo: Codable {
        let Code: String
        let Message: String
    }
}

// MARK: - Tencent MT Manager

class TencentMTManager {
    static let shared = TencentMTManager()

    private init() {}

    /// 共享的 URLSession
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        config.httpMaximumConnectionsPerHost = 10
        return URLSession(configuration: config)
    }()

    // MARK: - Public Methods

    /// 翻译 ASR 识别结果的 JSON 数据
    /// 使用腾讯云机器翻译 API 对每句 FinalSentence 做整句翻译，
    /// 同时对每个 Word 使用机械转换生成 Reading（罗马音）和 Furigana（平假名）
    ///
    /// - Parameters:
    ///   - jsonData: ASR 识别结果的 JSON 数据
    ///   - progress: 进度回调 (已完成句数, 总句数, 本句词数（始终为 0）)
    ///   - completion: 完成回调，返回翻译后的 JSON 数据或错误
    func translateASRJSON(
        jsonData: Data,
        progress: ((Int, Int, Int) -> Void)? = nil,
        completion: @escaping (Result<Data, Error>) -> Void
    ) {
        // 1. 解析 JSON
        guard var jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              var response = jsonObject["Response"] as? [String: Any],
              var data = response["Data"] as? [String: Any],
              var resultDetail = data["ResultDetail"] as? [[String: Any]] else {
            completion(.failure(NSError(domain: "TencentMTManager", code: -1,
                                        userInfo: [NSLocalizedDescriptionKey: "无法解析 JSON 中的 ResultDetail 数组"])))
            return
        }

        let totalSentences = resultDetail.count
        let sourceLang = TencentMTConfig.sourceLanguage
        let targetLang = TencentMTConfig.targetLanguage

        print("📝 Tencent MT 翻译: \(totalSentences) 句, \(sourceLang) → \(targetLang)")

        // 2. 收集需要翻译的句子
        var items: [SentenceItem] = []
        for (index, detail) in resultDetail.enumerated() {
            let sentenceText = detail["FinalSentence"] as? String ?? ""
            let words = detail["Words"] as? [[String: Any]] ?? []
            if !sentenceText.isEmpty {
                items.append(SentenceItem(index: index, text: sentenceText, words: words))
            }
        }

        guard !items.isEmpty else {
            // 没有需要翻译的句子，直接生成结果
            data["ResultDetail"] = resultDetail
            response["Data"] = data
            jsonObject["Response"] = response
            if let finalData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted) {
                completion(.success(finalData))
            } else {
                completion(.failure(NSError(domain: "TencentMTManager", code: -2,
                                            userInfo: [NSLocalizedDescriptionKey: "无法序列化 JSON"])))
            }
            return
        }

        // 3. 分批并发翻译
        let maxConcurrency = 5
        let batchSize = 10  // TextTranslateBatch 每次最多 10 条
        let semaphore = DispatchSemaphore(value: maxConcurrency)
        let group = DispatchGroup()
        let writeQueue = DispatchQueue(label: "com.perapera.mt.write")
        let progressLock = NSLock()
        var completedCount = 0
        var hadErrors = false

        for batchStart in stride(from: 0, to: items.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, items.count)
            let batch = Array(items[batchStart..<batchEnd])

            group.enter()
            semaphore.wait()

            translateSentenceBatch(batch, source: sourceLang, target: targetLang) { [weak self] result in
                guard let self = self else {
                    semaphore.signal()
                    group.leave()
                    return
                }

                switch result {
                case .success(let translatedTexts):
                    writeQueue.sync {
                        for (i, item) in batch.enumerated() {
                            guard i < translatedTexts.count else { break }
                            var detail = resultDetail[item.index]

                            // 存储整句翻译
                            detail["TranslatedText"] = translatedTexts[i]

                            // 为每个词生成 Reading（罗马音）和 Furigana（平假名）
                            let updatedWords = item.words.map { word -> [String: Any] in
                                var updatedWord = word
                                if let wordText = word["Word"] as? String {
                                    let trimmed = wordText.trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !trimmed.isEmpty && !self.isPunctuationOrSymbol(trimmed) {
                                        updatedWord["Reading"] = JapaneseTextConverter.shared.toRomaji(wordText)
                                        updatedWord["Furigana"] = JapaneseTextConverter.shared.toHiragana(wordText)
                                    } else {
                                        // 标点符号保持原样
                                        updatedWord["Reading"] = wordText
                                        updatedWord["Furigana"] = wordText
                                    }
                                }
                                return updatedWord
                            }
                            detail["Words"] = updatedWords
                            resultDetail[item.index] = detail
                        }
                    }
                    print("  ✅ 第 \(batchStart + 1)-\(batchEnd)/\(items.count) 句翻译完成")

                case .failure(let error):
                    print("  ⚠️ 批量翻译失败 (第 \(batchStart + 1)-\(batchEnd)): \(error.localizedDescription)")
                    hadErrors = true
                }

                progressLock.lock()
                completedCount += batch.count
                let cnt = min(completedCount, totalSentences)
                progressLock.unlock()
                progress?(cnt, totalSentences, 0)

                semaphore.signal()
                group.leave()
            }
        }

        // 4. 所有翻译完成后组装最终 JSON
        group.notify(queue: .global()) {
            if hadErrors {
                print("⚠️ 部分句子翻译失败，继续保存已翻译的内容")
            }

            data["ResultDetail"] = resultDetail
            response["Data"] = data
            jsonObject["Response"] = response

            guard let finalData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted) else {
                completion(.failure(NSError(domain: "TencentMTManager", code: -3,
                                            userInfo: [NSLocalizedDescriptionKey: "无法序列化最终 JSON"])))
                return
            }

            print("✅ Tencent MT 翻译完成: \(totalSentences) 句")
            completion(.success(finalData))
        }
    }

    // MARK: - Private: API Calls

    /// 批量翻译句子文本
    private func translateSentenceBatch(
        _ items: [SentenceItem],
        source: String,
        target: String,
        completion: @escaping (Result<[String], Error>) -> Void
    ) {
        let texts = items.map { $0.text }

        guard texts.count == 1 else {
            // 多条文本 → 使用 TextTranslateBatch
            translateBatch(texts: texts, source: source, target: target, completion: completion)
            return
        }

        // 单条文本 → 使用 TextTranslate
        translateSingle(text: texts[0], source: source, target: target) { result in
            switch result {
            case .success(let translated):
                completion(.success([translated]))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// TextTranslateBatch — 批量翻译
    private func translateBatch(
        texts: [String],
        source: String,
        target: String,
        completion: @escaping (Result<[String], Error>) -> Void
    ) {
        guard let url = TencentMTConfig.generateRequestURL() else {
            completion(.failure(NSError(domain: "TencentMTManager", code: -10,
                                        userInfo: [NSLocalizedDescriptionKey: "无效的 API URL"])))
            return
        }

        let timestamp = Int(Date().timeIntervalSince1970)
        let params: [String: Any] = [
            "SourceTextList": texts,
            "Source": source,
            "Target": target,
            "ProjectId": 0
        ]

        sendRequest(url: url, action: "TextTranslateBatch", timestamp: timestamp, params: params) { data, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "TencentMTManager", code: -11,
                                            userInfo: [NSLocalizedDescriptionKey: "无响应数据"])))
                return
            }

            do {
                let decoder = JSONDecoder()
                let result = try decoder.decode(TMTBatchTranslateResponse.self, from: data)

                if let apiError = result.Response.Error {
                    completion(.failure(NSError(domain: "TencentMTManager", code: -12,
                                                userInfo: [NSLocalizedDescriptionKey: "\(apiError.Code): \(apiError.Message)"])))
                    return
                }

                guard let targetTextList = result.Response.TargetTextList else {
                    completion(.failure(NSError(domain: "TencentMTManager", code: -13,
                                                userInfo: [NSLocalizedDescriptionKey: "响应中缺少 TargetTextList"])))
                    return
                }

                print("📥 TMT 批量翻译响应: \(texts.count) → \(targetTextList.count) 条")
                completion(.success(targetTextList))

            } catch {
                print("❌ TMT JSON 解析失败: \(error)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("   原始响应: \(responseString.prefix(500))")
                }
                completion(.failure(error))
            }
        }
    }

    /// TextTranslate — 单条翻译
    private func translateSingle(
        text: String,
        source: String,
        target: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let url = TencentMTConfig.generateRequestURL() else {
            completion(.failure(NSError(domain: "TencentMTManager", code: -10,
                                        userInfo: [NSLocalizedDescriptionKey: "无效的 API URL"])))
            return
        }

        let timestamp = Int(Date().timeIntervalSince1970)
        let params: [String: Any] = [
            "SourceText": text,
            "Source": source,
            "Target": target,
            "ProjectId": 0
        ]

        sendRequest(url: url, action: "TextTranslate", timestamp: timestamp, params: params) { data, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "TencentMTManager", code: -11,
                                            userInfo: [NSLocalizedDescriptionKey: "无响应数据"])))
                return
            }

            do {
                let decoder = JSONDecoder()
                let result = try decoder.decode(TMTTranslateResponse.self, from: data)

                if let apiError = result.Response.Error {
                    completion(.failure(NSError(domain: "TencentMTManager", code: -12,
                                                userInfo: [NSLocalizedDescriptionKey: "\(apiError.Code): \(apiError.Message)"])))
                    return
                }

                guard let targetText = result.Response.TargetText else {
                    completion(.failure(NSError(domain: "TencentMTManager", code: -13,
                                                userInfo: [NSLocalizedDescriptionKey: "响应中缺少 TargetText"])))
                    return
                }

                print("📥 TMT 单条翻译: \"\(text.prefix(30))...\" → \"\(targetText.prefix(30))...\"")
                completion(.success(targetText))

            } catch {
                print("❌ TMT JSON 解析失败: \(error)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("   原始响应: \(responseString.prefix(500))")
                }
                completion(.failure(error))
            }
        }
    }

    // MARK: - Private: HTTP Request + Signing

    /// 发送带 TC3-HMAC-SHA256 签名的请求
    private func sendRequest(
        url: URL,
        action: String,
        timestamp: Int,
        params: [String: Any],
        completion: @escaping (Data?, Error?) -> Void
    ) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue(TencentMTConfig.apiVersion, forHTTPHeaderField: "X-TC-Version")
        request.setValue(action, forHTTPHeaderField: "X-TC-Action")
        request.setValue("\(timestamp)", forHTTPHeaderField: "X-TC-Timestamp")

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: params)
            request.httpBody = jsonData

            let bodyString = String(data: jsonData, encoding: .utf8) ?? ""
            let signature = generateSignature(action: action, timestamp: timestamp, body: bodyString)
            request.setValue(signature, forHTTPHeaderField: "Authorization")

            print("🚀 TMT \(action) 请求: \(params.count) 个参数")

            let task = session.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(nil, error)
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    print("📥 TMT 响应 HTTP \(httpResponse.statusCode)")
                }

                completion(data, nil)
            }
            task.resume()

        } catch {
            completion(nil, error)
        }
    }

    // MARK: - TC3-HMAC-SHA256 签名

    private func generateSignature(action: String, timestamp: Int, body: String) -> String {
        let secretId = COSConfig.secretId
        let secretKey = COSConfig.secretKey

        let date = dateString(from: timestamp)
        let service = TencentMTConfig.service

        // 1. 拼接规范请求串
        let httpRequestMethod = "POST"
        let canonicalUri = "/"
        let canonicalQueryString = ""
        let canonicalHeaders = "content-type:application/json; charset=utf-8\nhost:\(TencentMTConfig.apiHost)\n"
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

    // MARK: - Helpers

    /// 判断字符串是否仅包含标点符号
    private func isPunctuationOrSymbol(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(
            in: CharacterSet.punctuationCharacters
                .union(.symbols)
                .union(.whitespacesAndNewlines)
        )
        return trimmed.isEmpty
    }
}

// MARK: - SentenceItem (nested in translateASRJSON context)

extension TencentMTManager {
    fileprivate struct SentenceItem {
        let index: Int
        let text: String
        let words: [[String: Any]]
    }
}

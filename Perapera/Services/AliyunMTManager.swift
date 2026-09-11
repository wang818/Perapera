//
//  AliyunMTManager.swift
//  Perapera
//
//  阿里云机器翻译 — 使用 RAM AccessKey 签名调用 Translate API
//

import Foundation
import CommonCrypto

// MARK: - Response Model

struct AliyunMTTranslateResponse: Codable {
    let Code: String?
    let Message: String?
    let RequestId: String?
    let Data: TranslateData?

    struct TranslateData: Codable {
        let Translated: String?
        let WordCount: String?
        let DetectedLanguage: String?
    }
}

// MARK: - Manager

class AliyunMTManager {
    static let shared = AliyunMTManager()

    /// 错误域
    static let errorDomain = "AliyunMTManager"
    /// 鉴权失败错误码
    static let authErrorCode = 401

    private init() {}

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        config.httpMaximumConnectionsPerHost = 10
        return URLSession(configuration: config)
    }()

    // MARK: - Public API

    /// 翻译 ASR 识别结果的 JSON 数据
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
            completion(.failure(NSError(domain: Self.errorDomain, code: -1,
                                        userInfo: [NSLocalizedDescriptionKey: "无法解析 JSON 中的 ResultDetail 数组"])))
            return
        }

        let totalSentences = resultDetail.count
        // 翻译源语言：优先用识别阶段已写入的真实语言；否则用 "auto" 让阿里云 MT 自动检测
        // （阿里云 fun-asr 不返回语言检测结果，故英文/中文等多语言视频需靠 MT auto 检测，
        //   响应里的 DetectedLanguage 会写回 SourceLanguage，避免一律按日语处理）。
        let existingSource = (data["SourceLanguage"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let sourceLang = existingSource ?? "auto"
        let targetLang = AliyunMTConfig.targetLanguage

        // 记录本次译文所用语言（统一用 App「第二字幕」语言代码），随 JSON 写回，
        // 供播放加载时比对是否需要按当前设置重翻
        data["TranslationLanguage"] = LanguageManager.getSecondSubtitleLanguageCode()
        // 记录视频源语言（语音识别语言）代码。若尚未确定（auto 检测中），暂先占位，
        // 整句翻译回调里会据 MT 返回的 DetectedLanguage 更新为真实语言。
        if existingSource == nil {
            data["SourceLanguage"] = "auto"
        }

        print("📝 Aliyun MT 翻译: \(totalSentences) 句, \(sourceLang) → \(targetLang)")

        // 2. 收集需要翻译的句子
        struct SentenceItem {
            let index: Int
            let text: String
            let words: [[String: Any]]
        }

        var items: [SentenceItem] = []
        for (index, detail) in resultDetail.enumerated() {
            let sentenceText = detail["FinalSentence"] as? String ?? ""
            let words = detail["Words"] as? [[String: Any]] ?? []
            if !sentenceText.isEmpty {
                items.append(SentenceItem(index: index, text: sentenceText, words: words))
            }
        }

        guard !items.isEmpty else {
            data["ResultDetail"] = resultDetail
            response["Data"] = data
            jsonObject["Response"] = response
            if let finalData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted) {
                completion(.success(finalData))
            } else {
                completion(.failure(NSError(domain: Self.errorDomain, code: -2,
                                            userInfo: [NSLocalizedDescriptionKey: "无法序列化 JSON"])))
            }
            return
        }

        // 3. 并发翻译（50 QPS 限制，保守用 45 QPS + 10 并发）
        let maxConcurrency = 10
        let maxQPS = 45
        let semaphore = DispatchSemaphore(value: maxConcurrency)
        let group = DispatchGroup()
        let writeQueue = DispatchQueue(label: "com.perapera.alimt.write")
        let rateLock = NSLock()
        var requestTimestamps: [Date] = []
        var completedCount = 0
        var hadErrors = false

        func waitForRateLimit() {
            rateLock.lock()
            let now = Date()
            requestTimestamps = requestTimestamps.filter { now.timeIntervalSince($0) < 1.0 }
            if requestTimestamps.count >= maxQPS {
                if let oldest = requestTimestamps.first {
                    let wait = 1.0 - now.timeIntervalSince(oldest) + 0.01
                    if wait > 0 {
                        rateLock.unlock()
                        Thread.sleep(forTimeInterval: wait)
                        rateLock.lock()
                    }
                }
            }
            requestTimestamps.append(Date())
            rateLock.unlock()
        }

        for (index, item) in items.enumerated() {
            group.enter()
            semaphore.wait()
            waitForRateLimit()

            translate(text: item.text, source: sourceLang, target: targetLang) { [weak self] result in
                guard let self = self else { return }

                switch result {
                case .success(let translated):
                    writeQueue.sync {
                        var detail = resultDetail[item.index]
                        detail["TranslatedText"] = translated.translated

                        // 捕获阿里云 MT 自动检测出的源语言（source 传 auto 时返回），
                        // 用于写回 SourceLanguage（真实视频语言）。
                        if let detected = translated.detectedLanguage, !detected.isEmpty {
                            let current = (data["SourceLanguage"] as? String) ?? ""
                            if current.isEmpty || current == "auto" {
                                data["SourceLanguage"] = detected
                            }
                        }

                        let updatedWords = item.words.map { word -> [String: Any] in
                            var updatedWord = word
                            if let wordText = word["Word"] as? String {
                                let trimmed = wordText.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !trimmed.isEmpty && !self.isPunctuationOrSymbol(trimmed) {
                                    // 词级读音优先保留 ASR 阶段 /reading 已写入的值，缺失才本地兜底。
                                    // 词级 Translation 由后续逐词翻译阶段写入（不再复用整句译文）。
                                    let existingReading = updatedWord["Reading"] as? String
                                    if existingReading == nil || existingReading!.isEmpty {
                                        updatedWord["Reading"] = JapaneseTextConverter.shared.toRomaji(wordText)
                                    }
                                    let existingFurigana = updatedWord["Furigana"] as? String
                                    if existingFurigana == nil || existingFurigana!.isEmpty {
                                        updatedWord["Furigana"] = JapaneseTextConverter.shared.toHiragana(wordText)
                                    }
                                } else {
                                    updatedWord["Translation"] = wordText
                                    updatedWord["Reading"] = wordText
                                    updatedWord["Furigana"] = wordText
                                }
                            }
                            return updatedWord
                        }
                        detail["Words"] = updatedWords
                        resultDetail[item.index] = detail
                    }

                case .failure(let error):
                    print("  ⚠️ 第 \(item.index + 1) 句翻译失败: \(error.localizedDescription)")
                    hadErrors = true
                }

                completedCount += 1
                if completedCount % 20 == 0 || completedCount == items.count {
                    print("  ✅ Aliyun MT 整句进度: \(completedCount)/\(items.count)")
                }
                progress?(min(completedCount, totalSentences), totalSentences, 0)

                semaphore.signal()
                group.leave()
            }
        }

        group.notify(queue: .global()) {
            if hadErrors {
                print("⚠️ 部分句子翻译失败，继续保存已翻译的内容")
            }

            // 逐词翻译阶段：对每个非标点词单独翻译（按第二语言），写入 Words[].Translation，
            // 供播放器点击词显示第二语言词义。
            // 源语言取整句翻译阶段检测到的真实语言（data["SourceLanguage"]），
            // 若仍为 auto（未检测到）则继续用 auto。
            let wordSourceLang = ((data["SourceLanguage"] as? String) ?? "").isEmpty
                ? "auto"
                : ((data["SourceLanguage"] as? String) ?? "auto")
            self.translateWordsInResultDetail(resultDetail, sourceLang: wordSourceLang, targetLang: targetLang) { wordResultDetail in
                data["ResultDetail"] = wordResultDetail
                response["Data"] = data
                jsonObject["Response"] = response

                if let finalData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted) {
                    print("✅ Aliyun MT 翻译完成: \(totalSentences) 句（含逐词翻译）")
                    completion(.success(finalData))
                } else {
                    completion(.failure(NSError(domain: Self.errorDomain, code: -3,
                                                userInfo: [NSLocalizedDescriptionKey: "无法序列化最终 JSON"])))
                }
            }
        }
    }

    /// 逐词翻译阶段：遍历所有句子的所有词，对非标点词按目标语言（第二语言）单独翻译，
    /// 写入每个词字典的 `Translation` 字段。复用与整句翻译一致的限流（45 QPS / 10 并发）。
    /// - Parameters:
    ///   - resultDetail: 已完成整句翻译的 ResultDetail 数组（会被深拷贝后修改并回调）
    ///   - sourceLang / targetLang: 源/目标语言代码
    ///   - completion: 主线程无关，在后台队列回调翻译后的 ResultDetail 数组
    private func translateWordsInResultDetail(
        _ resultDetail: [[String: Any]],
        sourceLang: String,
        targetLang: String,
        completion: @escaping ([[String: Any]]) -> Void
    ) {
        // 收集待翻译的词：记录其句子索引、词索引、词文本
        struct WordRef {
            let sentenceIndex: Int
            let wordIndex: Int
            let text: String
        }
        var refs: [WordRef] = []
        for (sIdx, detail) in resultDetail.enumerated() {
            guard let words = detail["Words"] as? [[String: Any]] else { continue }
            for (wIdx, word) in words.enumerated() {
                guard let text = word["Word"] as? String else { continue }
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty || isPunctuationOrSymbol(trimmed) { continue }
                refs.append(WordRef(sentenceIndex: sIdx, wordIndex: wIdx, text: trimmed))
            }
        }

        // 没有需要逐词翻译的词，直接返回原数组
        guard !refs.isEmpty else {
            completion(resultDetail)
            return
        }

        var mutated = resultDetail
        let total = refs.count
        let maxConcurrency = 10
        let semaphore = DispatchSemaphore(value: maxConcurrency)
        let group = DispatchGroup()
        let writeQueue = DispatchQueue(label: "com.perapera.alimt.wordwrite")
        let rateLock = NSLock()
        var requestTimestamps: [Date] = []
        var completedCount = 0

        func waitForWordRateLimit() {
            rateLock.lock()
            let now = Date()
            requestTimestamps = requestTimestamps.filter { now.timeIntervalSince($0) < 1.0 }
            if requestTimestamps.count >= 45 {
                if let oldest = requestTimestamps.first {
                    let wait = 1.0 - now.timeIntervalSince(oldest) + 0.01
                    if wait > 0 {
                        rateLock.unlock()
                        Thread.sleep(forTimeInterval: wait)
                        rateLock.lock()
                    }
                }
            }
            requestTimestamps.append(Date())
            rateLock.unlock()
        }

        for ref in refs {
            group.enter()
            semaphore.wait()
            waitForWordRateLimit()

            translate(text: ref.text, source: sourceLang, target: targetLang) { [weak self] result in
                guard let self = self else {
                    semaphore.signal()
                    group.leave()
                    return
                }
                if case .success(let wordTranslation) = result {
                    let trimmed = wordTranslation.translated.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        writeQueue.sync {
                            if var words = mutated[ref.sentenceIndex]["Words"] as? [[String: Any]],
                               ref.wordIndex < words.count {
                                words[ref.wordIndex]["Translation"] = trimmed
                                mutated[ref.sentenceIndex]["Words"] = words
                            }
                        }
                    }
                }
                completedCount += 1
                if completedCount % 50 == 0 || completedCount == total {
                    print("  🔤 逐词翻译进度: \(completedCount)/\(total)")
                }
                semaphore.signal()
                group.leave()
            }
        }

        group.notify(queue: .global()) {
            completion(mutated)
        }
    }

    // MARK: - Private: Translate API

    private func translate(
        text: String,
        source: String,
        target: String,
        completion: @escaping (Result<(translated: String, detectedLanguage: String?), Error>) -> Void
    ) {
        let accessKeyId = AliyunConfig.accessKeyId
        let accessKeySecret = AliyunConfig.accessKeySecret

        guard !accessKeyId.isEmpty, !accessKeySecret.isEmpty else {
            completion(.failure(NSError(domain: Self.errorDomain, code: Self.authErrorCode,
                                        userInfo: [NSLocalizedDescriptionKey: "阿里云 AccessKey 未配置"])))
            return
        }

        var params: [String: String] = [
            "Action": "Translate",
            "FormatType": "text",
            "SourceLanguage": source,
            "TargetLanguage": target,
            "SourceText": text,
            "Scene": "social",
            "Format": "JSON",
            "Version": "2018-10-12",
            "AccessKeyId": accessKeyId,
            "SignatureMethod": "HMAC-SHA1",
            "Timestamp": aliyunTimestamp(),
            "SignatureVersion": "1.0",
            "SignatureNonce": UUID().uuidString
        ]

        // 计算签名
        let signature = aliyunRPCSignature(params: params, secret: accessKeySecret, httpMethod: "POST")
        params["Signature"] = signature

        // 构建 form-urlencoded body
        let bodyString = params.sorted(by: { $0.key < $1.key })
            .map { "\(aliyunEncode($0.key))=\(aliyunEncode($0.value))" }
            .joined(separator: "&")

        guard let url = URL(string: "https://\(AliyunMTConfig.endpoint)/") else {
            completion(.failure(NSError(domain: Self.errorDomain, code: -10,
                                        userInfo: [NSLocalizedDescriptionKey: "无效的 API URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyString.data(using: .utf8)

        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: Self.errorDomain, code: -11,
                                            userInfo: [NSLocalizedDescriptionKey: "无响应数据"])))
                return
            }

            do {
                let decoder = JSONDecoder()
                let result = try decoder.decode(AliyunMTTranslateResponse.self, from: data)

                if let code = result.Code, code != "200" {
                    let message = result.Message ?? "未知错误"
                    let isAuthError = (code == "10009" || code == "10010" || code == "10011" || code == "10013")
                    let errCode = isAuthError ? Self.authErrorCode : (Int(code) ?? -1)
                    completion(.failure(NSError(domain: Self.errorDomain, code: errCode,
                                                userInfo: [NSLocalizedDescriptionKey: "[\(code)] \(message)"])))
                    return
                }

                guard let translated = result.Data?.Translated else {
                    completion(.failure(NSError(domain: Self.errorDomain, code: -13,
                                                userInfo: [NSLocalizedDescriptionKey: "响应中缺少翻译结果"])))
                    return
                }

                let detected = result.Data?.DetectedLanguage
                completion(.success((translated: translated, detectedLanguage: detected)))

            } catch {
                if let responseStr = String(data: data, encoding: .utf8) {
                    print("❌ Aliyun MT JSON 解析失败: \(responseStr.prefix(500))")
                }
                completion(.failure(error))
            }
        }
        task.resume()
    }

    // MARK: - Alibaba Cloud RPC Signature V1

    /// 阿里云 RPC 签名（HMAC-SHA1 + Base64）
    private func aliyunRPCSignature(params: [String: String], secret: String, httpMethod: String) -> String {
        // 1. 按参数名排序（排除 Signature）
        let sortedParams = params
            .filter { $0.key != "Signature" }
            .sorted { $0.key < $1.key }

        // 2. 构造规范化查询字符串
        let canonicalQueryString = sortedParams
            .map { "\(aliyunEncode($0.key))=\(aliyunEncode($0.value))" }
            .joined(separator: "&")

        // 3. 构造待签名字符串
        let stringToSign = "\(httpMethod)&\(aliyunEncode("/"))&\(aliyunEncode(canonicalQueryString))"

        // 4. HMAC-SHA1 + Base64
        let key = "\(secret)&"
        let signData = hmacSHA1(key: key, data: stringToSign)
        return signData.base64EncodedString()
    }

    /// 阿里云 RFC 3986 URL 编码（大写十六进制）
    private func aliyunEncode(_ string: String) -> String {
        let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~")
        return string.addingPercentEncoding(withAllowedCharacters: unreserved) ?? string
    }

    /// ISO 8601 UTC 时间戳
    private func aliyunTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: Date())
    }

    // MARK: - HMAC-SHA1

    private func hmacSHA1(key: String, data: String) -> Data {
        let keyData = key.data(using: .utf8)!
        let dataData = data.data(using: .utf8)!
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        keyData.withUnsafeBytes { keyBytes in
            dataData.withUnsafeBytes { dataBytes in
                CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA1), keyBytes.baseAddress, keyData.count, dataBytes.baseAddress, dataData.count, &hash)
            }
        }
        return Data(hash)
    }

    // MARK: - Helpers

    private func isPunctuationOrSymbol(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(
            in: CharacterSet.punctuationCharacters
                .union(.symbols)
                .union(.whitespacesAndNewlines)
        )
        return trimmed.isEmpty
    }
}

// MARK: - MT Config

struct AliyunMTConfig {
    /// 阿里云机器翻译 API 端点（新加坡）
    static let endpoint = "mt.ap-southeast-1.aliyuncs.com"

    /// 源语言代码
    static var sourceLanguage: String {
        switch ASRConfig.engineModelType {
        case "16k_ja": return "ja"
        case "16k_en": return "en"
        case "16k_zh", "16k_zh_video": return "zh"
        case "16k_ca": return "zh"
        default: return "auto"
        }
    }

    /// 目标语言代码
    static var targetLanguage: String {
        switch ASRConfig.translationTargetLanguage {
        case "zh-CN": return "zh"
        case "ja-JP": return "ja"
        case "en-US": return "en"
        case "ko-KR": return "ko"
        default: return "zh"
        }
    }
}

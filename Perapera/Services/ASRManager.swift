//
//  ASRManager.swift
//  Perapera
//
//  Created by Perapera on 2024.
//

import Foundation
import CommonCrypto

struct ASRTaskResponse: Codable {
    let Response: ResponseData
    
    struct ResponseData: Codable {
        let RequestId: String
        let Data: TaskData?
        let Error: ErrorInfo?
    }
    
    struct TaskData: Codable {
        let TaskId: Int
    }
    
    struct ErrorInfo: Codable {
        let Code: String
        let Message: String
    }
}

struct ASRResultResponse: Codable {
    let Response: ResponseData
    
    struct ResponseData: Codable {
        let RequestId: String
        let Data: TaskResult?
        let Error: ErrorInfo?
    }
    
    struct TaskResult: Codable {
        let TaskId: Int
        let Status: Int  // 0: 等待, 1: 执行中, 2: 成功, 3: 失败
        let StatusStr: String
        let Result: String?  // 识别结果文本
        let ResultDetail: [SentenceDetail]?  // 详细识别结果
        let AudioDuration: Double?  // 音频时长（秒）
        let ErrorMsg: String?
    }
    
    struct SentenceDetail: Codable {
        let FinalSentence: String  // 最终识别结果
        let SliceSentence: String  // 分词结果
        let WrittenText: String?  // 书面化文本
        let StartMs: Int  // 开始时间（毫秒）
        let EndMs: Int  // 结束时间（毫秒）
        let SpeechSpeed: Double  // 语速
        let WordsNum: Int  // 词数
        let Words: [WordDetail]?  // 词级别详细信息
        let SpeakerId: Int?  // 说话人ID
        let EmotionalEnergy: Double?  // 情绪能量
        let SilenceTime: Int?  // 静音时长
        let EmotionType: [String]?  // 情绪类型
    }
    
    struct WordDetail: Codable {
        let Word: String  // 词
        let OffsetStartMs: Int  // 开始时间（毫秒）
        let OffsetEndMs: Int  // 结束时间（毫秒）
    }
    
    struct ErrorInfo: Codable {
        let Code: String
        let Message: String
    }
}

class ASRManager: NSObject {
    
    static let shared = ASRManager()
    
    private override init() {
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// 创建录音文件识别任务
    /// - Parameters:
    ///   - audioURL: 音频文件的 COS URL
    ///   - completion: 完成回调，返回 TaskId 或错误
    func createRecognitionTask(
        audioURL: String,
        completion: @escaping (Result<Int, Error>) -> Void
    ) {
        let timestamp = Int(Date().timeIntervalSince1970)
        let nonce = Int.random(in: 1000...9999)
        
        // 构建请求参数
        let params: [String: Any] = [
            "EngineModelType": ASRConfig.engineModelType,
            "ChannelNum": ASRConfig.channelNum,
            "ResTextFormat": ASRConfig.resTextFormat,
            "SourceType": ASRConfig.sourceType,
            "Url": audioURL,
            "FilterDirty": ASRConfig.filterDirty,
            "FilterModal": ASRConfig.filterModal,
            "FilterPunc": ASRConfig.filterPunc,
            "ConvertNumMode": ASRConfig.convertNumMode
        ]
        
        guard let url = ASRConfig.generateRequestURL() else {
            completion(.failure(NSError(domain: "ASRManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的 API URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue(ASRConfig.apiVersion, forHTTPHeaderField: "X-TC-Version")
        request.setValue("CreateRecTask", forHTTPHeaderField: "X-TC-Action")
        request.setValue("\(timestamp)", forHTTPHeaderField: "X-TC-Timestamp")
        
        // 生成签名
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: params)
            request.httpBody = jsonData
            
            let signature = generateSignature(
                action: "CreateRecTask",
                timestamp: timestamp,
                body: String(data: jsonData, encoding: .utf8) ?? ""
            )
            request.setValue(signature, forHTTPHeaderField: "Authorization")
            
            // 发送请求
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                    return
                }
                
                guard let data = data else {
                    DispatchQueue.main.async {
                        completion(.failure(NSError(domain: "ASRManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "无响应数据"])))
                    }
                    return
                }
                
                // 打印原始响应数据用于调试
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📥 创建识别任务 API 响应:")
                    print(responseString)
                }
                
                do {
                    let decoder = JSONDecoder()
                    let result = try decoder.decode(ASRTaskResponse.self, from: data)
                    
                    DispatchQueue.main.async {
                        if let error = result.Response.Error {
                            completion(.failure(NSError(domain: "ASRManager", code: -3, userInfo: [NSLocalizedDescriptionKey: error.Message])))
                        } else if let taskId = result.Response.Data?.TaskId {
                            completion(.success(taskId))
                        } else {
                            completion(.failure(NSError(domain: "ASRManager", code: -4, userInfo: [NSLocalizedDescriptionKey: "未返回 TaskId"])))
                        }
                    }
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
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            }
            task.resume()
            
        } catch {
            completion(.failure(error))
        }
    }
    
    /// 查询识别结果
    /// - Parameters:
    ///   - taskId: 任务 ID
    ///   - completion: 完成回调，返回原始 JSON Data 和解析后的结果
    func queryRecognitionResult(
        taskId: Int,
        completion: @escaping (Result<(taskResult: ASRResultResponse.TaskResult, rawJSON: Data), Error>) -> Void
    ) {
        let timestamp = Int(Date().timeIntervalSince1970)
        
        let params: [String: Any] = [
            "TaskId": taskId
        ]
        
        guard let url = ASRConfig.generateRequestURL() else {
            completion(.failure(NSError(domain: "ASRManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的 API URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue(ASRConfig.apiVersion, forHTTPHeaderField: "X-TC-Version")
        request.setValue("DescribeTaskStatus", forHTTPHeaderField: "X-TC-Action")
        request.setValue("\(timestamp)", forHTTPHeaderField: "X-TC-Timestamp")
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: params)
            request.httpBody = jsonData
            
            let signature = generateSignature(
                action: "DescribeTaskStatus",
                timestamp: timestamp,
                body: String(data: jsonData, encoding: .utf8) ?? ""
            )
            request.setValue(signature, forHTTPHeaderField: "Authorization")
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                    return
                }
                
                guard let data = data else {
                    DispatchQueue.main.async {
                        completion(.failure(NSError(domain: "ASRManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "无响应数据"])))
                    }
                    return
                }
                
                // 打印原始响应数据用于调试
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📥 查询识别结果 API 响应:")
                    print(responseString)
                }
                
                do {
                    let decoder = JSONDecoder()
                    let result = try decoder.decode(ASRResultResponse.self, from: data)
                    
                    DispatchQueue.main.async {
                        if let error = result.Response.Error {
                            completion(.failure(NSError(domain: "ASRManager", code: -3, userInfo: [NSLocalizedDescriptionKey: error.Message])))
                        } else if let taskResult = result.Response.Data {
                            // 返回解析后的结果和原始 JSON 数据
                            completion(.success((taskResult: taskResult, rawJSON: data)))
                        } else {
                            completion(.failure(NSError(domain: "ASRManager", code: -4, userInfo: [NSLocalizedDescriptionKey: "未返回任务结果"])))
                        }
                    }
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
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            }
            task.resume()
            
        } catch {
            completion(.failure(error))
        }
    }
    
    // MARK: - Private Methods
    
    /// 生成腾讯云 API 签名 (V3)
    private func generateSignature(action: String, timestamp: Int, body: String) -> String {
        let secretId = COSConfig.secretId
        let secretKey = COSConfig.secretKey
        
        let date = dateString(from: timestamp)
        let service = ASRConfig.service
        
        // 1. 拼接规范请求串
        let httpRequestMethod = "POST"
        let canonicalUri = "/"
        let canonicalQueryString = ""
        let canonicalHeaders = "content-type:application/json; charset=utf-8\nhost:\(ASRConfig.apiHost)\n"
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

//
//  COSConfig.swift
//  Perapera
//
//  Created by Perapera on 2024.
//

import Foundation

struct COSConfig {
    // MARK: - COS Configuration
    // TODO: Replace these with your actual Tencent Cloud COS credentials
    
    // 本地开发配置（在 COSConfig.local.swift 中设置）
    internal static var _localSecretId: String = ""
    internal static var _localSecretKey: String = ""
    
    /// 腾讯云 SecretId
    /// 优先使用本地配置，其次使用环境变量
    static var secretId: String {
        #if DEBUG
        let id = _localSecretId.isEmpty ? (ProcessInfo.processInfo.environment["COS_SECRET_ID"] ?? "") : _localSecretId
        if id.isEmpty {
            print("⚠️ COSConfig.secretId 为空! _localSecretId=\(_localSecretId.isEmpty ? "空" : "有值")")
        }
        return id
        #else
        return ProcessInfo.processInfo.environment["COS_SECRET_ID"] ?? ""
        #endif
    }
    
    /// 腾讯云 SecretKey
    /// 优先使用本地配置，其次使用环境变量
    static var secretKey: String {
        #if DEBUG
        let key = _localSecretKey.isEmpty ? (ProcessInfo.processInfo.environment["COS_SECRET_KEY"] ?? "") : _localSecretKey
        if key.isEmpty {
            print("⚠️ COSConfig.secretKey 为空! _localSecretKey=\(_localSecretKey.isEmpty ? "空" : "有值")")
        }
        return key
        #else
        return ProcessInfo.processInfo.environment["COS_SECRET_KEY"] ?? ""
        #endif
    }
    
    /// COS 存储桶名称
    static let bucket = "perapera-1255314189"
    
    /// COS 地域 (例如: ap-guangzhou, ap-shanghai, ap-beijing)
    static let region = "ap-tokyo"
    
    /// 上传文件的目录前缀 (例如: "audio/", "uploads/")
    static let uploadPrefix = "audios/"
    
    /// COS 访问域名 (可选，用于生成访问URL)
    static var cosHost: String {
        return "https://\(bucket).cos.\(region).myqcloud.com"
    }
    
    // MARK: - Helper Methods
    
    /// 生成文件在COS中的完整路径
    /// - Parameter fileName: 文件名
    /// - Returns: 完整的对象键 (object key)
    static func generateObjectKey(fileName: String) -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let uuid = UUID().uuidString.prefix(8)
        let fileExtension = (fileName as NSString).pathExtension
        let baseName = (fileName as NSString).deletingPathExtension
        
        // 生成格式: audio/baseName_timestamp_uuid.ext
        return "\(uploadPrefix)\(baseName)_\(timestamp)_\(uuid).\(fileExtension)"
    }
    
    /// 生成文件的访问URL
    /// - Parameter objectKey: COS对象键
    /// - Returns: 完整的访问URL
    static func generateAccessURL(objectKey: String) -> String {
        return "\(cosHost)/\(objectKey)"
    }
}

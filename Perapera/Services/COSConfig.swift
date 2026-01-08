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
    
    /// 腾讯云 SecretId
    static let secretId = "YOUR_SECRET_ID"
    
    /// 腾讯云 SecretKey
    static let secretKey = "YOUR_SECRET_KEY"
    
    /// COS 存储桶名称
    static let bucket = "YOUR_BUCKET_NAME"
    
    /// COS 地域 (例如: ap-guangzhou, ap-shanghai, ap-beijing)
    static let region = "ap-guangzhou"
    
    /// 上传文件的目录前缀 (例如: "audio/", "uploads/")
    static let uploadPrefix = "audio/"
    
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

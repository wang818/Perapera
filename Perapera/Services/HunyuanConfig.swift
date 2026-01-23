//
//  HunyuanConfig.swift
//  Perapera
//
//  Created by Perapera on 2025.
//

import Foundation

struct HunyuanConfig {
    // MARK: - Hunyuan Configuration
    
    // 本地开发配置（在 HunyuanConfig.local.swift 中设置）
    internal static var _localSecretId: String = ""
    internal static var _localSecretKey: String = ""
    
    /// 腾讯云 SecretId
    /// 优先使用本地配置，其次使用环境变量
    static var secretId: String {
        // 确保本地配置已加载
        _ = _ensureLocalConfigLoaded
        
        #if DEBUG
        let id = _localSecretId.isEmpty ? (ProcessInfo.processInfo.environment["HUNYUAN_SECRET_ID"] ?? "") : _localSecretId
        return id
        #else
        return ProcessInfo.processInfo.environment["HUNYUAN_SECRET_ID"] ?? ""
        #endif
    }
    
    /// 腾讯云 SecretKey
    /// 优先使用本地配置，其次使用环境变量
    static var secretKey: String {
        // 确保本地配置已加载
        _ = _ensureLocalConfigLoaded
        
        #if DEBUG
        let key = _localSecretKey.isEmpty ? (ProcessInfo.processInfo.environment["HUNYUAN_SECRET_KEY"] ?? "") : _localSecretKey
        return key
        #else
        return ProcessInfo.processInfo.environment["HUNYUAN_SECRET_KEY"] ?? ""
        #endif
    }
    
    // 确保本地配置已加载的标志
    private static let _ensureLocalConfigLoaded: Void = {
        setupLocalCredentials()
        return ()
    }()
    
    /// 腾讯云混元 API 域名
    static let apiHost = "hunyuan.tencentcloudapi.com"
    
    /// API 版本
    static let apiVersion = "2023-09-01"
    
    /// 服务名称
    static let service = "hunyuan"
    
    /// 默认使用的模型
    static let defaultModel = "hunyuan-turbo"
    
    /// 最大 token 数
    static let maxTokens = 4096
    
    /// 温度参数（控制输出多样性）
    static let temperature: Double = 0.7
    
    // MARK: - Helper Methods
    
    /// 生成请求 URL
    static func generateRequestURL() -> URL? {
        return URL(string: "https://\(apiHost)/")
    }
}

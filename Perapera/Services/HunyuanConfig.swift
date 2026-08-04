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
    internal static var _localApiKey: String = ""

    /// 腾讯云 SecretId（旧版 TC3 签名鉴权，已弃用）
    static var secretId: String {
        _ = _ensureLocalConfigLoaded
        #if DEBUG
        return _localSecretId.isEmpty ? (ProcessInfo.processInfo.environment["HUNYUAN_SECRET_ID"] ?? "") : _localSecretId
        #else
        return ProcessInfo.processInfo.environment["HUNYUAN_SECRET_ID"] ?? ""
        #endif
    }

    /// 腾讯云 SecretKey（旧版 TC3 签名鉴权，已弃用）
    static var secretKey: String {
        _ = _ensureLocalConfigLoaded
        #if DEBUG
        return _localSecretKey.isEmpty ? (ProcessInfo.processInfo.environment["HUNYUAN_SECRET_KEY"] ?? "") : _localSecretKey
        #else
        return ProcessInfo.processInfo.environment["HUNYUAN_SECRET_KEY"] ?? ""
        #endif
    }

    /// TokenHub API Key（新版 Bearer Token 鉴权）
    static var apiKey: String {
        _ = _ensureLocalConfigLoaded
        #if DEBUG
        return _localApiKey.isEmpty ? (ProcessInfo.processInfo.environment["TOKENHUB_API_KEY"] ?? "") : _localApiKey
        #else
        return ProcessInfo.processInfo.environment["TOKENHUB_API_KEY"] ?? ""
        #endif
    }

    private static let _ensureLocalConfigLoaded: Void = {
        setupLocalCredentials()
        return ()
    }()

    /// TokenHub API 基础 URL（OpenAI 兼容）
    static let apiBaseURL = "https://tokenhub-intl.tencentmaas.com/v1"

    /// 默认使用的模型
    static let defaultModel = "deepseek-v4-flash-202605"

    /// 旧版配置（保留兼容）
    static let apiHost = "hunyuan.tencentcloudapi.com"
    static let apiVersion = "2023-09-01"
    static let service = "hunyuan"
    static let maxTokens = 4096
    static let temperature: Double = 0.7

    // MARK: - Helper Methods

    /// 生成请求 URL（新版 TokenHub OpenAI 兼容 API）
    static func generateRequestURL() -> URL? {
        return URL(string: "\(apiBaseURL)/chat/completions")
    }
}

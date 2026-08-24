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
    /// 国内站 TokenHub API Key（可选）：tokenhub-intl 不可达时自动切换国内端点使用。
    /// 国内站与国际站的 key 不通用（国际站 key 在国内端点返回 401002），需在
    /// https://console.cloud.tencent.com/tokenhub/api-key 单独创建。留空则国内端点回退使用 apiKey。
    internal static var _localApiKeyDomestic: String = ""

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

    /// 国内站 TokenHub API Key（可选）：留空回退 apiKey
    static var apiKeyDomestic: String {
        _ = _ensureLocalConfigLoaded
        #if DEBUG
        return _localApiKeyDomestic.isEmpty ? (ProcessInfo.processInfo.environment["TOKENHUB_API_KEY_DOMESTIC"] ?? "") : _localApiKeyDomestic
        #else
        return ProcessInfo.processInfo.environment["TOKENHUB_API_KEY_DOMESTIC"] ?? ""
        #endif
    }

    /// 按端点取 API Key：国内端点优先用国内站 key（非空时），其余端点用默认 apiKey。
    /// 双端点容错切换端点时必须用与端点配套的 key，否则会 401002。
    static func apiKey(for baseURL: String) -> String {
        if baseURL == tokenHubEndpoints.last, !apiKeyDomestic.isEmpty {
            return apiKeyDomestic
        }
        return apiKey
    }

    private static let _ensureLocalConfigLoaded: Void = {
        setupLocalCredentials()
        return ()
    }()

    /// TokenHub API 基础 URL（OpenAI 兼容）——默认国际端点
    static let apiBaseURL = "https://tokenhub-intl.tencentmaas.com/v1"

    /// TokenHub 端点列表（按优先级）：先国际端点，连接失败/鉴权失败自动切换国内端点。
    /// 设备侧连不上国际域名（socket 超时 -1001/-2102）时，自动回退到国内端点。
    static let tokenHubEndpoints: [String] = [
        "https://tokenhub-intl.tencentmaas.com/v1",
        "https://tokenhub.tencentmaas.com/v1"
    ]

    /// 默认使用的模型
    static let defaultModel = "deepseek-v4-flash-202605"

    /// 旧版配置（保留兼容）
    static let apiHost = "hunyuan.tencentcloudapi.com"
    static let apiVersion = "2023-09-01"
    static let service = "hunyuan"
    static let maxTokens = 4096
    static let temperature: Double = 0.7

    // MARK: - Helper Methods

    /// 生成请求 URL（新版 TokenHub OpenAI 兼容 API，默认国际端点）
    static func generateRequestURL() -> URL? {
        return generateRequestURL(baseURL: apiBaseURL)
    }

    /// 生成指定端点的请求 URL（用于双端点容错切换）
    static func generateRequestURL(baseURL: String) -> URL? {
        return URL(string: "\(baseURL)/chat/completions")
    }
}

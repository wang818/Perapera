//
//  AliyunConfig.swift
//  Perapera
//
//  阿里云 DashScope 配置
//

import Foundation
import UIKit

struct AliyunConfig {
    // MARK: - Aliyun Configuration

    // 本地开发配置（在 AliyunConfig.local.swift 中设置）
    internal static var _localApiKey: String = ""
    internal static var _localAccessKeyId: String = ""
    internal static var _localAccessKeySecret: String = ""

    /// 阿里云 DashScope API Key
    /// 优先使用本地配置，其次使用环境变量
    static var apiKey: String {
        #if DEBUG
        let key = _localApiKey.isEmpty ? (ProcessInfo.processInfo.environment["ALIYUN_DASHSCOPE_API_KEY"] ?? "") : _localApiKey
        if key.isEmpty {
            print("⚠️ AliyunConfig.apiKey 为空! _localApiKey=\(_localApiKey.isEmpty ? "空" : "有值")")
        }
        return key
        #else
        return ProcessInfo.processInfo.environment["ALIYUN_DASHSCOPE_API_KEY"] ?? ""
        #endif
    }

    /// DashScope WebSocket 端点
    static let webSocketURL = "wss://dashscope.aliyuncs.com/api-ws/v1/inference"

    /// DashScope REST API 域名
    /// 公开版: dashscope.aliyuncs.com
    /// MAAS 专属实例: ws-1rbna8yglqw4yjyt.ap-southeast-1.maas.aliyuncs.com
    static let apiHost = "ws-1rbna8yglqw4yjyt.ap-southeast-1.maas.aliyuncs.com"

    /// DashScope API 基础 URL
    static var apiBaseURL: String {
        return "https://\(apiHost)/api/v1"
    }

    /// 服务模式：1 = 文件转录
    static let serviceMode = "1"

    /// 使用的模型
    static let model = "fun-asr"

    /// 是否启用说话人分离
    static let diarizationEnabled = false

    /// 语音噪声阈值
    static let speechNoiseThreshold: Double = 0.0

    // MARK: - 机器翻译（阿里云 MT）

    /// 阿里云 AccessKey ID（机器翻译 RAM 用户）
    static var accessKeyId: String {
        _ = _ensureLocalConfigLoaded
        #if DEBUG
        return _localAccessKeyId.isEmpty ? (ProcessInfo.processInfo.environment["ALIYUN_ACCESS_KEY_ID"] ?? "") : _localAccessKeyId
        #else
        return ProcessInfo.processInfo.environment["ALIYUN_ACCESS_KEY_ID"] ?? ""
        #endif
    }

    /// 阿里云 AccessKey Secret（机器翻译 RAM 用户）
    static var accessKeySecret: String {
        _ = _ensureLocalConfigLoaded
        #if DEBUG
        return _localAccessKeySecret.isEmpty ? (ProcessInfo.processInfo.environment["ALIYUN_ACCESS_KEY_SECRET"] ?? "") : _localAccessKeySecret
        #else
        return ProcessInfo.processInfo.environment["ALIYUN_ACCESS_KEY_SECRET"] ?? ""
        #endif
    }

    private static let _ensureLocalConfigLoaded: Void = {
        setupLocalCredentials()
        return ()
    }()

    /// 机器翻译 API 端点（新加坡）
    static let mtEndpoint = "mt.ap-southeast-1.aliyuncs.com"

    // MARK: - Helper Methods

    /// 生成设备 ID（用于 SDK 日志追踪）
    static func generateDeviceId() -> String {
        return UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
    }
}

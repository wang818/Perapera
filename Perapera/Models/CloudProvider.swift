//
//  CloudProvider.swift
//  Perapera
//
//  云服务提供商配置
//

import Foundation

/// 云服务提供商
enum CloudProvider: String, CaseIterable, Identifiable {
    case tencent  // 腾讯云
    case aliyun   // 阿里云

    var id: String { rawValue }

    /// 本地化显示名称
    var displayName: String {
        switch self {
        case .tencent:
            return "cloud_provider_tencent".localized()
        case .aliyun:
            return "cloud_provider_aliyun".localized()
        }
    }

    /// 默认值
    static let `default`: CloudProvider = .aliyun
}

/// 云服务提供商管理器
class CloudProviderManager: ObservableObject {
    static let shared = CloudProviderManager()

    private static let userDefaultsKey = "CloudProvider"

    /// 当前云服务提供商
    @Published var currentProvider: CloudProvider {
        didSet {
            UserDefaults.standard.set(currentProvider.rawValue, forKey: Self.userDefaultsKey)
        }
    }

    private init() {
        if let rawValue = UserDefaults.standard.string(forKey: Self.userDefaultsKey),
           let provider = CloudProvider(rawValue: rawValue) {
            currentProvider = provider
        } else {
            currentProvider = .default
        }
    }
}

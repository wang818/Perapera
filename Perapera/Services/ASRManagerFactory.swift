//
//  ASRManagerFactory.swift
//  Perapera
//
//  ASR 服务工厂 — 根据 CloudProvider 设置返回对应的 ASR 实现
//

import Foundation

/// ASR 服务工厂
class ASRManagerFactory {
    static let shared = ASRManagerFactory()

    private let providerManager = CloudProviderManager.shared

    private init() {}

    /// 获取当前云提供商对应的 ASR 服务
    func getService() -> ASRServiceProtocol {
        switch providerManager.currentProvider {
        case .tencent:
            return ASRManager.shared
        case .aliyun:
            return AliyunASRManager.shared
        }
    }
}

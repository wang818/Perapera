//
//  TencentMTConfig.swift
//  Perapera
//
//  Created by Perapera on 2025.
//

import Foundation

struct TencentMTConfig {
    // MARK: - TMT Configuration

    /// 腾讯云机器翻译 API 域名
    static let apiHost = "tmt.tencentcloudapi.com"

    /// API 版本
    static let apiVersion = "2018-03-21"

    /// 服务名称
    static let service = "tmt"

    // MARK: - Language Code Mapping

    /// 源语言代码（根据 ASR 引擎模型推导）
    /// ja: 日语, zh: 中文, en: 英语, ko: 韩语, auto: 自动检测
    static var sourceLanguage: String {
        switch ASRConfig.engineModelType {
        case "16k_ja": return "ja"
        case "16k_en": return "en"
        case "16k_zh", "16k_zh_video": return "zh"
        case "16k_ca": return "zh"  // 粤语 → 映射为中文
        default: return "auto"
        }
    }

    /// 目标语言代码（根据 ASR 翻译目标推导）
    static var targetLanguage: String {
        switch ASRConfig.translationTargetLanguage {
        case "zh-CN": return "zh"
        case "ja-JP": return "ja"
        case "en-US": return "en"
        case "ko-KR": return "ko"
        default: return "zh"
        }
    }

    // MARK: - Helper Methods

    static func generateRequestURL() -> URL? {
        return URL(string: "https://\(apiHost)/")
    }
}

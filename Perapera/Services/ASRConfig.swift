//
//  ASRConfig.swift
//  Perapera
//
//  Created by Perapera on 2024.
//. https://cloud.tencent.com/document/api/1093/37823.参考这个网址

import Foundation

struct ASRConfig {
    // MARK: - ASR Configuration
    
    /// 腾讯云语音识别 API 域名
    static let apiHost = "asr.tencentcloudapi.com"
    
    /// API 版本
    static let apiVersion = "2019-06-14"
    
    /// 服务名称
    static let service = "asr"
    
    /// 引擎模型类型
    /// 16k_zh: 16k 中文普通话通用
    /// 16k_zh_video: 16k 音视频领域
    /// 16k_en: 16k 英语
    /// 16k_ca: 16k 粤语
    static let engineModelType = "16k_ja"
    
    /// 识别结果文本编码方式
    /// 0: UTF-8
    /// 1: GB2312
    /// 2: GBK
    /// 3: BIG5
    static let resTextFormat: Int = 3
    
    /// 音频来源
    /// 0: 音频 URL
    /// 1: 音频数据（base64）
    static let sourceType: Int = 0
    
    /// 声道数
    /// 1: 单声道
    /// 2: 双声道（仅支持 8k_zh 引擎模型）
    static let channelNum: Int = 1
    
    /// 是否过滤脏词
    static let filterDirty: Int = 0
    
    /// 是否过滤语气词
    static let filterModal: Int = 0
    
    /// 是否过滤标点符号
    static let filterPunc: Int = 0
    
    /// 是否进行阿拉伯数字智能转换
    static let convertNumMode: Int = 1
    
    // MARK: - Translation Configuration
    
    /// 翻译目标语言代码（来自「第二字幕」设置，缺省简体中文）
    /// zh-CN: 简体中文
    /// ja-JP: 日语
    /// en-US: 英语
    /// ko-KR: 韩语
    static var translationTargetLanguage: String {
        switch LanguageManager.getSecondSubtitleLanguageCode() {
        case "zh-Hans", "zh-Hant": return "zh-CN"
        case "ja": return "ja-JP"
        case "en": return "en-US"
        case "ko": return "ko-KR"
        default: return "zh-CN"
        }
    }
    
    /// 翻译目标语言显示名称
    static var translationLanguageName: String {
        switch translationTargetLanguage {
        case "zh-CN": return "中文"
        case "ja-JP": return "日文"
        case "en-US": return "英文"
        case "ko-KR": return "韩文"
        default: return "中文"
        }
    }
    
    /// 翻译响应 JSON Key
    static var translationResponseKey: String {
        switch translationTargetLanguage {
        case "zh-CN": return "ZhCNWords"
        case "ja-JP": return "JaJPWords"
        case "en-US": return "EnUSWords"
        case "ko-KR": return "KoKRWords"
        default: return "ZhCNWords"
        }
    }
    
    // MARK: - Helper Methods
    
    /// 生成请求 URL
    static func generateRequestURL() -> URL? {
        return URL(string: "https://\(apiHost)/")
    }

    /// 视频源语言代码（语音识别语言），由引擎模型类型推导。
    /// 注意：识别已改用阿里云 fun-asr（多语言自动识别，不返回语言检测结果），
    /// 真实语言由翻译阶段经阿里云 MT 的 auto 检测（DetectedLanguage）确定。
    /// 因此识别保存阶段统一写 "auto"（语言待检测），避免用写死的引擎模型误标语言。
    static var sourceLanguageCode: String {
        return "auto"
    }

    /// 向 ASR 原始响应的 `Response.Data` 层注入「视频源语言」字段（`SourceLanguage`），
    /// 用于在识别文件里持久化「该视频是什么语言」。注入失败（无法解析）时返回原数据不变。
    /// 若 Data 层已有非空 SourceLanguage（如翻译阶段检测出的真实语言），则保留不覆盖；
    /// 否则写入 "auto"（语言待后续翻译阶段检测）。
    /// - Parameter jsonData: ASR 原始响应 JSON Data（结构 `{"Response":{"Data":{...}}}`）
    /// - Returns: 注入 SourceLanguage 后的 JSON Data
    static func injectSourceLanguage(into jsonData: Data) -> Data {
        guard var jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              var response = jsonObject["Response"] as? [String: Any],
              var data = response["Data"] as? [String: Any] else {
            return jsonData
        }
        // 已存在非空 SourceLanguage（真实检测值）→ 保留，不覆盖
        if let existing = data["SourceLanguage"] as? String, !existing.isEmpty {
            return jsonData
        }
        data["SourceLanguage"] = sourceLanguageCode
        response["Data"] = data
        jsonObject["Response"] = response
        guard let out = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted) else {
            return jsonData
        }
        return out
    }
}

//
//  ASRConfig.swift
//  Perapera
//
//  Created by Perapera on 2024.
//

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
    static let engineModelType = "16k_zh"
    
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
    
    // MARK: - Helper Methods
    
    /// 生成请求 URL
    static func generateRequestURL() -> URL? {
        return URL(string: "https://\(apiHost)/")
    }
}

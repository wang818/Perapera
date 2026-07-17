//
//  ASRServiceProtocol.swift
//  Perapera
//
//  语音识别服务协议 — 腾讯云和阿里云 ASR 实现此协议
//

import Foundation

// MARK: - Shared Result Types

/// 识别结果中的词级别详情
struct ASRWordItem: Codable {
    let Word: String
    let OffsetStartMs: Int
    let OffsetEndMs: Int
}

/// 识别结果中的句子级别详情
struct ASRSentenceItem: Codable {
    let FinalSentence: String
    let SliceSentence: String
    let WrittenText: String?
    let StartMs: Int
    let EndMs: Int
    let SpeechSpeed: Double
    let WordsNum: Int
    let Words: [ASRWordItem]?
    let SpeakerId: Int?
    let EmotionalEnergy: Double?
    let SilenceTime: Int?
    let EmotionType: [String]?
}

/// 识别任务结果（通用结构，各服务实现映射到此）
struct ASRTaskResult {
    let taskId: Int
    let status: Int         // 0: 等待, 1: 执行中, 2: 成功, 3: 失败
    let statusStr: String
    let result: String?     // 识别结果文本
    let resultDetail: [ASRSentenceItem]?
    let audioDuration: Double?
    let errorMsg: String?
    let rawJSON: Data       // 原始响应数据（供翻译步骤使用）
}

// MARK: - Protocol

/// 语音识别服务协议
protocol ASRServiceProtocol {
    /// 创建录音文件识别任务
    /// - Parameters:
    ///   - audioURL: 音频文件的公开访问 URL
    ///   - completion: 完成回调，返回 TaskId 或错误
    func createRecognitionTask(
        audioURL: String,
        completion: @escaping (Result<Int, Error>) -> Void
    )

    /// 查询识别结果
    /// - Parameters:
    ///   - taskId: 任务 ID
    ///   - completion: 完成回调，返回统一的识别结果或错误
    func queryRecognitionResult(
        taskId: Int,
        completion: @escaping (Result<ASRTaskResult, Error>) -> Void
    )
}

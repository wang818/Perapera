//
//  AliyunASRManager.swift
//  Perapera
//
//  阿里云语音识别 — 直接调用 DashScope REST API
//  实现 ASRServiceProtocol 协议
//

import Foundation

/// 阿里云 fun-asr 语音识别服务（直连 DashScope HTTP API）
class AliyunASRManager: NSObject, ASRServiceProtocol {

    static let shared = AliyunASRManager()

    private override init() {
        super.init()
    }

    // MARK: - Internal State

    /// DashScope 任务 ID → 内部任务信息 映射
    private var tasks: [String: AliyunASRTask] = [:]

    /// 内部任务 ID 计数器
    private var taskIdCounter: Int = 0

    /// 识别结果缓存 (internalTaskId → ASRTaskResult)
    private var resultCache: [Int: ASRTaskResult] = [:]

    /// 内部 ID → DashScope 任务 ID 映射
    private var idMap: [Int: String] = [:]

    private let lock = NSLock()
    private let session = URLSession.shared

    /// 轮询间隔（秒）
    private let pollInterval: TimeInterval = 3.0

    // MARK: - ASRServiceProtocol

    func createRecognitionTask(
        audioURL: String,
        completion: @escaping (Result<Int, Error>) -> Void
    ) {
        let apiKey = AliyunConfig.apiKey
        guard !apiKey.isEmpty, apiKey != "your-dashscope-api-key-here" else {
            completion(.failure(NSError(
                domain: "AliyunASRManager",
                code: -10,
                userInfo: [NSLocalizedDescriptionKey: "阿里云 DashScope API Key 未配置"]
            )))
            return
        }

        // 生成内部任务 ID
        lock.lock()
        taskIdCounter += 1
        let internalTaskId = taskIdCounter
        lock.unlock()

        // 构建请求
        let requestBody: [String: Any] = [
            "model": "fun-asr",
            "input": [
                "file_urls": [audioURL]
            ],
            "parameters": [
                "diarization_enabled": false
            ]
        ]

        guard let url = URL(string: "\(AliyunConfig.apiBaseURL)/services/audio/asr/transcription") else {
            completion(.failure(NSError(domain: "AliyunASRManager", code: -1)))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("enable", forHTTPHeaderField: "X-DashScope-Async")
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 30

        print("🚀 AliyunASR: 创建转录任务, internalTaskId=\(internalTaskId)")
        print("   audioURL: \(audioURL)")

        session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                print("❌ AliyunASR: 创建任务网络错误: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let bodyStr = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            print("📥 AliyunASR: 创建任务响应 HTTP \(statusCode)")
            print("   body: \(bodyStr.prefix(500))")

            guard let data = data, statusCode == 200 else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(
                        domain: "AliyunASRManager", code: statusCode,
                        userInfo: [NSLocalizedDescriptionKey: "创建任务失败 HTTP \(statusCode): \(bodyStr.prefix(200))"]
                    )))
                }
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let output = json["output"] as? [String: Any],
                   let dsTaskId = output["task_id"] as? String {

                    print("✅ AliyunASR: 任务已创建, dashscopeTaskId=\(dsTaskId), internalTaskId=\(internalTaskId)")

                    let task = AliyunASRTask(internalTaskId: internalTaskId, dashscopeTaskId: dsTaskId, audioURL: audioURL)

                    self.lock.lock()
                    self.tasks[dsTaskId] = task
                    self.idMap[internalTaskId] = dsTaskId
                    self.lock.unlock()

                    DispatchQueue.main.async {
                        completion(.success(internalTaskId))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(NSError(
                            domain: "AliyunASRManager", code: -3,
                            userInfo: [NSLocalizedDescriptionKey: "响应中无 task_id: \(bodyStr.prefix(200))"]
                        )))
                    }
                }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }.resume()
    }

    func queryRecognitionResult(
        taskId: Int,
        completion: @escaping (Result<ASRTaskResult, Error>) -> Void
    ) {
        // 检查缓存
        lock.lock()
        if let cached = resultCache[taskId] {
            lock.unlock()
            completion(.success(cached))
            return
        }
        let dsTaskId = idMap[taskId]
        let taskExists = tasks[dsTaskId ?? ""] != nil
        lock.unlock()

        guard let dsTaskId = dsTaskId, taskExists else {
            completion(.failure(NSError(
                domain: "AliyunASRManager", code: -4,
                userInfo: [NSLocalizedDescriptionKey: "任务不存在"]
            )))
            return
        }

        // 查询 DashScope 任务状态
        guard let url = URL(string: "\(AliyunConfig.apiBaseURL)/tasks/\(dsTaskId)") else {
            completion(.failure(NSError(domain: "AliyunASRManager", code: -1)))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(AliyunConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        let apiKey = AliyunConfig.apiKey
        print("🔍 AliyunASR: 查询任务状态, dsTaskId=\(dsTaskId)")

        session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                print("❌ AliyunASR: 查询任务网络错误: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.success(ASRTaskResult(
                        taskId: taskId, status: 0, statusStr: "waiting",
                        result: nil, resultDetail: nil, audioDuration: nil,
                        errorMsg: nil, rawJSON: Data()
                    )))
                }
                return
            }

            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.success(ASRTaskResult(
                        taskId: taskId, status: 0, statusStr: "waiting",
                        result: nil, resultDetail: nil, audioDuration: nil,
                        errorMsg: nil, rawJSON: Data()
                    )))
                }
                return
            }

            let bodyStr = String(data: data, encoding: .utf8) ?? ""
            print("📥 AliyunASR: 查询响应 HTTP \(statusCode)")
            print("   body: \(bodyStr.prefix(300))")

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let output = json["output"] as? [String: Any] {

                    let taskStatus = output["task_status"] as? String ?? ""

                    switch taskStatus {
                    case "SUCCEEDED":
                        print("✅ AliyunASR: 识别成功! taskId=\(taskId)")
                        let result = self.parseSucceededResult(output: output, data: data, taskId: taskId)

                        self.lock.lock()
                        self.resultCache[taskId] = result
                        self.lock.unlock()

                        DispatchQueue.main.async { completion(.success(result)) }

                    case "FAILED":
                        let errMsg = output["message"] as? String ?? "未知错误"
                        print("❌ AliyunASR: 识别失败: \(errMsg)")

                        let failedResult = ASRTaskResult(
                            taskId: taskId, status: 3, statusStr: "failed",
                            result: nil, resultDetail: nil, audioDuration: nil,
                            errorMsg: errMsg, rawJSON: data
                        )
                        self.lock.lock()
                        self.resultCache[taskId] = failedResult
                        self.lock.unlock()

                        DispatchQueue.main.async { completion(.success(failedResult)) }

                    case "PENDING", "RUNNING":
                        let progress = output["task_progress"] as? Double ?? 0
                        print("⏳ AliyunASR: 进行中, progress=\(Int(progress * 100))%")
                        DispatchQueue.main.async {
                            completion(.success(ASRTaskResult(
                                taskId: taskId, status: 1, statusStr: "processing",
                                result: nil, resultDetail: nil, audioDuration: nil,
                                errorMsg: nil, rawJSON: Data()
                            )))
                        }

                    default:
                        print("⚠️ AliyunASR: 未知状态: \(taskStatus)")
                        DispatchQueue.main.async {
                            completion(.success(ASRTaskResult(
                                taskId: taskId, status: 0, statusStr: "waiting",
                                result: nil, resultDetail: nil, audioDuration: nil,
                                errorMsg: nil, rawJSON: Data()
                            )))
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.success(ASRTaskResult(
                            taskId: taskId, status: 0, statusStr: "waiting",
                            result: nil, resultDetail: nil, audioDuration: nil,
                            errorMsg: nil, rawJSON: Data()
                        )))
                    }
                }
            } catch {
                print("⚠️ AliyunASR: JSON 解析失败: \(error)")
                DispatchQueue.main.async {
                    completion(.success(ASRTaskResult(
                        taskId: taskId, status: 0, statusStr: "waiting",
                        result: nil, resultDetail: nil, audioDuration: nil,
                        errorMsg: nil, rawJSON: Data()
                    )))
                }
            }
        }.resume()
    }

    // MARK: - Result Parsing

    private func parseSucceededResult(output: [String: Any], data: Data, taskId: Int) -> ASRTaskResult {
        var fullText = ""
        var sentences: [ASRSentenceItem] = []

        print("🔍 AliyunASR: parseSucceededResult 开始")
        print("   output keys: \(output.keys.sorted())")

        // 打印完整的 output JSON（用于调试）
        if let outputData = try? JSONSerialization.data(withJSONObject: output, options: .prettyPrinted),
           let outputStr = String(data: outputData, encoding: .utf8) {
            print("📄 AliyunASR: 完整 output JSON:\n\(outputStr)")
        }

        // results 数组中每项包含 transcription_url
        if let results = output["results"] as? [[String: Any]] {
            print("🔍 AliyunASR: results 数组有 \(results.count) 项")
            for (idx, resultItem) in results.enumerated() {
                print("🔍 AliyunASR: resultItem[\(idx)] keys: \(resultItem.keys.sorted())")
                if let transcriptionURLStr = resultItem["transcription_url"] as? String {
                    print("🔍 AliyunASR: transcription_url[\(idx)]: \(transcriptionURLStr)")
                }
                if let transcriptionURLStr = resultItem["transcription_url"] as? String,
                   let transcriptionURL = URL(string: transcriptionURLStr) {
                    // 同步下载转录结果
                    let semaphore = DispatchSemaphore(value: 0)
                    var transcriptionData: Data?
                    var downloadError: Error?

                    print("📥 AliyunASR: 开始下载转录结果: \(transcriptionURLStr)")

                    // 使用独立 URLSession 避免与外部 query dataTask 在同队列死锁
                    let downloadSession = URLSession(configuration: .ephemeral)
                    downloadSession.dataTask(with: transcriptionURL) { tData, response, error in
                        transcriptionData = tData
                        downloadError = error
                        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                        print("📥 AliyunASR: 下载完成, HTTP \(statusCode), dataSize=\(tData?.count ?? 0), error=\(error?.localizedDescription ?? "nil")")
                        semaphore.signal()
                    }.resume()
                    let waitResult = semaphore.wait(timeout: .now() + 30)
                    if waitResult == .timedOut {
                        print("⚠️ AliyunASR: 下载转录结果超时(30s)")
                    }

                    if let error = downloadError {
                        print("❌ AliyunASR: 下载转录结果失败: \(error.localizedDescription)")
                        continue
                    }

                    guard let tData = transcriptionData else {
                        print("❌ AliyunASR: 下载转录结果为空")
                        continue
                    }

                    print("📄 AliyunASR: 转录原始数据 (\(tData.count) bytes): \(String(data: tData, encoding: .utf8)?.prefix(2000) ?? "非UTF8")")

                    guard let tJson = try? JSONSerialization.jsonObject(with: tData) as? [String: Any] else {
                        print("❌ AliyunASR: 转录 JSON 解析失败")
                        continue
                    }

                    print("🔍 AliyunASR: 转录 JSON keys: \(tJson.keys.sorted())")

                    // 解析转录 JSON - fun-asr 格式
                    if let transcripts = tJson["transcripts"] as? [[String: Any]] {
                        print("🔍 AliyunASR: transcripts 数组有 \(transcripts.count) 项")
                        for (tIdx, transcript) in transcripts.enumerated() {
                            print("🔍 AliyunASR: transcript[\(tIdx)] keys: \(transcript.keys.sorted())")
                            let channelId = transcript["channel_id"] as? Int ?? 0
                            let text = transcript["text"] as? String ?? ""
                            print("   channel_id=\(channelId), text长度=\(text.count)")

                            if !text.isEmpty {
                                fullText += (fullText.isEmpty ? "" : "\n") + text
                            }

                            // 句子级结果
                            if let sents = transcript["sentences"] as? [[String: Any]] {
                                print("🔍 AliyunASR: sentences 数组有 \(sents.count) 项")
                                for (sIdx, sent) in sents.enumerated() {
                                    let sText = sent["text"] as? String ?? ""
                                    let beginMs = sent["begin_time"] as? Int ?? 0
                                    let endMs = sent["end_time"] as? Int ?? 0
                                    var words: [ASRWordItem]?

                                    if let wList = sent["words"] as? [[String: Any]] {
                                        words = wList.map { w in
                                            ASRWordItem(
                                                Word: w["text"] as? String ?? "",
                                                OffsetStartMs: w["begin_time"] as? Int ?? 0,
                                                OffsetEndMs: w["end_time"] as? Int ?? 0
                                            )
                                        }
                                    }

                                    if sIdx < 3 {
                                        print("   sentence[\(sIdx)]: text=\"\(sText.prefix(80))\", begin=\(beginMs), end=\(endMs), words=\(words?.count ?? 0)")
                                    }

                                    sentences.append(ASRSentenceItem(
                                        FinalSentence: sText,
                                        SliceSentence: sText,
                                        WrittenText: nil,
                                        StartMs: beginMs,
                                        EndMs: endMs,
                                        SpeechSpeed: 0,
                                        WordsNum: words?.count ?? 0,
                                        Words: words,
                                        SpeakerId: channelId,
                                        EmotionalEnergy: nil,
                                        SilenceTime: nil,
                                        EmotionType: nil
                                    ))
                                }
                            } else {
                                print("⚠️ AliyunASR: transcript[\(tIdx)] 无 sentences 字段")
                            }
                        }
                    } else {
                        print("⚠️ AliyunASR: 转录 JSON 无 transcripts 字段")
                    }
                } else {
                    print("⚠️ AliyunASR: resultItem[\(idx)] 无 transcription_url")
                }
            }
        } else {
            print("⚠️ AliyunASR: output 中无 results 数组")
        }

        // 如果没下载到转录详情，用 output.text 兜底
        if fullText.isEmpty {
            fullText = output["text"] as? String ?? ""
            print("🔍 AliyunASR: 兜底 text = \"\(fullText.prefix(200))\"")
        }

        print("✅ AliyunASR: 解析完成, fullText长度=\(fullText.count), sentences=\(sentences.count)")

        // 包装为腾讯云兼容格式
        let wrappedJSON = wrapAsTencentCompatibleJSON(
            fullText: fullText,
            sentences: sentences,
            taskId: taskId
        )

        return ASRTaskResult(
            taskId: taskId,
            status: 2,
            statusStr: "success",
            result: fullText,
            resultDetail: sentences.isEmpty ? nil : sentences,
            audioDuration: nil,
            errorMsg: nil,
            rawJSON: wrappedJSON
        )
    }

    /// 包装为腾讯云 ASR 兼容 JSON
    /// 整句 furigana 优先用 /reading 服务的词级读音拼接（katakana→hiragana），失败兜底本地转换；
    /// 词级 Furigana/Reading 在 ASR 阶段就用 /reading 对齐写好，MT 阶段不再覆盖。
    private func wrapAsTencentCompatibleJSON(
        fullText: String,
        sentences: [ASRSentenceItem],
        taskId: Int
    ) -> Data {
        var sentenceItems: [[String: Any]] = []
        sentenceItems.reserveCapacity(sentences.count)

        // /reading 服务连续失败后快速降级为本地转换，避免多句逐句超时
        var readingAvailable = true

        for sentence in sentences {
            let sliceText = sentence.SliceSentence.isEmpty ? sentence.FinalSentence : sentence.SliceSentence

            // 1) 调用 /reading 获取整句与词级读音（同步，失败返回 nil）
            let readingResult = readingAvailable
                ? ReadingAPIClient.shared.fetchReadingSync(text: sliceText)
                : nil
            if readingResult == nil {
                readingAvailable = false
            }

            // 2) 整句 furigana：/reading 优先，失败本地兜底
            var furigana: [String: Any]
            if let reading = readingResult {
                furigana = [
                    "hiragana": reading.hiragana,
                    "katakana": reading.katakana,
                    "romaji": reading.romaji
                ]
            } else {
                furigana = [
                    "hiragana": JapaneseTextConverter.shared.toHiragana(sliceText),
                    "katakana": JapaneseTextConverter.shared.toKatakana(sliceText),
                    "romaji": JapaneseTextConverter.shared.toRomaji(sliceText)
                ]
            }

            // 3) 词级：/reading 词级读音对齐到阿里云分词（时间轴仍以阿里云为准）
            var wordsJSON: [[String: Any]] = []
            if let words = sentence.Words, !words.isEmpty {
                if let reading = readingResult, !reading.words.isEmpty {
                    let aligned = ReadingAPIClient.alignToAliyunWords(
                        readingWords: reading.words,
                        aliyunWords: words
                    )
                    for (idx, word) in words.enumerated() {
                        var w: [String: Any] = [
                            "Word": word.Word,
                            "OffsetStartMs": word.OffsetStartMs,
                            "OffsetEndMs": word.OffsetEndMs
                        ]
                        if idx < aligned.count,
                           let hiragana = aligned[idx].hiragana,
                           let romaji = aligned[idx].romaji {
                            w["Furigana"] = hiragana
                            w["Reading"] = romaji
                        }
                        wordsJSON.append(w)
                    }
                } else {
                    // /reading 无词级结果 → 词级保持时间轴信息（读音由 MT 阶段本地兜底填充）
                    wordsJSON = words.map { word in
                        [
                            "Word": word.Word,
                            "OffsetStartMs": word.OffsetStartMs,
                            "OffsetEndMs": word.OffsetEndMs
                        ]
                    }
                }
            }

            sentenceItems.append([
                "FinalSentence": sentence.FinalSentence,
                "SliceSentence": sentence.SliceSentence,
                "furigana": furigana,
                "StartMs": sentence.StartMs,
                "EndMs": sentence.EndMs,
                "WordsNum": sentence.WordsNum,
                "SpeechSpeed": sentence.SpeechSpeed,
                "Words": wordsJSON
            ] as [String: Any])
        }

        let wrapper: [String: Any] = [
            "Response": [
                "RequestId": "aliyun-funasr-\(taskId)",
                "Data": [
                    "TaskId": taskId,
                    "Status": 2,
                    "StatusStr": "success",
                    "Result": fullText,
                    "ResultDetail": sentenceItems,
                    "AudioDuration": 0
                ]
            ]
        ]

        return (try? JSONSerialization.data(withJSONObject: wrapper)) ?? Data()
    }
}

// MARK: - Internal Task Model

private class AliyunASRTask {
    let internalTaskId: Int
    let dashscopeTaskId: String
    let audioURL: String

    init(internalTaskId: Int, dashscopeTaskId: String, audioURL: String) {
        self.internalTaskId = internalTaskId
        self.dashscopeTaskId = dashscopeTaskId
        self.audioURL = audioURL
    }
}

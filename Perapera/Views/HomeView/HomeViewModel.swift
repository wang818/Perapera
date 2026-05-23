//
//  HomeViewModel.swift
//  Perapera
//
//  Created by Perapera on 2025.
//

import Foundation
import Moya
import RxSwift

class HomeViewModel: ObservableObject {
    @Published var isTranslating: Bool = false
    @Published var isFetchingYoutubeAudio: Bool = false
    @Published var youtubeAudioError: String?
    @Published var youtubeErrorLog: String?

    private let disposeBag = DisposeBag()

    /// 翻译 123.json 文件
    func translate123Json(videoId: String? = nil) {
        guard let path = Bundle.main.path(forResource: "123", ofType: "json"),
              let jsonData = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            print("❌ 无法读取 123.json 文件")
            return
        }

        print("\n" + String(repeating: "🌟", count: 40))
        print("🚀 开始翻译 123.json")
        print(String(repeating: "🌟", count: 40) + "\n")

        isTranslating = true

        HunyuanManager.shared.translateWordsToJapanese(jsonData: jsonData) { [weak self] result in
            DispatchQueue.main.async {
                self?.isTranslating = false

                switch result {
                case .success(let translatedData):
                    if let jsonString = String(data: translatedData, encoding: .utf8) {
                        print("\n" + String(repeating: "=", count: 80))
                        print("📄 完整的翻译后 JSON 数据")
                        print(String(repeating: "=", count: 80))
                        print(jsonString)
                        print(String(repeating: "=", count: 80) + "\n")

                        // 保存翻译结果为 txt 文件到 Documents 目录
                        self?.saveTranslationResultToTxt(jsonString: jsonString, videoId: videoId)
                    }

                case .failure(let error):
                    print("\n" + String(repeating: "=", count: 80))
                    print("❌ 翻译失败")
                    print(String(repeating: "=", count: 80))
                    print("错误信息: \(error.localizedDescription)")
                    print(String(repeating: "=", count: 80) + "\n")

                }
            }
        }
    }

    /// 调用 YouTube 音频 API，获取音频信息
    func fetchYoutubeAudio(url: String, completion: @escaping (YTAudioModel?) -> Void) {
        isFetchingYoutubeAudio = true
        youtubeAudioError = nil
        youtubeErrorLog = nil

        appApi.rx.request(.ytAudio(url: url))
            .asObservable()
            .mapObject(YTAudioModel.self)
            .subscribe(onNext: { [weak self] model in
                DispatchQueue.main.async {
                    self?.isFetchingYoutubeAudio = false
                    if model.status == "ok" {
                        print("✅ YouTube 音频获取成功: \(model.title)")
                        completion(model)
                    } else {
                        print("❌ YouTube 音频获取失败，status: \(model.status)")
                        self?.youtubeAudioError = "获取失败"
                        self?.youtubeErrorLog = Self.buildErrorLog(
                            requestURL: url,
                            status: model.status,
                            title: model.title,
                            error: nil
                        )
                        completion(nil)
                    }
                }
            }, onError: { [weak self] error in
                DispatchQueue.main.async {
                    self?.isFetchingYoutubeAudio = false
                    print("❌ YouTube 音频请求错误: \(error.localizedDescription)")
                    self?.youtubeAudioError = error.localizedDescription
                    self?.youtubeErrorLog = Self.buildErrorLog(
                        requestURL: url,
                        status: nil,
                        title: nil,
                        error: error
                    )
                    completion(nil)
                }
            })
            .disposed(by: disposeBag)
    }

    /// Build a detailed console log string for YouTube import errors
    private static func buildErrorLog(requestURL: String, status: String?, title: String?, error: Error?) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        var log = String(repeating: "=", count: 60) + "\n"
        log += "❌ YouTube Audio Import Error\n"
        log += String(repeating: "=", count: 60) + "\n"
        log += "🕐 Timestamp: \(formatter.string(from: Date()))\n"
        log += "🔗 Request URL: \(requestURL)\n"
        log += "🌐 API Endpoint: https://www.perapera.cc/api/v1/common/yt_audio\n"

        if let status = status {
            log += "📊 Response Status: \(status)\n"
        }
        if let title = title, !title.isEmpty {
            log += "📝 Video Title: \(title)\n"
        }
        if let error = error {
            log += "🚫 Error: \(error.localizedDescription)\n"
            let nsError = error as NSError
            log += "⚠️  Error Code: \(nsError.code)\n"
            log += "📍 Domain: \(nsError.domain)\n"
            if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
                log += "📎 Underlying Error: \(underlying.localizedDescription)\n"
            }
        }

        let moyaError = error as? MoyaError
        if let moyaError = moyaError {
            switch moyaError {
            case .underlying(let underlyingError, let response):
                log += "🔍 Moya Underlying Error: \(underlyingError.localizedDescription)\n"
                if let response = response {
                    log += "📡 HTTP Status Code: \(response.statusCode)\n"
                    if let body = String(data: response.data, encoding: .utf8) {
                        log += "📦 Response Body: \(body)\n"
                    }
                }
            case .statusCode(let response):
                log += "📡 HTTP Status Code: \(response.statusCode)\n"
                if let body = String(data: response.data, encoding: .utf8) {
                    log += "📦 Response Body: \(body)\n"
                }
            case .objectMapping(let mappingError, let response):
                log += "🗺️  Mapping Error: \(mappingError.localizedDescription)\n"
                log += "📡 HTTP Status Code: \(response.statusCode)\n"
                if let body = String(data: response.data, encoding: .utf8) {
                    log += "📦 Response Body: \(body)\n"
                }
            default:
                log += "🔍 Moya Error: \(moyaError.localizedDescription)\n"
            }
        }

        let targetURL = URL(string: requestURL)
        log += "\n💡 Possible Causes\n"
        log += String(repeating: "-", count: 40) + "\n"
        if let url = targetURL, url.youtubeVideoID != nil {
            log += "  • Invalid or unsupported YouTube URL\n"
            log += "  • Video is unavailable or region-restricted\n"
            log += "  • Video is age-restricted or private\n"
        } else {
            log += "  • URL is not a valid YouTube link\n"
        }
        log += "  • Network connectivity issue\n"
        log += "  • Backend API service unavailable\n"
        log += "  • Rate limiting or quota exceeded\n"

        log += "\n" + String(repeating: "=", count: 60) + "\n"

        // Also print to console
        print(log)

        return log
    }

    /// 保存翻译结果为 txt 文件到 Documents 目录
    private func saveTranslationResultToTxt(jsonString: String, videoId: String?) {
        do {
            // 获取 Documents 目录
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

            // 生成文件名：如果有 videoId 则使用 videoId_translation.txt，否则使用时间戳
            let fileName: String
            if let videoId = videoId {
                fileName = "\(videoId)_translation.txt"
            } else {
                let timestamp = Int(Date().timeIntervalSince1970)
                fileName = "translation_\(timestamp).txt"
            }

            let fileURL = documentsDirectory.appendingPathComponent(fileName)

            // 写入文件
            try jsonString.write(to: fileURL, atomically: true, encoding: .utf8)

            print("\n" + String(repeating: "=", count: 60))
            print("💾 翻译结果已保存为 TXT 文件")
            print(String(repeating: "=", count: 60))
            print("📝 文件名: \(fileName)")
            print("📂 文件路径: \(fileURL.path)")
            print("📄 内容长度: \(jsonString.count) 字符")
            print(String(repeating: "=", count: 60) + "\n")

        } catch {
            print("❌ 保存翻译结果 TXT 文件失败: \(error.localizedDescription)")
        }
    }
}

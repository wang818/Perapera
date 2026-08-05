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

    // 鉴权错误提示
    @Published var showAuthAlert: Bool = false
    @Published var authErrorMessage: String = ""

    // 输入 URL 后解析出的预览（首页直接显示）
    @Published var youtubePreview: YTBasicInfoModel?

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

        TencentMTManager.shared.translateASRJSON(jsonData: jsonData) { [weak self] result in
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

                    let nsError = error as NSError
                    if nsError.domain == TencentMTManager.errorDomain && nsError.code == TencentMTManager.authErrorCode {
                        DispatchQueue.main.async {
                            self?.authErrorMessage = nsError.localizedDescription
                            self?.showAuthAlert = true
                        }
                    }
                }
            }
        }
    }

    /// 用 yt_info 接口拿基本信息（不下载、不消耗时长），并入库
    func fetchYoutubeAudio(url: String, completion: @escaping (YTAudioModel?) -> Void) {
        isFetchingYoutubeAudio = true
        youtubeAudioError = nil
        youtubeErrorLog = nil

        appApi.rx.request(.ytInfo(url: url))
            .asObservable()
            .subscribe(onNext: { [weak self] response in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.isFetchingYoutubeAudio = false
                    let data = response.data
                    let json = String(data: data, encoding: .utf8) ?? ""
                    let basicInfo = YTBasicInfoModel.deserialize(from: json)
                    if let basicInfo = basicInfo {
                        self.youtubePreview = basicInfo
                        self.saveYouTubeVideoToLocal(url: url, info: basicInfo)
                    }
                    let model = YTAudioModel()
                    model.status = "ok"
                    model.title = basicInfo?.title ?? ""
                    completion(model)
                }
            }, onError: { [weak self] error in
                DispatchQueue.main.async {
                    self?.isFetchingYoutubeAudio = false
                    print("❌ yt_info 请求错误: \(error.localizedDescription)")
                    self?.youtubeAudioError = error.localizedDescription
                    completion(nil)
                }
            })
            .disposed(by: disposeBag)
    }

    private func saveYouTubeVideoToLocal(url: String, info: YTBasicInfoModel) {
        let videoName = info.title.isEmpty ? "YouTube - \(info.video_id)" : info.title
        let duration = Double(info.video_length) ?? 0
        let thumbnailURL = info.bestThumbnail?.url

        _ = VideoStorageManager.shared.addVideo(
            name: videoName,
            posterImage: nil,
            videoURL: url,
            isYouTube: true,
            duration: duration,
            youtubeVideoID: info.video_id,
            author: info.author,
            numberOfViews: info.number_of_views,
            videoDescription: info.description,
            channelID: info.channel_id,
            category: info.category,
            publishedTime: info.published_time,
            keywords: info.keywords,
            thumbnailURL: thumbnailURL
        )

        NotificationCenter.default.post(name: NSNotification.Name("HomeViewShouldRefreshVideos"), object: nil)
    }

    /// 用 yt_info 接口只拿基本信息（不下载、不消耗时长）
    func refreshYoutubePreview(url: String) {
        appApi.rx.request(.ytInfo(url: url))
            .asObservable()
            .subscribe(onNext: { [weak self] response in
                guard let self = self else { return }
                let data = response.data
                if let json = String(data: data, encoding: .utf8),
                   let model = YTBasicInfoModel.deserialize(from: json) {
                    DispatchQueue.main.async {
                        self.youtubePreview = model
                    }
                }
            }, onError: { _ in })
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
        //log += "🌐 API Endpoint: https://www.perapera.cc/api/v1/common/yt_audio\n" //这一句隐藏，不然暴露接口

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

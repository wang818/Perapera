import SwiftUI
import UniformTypeIdentifiers
import Photos
import AVFoundation
import UIKit

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var videos: [VideoItem] = []
    @State private var showingSheet = false
    @State private var showingYoutubeAlert = false
    /// 待删除视频（用于弹确认框）
    @State private var pendingDeleteVideo: VideoItem?
    /// 显式 push 目标
    @State private var navigationDestination: VideoItem?
    @State private var showingFileImporter = false
    @State private var showingPhotoPicker = false
    @State private var youtubeUrl = ""
    @State private var uploadProgress: Double = 0.0
    @State private var isUploading: Bool = false
    @State private var asrTaskId: Int?
    @State private var isRecognizing: Bool = false
    @State private var showProcessComplete: Bool = false
    @State private var processCompleteSuccess: Bool = true
    @State private var translatingCurrent: Int = 0
    @State private var translatingTotal: Int = 0
    @State private var translatingWords: Int = 0
    @State private var isConverting: Bool = false
    @State private var conversionProgress: Double = 0.0
    @State private var currentConvertingVideoId: String?
    @State private var currentRecognizingVideoId: String?
    @State private var currentTranslatingVideoId: String?
    @State private var showYoutubeToast: Bool = false
    @State private var showYoutubeErrorLog: Bool = false
    @State private var pendingYoutubeURL: String?
    @State private var showSettings = false
    @State private var showAuthAlert = false
    @State private var authErrorMessage = ""

    // 根据当前状态动态返回提示文字
    private var processingMessage: String {
        if viewModel.isFetchingYoutubeAudio { return "home_youtube_parsing".localized() }
        if isRecognizing { return "home_recognizing_audio".localized() }
        if viewModel.isTranslating {
            if translatingTotal > 0 {
                return "home_translating_progress".localized(translatingCurrent, translatingTotal, translatingWords)
            }
            return "home_translating".localized()
        }
        if showProcessComplete { return processCompleteSuccess ? "home_recognition_success".localized() : "home_recognition_failed".localized() }
        return ""
    }

    // 按日期分组视频
    private var groupedVideos: [(String, [VideoItem])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-M-d"
        formatter.locale = Locale(identifier: "zh_CN")
        let grouped = Dictionary(grouping: videos) { video in
            formatter.string(from: video.createdAt)
        }
        return grouped.sorted { a, b in
            let df = DateFormatter()
            df.dateFormat = "yyyy-M-d"
            let d1 = df.date(from: a.0) ?? Date.distantPast
            let d2 = df.date(from: b.0) ?? Date.distantPast
            return d1 > d2
        }
    }

    var body: some View {
        ZStack {
            NavigationView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // 大标题区域
                        HStack(alignment: .center) {
                            Text("Perapera")
                                .font(.system(size: 42, weight: .black, design: .rounded))
                                .foregroundColor(.Ex.text1)
                            Spacer()
                            // 暂时隐藏搜索按钮
//                            Button(action: {}) {
//                                Image(systemName: "magnifyingglass")
//                                    .font(.system(size: 18, weight: .medium))
//                                    .foregroundColor(.Ex.text1)
//                            }
//                            .padding(.trailing, 12)
                            // + 按钮
                            Button(action: { showingSheet = true }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.Ex.main)
                                        .frame(width: 38, height: 38)
                                    Image(systemName: "plus")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 16)

                        if videos.isEmpty {
                            // 空状态
                            VStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(Color.Ex.main.opacity(0.12))
                                        .frame(width: 100, height: 100)
                                    Image(systemName: "video.slash")
                                        .font(.system(size: 44))
                                        .foregroundColor(Color.Ex.main)
                                }
                                Text("home_empty_title".localized())
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.Ex.text1)
                                Text("home_empty_subtitle".localized())
                                    .font(.subheadline)
                                    .foregroundColor(.Ex.text2)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 80)
                        } else {
                            // 按日期分组的视频列表
                            ForEach(groupedVideos, id: \.0) { dateStr, items in
                                // 日期分组标题
                                Text(dateStr)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color.Ex.main)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 16)
                                    .padding(.bottom, 8)

                                ForEach(items) { video in
                                    VideoRowView(
                                        video: video,
                                        onDelete: { requestDeleteVideo(video) },
                                        onConvertAudio: { convertAudioForVideo(video) },
                                        onStartRecognition: { startRecognitionForVideo(video) },
                                        onStartTranslation: { startTranslationForVideo(video) }
                                    )
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        navigateToVideo(video)
                                    }
                                    // 用传统 NavigationLink(isActive:) 兜底跳转，
                                    // 避免 navigationDestination(item:) 受 deployment target 影响
                                    .background {
                                        NavigationLink(
                                            destination: destinationView(for: video),
                                            isActive: Binding(
                                                get: { navigationDestination?.id == video.id },
                                                set: { isActive in
                                                    if !isActive && navigationDestination?.id == video.id {
                                                        navigationDestination = nil
                                                    }
                                                }
                                            )
                                        ) { EmptyView() }
                                        .hidden()
                                    }
                                    // 左滑删除
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            requestDeleteVideo(video)
                                        } label: {
                                            Label("home_video_delete".localized(), systemImage: "trash")
                                        }
                                    }
                                    // 长按菜单
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            requestDeleteVideo(video)
                                        } label: {
                                            Label("home_video_delete".localized(), systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }

                        Spacer(minLength: 20)
                    }
                }
                .background(Color.Ex.homepagebg)
                .navigationBarHidden(true)
                .alert(
                    "home_video_delete_confirm_title".localized(),
                    isPresented: Binding<Bool>(
                        get: { pendingDeleteVideo != nil },
                        set: { if !$0 { pendingDeleteVideo = nil } }
                    ),
                    presenting: pendingDeleteVideo
                ) { video in
                    Button("common_delete".localized(), role: .destructive) {
                        deleteVideo(video)
                        pendingDeleteVideo = nil
                    }
                    Button("common_cancel".localized(), role: .cancel) {
                        pendingDeleteVideo = nil
                    }
                } message: { video in
                    Text("home_video_delete_confirm_message".localized())
                }
                .onAppear {
                    loadVideos()
                    DispatchQueue.global(qos: .background).async {
                        let hasChanges = VideoStorageManager.shared.refreshVideoDurations()
                        guard hasChanges else { return }
                        DispatchQueue.main.async { loadVideos() }
                    }
                }
                .onChange(of: viewModel.youtubeAudioError) { newValue in
                    if newValue != nil {
                        showYoutubeErrorLog = true
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("HomeViewShouldRefreshVideos"))) { _ in
                    loadVideos()
                }
                .sheet(isPresented: $showingSheet) {
                    if #available(iOS 16.0, *) {
                        addMenuSheetContent
                            .presentationDetents([.height(240)])
                            .presentationDragIndicator(.visible)
                    } else {
                        addMenuSheetContent
                    }
                }
                .fullScreenCover(isPresented: Binding<Bool>(
                    get: { pendingYoutubeURL != nil },
                    set: { if !$0 { pendingYoutubeURL = nil } }
                )) {
                    if let url = pendingYoutubeURL {
                        VideoPlayerView(pendingYouTubeURL: url)
                    }
                }
                .fileImporter(
                    isPresented: $showingFileImporter,
                    allowedContentTypes: [.audio, .movie, UTType(filenameExtension: "opus")].compactMap { $0 },
                    allowsMultipleSelection: false
                ) { result in
                    switch result {
                    case .success(let urls):
                        guard let url = urls.first else { return }
                        
                        // 获取访问权限
                        guard url.startAccessingSecurityScopedResource() else {
                            print("❌ 无法访问文件")
                            return
                        }
                        
                        defer { url.stopAccessingSecurityScopedResource() }
                        
                        print("Selected media file: \(url.lastPathComponent)")
                        
                        // 保存视频到 Documents 目录
                        let videoName = url.deletingPathExtension().lastPathComponent
                        
                        if let newVideo = VideoStorageManager.shared.addLocalVideo(
                            name: videoName,
                            posterImage: UIImage(systemName: "video.fill"),
                            sourceURL: url
                        ) {
                            // 仅入列，不在首页跑流水线
                            loadVideos()
                            _ = newVideo
                        }
                        
                    case .failure(let error):
                        print("File selection error: \(error.localizedDescription)")
                    }
                }
                .sheet(isPresented: $showingPhotoPicker) {
                    VideoPicker { sourceURL in
                        processPickedVideo(sourceURL)
                    }
                }
                .sheet(isPresented: $showSettings) {
                    NavigationView {
                        SettingsView()
                    }
                }
                .alert("home_auth_error_title".localized(), isPresented: $showAuthAlert) {
                    Button("common_cancel".localized(), role: .cancel) { }
                    Button("home_go_settings".localized()) {
                        showSettings = true
                    }
                } message: {
                    Text(authErrorMessage)
                }
                .alert("home_auth_error_title".localized(), isPresented: $viewModel.showAuthAlert) {
                    Button("common_cancel".localized(), role: .cancel) { }
                    Button("home_go_settings".localized()) {
                        showSettings = true
                    }
                } message: {
                    Text(viewModel.authErrorMessage)
                }
            }
            
            if isUploading {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    ProgressView(value: uploadProgress)
                        .progressViewStyle(.linear)
                        .tint(.blue)
                    
                    Text("home_uploading_progress".localized(Int(uploadProgress * 100)))
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .padding(40)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 10)
                .padding(.horizontal, 40)
            }
            
            if isConverting {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    ProgressView(value: conversionProgress)
                        .progressViewStyle(.linear)
                        .tint(.green)
                    
                    Text("home_converting_audio_progress".localized(Int(conversionProgress * 100)))
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("home_converting_to_opus".localized())
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(40)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 10)
                .padding(.horizontal, 40)
            }
            
            // YouTube解析 → 识别 → 翻译 统一加载弹窗
            if viewModel.isFetchingYoutubeAudio || isRecognizing || viewModel.isTranslating || showProcessComplete {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)

                VStack(spacing: 20) {
                    if showProcessComplete {
                        Image(systemName: processCompleteSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .resizable()
                            .frame(width: 44, height: 44)
                            .foregroundColor(processCompleteSuccess ? .green : .red)
                    } else {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(1.5)
                    }

                    Text(processingMessage)
                        .font(.headline)
                        .foregroundColor(.black)
                }
                .padding(40)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 10)
                .padding(.horizontal, 40)
            }
            
            if showingYoutubeAlert {
                Color.clear
                    .contentShape(Rectangle())
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        showingYoutubeAlert = false
                    }
                
                VStack(spacing: 20) {
                    Text("home_Youtube_Alert_title".localized())
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    TextField("home_Youtube_Alert_textFiled_placeholder".localized(), text: $youtubeUrl)
                        .padding()
                        .frame(height: 50)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                        .onChange(of: youtubeUrl) { newValue in
                            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                            if trimmed.contains("youtube.com") || trimmed.contains("youtu.be") {
                                viewModel.refreshYoutubePreview(url: trimmed)
                            }
                        }

                    if let preview = viewModel.youtubePreview {
                        youtubePreviewCard(preview: preview)
                    }

                    HStack(spacing: 20) {
                        Button(action: {
                            showingYoutubeAlert = false
                        }) {
                            Text("colse".localized())
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                                .foregroundColor(.primary)
                        }
                        
                        Button(action: {
                            // 只调 yt_audio 拿信息，弹框关闭，不跳播放页
                            let urlToOpen = youtubeUrl.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !urlToOpen.isEmpty {
                                viewModel.fetchYoutubeAudio(url: urlToOpen) { _ in }
                            }
                            showingYoutubeAlert = false
                        }) {
                            Text("save".localized())
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(8)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 20)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 10)
                .padding(.horizontal, 40)
            }

            if showYoutubeErrorLog, let errorLog = viewModel.youtubeErrorLog {
                YoutubeErrorLogView(
                    isPresented: $showYoutubeErrorLog,
                    logText: errorLog,
                    errorMessage: viewModel.youtubeAudioError
                )
            }
        }
    }

    private var addMenuSheetContent: some View {
        VStack(alignment: .leading) {
            Text("home_sheet_title".localized())
                .foregroundColor(.Ex.text1)
                .font(.title3)
                .fontWeight(.bold)
                .padding(.top, 22)
                .padding(.leading, 22)
            Text("home_sheet_subtitle".localized())
                .foregroundColor(.Ex.text2)
                .font(.subheadline)
                .padding(.leading, 22)
                .padding(.bottom, 14)

            VStack(spacing: 10) {
                Button(action: {
                    print("Item 1 tapped")
                    youtubeUrl = ""
                    showingSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        showingYoutubeAlert = true
                    }
                }) {
                    HStack(spacing: 15) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.Ex.main.opacity(0.15))
                                .frame(width: 38, height: 38)
                            Image(systemName: "photo")
                                .resizable()
                                .frame(width: 18, height: 18)
                                .foregroundColor(Color.Ex.main)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("home_sheet_list_title1".localized())
                                .font(.headline)
                                .foregroundColor(.Ex.text1)
                            Text("home_sheet_list_subtitle1".localized())
                                .font(.subheadline)
                                .foregroundColor(.Ex.text2)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.Ex.text2)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.Ex.main.opacity(0.08))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.Ex.main.opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 22)

                Button(action: {
                    print("Item 3 tapped")
                    showingSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        showingPhotoPicker = true
                    }
                }) {
                    HStack(spacing: 15) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.1))
                                .frame(width: 38, height: 38)
                            Image(systemName: "doc")
                                .resizable()
                                .frame(width: 18, height: 18)
                                .foregroundColor(.orange)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("home_sheet_list_title3".localized())
                                .font(.headline)
                                .foregroundColor(.Ex.text1)
                            Text("home_sheet_list_subtitle3".localized())
                                .font(.subheadline)
                                .foregroundColor(.Ex.text2)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.Ex.text2)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.Ex.bg2)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 22)
            }
        }
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Helper Methods
    
    /// 加载视频列表
    private func loadVideos() {
        videos = VideoStorageManager.shared.loadVideos()
        printVideosInfo()
    }
    
    /// 输出 videos 变量信息到控制台
    private func printVideosInfo() {
//        print("\n" + String(repeating: "=", count: 70))
//        print("📹 当前视频列表 (共 \(videos.count) 个)")
//        print(String(repeating: "=", count: 70))
        
        if videos.isEmpty {
            print("📭 列表为空")
        } else {
            for (index, video) in videos.enumerated() {
//                print("\n[\(index + 1)] 视频信息:")
//                print("  🆔 ID: \(video.id)")
//                print("  📝 名称: \(video.name)")
//                print("  🎬 视频路径: \(video.videoURL)")
//                
//                print("  🕐 创建时间: \(formatDateForConsole(video.createdAt))")
                
                if let posterImage = video.posterImage {
                    let size = posterImage.size
//                    print("  🖼️  海报图: 有 (\(Int(size.width))x\(Int(size.height)))")
                } else {
                    print("  🖼️  海报图: 无")
                }
                
                // 检查视频类型
                if video.isYouTube {
                    print("  📺 类型: YouTube 视频")
                } else {
                    print("  📁 类型: 本地视频")
                }
                
                // 检查文件状态
//                print("  📊 文件状态:")
//                print("    🎵 音频文件: \(video.hasAudio ? "✅ 已转换" : "❌ 未转换") - \(video.audioURL.path)")
//                print("    📝 识别结果: \(video.hasRecognition ? "✅ 已识别" : "❌ 未识别") - \(video.recognitionURL.path)")
//                print("    🌐 翻译结果: \(video.hasTranslation ? "✅ 已翻译" : "❌ 未翻译") - \(video.translationURL.path)")
//                
//                print("  " + String(repeating: "-", count: 66))
            }
        }
        
        print(String(repeating: "=", count: 70) + "\n")
    }
    
    /// 格式化日期用于控制台输出
    private func formatDateForConsole(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
    
    /// 删除视频
    private func deleteVideo(_ video: VideoItem) {
        VideoStorageManager.shared.deleteVideo(id: video.id)
        loadVideos()
    }

    /// 删除前弹确认框
    private func requestDeleteVideo(_ video: VideoItem) {
        pendingDeleteVideo = video
    }

    /// 跳转到播放页
    private func navigateToVideo(_ video: VideoItem) {
        navigationDestination = video
    }

    /// 根据视频类型选择进入播放页的方式
    /// - YouTube：直接传当前视频对象，播放页点击按钮后再执行完整流水线
    /// - 本地：直接传 video，播放页只负责播放
    @ViewBuilder
    private func destinationView(for video: VideoItem) -> some View {
        VideoPlayerView(video: video)
    }
    
    /// 批量删除视频
    private func deleteVideos(at offsets: IndexSet) {
        for index in offsets {
            let video = videos[index]
            VideoStorageManager.shared.deleteVideo(id: video.id)
        }
        loadVideos()
    }
    
    /// 转换音频
    private func convertAudioForVideo(_ video: VideoItem) {
        if let reason = canStartTranslation(for: video) {
            showTranslationBlockedAlert(reason: reason)
            return
        }
        print("🎵 开始转换音频: \(video.name)")
        currentConvertingVideoId = video.id
        convertVideoToAudio(videoURL: video.actualVideoURL, videoId: video.id)
    }

    /// 开始识别（手动触发）
    private func startRecognitionForVideo(_ video: VideoItem) {
        guard video.hasAudio else {
            print("❌ 音频文件不存在，无法识别")
            return
        }

        print("🎤 开始语音识别: \(video.name)")

        // 上传音频到 COS，拿到 COS URL 后走统一识别 → 翻译流程
        COSUploadManager.shared.uploadFile(fileURL: video.audioURL) { result in
            switch result {
            case .success(let cosURL):
                print("✅ 音频上传成功: \(cosURL)")
                startASRRecognition(cosAudioURL: cosURL, videoId: video.id)

            case .failure(let error):
                print("❌ 音频上传失败: \(error.localizedDescription)")
            }
        }
    }

    /// 开始翻译
    private func startTranslationForVideo(_ video: VideoItem) {
        guard video.hasRecognition else {
            print("❌ 识别结果不存在，无法翻译")
            return
        }

        if let reason = canStartTranslation(for: video) {
            showTranslationBlockedAlert(reason: reason)
            return
        }

        print("🌐 开始翻译: \(video.name)")

        // 读取识别结果
        do {
            let recognitionData = try Data(contentsOf: video.recognitionURL)

            // 解析获取识别文本
            if let jsonObject = try? JSONSerialization.jsonObject(with: recognitionData) as? [String: Any],
               let response = jsonObject["Response"] as? [String: Any],
               let data = response["Data"] as? [String: Any],
               let result = data["Result"] as? String {

                // 开始翻译
                translateRecognitionResult(videoId: video.id, recognizedText: result)
            } else {
                print("❌ 无法解析识别结果")
            }
        } catch {
            print("❌ 读取识别结果失败: \(error.localizedDescription)")
        }
    }

    /// 根据会员剩余时间 + 音频时长判断是否允许开始翻译
    private func canStartTranslation(for video: VideoItem) -> TranslationBlockReason? {
        let duration = video.duration
        return PurchaseManager.shared.translationBlockedReason(audioDurationSeconds: duration!)
    }

    /// 展示会员时间不足提示
    private func showTranslationBlockedAlert(reason: TranslationBlockReason) {
        let title = "home_translation_blocked_title".localized()
        let message: String
        switch reason {
        case .noActivePlan:
            message = "home_translation_blocked_no_plan".localized()
        case .unknownEntitlementExpiration:
            message = "home_translation_blocked_unknown".localized()
        case .insufficientRemainingTime(let remaining, let required):
            let remainingText = Self.formatDuration(seconds: max(0, remaining))
            let requiredText = Self.formatDuration(seconds: max(0, required))
            message = "home_translation_blocked_insufficient".localized(remainingText, requiredText)
        }

        showAlert(title: title, message: message)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "common_ok".localized(), style: .default))
        if let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }),
           var top = window.rootViewController {
            while let presented = top.presentedViewController {
                top = presented
            }
            top.present(alert, animated: true)
        }
    }

    private static func formatDuration(seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    @ViewBuilder
    private func youtubePreviewCard(preview: YTBasicInfoModel) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if let urlString = preview.bestThumbnail?.url,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                    case .success(let image):
                        image.resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .overlay(Image(systemName: "photo").foregroundColor(.gray))
                    @unknown default:
                        Rectangle().fill(Color.gray.opacity(0.2))
                    }
                }
                .frame(width: 120, height: 70)
                .clipped()
                .cornerRadius(6)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 120, height: 70)
                    .cornerRadius(6)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(preview.title.isEmpty ? "YouTube" : preview.title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(Self.formatDuration(seconds: TimeInterval(preview.durationSeconds)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if !preview.author.isEmpty {
                        Text("·")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(preview.author)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(8)
        .padding(.horizontal)
    }
    
    /// 已迁移到 VideoPlayerView 处理（首页仅负责把 URL 推给播放页）
    private func saveYoutubeVideo(url: String) {
        print("ℹ️ saveYoutubeVideo 已废弃，URL 已转交给 VideoPlayerView")
    }

    /// 通用入口：用 COS 音频 URL 启动识别 → 识别完成自动触发翻译
    /// 适用于 YouTube（API 已返回 COS URL）和本地视频（上传后得到 COS URL）
    private func startASRRecognition(cosAudioURL: String, videoId: String) {
        print("🎤 开始 ASR 识别 - videoId: \(videoId), cosURL: \(cosAudioURL)")
        isRecognizing = true
        currentRecognizingVideoId = videoId

        let asrService = ASRManagerFactory.shared.getService()
        asrService.createRecognitionTask(audioURL: cosAudioURL) { result in
            switch result {
            case .success(let taskId):
                print("✅ ASR 任务创建成功，TaskId: \(taskId)")
                asrTaskId = taskId
                pollRecognitionResult(taskId: taskId, videoId: videoId)

            case .failure(let error):
                print("❌ 创建 ASR 任务失败: \(error.localizedDescription)")
                isRecognizing = false
                currentRecognizingVideoId = nil
            }
        }
    }

    /// 下载 YouTube 音频到本地（保存为 .opus 以兼容现有 hasAudio 检查）
    private func downloadYoutubeAudio(from remoteURL: URL, videoId: String) {
        // 使用 .opus 扩展名以兼容 VideoItem.audioURL / hasAudio
        let destinationURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("\(videoId).opus")

        // 如果文件已存在，跳过下载
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            print("📁 音频文件已存在: \(destinationURL.path)")
            loadVideos()
            return
        }

        let task = URLSession.shared.downloadTask(with: remoteURL) { localURL, response, error in
            if let error = error {
                print("❌ 下载音频失败: \(error.localizedDescription)")
                return
            }

            guard let localURL = localURL else {
                print("❌ 下载音频失败: 无本地文件")
                return
            }

            do {
                try FileManager.default.moveItem(at: localURL, to: destinationURL)
                print("✅ 音频下载成功: \(destinationURL.path)")
                DispatchQueue.main.async { [self] in
                    loadVideos()
                }
            } catch {
                print("❌ 移动音频文件失败: \(error.localizedDescription)")
            }
        }
        task.resume()
    }
    
    /// 从 URL 提取视频名称
    private func extractVideoName(from urlString: String) -> String {
        if let url = URL(string: urlString) {
            // 尝试从 YouTube URL 提取视频 ID
            if urlString.contains("youtube.com") || urlString.contains("youtu.be") {
                if let videoId = extractYoutubeVideoId(from: urlString) {
                    return "YouTube - \(videoId)"
                }
            }
            return url.lastPathComponent
        }
        return "home_unnamed_video".localized()
    }
    
    /// 提取 YouTube 视频 ID
    private func extractYoutubeVideoId(from urlString: String) -> String? {
        if let url = URL(string: urlString) {
            if urlString.contains("youtube.com") {
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                return components?.queryItems?.first(where: { $0.name == "v" })?.value
            } else if urlString.contains("youtu.be") {
                return url.lastPathComponent
            }
        }
        return nil
    }
    
    /// 生成视频缩略图
    private func generateVideoThumbnail(url: URL) -> UIImage? {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        let time = CMTime(seconds: 1, preferredTimescale: 60)
        
        do {
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            print("❌ 生成缩略图失败: \(error.localizedDescription)")
            return nil
        }
    }

    /// 处理从系统相册选择的视频
    private func processPickedVideo(_ sourceURL: URL) {
        let videoName = sourceURL.deletingPathExtension().lastPathComponent
        print("Selected media file: \(sourceURL.lastPathComponent)")

        let thumbnail = generateVideoThumbnail(url: sourceURL)

        if let newVideo = VideoStorageManager.shared.addLocalVideo(
            name: videoName,
            posterImage: thumbnail,
            sourceURL: sourceURL
        ) {
            // 仅入列，不在首页跑流水线
            loadVideos()
            _ = newVideo
        }
    }
    
    /// 转换视频为音频
    private func convertVideoToAudio(videoURL: URL, videoId: String) {
        isConverting = true
        conversionProgress = 0.0
        
        AudioConverter.shared.convertVideoToOpusWithProgress(
            inputURL: videoURL,
            videoId: videoId,
            bitrate: "64k",
            sampleRate: 48000,
            progress: { progress in
                DispatchQueue.main.async {
                    conversionProgress = progress
                }
            },
            completion: { result in
                DispatchQueue.main.async {
                    isConverting = false
                    
                    switch result {
                    case .success(let audioURL):
                        print("✅ 音频转换成功!")
                        print("📁 音频路径: \(audioURL.path)")
                        
                        // 输出文件详细信息到控制台
                        printAudioFileInfo(audioURL: audioURL)
                        
                        // 刷新列表（音频文件已保存，状态会自动更新）
                        loadVideos()
                        
                        // 上传音频到 COS 并进行语音识别
                        uploadAudioAndRecognize(audioURL: audioURL, videoId: videoId)
                        
                    case .failure(let error):
                        print("❌ 音频转换失败: \(error.localizedDescription)")
                        // TODO: 显示错误提示给用户
                    }
                    
                    currentConvertingVideoId = nil
                }
            }
        )
    }
    
    /// 上传音频并进行语音识别
    private func uploadAudioAndRecognize(audioURL: URL, videoId: String) {
        isUploading = true
        uploadProgress = 0.0

        COSUploadManager.shared.uploadFile(
            fileURL: audioURL,
            progress: { progress in
                DispatchQueue.main.async {
                    uploadProgress = progress
                }
                print("上传进度: \(Int(progress * 100))%")
            },
            completion: { result in
                DispatchQueue.main.async {
                    isUploading = false
                }
                switch result {
                case .success(let cosURL):
                    print("✅ 音频上传成功! COS访问地址: \(cosURL)")
                    // 拿到 COS URL 后走与 YouTube 相同的识别 → 翻译流程
                    startASRRecognition(cosAudioURL: cosURL, videoId: videoId)
                case .failure(let error):
                    print("❌ 音频上传失败: \(error.localizedDescription)")
                    // TODO: 显示错误提示给用户
                }
            }
        )
    }
    
    /// 读取并打印 123.json 的内容
    private func print123JsonContent() {
        viewModel.translate123Json()
    }
    
    /// 输出音频文件详细信息到控制台
    private func printAudioFileInfo(audioURL: URL) {
        print("\n" + String(repeating: "=", count: 60))
        print("📄 转换后的音频文件信息")
        print(String(repeating: "=", count: 60))
        
        do {
            // 获取文件属性
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: audioURL.path)
            
            // 文件名
            print("📝 文件名: \(audioURL.lastPathComponent)")
            
            // 文件路径
            print("📂 完整路径: \(audioURL.path)")
            
            // 文件大小
            if let fileSize = fileAttributes[.size] as? Int64 {
                let fileSizeMB = Double(fileSize) / (1024 * 1024)
                let fileSizeKB = Double(fileSize) / 1024
                print("💾 文件大小: \(String(format: "%.2f", fileSizeMB)) MB (\(String(format: "%.2f", fileSizeKB)) KB)")
            }
            
            // 创建时间
            if let creationDate = fileAttributes[.creationDate] as? Date {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                print("🕐 创建时间: \(formatter.string(from: creationDate))")
            }
            
            // 文件格式
            print("🎵 文件格式: \(audioURL.pathExtension.uppercased())")
            
            // 检查文件是否存在
            let fileExists = FileManager.default.fileExists(atPath: audioURL.path)
            print("✓ 文件存在: \(fileExists ? "是" : "否")")
            
            // 尝试读取音频元数据
            let asset = AVAsset(url: audioURL)
            let duration = asset.duration
            let durationSeconds = CMTimeGetSeconds(duration)
            
            if durationSeconds.isFinite && durationSeconds > 0 {
                let minutes = Int(durationSeconds) / 60
                let seconds = Int(durationSeconds) % 60
                print("⏱️  音频时长: \(minutes)分\(seconds)秒 (\(String(format: "%.2f", durationSeconds))秒)")
            }
            
            print(String(repeating: "=", count: 60) + "\n")
            
        } catch {
            print("❌ 无法读取文件信息: \(error.localizedDescription)")
        }
    }
    
    /// 轮询查询语音识别结果
    private func pollRecognitionResult(taskId: Int, videoId: String, retryCount: Int = 0) {
        let maxRetries = 60 // 最多轮询 60 次（约 5 分钟）
        
        guard retryCount < maxRetries else {
            print("❌ 语音识别超时")
            DispatchQueue.main.async {
                isRecognizing = false
            }
            return
        }
        
        let asrService = ASRManagerFactory.shared.getService()
        asrService.queryRecognitionResult(taskId: taskId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let taskResult):
                    print("📊 识别状态: \(taskResult.statusStr)")

                    switch taskResult.status {
                    case 2: // 成功
                        if let recognizedText = taskResult.result {
                            print("✅ 识别成功!")
                            print("识别结果: \(recognizedText)")
                            isRecognizing = false

                            // 直接保存原始 JSON 响应
                            saveRawRecognitionJSON(videoId: videoId, rawJSON: taskResult.rawJSON, recognizedText: recognizedText)
                        }

                    case 3: // 失败
                        print("❌ 识别失败: \(taskResult.errorMsg ?? "未知错误")")
                        isRecognizing = false

                    case 0, 1: // 等待中或执行中
                        // 5 秒后继续轮询
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                            pollRecognitionResult(taskId: taskId, videoId: videoId, retryCount: retryCount + 1)
                        }

                    default:
                        print("⚠️ 未知状态: \(taskResult.status)")
                        isRecognizing = false
                    }
                    
                case .failure(let error):
                    print("❌ 查询识别结果失败: \(error.localizedDescription)")
                    // 失败后重试
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        pollRecognitionResult(taskId: taskId, videoId: videoId, retryCount: retryCount + 1)
                    }
                }
            }
        }
    }
    
    /// 保存原始 ASR JSON 响应
    private func saveRawRecognitionJSON(videoId: String, rawJSON: Data, recognizedText: String) {
        do {
            // 获取 Documents 目录
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            
            // 生成文件路径：videoId.json
            let fileURL = documentsDirectory.appendingPathComponent("\(videoId).json")
            
            // 直接写入原始 JSON 数据
            try rawJSON.write(to: fileURL)
            
            print("\n" + String(repeating: "=", count: 60))
            print("💾 ASR 原始 JSON 已保存")
            print(String(repeating: "=", count: 60))
            print("📝 文件名: \(videoId).json")
            print("📂 文件路径: \(fileURL.path)")
            print("🆔 视频ID: \(videoId)")
            print("📄 识别文本长度: \(recognizedText.count) 字符")
            print("📦 JSON 文件大小: \(ByteCountFormatter.string(fromByteCount: Int64(rawJSON.count), countStyle: .file))")
            
            // 输出完整 JSON 内容到控制台（格式化）
            if let jsonObject = try? JSONSerialization.jsonObject(with: rawJSON),
               let prettyJSON = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted),
               let jsonString = String(data: prettyJSON, encoding: .utf8) {
                print("\n📋 JSON 完整内容:")
                print(jsonString)
            }
            
            print(String(repeating: "=", count: 60) + "\n")
            
            // 刷新列表（识别结果文件已保存，状态会自动更新）
            loadVideos()
            
            // 自动触发翻译
            translateRecognitionResult(videoId: videoId, recognizedText: recognizedText)
            
        } catch {
            print("❌ 保存原始 JSON 失败: \(error.localizedDescription)")
        }
    }
    
    /// 翻译识别结果
    private func translateRecognitionResult(videoId: String, recognizedText: String) {
        print("\n" + String(repeating: "🌟", count: 40))
        print("🚀 开始翻译识别结果（逐句翻译 + 读音）")
        print(String(repeating: "🌟", count: 40) + "\n")
        
        DispatchQueue.main.async {
            viewModel.isTranslating = true
            translatingCurrent = 0
            translatingTotal = 0
            translatingWords = 0
        }
        
        // 读取 JSON 文件
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let jsonFileURL = documentsDirectory.appendingPathComponent("\(videoId).json")
        
        guard let jsonData = try? Data(contentsOf: jsonFileURL) else {
            print("❌ 无法读取 JSON 文件")
            DispatchQueue.main.async {
                viewModel.isTranslating = false
            }
            return
        }
        
        // 调用腾讯云机器翻译 API（整句翻译 + 机械生成假名/罗马音）
        AliyunMTManager.shared.translateASRJSON(jsonData: jsonData, progress: { current, total, wordCount in
            DispatchQueue.main.async {
                translatingCurrent = current
                translatingTotal = total
                translatingWords = wordCount
            }
        }) { result in
            DispatchQueue.main.async {
                viewModel.isTranslating = false
                
                switch result {
                case .success(let enrichedData):
                    // 将翻译后的 JSON 覆盖写回原文件
                    do {
                        try enrichedData.write(to: jsonFileURL)
                        print("✅ 翻译结果已写回 JSON 文件: \(jsonFileURL.path)")

                        // 输出完整 JSON 到控制台
                        if let jsonString = String(data: enrichedData, encoding: .utf8) {
                            print("\n📋 翻译后的 JSON 完整内容:")
                            print(jsonString)
                        }

                    } catch {
                        print("❌ 写回 JSON 文件失败: \(error.localizedDescription)")
                    }

                    // 刷新列表
                    loadVideos()

                    // 显示完成提示
                    processCompleteSuccess = true
                    showProcessComplete = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showProcessComplete = false
                    }

                case .failure(let error):
                    print("❌ 翻译失败: \(error.localizedDescription)")
                    let nsError = error as NSError
                    if nsError.domain == AliyunMTManager.errorDomain && nsError.code == AliyunMTManager.authErrorCode {
                        // 鉴权失败 → 提示用户登录/配置密钥，跳转设置页
                        authErrorMessage = nsError.localizedDescription
                        showAuthAlert = true
                    } else {
                        processCompleteSuccess = false
                        showProcessComplete = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            showProcessComplete = false
                        }
                    }
                }
            }
        }
    }
    
}

struct VideoPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void
    @Environment(\.presentationMode) private var presentationMode

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .savedPhotosAlbum
        picker.mediaTypes = ["public.movie"]
        picker.videoQuality = .typeMedium
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let parent: VideoPicker

        init(_ parent: VideoPicker) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let url = info[.mediaURL] as? URL {
                parent.onPick(url)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Video Row View
struct VideoRowView: View {
    let video: VideoItem
    let onDelete: () -> Void
    let onConvertAudio: () -> Void
    let onStartRecognition: () -> Void
    let onStartTranslation: () -> Void

    @State private var loadedThumbnail: UIImage?
    @State private var isLoadingThumbnail: Bool = false

    var body: some View {
        // 整个卡片包裹在圆角灰色背景矩形里，padding 为 5
        VStack(alignment: .leading, spacing: 0) {
            // 缩略图区域
            ZStack(alignment: .topLeading) {
                Group {
                    if let posterImage = video.posterImage {
                        Image(uiImage: posterImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else if video.isYouTube,
                              let thumbnail = video.thumbnailURL,
                              let url = URL(string: thumbnail) {
                        if let img = loadedThumbnail {
                            Image(uiImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else if isLoadingThumbnail {
                            Rectangle()
                                .fill(Color.Ex.bg3)
                                .overlay(
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                )
                        } else {
                            Rectangle()
                                .fill(Color.Ex.bg3)
                                .overlay(
                                    Image(systemName: "play.fill")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 24, height: 24)
                                        .foregroundColor(Color.Ex.text3)
                                )
                        }
                    } else {
                        Rectangle()
                            .fill(Color.Ex.bg3)
                            .overlay(
                                Image(systemName: "video.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 24, height: 24)
                                    .foregroundColor(Color.Ex.text3)
                            )
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .clipped()
                .cornerRadius(10)
                .onAppear {
                    if video.isYouTube,
                       let thumbnail = video.thumbnailURL,
                       URL(string: thumbnail) != nil,
                       loadedThumbnail == nil {
                        loadThumbnail(from: thumbnail)
                    }
                }

                // 左上角类型图标角标
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.35))
                        .frame(width: 36, height: 36)
                    Image(systemName: video.isYouTube ? "play.fill" : "video.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(10)
            }

            // 时长 + 标题
            VStack(alignment: .leading, spacing: 4) {
                if let duration = video.duration {
                    Text(formatDuration(duration))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.Ex.text2)
                        .padding(.top, 8)
                }

                Text(video.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.Ex.text1)
                    .lineLimit(2)
                    .padding(.bottom, 10)
            }
            .padding(.horizontal, 4)
        }
        .padding(10)
        .background(Color.Ex.bg3)
        .cornerRadius(14)
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }

    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    private func loadThumbnail(from urlString: String) {
        guard !isLoadingThumbnail else { return }
        isLoadingThumbnail = true
        guard let url = URL(string: urlString) else {
            isLoadingThumbnail = false
            return
        }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async {
                self.isLoadingThumbnail = false
                if let data = data, let image = UIImage(data: data) {
                    self.loadedThumbnail = image
                }
            }
        }.resume()
    }
}

// MARK: - YouTube Error Log View

struct YoutubeErrorLogView: View {
    @Binding var isPresented: Bool
    let logText: String
    let errorMessage: String?

    @State private var showCopiedToast: Bool = false

    var body: some View {
        ZStack {
            // Dimmed background overlay
            Color.black.opacity(0.45)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    isPresented = false
                }

            // Modal card
            VStack(spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 18))
                    Text("home_youtube_import_error".localized())
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    Spacer()
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)

                Divider()
                    .padding(.horizontal, 20)

                // Console log content
                ScrollView {
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(logText)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.primary)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxHeight: 320)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

                Divider()
                    .padding(.horizontal, 20)

                // Bottom buttons
                HStack(spacing: 12) {
                    // Copy button
                    Button(action: {
                        UIPasteboard.general.string = logText
                        showCopiedToast = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            showCopiedToast = false
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: showCopiedToast ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 14))
                            Text(showCopiedToast ? "home_log_copied".localized() : "home_copy_log".localized())
                                .font(.system(size: 14, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                    }

                    // Close button
                    Button(action: { isPresented = false }) {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14))
                            Text("colse".localized())
                                .font(.system(size: 14, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.15))
                        .foregroundColor(.primary)
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .frame(maxWidth: 400)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 20)
        }
    }
}

#Preview {
    HomeView()
}

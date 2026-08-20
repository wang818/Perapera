import SwiftUI
import AVKit
import AVFoundation
import UIKit

struct TabBarHiderModifier: ViewModifier {
    @State private var hostingController: UITabBarController?

    func body(content: Content) -> some View {
        content
            .onAppear {
                DispatchQueue.main.async {
                    self.hostingController = Self.findTabBarController()
                    self.hostingController?.tabBar.isHidden = true
                }
            }
            .onDisappear {
                DispatchQueue.main.async {
                    self.hostingController?.tabBar.isHidden = false
                }
            }
    }

    private static func findTabBarController() -> UITabBarController? {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) ?? UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first else {
            return nil
        }

        if let tab = window.rootViewController as? UITabBarController {
            return tab
        }
        if let nav = window.rootViewController as? UINavigationController,
           let tab = nav.topViewController as? UITabBarController {
            return tab
        }
        var current: UIViewController? = window.rootViewController
        while let next = current {
            if let tab = next as? UITabBarController {
                return tab
            }
            if let presented = next.presentedViewController {
                current = presented
                continue
            }
            current = next.children.first
        }
        return nil
    }
}

struct VideoPlayerView: View {
    let video: VideoItem
    let pendingYouTubeURL: String?

    @StateObject private var viewModel: VideoPlayerViewModel
    @Environment(\.dismiss) private var dismiss

    /// 播放页本身是 fullScreenCover，再 fullScreenCover 在 iOS 上会被吞掉。
    /// 所以"去登录"行为：dismiss 自己 + 发通知给 ContentView，由它弹 LoginView。
    private func requestShowLogin() {
        NotificationCenter.default.post(name: .peraperaRequestShowLogin, object: nil)
        // YouTube 路径下是 fullScreenCover 进来的，可以直接 dismiss
        dismiss()
    }

    init(video: VideoItem) {
        self.video = video
        self.pendingYouTubeURL = nil
        _viewModel = StateObject(wrappedValue: VideoPlayerViewModel(video: video, pendingYouTubeURL: nil))
    }

    init(pendingYouTubeURL: String) {
        let placeholderID = UUID().uuidString
        let placeholder = VideoItem(
            id: placeholderID,
            name: "YouTube - \(Self.preferredYouTubeID(from: pendingYouTubeURL) ?? placeholderID)",
            posterImageData: nil,
            videoURL: pendingYouTubeURL,
            createdAt: Date(),
            isYouTube: true,
            duration: nil
        )
        self.video = placeholder
        self.pendingYouTubeURL = pendingYouTubeURL
        _viewModel = StateObject(wrappedValue: VideoPlayerViewModel(video: placeholder, pendingYouTubeURL: pendingYouTubeURL))
    }

    var body: some View {
        VStack(spacing: 0) {
            topNavigationBar
            videoPlayerSection
            if viewModel.shouldShowYouTubeProcessButton {
                youtubeProcessSection
            }
            if viewModel.shouldShowLocalAudioProcessButton {
                localAudioProcessSection
            }
            subtitleScrollSection
            if !viewModel.pipelineStatusMessage.isEmpty {
                Text(viewModel.pipelineStatusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
            }
            Spacer(minLength: 0)
            bottomControlBar
        }
        .background(Color.ex.main.opacity(0.1))
        .ignoresSafeArea(.container, edges: .bottom)
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .modifier(TabBarHiderModifier())
        .onAppear {
            viewModel.setupPlayer()
            viewModel.refreshUserInfoOnAppear()
        }
        .onDisappear {
            viewModel.cleanup()
        }
        .alert("home_auth_error_title".localized(), isPresented: $viewModel.showAuthAlert) {
            Button("common_cancel".localized(), role: .cancel) { }
            Button("home_go_settings".localized()) {
                UserManager.shared.logout()
                viewModel.showAuthAlert = false
                requestShowLogin()
            }
        } message: {
            Text(viewModel.authErrorMessage)
        }
        .alert("common_notice".localized(), isPresented: Binding<Bool>(
            get: { viewModel.localProcessBlockedMessage != nil },
            set: { if !$0 { viewModel.localProcessBlockedMessage = nil } }
        )) {
            Button("common_cancel".localized(), role: .cancel) { }
            if !UserManager.shared.isLoggedIn {
                Button("home_go_settings".localized()) {
                    viewModel.localProcessBlockedMessage = nil
                    requestShowLogin()
                }
            }
        } message: {
            Text(viewModel.localProcessBlockedMessage ?? "")
        }
        .onReceive(NotificationCenter.default.publisher(for: .peraperaRequestShowLogin)) { _ in
            // 通知到了，说明是 viewModel 拦截触发的，本页已经全屏 cover，直接 dismiss 回首页
            dismiss()
        }
        .sheet(isPresented: $viewModel.showSettings) {
            NavigationView {
                SettingsView()
            }
        }
    }

    private static func preferredYouTubeID(from url: String) -> String? {
        if url.contains("youtube.com") {
            if let comps = URLComponents(string: url),
               let id = comps.queryItems?.first(where: { $0.name == "v" })?.value {
                return id
            }
        } else if url.contains("youtu.be") {
            return URL(string: url)?.lastPathComponent
        }
        return nil
    }
    
    // MARK: - 顶部导航栏
    private var topNavigationBar: some View {
        ZStack {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color.ex.text1)
                }
                
                Spacer()
            }
            
            Text(viewModel.video.name)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.ex.text1)
                .lineLimit(1)
                .padding(.horizontal, 60)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - YouTube 视频 ID
    private var youtubeVideoID: String? {
        viewModel.video.videoURL.youtubeVideoID
    }

    // MARK: - 视频播放器
    private var videoPlayerSection: some View {
        ZStack {
            Color.black

            if viewModel.isYouTube, let videoID = youtubeVideoID {
                // YouTube 播放器
                YouTubePlayerView(videoID: videoID, controller: viewModel.youtubeController)

                // 播放/暂停按钮覆盖层（仅当 YouTube 播放器 ready 后显示）
                if !viewModel.isLoading {
                    (viewModel.isPlaying ? Color.clear : Color.black.opacity(0.3))
                        .onTapGesture { viewModel.togglePlayPause() }
                        .animation(.none, value: viewModel.isPlaying)
                }

                // 大播放按钮（暂停状态时显示）
                if !viewModel.isPlaying && !viewModel.isLoading {
                    Button(action: { viewModel.togglePlayPause() }) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.white)
                            .frame(width: 64, height: 64)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .transition(.opacity)
                }

            } else if let player = viewModel.player {
                // 本地视频 AVPlayer
                VideoPlayer(player: player)
                    .disabled(true)

                // 播放/暂停按钮覆盖层（透明确保可点击暂停）
                (viewModel.isPlaying ? Color.clear : Color.black.opacity(0.3))
                    .onTapGesture { viewModel.togglePlayPause() }
                    .animation(.none, value: viewModel.isPlaying)

                if !viewModel.isPlaying {
                    Button(action: { viewModel.togglePlayPause() }) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.white)
                            .frame(width: 64, height: 64)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .transition(.opacity)
                }

            } else {
                // 加载中或错误状态
                VStack(spacing: 16) {
                    if viewModel.isLoading {
                        ProgressView().scaleEffect(1.5).tint(.white)
                        Text("加载中...").font(.subheadline).foregroundColor(.white.opacity(0.7))
                    } else {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40)).foregroundColor(.white.opacity(0.5))
                        Text("无法加载视频").font(.subheadline).foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
        .aspectRatio(16/9, contentMode: .fit)
        .clipped()
    }

    private var youtubeProcessSection: some View {
        VStack(spacing: 10) {
            Button(action: {
                viewModel.startYouTubePipelineFromButton()
            }) {
                HStack(spacing: 8) {
                    if viewModel.isProcessingYouTubePipeline {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    }
                    Text(viewModel.youtubeProcessButtonTitle)
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(viewModel.isProcessingYouTubePipeline ? Color.gray : Color.Ex.main)
                .cornerRadius(12)
            }
            .disabled(viewModel.isProcessingYouTubePipeline)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var localAudioProcessSection: some View {
        VStack(spacing: 10) {
            Button(action: {
                viewModel.startLocalAudioPipelineFromButton()
            }) {
                HStack(spacing: 8) {
                    if viewModel.isProcessingYouTubePipeline {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    }
                    Text(viewModel.youtubeProcessButtonTitle)
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(viewModel.isProcessingYouTubePipeline ? Color.gray : Color.Ex.main)
                .cornerRadius(12)
            }
            .disabled(viewModel.isProcessingYouTubePipeline)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
    
    // MARK: - 字幕滚动区域
    private var subtitleScrollSection: some View {
        Group {
            if viewModel.subtitles.isEmpty {
                noSubtitleView
            } else {
                subtitleListView
            }
        }
    }
    
    // MARK: - 无字幕
    private var noSubtitleView: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("No Subtitles?")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(Color.ex.text1)
            
            Button(action: {}) {
                Text("Enable AI Subtitles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.ex.text1)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color(red: 0.78, green: 0.92, blue: 0.58)))
            }
            
            HStack(spacing: 4) {
                Text("Language Detection").font(.system(size: 14)).foregroundColor(Color.ex.text2)
                Text("Auto").font(.system(size: 14, weight: .semibold)).foregroundColor(Color.ex.text1)
                Image(systemName: "chevron.down").font(.system(size: 10, weight: .medium)).foregroundColor(Color.ex.text2)
            }
            Spacer()
        }
    }
    
    // MARK: - 字幕列表（ScrollViewReader 内联）
    private var subtitleListView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 16) {
                    // 上方留白，让第一句可以滚动到中间
                    Color.clear.frame(height: 60)
                    
                    ForEach(Array(viewModel.subtitles.enumerated()), id: \.offset) { index, subtitle in
                        SentenceCardView(
                            subtitle: subtitle,
                            isActive: viewModel.currentSubtitleIndex == index,
                            currentTime: viewModel.currentTime,
                            onTap: {
                                viewModel.seek(to: subtitle.startTime)
                            }
                        )
                        .id(index)
                    }
                    
                    // 下方留白
                    Color.clear.frame(height: 60)
                }
                .padding(.horizontal, 16)
            }
            .onAppear {
                // 初始滚动到第一条字幕
                let initialIndex = viewModel.currentSubtitleIndex
                if initialIndex >= 0 {
                    proxy.scrollTo(initialIndex, anchor: .center)
                }
            }
            .onChange(of: viewModel.currentSubtitleIndex) { newIndex in
                guard newIndex >= 0 else { return }
                if !viewModel.isSubtitlePinned {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
        }
    }
    
    // MARK: - 底部控制栏
    private var bottomControlBar: some View {
        VStack(spacing: 12) {
            progressBar
            toolBar
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - 进度条
    private var progressBar: some View {
        HStack(spacing: 10) {
            Text(formatTime(viewModel.currentTime))
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(Color.ex.text2)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(width: 48, alignment: .leading)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.ex.text3.opacity(0.3)).frame(height: 4)
                    Capsule().fill(Color(red: 0.30, green: 0.45, blue: 0.26))
                        .frame(width: progressWidth(in: geometry.size.width), height: 4)
                    Circle().fill(Color(red: 0.30, green: 0.45, blue: 0.26))
                        .frame(width: 14, height: 14)
                        .offset(x: progressWidth(in: geometry.size.width) - 7)
                        .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                            let ratio = max(0, min(1, value.location.x / geometry.size.width))
                            viewModel.seek(to: Double(ratio) * viewModel.duration)
                        })
                }
                .frame(height: 14)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            let ratio = max(0, min(1, value.location.x / geometry.size.width))
                            viewModel.seek(to: Double(ratio) * viewModel.duration)
                        }
                )
            }
            .frame(height: 14)
            
            Text(formatTime(viewModel.duration))
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(Color.ex.text2)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(width: 48, alignment: .trailing)
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - 功能按钮栏
    private var toolBar: some View {
        HStack {
            HStack(spacing: 0) {
                toolBarButton(
                    icon: viewModel.isSubtitlePinned ? "pin.fill" : "pin.slash",
                    label: viewModel.isSubtitlePinned ? "Pinned" : "Pin"
                ) {
                    viewModel.isSubtitlePinned.toggle()
                }
                // toolBarButton(icon: "star.square.on.square", label: "Explain") {}
                toolBarButton(icon: "repeat", label: "Repeat") { viewModel.replay() }
                toolBarButton(
                    icon: "gauge.with.dots.needle.33percent",
                    label: viewModel.playbackSpeedText
                ) {
                    viewModel.cycleSpeed()
                }
                toolBarButton(
                    icon: viewModel.isPlaying ? "pause" : "play.fill",
                    label: viewModel.isPlaying ? "Pause" : "Play"
                ) { viewModel.togglePlayPause() }
            }
            Spacer()
            // Button(action: {}) {
            //     ZStack {
            //         Circle().fill(Color.ex.text3.opacity(0.15)).frame(width: 44, height: 44)
            //         Image(systemName: "person.2.fill").font(.system(size: 18)).foregroundColor(Color.ex.text2)
            //     }
            // }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }
    
    private func toolBarButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 18)).frame(height: 22)
                Text(label).font(.system(size: 10))
            }
            .foregroundColor(Color.ex.text1)
            .frame(width: 56, height: 48)
        }
    }
    
    private func progressWidth(in totalWidth: CGFloat) -> CGFloat {
        guard viewModel.duration > 0 else { return 0 }
        return max(0, min(totalWidth, totalWidth * CGFloat(viewModel.currentTime / viewModel.duration)))
    }
    
    private func formatTime(_ time: Double) -> String {
        guard !time.isNaN && !time.isInfinite else { return "0:00" }
        return String(format: "%d:%02d", Int(time) / 60, Int(time) % 60)
    }
}

// MARK: - 单句字幕卡片
struct SentenceCardView: View {
    let subtitle: SubtitleItem
    let isActive: Bool
    let currentTime: Double
    let onTap: () -> Void
    
    private let greenDark = Color(red: 0.30, green: 0.45, blue: 0.26)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let words = subtitle.words {
                // 词级别显示：假名 + 原文 + romaji
                WordWrapView(words: words, isSentenceActive: isActive, currentTime: currentTime, subtitleStartTime: subtitle.startTime)
                
                // 整句平假名（译文上方）
                if let hiragana = subtitle.hiragana, !hiragana.isEmpty {
                    Text(hiragana)
                        .font(.system(size: 13))
                        .foregroundColor(Color.ex.text2)
                        .padding(.horizontal, 12)
                        .padding(.top, 2)
                        .padding(.bottom, 0)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // 整句翻译 - 优先使用 subtitle.translatedText（Tencent MT 整句翻译），fallback 到逐词翻译拼接
                let sentenceTranslation = !subtitle.translatedText.isEmpty ? subtitle.translatedText : words.compactMap { $0.translation }.joined()
                if !sentenceTranslation.isEmpty {
                    Text(sentenceTranslation)
                        .font(.system(size: 14))
                        .foregroundColor(Color.ex.text1)
                        .padding(.horizontal, 12)
                        .padding(.top, 0)
                        .padding(.bottom, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // 整句罗马音（译文下方）
                if let romaji = subtitle.romaji, !romaji.isEmpty {
                    Text(romaji)
                        .font(.system(size: 12))
                        .foregroundColor(Color.ex.text3)
                        .padding(.horizontal, 12)
                        .padding(.top, 0)
                        .padding(.bottom, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                // 没有词级别信息，显示整句
                Text(subtitle.originalText)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isActive ? greenDark : Color.ex.text1)
                
                // 整句平假名（译文上方）
                if let hiragana = subtitle.hiragana, !hiragana.isEmpty {
                    Text(hiragana)
                        .font(.system(size: 13))
                        .foregroundColor(Color.ex.text2)
                        .padding(.horizontal, 12)
                        .padding(.top, 2)
                        .padding(.bottom, 0)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                if !subtitle.translatedText.isEmpty {
                    Text(subtitle.translatedText)
                        .font(.system(size: 14))
                        .foregroundColor(Color.ex.text1)
                        .padding(.horizontal, 12)
                        .padding(.top, 0)
                        .padding(.bottom, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // 整句罗马音（译文下方）
                if let romaji = subtitle.romaji, !romaji.isEmpty {
                    Text(romaji)
                        .font(.system(size: 12))
                        .foregroundColor(Color.ex.text3)
                        .padding(.horizontal, 12)
                        .padding(.top, 0)
                        .padding(.bottom, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isActive ? Color.ex.main.opacity(0.13) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .opacity(isActive ? 1.0 : 0.5)
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }
    
    private func isWordCurrent(_ word: WordTiming) -> Bool {
        let absoluteStart = subtitle.startTime + word.startTime
        let absoluteEnd = subtitle.startTime + word.endTime
        return currentTime >= absoluteStart && currentTime <= absoluteEnd
    }
}

// MARK: - 自动换行词组布局（VStack + HStack，避免 alignment guide 导致的布局异常）
struct WordWrapView: View {
    let words: [WordTiming]
    let isSentenceActive: Bool
    let currentTime: Double
    let subtitleStartTime: Double

    private let greenDark = Color(red: 0.30, green: 0.45, blue: 0.26)

    var body: some View {
        // 在 GeometryReader 内计算每行能放多少个词，用 VStack+HStack 渲染
        GeometryReader { geometry in
            let rows = computeRows(availableWidth: geometry.size.width)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 6) {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, word in
                            wordView(for: word)
                        }
                    }
                }
            }
        }
        .frame(minHeight: estimatedTotalHeight(maxWidth: UIScreen.main.bounds.width - 56))
    }

    // MARK: - 按可用宽度分行
    private func computeRows(availableWidth: CGFloat) -> [[WordTiming]] {
        var rows: [[WordTiming]] = []
        var currentRow: [WordTiming] = []
        var currentWidth: CGFloat = 0

        for word in words {
            let wordWidth = estimatedWordWidth(word) + 6 // trailing spacing
            if currentWidth + wordWidth > availableWidth && !currentRow.isEmpty {
                rows.append(currentRow)
                currentRow = [word]
                currentWidth = wordWidth
            } else {
                currentRow.append(word)
                currentWidth += wordWidth
            }
        }
        if !currentRow.isEmpty { rows.append(currentRow) }
        return rows
    }

    private func estimatedWordWidth(_ word: WordTiming) -> CGFloat {
        let original = word.word as NSString
        let furigana = (word.furigana ?? " ") as NSString
        let reading = (word.reading ?? " ") as NSString

        let fSize = furigana.size(withAttributes: [.font: UIFont.systemFont(ofSize: 10)])
        let oSize = original.size(withAttributes: [.font: UIFont.systemFont(ofSize: 20, weight: .medium)])
        let rSize = reading.size(withAttributes: [.font: UIFont.systemFont(ofSize: 10)])

        return ceil(max(fSize.width, oSize.width + 10, rSize.width))
    }

    private func estimatedTotalHeight(maxWidth: CGFloat) -> CGFloat {
        let rows = computeRows(availableWidth: maxWidth)
        let lineHeight: CGFloat = 64 // furigana(12) + word(28) + reading(12) + spacing
        return CGFloat(rows.count) * lineHeight + CGFloat(max(0, rows.count - 1)) * 4
    }

    // MARK: - 单个词的 View
    private func wordView(for word: WordTiming) -> some View {
        let isWordActive = isSentenceActive && isWordCurrent(word)

        return VStack(spacing: 1) {
            Text(word.furigana ?? " ")
                .font(.system(size: 10))
                .foregroundColor(Color.ex.text3)
                .lineLimit(1)

            Text(word.word)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(isWordActive ? greenDark : Color.ex.text1)
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isWordActive ? greenDark : Color.clear, lineWidth: 2)
                )

            Text(word.reading ?? " ")
                .font(.system(size: 10))
                .foregroundColor(Color.ex.text2)
                .lineLimit(1)
        }
        .fixedSize() // 防止单词被截断
    }

    private func isWordCurrent(_ word: WordTiming) -> Bool {
        // word.startTime/endTime 已经是绝对时间（秒），不需要再加 subtitleStartTime
        return currentTime >= word.startTime && currentTime <= word.endTime
    }
}

#Preview {
    VideoPlayerView(video: VideoItem(
        name: "IMG_0743.MP4",
        posterImageData: nil,
        videoURL: ""
    ))
}

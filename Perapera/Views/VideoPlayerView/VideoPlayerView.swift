import SwiftUI
import AVKit
import AVFoundation

struct VideoPlayerView: View {
    let video: VideoItem
    
    @StateObject private var viewModel: VideoPlayerViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(video: VideoItem) {
        self.video = video
        _viewModel = StateObject(wrappedValue: VideoPlayerViewModel(video: video))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            topNavigationBar
            videoPlayerSection
            subtitleScrollSection
            Spacer(minLength: 0)
            bottomControlBar
        }
        .background(Color.ex.bg1)
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            viewModel.setupPlayer()
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }
    
    // MARK: - 顶部导航栏
    private var topNavigationBar: some View {
        HStack(spacing: 12) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color.ex.text1)
            }
            
            Text(video.name)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.ex.text1)
                .lineLimit(1)
            
            Spacer()
            
            Button(action: {}) {
                Image(systemName: "rectangle.on.rectangle")
                    .font(.system(size: 18))
                    .foregroundColor(Color.ex.text1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - 视频播放器
    private var videoPlayerSection: some View {
        ZStack {
            Color.black
            if let player = viewModel.player {
                VideoPlayer(player: player)
                    .disabled(true)
                    .onTapGesture { viewModel.togglePlayPause() }
            } else {
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
                            currentTime: viewModel.currentTime
                        )
                        .id(index)
                    }
                    
                    // 下方留白
                    Color.clear.frame(height: 60)
                }
                .padding(.horizontal, 16)
            }
            .onChange(of: viewModel.currentSubtitleIndex) { newIndex in
                guard newIndex >= 0 else { return }
                withAnimation(.easeInOut(duration: 0.4)) {
                    proxy.scrollTo(newIndex, anchor: .center)
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
                .frame(width: 40, alignment: .leading)
            
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
                .onTapGesture { location in
                    let ratio = max(0, min(1, location.x / geometry.size.width))
                    viewModel.seek(to: Double(ratio) * viewModel.duration)
                }
            }
            .frame(height: 14)
            
            Text(formatTime(viewModel.duration))
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(Color.ex.text2)
                .frame(width: 40, alignment: .trailing)
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - 功能按钮栏
    private var toolBar: some View {
        HStack {
            HStack(spacing: 0) {
                toolBarButton(icon: "pin", label: "Pin") {}
                toolBarButton(icon: "star.square.on.square", label: "Explain") {}
                toolBarButton(icon: "repeat", label: "Repeat") { viewModel.replay() }
                toolBarButton(icon: "gauge.with.dots.needle.33percent", label: "Speed") {}
                toolBarButton(
                    icon: viewModel.isPlaying ? "pause" : "play.fill",
                    label: viewModel.isPlaying ? "Pause" : "Play"
                ) { viewModel.togglePlayPause() }
            }
            Spacer()
            Button(action: {}) {
                ZStack {
                    Circle().fill(Color.ex.text3.opacity(0.15)).frame(width: 44, height: 44)
                    Image(systemName: "person.2.fill").font(.system(size: 18)).foregroundColor(Color.ex.text2)
                }
            }
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
    
    private let greenDark = Color(red: 0.30, green: 0.45, blue: 0.26)
    private let greenLight = Color(red: 0.78, green: 0.92, blue: 0.58)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let words = subtitle.words {
                // 词级别显示：假名 + 原文 + romaji
                FlowLayout(spacing: 6) {
                    ForEach(Array(words.enumerated()), id: \.offset) { _, word in
                        let isWordActive = isActive && isWordCurrent(word)
                        
                        VStack(spacing: 1) {
                            // 假名（furigana）
                            Text(word.furigana ?? " ")
                                .font(.system(size: 10))
                                .foregroundColor(Color.ex.text3)
                                .lineLimit(1)
                            
                            // 原文（日语词）
                            Text(word.word)
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(isWordActive ? greenDark : Color.ex.text1)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 3)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(isWordActive ? greenDark : Color.clear, lineWidth: 2)
                                )
                            
                            // 罗马音（romaji）
                            Text(word.reading ?? " ")
                                .font(.system(size: 10))
                                .foregroundColor(Color.ex.text2)
                                .lineLimit(1)
                        }
                    }
                }
                
                // 整句中文翻译 - 单独一行，圆角背景
                let sentenceTranslation = words.compactMap { $0.translation }.joined()
                if !sentenceTranslation.isEmpty {
                    Text(sentenceTranslation)
                        .font(.system(size: 14))
                        .foregroundColor(Color.ex.text1)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.ex.text3.opacity(0.08))
                        )
                }
            } else {
                // 没有词级别信息，显示整句
                Text(subtitle.originalText)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isActive ? greenDark : Color.ex.text1)
                
                if !subtitle.translatedText.isEmpty {
                    Text(subtitle.translatedText)
                        .font(.system(size: 14))
                        .foregroundColor(Color.ex.text1)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.ex.text3.opacity(0.08))
                        )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isActive ? greenLight.opacity(0.08) : Color.clear)
        )
        .opacity(isActive ? 1.0 : 0.5)
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }
    
    private func isWordCurrent(_ word: WordTiming) -> Bool {
        let absoluteStart = subtitle.startTime + word.startTime
        let absoluteEnd = subtitle.startTime + word.endTime
        return currentTime >= absoluteStart && currentTime <= absoluteEnd
    }
}

// MARK: - FlowLayout（自动换行布局）
struct FlowLayout: Layout {
    var spacing: CGFloat = 4
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }
    
    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
        }
        
        let totalHeight = currentY + lineHeight
        return (CGSize(width: totalWidth, height: totalHeight), positions)
    }
}

#Preview {
    VideoPlayerView(video: VideoItem(
        name: "IMG_0743.MP4",
        posterImageData: nil,
        videoURL: ""
    ))
}

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
            // 顶部导航栏
            topNavigationBar
            
            // 视频播放器
            videoPlayerSection
            
            // 字幕区域
            subtitleSection
            
            Spacer()
            
            // 底部进度条 + 控制栏
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
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color.ex.text1)
            }
            
            Text(video.name)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.ex.text1)
                .lineLimit(1)
            
            Spacer()
            
            Button(action: {
                // PiP / AirPlay
            }) {
                Image(systemName: "rectangle.on.rectangle")
                    .font(.system(size: 18))
                    .foregroundColor(Color.ex.text1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.ex.bg1)
    }
    
    // MARK: - 视频播放器
    private var videoPlayerSection: some View {
        ZStack {
            Color.black
            
            if let player = viewModel.player {
                VideoPlayer(player: player)
                    .disabled(true) // 禁用默认控件，使用自定义控件
                    .onTapGesture {
                        viewModel.togglePlayPause()
                    }
            } else {
                // 加载中或错误状态
                VStack(spacing: 16) {
                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Text("加载中...")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    } else {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.5))
                        Text("无法加载视频")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
        .aspectRatio(16/9, contentMode: .fit)
        .clipped()
    }
    
    // MARK: - 字幕区域
    private var subtitleSection: some View {
        Group {
            if viewModel.subtitles.isEmpty {
                // 无字幕状态 - 显示 Enable AI Subtitles
                noSubtitleView
            } else if let subtitle = viewModel.currentSubtitle {
                // 有字幕 - 显示当前字幕
                activeSubtitleView(subtitle: subtitle)
            } else {
                // 有字幕数据但当前时间无字幕
                VStack(spacing: 8) {
                    Text(" ")
                        .font(.system(size: 18))
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                }
            }
        }
    }
    
    // MARK: - 无字幕视图
    private var noSubtitleView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Text("No Subtitles?")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(Color.ex.text1)
            
            Button(action: {
                // TODO: 启用 AI 字幕
            }) {
                Text("Enable AI Subtitles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.ex.text1)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.78, green: 0.92, blue: 0.58))
                    )
            }
            
            HStack(spacing: 4) {
                Text("Language Detection")
                    .font(.system(size: 14))
                    .foregroundColor(Color.ex.text2)
                
                Text("Auto")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.ex.text1)
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color.ex.text2)
            }
            
            Spacer()
        }
    }
    
    // MARK: - 有字幕时的显示
    private func activeSubtitleView(subtitle: SubtitleItem) -> some View {
        VStack(spacing: 8) {
            // 翻译字幕
            if let translatedWords = subtitle.translatedWords {
                WordHighlightSubtitleView(
                    words: translatedWords,
                    currentTime: viewModel.currentTime
                )
                .frame(height: 60)
            } else if !subtitle.translatedText.isEmpty {
                Text(subtitle.translatedText)
                    .font(.system(size: 18))
                    .foregroundColor(Color.ex.text1)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
            }
            
            Divider()
                .padding(.horizontal, 20)
            
            // 原文字幕
            if let words = subtitle.words {
                WordHighlightSubtitleView(
                    words: words,
                    currentTime: viewModel.currentTime
                )
                .frame(height: 60)
            } else {
                Text(subtitle.originalText)
                    .font(.system(size: 16))
                    .foregroundColor(Color.ex.text2)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }
            
            // 字幕计数
            Text("字幕 \(viewModel.currentSubtitleIndex + 1)/\(viewModel.subtitles.count)")
                .font(.caption2)
                .foregroundColor(Color.ex.text3)
                .padding(.bottom, 4)
        }
    }
    
    // MARK: - 底部控制栏
    private var bottomControlBar: some View {
        VStack(spacing: 12) {
            // 进度条
            progressBar
            
            // 功能按钮栏
            toolBar
        }
        .padding(.bottom, 8)
        .background(Color.ex.bg1)
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
                    // 背景轨道
                    Capsule()
                        .fill(Color.ex.text3.opacity(0.3))
                        .frame(height: 4)
                    
                    // 已播放进度
                    Capsule()
                        .fill(Color(red: 0.30, green: 0.45, blue: 0.26))
                        .frame(width: progressWidth(in: geometry.size.width), height: 4)
                    
                    // 拖动圆点
                    Circle()
                        .fill(Color(red: 0.30, green: 0.45, blue: 0.26))
                        .frame(width: 14, height: 14)
                        .offset(x: progressWidth(in: geometry.size.width) - 7)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let ratio = max(0, min(1, value.location.x / geometry.size.width))
                                    viewModel.seek(to: Double(ratio) * viewModel.duration)
                                }
                        )
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
                toolBarButton(icon: "pin", label: "Pin") {
                    // Pin 功能
                }
                
                toolBarButton(icon: "star.square.on.square", label: "Explain") {
                    // Explain 功能
                }
                
                toolBarButton(icon: "repeat", label: "Repeat") {
                    viewModel.replay()
                }
                
                toolBarButton(icon: "gauge.with.dots.needle.33percent", label: "Speed") {
                    // Speed 功能
                }
                
                toolBarButton(
                    icon: viewModel.isPlaying ? "pause" : "play.fill",
                    label: viewModel.isPlaying ? "Pause" : "Play"
                ) {
                    viewModel.togglePlayPause()
                }
            }
            
            Spacer()
            
            // 头像按钮
            Button(action: {
                // 用户/角色切换
            }) {
                ZStack {
                    Circle()
                        .fill(Color.ex.text3.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color.ex.text2)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }
    
    // MARK: - 工具栏按钮
    private func toolBarButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .frame(height: 22)
                
                Text(label)
                    .font(.system(size: 10))
            }
            .foregroundColor(Color.ex.text1)
            .frame(width: 56, height: 48)
        }
    }
    
    // MARK: - 计算进度宽度
    private func progressWidth(in totalWidth: CGFloat) -> CGFloat {
        guard viewModel.duration > 0 else { return 0 }
        let ratio = CGFloat(viewModel.currentTime / viewModel.duration)
        return max(0, min(totalWidth, totalWidth * ratio))
    }
    
    // MARK: - 格式化时间
    private func formatTime(_ time: Double) -> String {
        guard !time.isNaN && !time.isInfinite else { return "0:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - 词级别高亮字幕组件
struct WordHighlightSubtitleView: View {
    let words: [WordTiming]
    let currentTime: Double
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                        let isActive = currentTime >= word.startTime && currentTime <= word.endTime
                        
                        Text(word.word)
                            .font(.system(size: 16))
                            .fontWeight(isActive ? .bold : .regular)
                            .foregroundColor(isActive ? Color(red: 0.30, green: 0.45, blue: 0.26) : Color.ex.text1)
                            .padding(.horizontal, 2)
                            .background(
                                isActive ? Color(red: 0.78, green: 0.92, blue: 0.58).opacity(0.3) : Color.clear
                            )
                            .cornerRadius(4)
                            .id(index)
                            .onChange(of: isActive) { newValue in
                                if newValue {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        proxy.scrollTo(index, anchor: .center)
                                    }
                                }
                            }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
        }
    }
}

#Preview {
    VideoPlayerView(video: VideoItem(
        name: "IMG_0743.MP4",
        posterImageData: nil,
        videoURL: ""
    ))
}

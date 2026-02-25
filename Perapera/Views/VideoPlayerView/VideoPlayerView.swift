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
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部导航栏
                topNavigationBar
                
                // 视频播放器
                videoPlayerSection
                
                // 字幕区域
                subtitleSection
                
                // 控制栏
                controlBar
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            viewModel.setupPlayer()
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }
    
    // MARK: - 顶部导航栏
    private var topNavigationBar: some View {
        HStack {
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding()
            }
            
            Text(video.name)
                .font(.headline)
                .foregroundColor(.white)
                .lineLimit(1)
            
            Spacer()
            
            Button(action: {
                // TODO: 更多选项
            }) {
                Image(systemName: "ellipsis")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding()
            }
        }
        .background(Color.black.opacity(0.5))
    }
    
    // MARK: - 视频播放器
    private var videoPlayerSection: some View {
        GeometryReader { geometry in
            ZStack {
                if let player = viewModel.player {
                    VideoPlayer(player: player)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .onTapGesture {
                            viewModel.togglePlayPause()
                        }
                } else {
                    // 加载中或错误状态
                    VStack(spacing: 20) {
                        if viewModel.isLoading {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                            Text("加载中...")
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 50))
                                .foregroundColor(.white)
                            Text("无法加载视频")
                                .foregroundColor(.white)
                        }
                    }
                }
            }
        }
        .aspectRatio(16/9, contentMode: .fit)
    }
    
    // MARK: - 字幕区域
    private var subtitleSection: some View {
        VStack(spacing: 0) {
            // 翻译字幕（上）- 日文
            SubtitleRow(
                text: viewModel.currentSubtitle?.translatedText ?? "",
                isActive: viewModel.currentSubtitle != nil && !viewModel.currentSubtitle!.translatedText.isEmpty,
                language: .japanese,
                placeholder: "日文字幕"
            )
            .frame(height: 60)
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            // 原文字幕（下）- 中文，带词级别高亮
            if let subtitle = viewModel.currentSubtitle, let words = subtitle.words {
                WordHighlightSubtitleView(
                    words: words,
                    currentTime: viewModel.currentTime
                )
                .frame(height: 80)
            } else {
                SubtitleRow(
                    text: viewModel.currentSubtitle?.originalText ?? "",
                    isActive: viewModel.currentSubtitle != nil,
                    language: .original,
                    placeholder: "原文字幕"
                )
                .frame(height: 60)
            }
            
            // 调试信息
            if viewModel.currentSubtitle != nil {
                Text("字幕 \(viewModel.currentSubtitleIndex + 1)/\(viewModel.subtitles.count)")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.vertical, 4)
            }
        }
        .background(Color.black.opacity(0.8))
    }
    
    // MARK: - 控制栏
    private var controlBar: some View {
        VStack(spacing: 10) {
            // 进度条
            HStack(spacing: 10) {
                Text(formatTime(viewModel.currentTime))
                    .font(.caption)
                    .foregroundColor(.white)
                    .frame(width: 50)
                
                Slider(
                    value: Binding(
                        get: { viewModel.currentTime },
                        set: { viewModel.seek(to: $0) }
                    ),
                    in: 0...viewModel.duration
                )
                .tint(.blue)
                
                Text(formatTime(viewModel.duration))
                    .font(.caption)
                    .foregroundColor(.white)
                    .frame(width: 50)
            }
            .padding(.horizontal)
            
            // 播放控制按钮
            HStack(spacing: 40) {
                // 后退 10 秒
                Button(action: {
                    viewModel.skipBackward()
                }) {
                    Image(systemName: "gobackward.10")
                        .font(.title)
                        .foregroundColor(.white)
                }
                
                // 播放/暂停
                Button(action: {
                    viewModel.togglePlayPause()
                }) {
                    Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                }
                
                // 前进 10 秒
                Button(action: {
                    viewModel.skipForward()
                }) {
                    Image(systemName: "goforward.10")
                        .font(.title)
                        .foregroundColor(.white)
                }
                
                // 重新播放
                Button(action: {
                    viewModel.replay()
                }) {
                    Image(systemName: "arrow.counterclockwise.circle")
                        .font(.title)
                        .foregroundColor(.white)
                }
            }
            .padding(.bottom, 20)
        }
        .background(Color.black.opacity(0.5))
    }
    
    // MARK: - 格式化时间
    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - 字幕行组件
struct SubtitleRow: View {
    let text: String
    let isActive: Bool
    let language: SubtitleLanguage
    let placeholder: String
    
    enum SubtitleLanguage {
        case japanese
        case original
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(text.isEmpty ? placeholder : text)
                .font(language == .japanese ? .body : .subheadline)
                .foregroundColor(isActive ? .yellow : .gray)
                .fontWeight(isActive ? .bold : .regular)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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
                            .font(.subheadline)
                            .fontWeight(isActive ? .bold : .regular)
                            .foregroundColor(isActive ? .yellow : .white)
                            .padding(.horizontal, 2)
                            .background(
                                isActive ? Color.yellow.opacity(0.2) : Color.clear
                            )
                            .cornerRadius(4)
                            .id(index)
                            .onChange(of: isActive) { newValue in
                                if newValue {
                                    // 自动滚动到当前高亮的词
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
        name: "测试视频",
        posterImageData: nil,
        videoURL: ""
    ))
}

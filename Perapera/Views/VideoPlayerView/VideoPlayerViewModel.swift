import Foundation
import AVKit
import Combine

class VideoPlayerViewModel: ObservableObject {
    let video: VideoItem
    
    @Published var player: AVPlayer?
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var isPlaying: Bool = false
    @Published var isLoading: Bool = true
    @Published var currentSubtitle: SubtitleItem?
    @Published var currentSubtitleIndex: Int = -1
    @Published var subtitles: [SubtitleItem] = []
    @Published var playbackSpeed: Float = 1.0
    
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    
    init(video: VideoItem) {
        self.video = video
        loadSubtitles()
    }
    
    // MARK: - 设置播放器
    func setupPlayer() {
        let videoURL = video.actualVideoURL
        
        print("🎬 准备加载视频")
        print("📂 视频路径: \(videoURL.path)")
        print("🆔 视频ID: \(video.id)")
        print("📺 是否YouTube: \(video.isYouTube)")
        
        // 如果是本地视频，检查文件是否存在
        if !video.isYouTube {
            if !FileManager.default.fileExists(atPath: videoURL.path) {
                print("❌ 视频文件不存在: \(videoURL.path)")
                isLoading = false
                return
            }
        }
        
        let playerItem = AVPlayerItem(url: videoURL)
        player = AVPlayer(playerItem: playerItem)
        
        // 获取视频时长
        playerItem.asset.loadValuesAsynchronously(forKeys: ["duration"]) { [weak self] in
            DispatchQueue.main.async {
                if let duration = self?.player?.currentItem?.asset.duration {
                    self?.duration = CMTimeGetSeconds(duration)
                }
                self?.isLoading = false
            }
        }
        
        // 添加时间观察器
        addTimeObserver()
        
        // 监听播放状态
        observePlaybackStatus()
        
        print("✅ 播放器设置完成")
    }
    
    // MARK: - 添加时间观察器
    private func addTimeObserver() {
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            
            let currentTime = CMTimeGetSeconds(time)
            self.currentTime = currentTime
            
            // 更新当前字幕
            self.updateCurrentSubtitle(at: currentTime)
        }
    }
    
    // MARK: - 监听播放状态
    private func observePlaybackStatus() {
        player?.publisher(for: \.timeControlStatus)
            .sink { [weak self] status in
                DispatchQueue.main.async {
                    self?.isPlaying = (status == .playing)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 加载字幕
    private func loadSubtitles() {
        // 从 ASR JSON 文件加载（翻译结果已内嵌在 JSON 中）
        if let asrSubtitles = SubtitleManager.shared.loadSubtitlesFromASRFile(videoId: video.id) {
            subtitles = asrSubtitles
            print("✅ 从 ASR 文件加载字幕成功，共 \(subtitles.count) 条")
            return
        }
        
        // 如果 ASR 文件不存在，尝试从 UserDefaults 加载已保存的字幕
        if let subtitleData = SubtitleManager.shared.loadSubtitles(for: video.id) {
            subtitles = subtitleData.subtitles
            print("✅ 从 UserDefaults 加载字幕成功，共 \(subtitles.count) 条")
        } else {
            print("📭 没有找到字幕数据")
            generateDefaultSubtitles()
        }
    }
    
    // MARK: - 生成默认字幕
    private func generateDefaultSubtitles() {
        // TODO: 从 ASR 识别结果生成字幕
        // 这里创建一些示例字幕用于测试
        subtitles = [
            SubtitleItem(startTime: 0, endTime: 5, originalText: "这是第一句话", translatedText: "This is the first sentence"),
            SubtitleItem(startTime: 5, endTime: 10, originalText: "这是第二句话", translatedText: "This is the second sentence"),
            SubtitleItem(startTime: 10, endTime: 15, originalText: "这是第三句话", translatedText: "This is the third sentence"),
        ]
    }
    
    // MARK: - 更新当前字幕
    private func updateCurrentSubtitle(at time: Double) {
        // 查找当前时间对应的字幕
        if let index = subtitles.firstIndex(where: { $0.isActive(at: time) }) {
            let newSubtitle = subtitles[index]
            
            // 只在字幕变化时更新
            if newSubtitle.id != currentSubtitle?.id {
                currentSubtitle = newSubtitle
                currentSubtitleIndex = index
                print("📝 字幕切换: [\(index + 1)/\(subtitles.count)] \(String(format: "%.1f", time))s - \(newSubtitle.originalText.prefix(20))...")
            }
        } else {
            // 没有匹配的字幕
            if currentSubtitle != nil {
                currentSubtitle = nil
                currentSubtitleIndex = -1
            }
        }
    }
    
    // MARK: - 播放/暂停
    func togglePlayPause() {
        guard let player = player else { return }
        
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
    }
    
    // MARK: - 跳转到指定时间
    func seek(to time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    // MARK: - 后退 10 秒
    func skipBackward() {
        let newTime = max(0, currentTime - 10)
        seek(to: newTime)
    }
    
    // MARK: - 前进 10 秒
    func skipForward() {
        let newTime = min(duration, currentTime + 10)
        seek(to: newTime)
    }
    
    // MARK: - 重新播放
    func replay() {
        seek(to: 0)
        player?.play()
    }
    
    // MARK: - 切换播放速度
    func cycleSpeed() {
        let speeds: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
        if let currentIndex = speeds.firstIndex(of: playbackSpeed) {
            let nextIndex = (currentIndex + 1) % speeds.count
            playbackSpeed = speeds[nextIndex]
        } else {
            playbackSpeed = 1.0
        }
        player?.rate = isPlaying ? playbackSpeed : 0
    }
    
    // MARK: - 清理
    func cleanup() {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        
        player?.pause()
        player = nil
        cancellables.removeAll()
        
        print("🧹 播放器已清理")
    }
    
    deinit {
        cleanup()
    }
}

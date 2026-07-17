import Foundation
import AVKit
import Combine

class VideoPlayerViewModel: ObservableObject {
    let video: VideoItem

    // AVPlayer (本地视频)
    @Published var player: AVPlayer?

    // YouTube 播放器
    let youtubeController = YouTubePlayerController()

    // 共享状态
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var isPlaying: Bool = false
    @Published var isLoading: Bool = true
    @Published var currentSubtitle: SubtitleItem?
    @Published var currentSubtitleIndex: Int = -1
    @Published var subtitles: [SubtitleItem] = []
    @Published var playbackSpeed: Float = 1.0
    @Published var isSubtitlePinned: Bool = false

    var playbackSpeedText: String {
        if playbackSpeed.rounded() == playbackSpeed {
            return String(format: "%.0fx", playbackSpeed)
        }
        return String(format: "%.2fx", playbackSpeed)
            .replacingOccurrences(of: "0x", with: "x")
    }

    /// 是否为 YouTube 视频
    var isYouTube: Bool { video.isYouTube }

    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()

    init(video: VideoItem) {
        self.video = video
        loadSubtitles()
    }

    // MARK: - 设置播放器

    func setupPlayer() {
        if video.isYouTube {
            setupYouTubePlayer()
        } else {
            setupAVPlayer()
        }
    }

    private func setupAVPlayer() {
        let videoURL = video.actualVideoURL

        print("🎬 准备加载本地视频")
        print("📂 视频路径: \(videoURL.path)")
        print("🆔 视频ID: \(video.id)")

        // 检查文件是否存在
        if !FileManager.default.fileExists(atPath: videoURL.path) {
            print("❌ 视频文件不存在: \(videoURL.path)")
            isLoading = false
            return
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
        addAVTimeObserver()

        // 监听播放状态
        observeAVPlaybackStatus()

        print("✅ AVPlayer 设置完成")
    }

    private func setupYouTubePlayer() {
        print("🎬 准备加载 YouTube 视频")
        print("🆔 视频ID: \(video.id)")

        // YouTube 播放器由 JS Bridge 报告状态
        // 订阅 YouTube 控制器的状态变化
        youtubeController.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] playing in
                self?.isPlaying = playing
            }
            .store(in: &cancellables)

        youtubeController.$currentTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] time in
                self?.currentTime = time
                self?.updateCurrentSubtitle(at: time)
            }
            .store(in: &cancellables)

        youtubeController.$duration
            .receive(on: DispatchQueue.main)
            .sink { [weak self] dur in
                self?.duration = dur
            }
            .store(in: &cancellables)

        youtubeController.$isReady
            .receive(on: DispatchQueue.main)
            .sink { [weak self] ready in
                if ready {
                    self?.isLoading = false
                }
            }
            .store(in: &cancellables)

        print("✅ YouTube 播放器等待加载")
    }

    // MARK: - AVPlayer 时间观察器

    private func addAVTimeObserver() {
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))

        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.currentTime = CMTimeGetSeconds(time)
            self.updateCurrentSubtitle(at: self.currentTime)
        }
    }

    // MARK: - AVPlayer 播放状态监听

    private func observeAVPlaybackStatus() {
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
        subtitles = [
            SubtitleItem(startTime: 0, endTime: 5, originalText: "这是第一句话", translatedText: "This is the first sentence"),
            SubtitleItem(startTime: 5, endTime: 10, originalText: "这是第二句话", translatedText: "This is the second sentence"),
            SubtitleItem(startTime: 10, endTime: 15, originalText: "这是第三句话", translatedText: "This is the third sentence"),
        ]
    }

    // MARK: - 更新当前字幕

    private func updateCurrentSubtitle(at time: Double) {
        guard let index = subtitles.firstIndex(where: { $0.isActive(at: time) }) else {
            if currentSubtitle != nil {
                currentSubtitle = nil
                currentSubtitleIndex = -1
            }
            return
        }

        let newSubtitle = subtitles[index]
        if newSubtitle.id != currentSubtitle?.id {
            currentSubtitle = newSubtitle
            currentSubtitleIndex = index
            print("📝 字幕切换: [\(index + 1)/\(subtitles.count)] \(String(format: "%.1f", time))s")
        }
    }

    // MARK: - 播放/暂停

    func togglePlayPause() {
        if isYouTube {
            youtubeController.togglePlayPause()
        } else {
            guard let player = player else { return }
            if isPlaying {
                player.pause()
                isPlaying = false
            } else {
                player.play()
                isPlaying = true
            }
        }
    }

    // MARK: - 跳转到指定时间

    func seek(to time: Double) {
        if isYouTube {
            youtubeController.seek(to: time)
        } else {
            let cmTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        }
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
        if isYouTube {
            youtubeController.play()
            youtubeController.setPlaybackRate(Double(playbackSpeed))
        } else {
            player?.rate = playbackSpeed
        }
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

        if isYouTube {
            youtubeController.setPlaybackRate(Double(playbackSpeed))
        } else {
            player?.rate = isPlaying ? playbackSpeed : 0
        }
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
        youtubeController.stopVideo()

        print("🧹 播放器已清理")
    }

    deinit {
        cleanup()
    }
}

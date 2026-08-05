import Foundation
import AVKit
import Combine
import Moya
import RxSwift

class VideoPlayerViewModel: ObservableObject {
    var video: VideoItem

    // 来自首页的 YouTube 原始 URL（用于进入页面后启动流水线）
    let pendingYouTubeURL: String?

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

    // 流水线状态（仅 YouTube 新增 URL 时使用）
    @Published var pipelineStatusMessage: String = ""
    @Published var isProcessingYouTubePipeline: Bool = false
    @Published var hasCompletedYouTubeTranslation: Bool = false
    @Published private var hasResolvedTranslationState: Bool = false

    private let disposeBag = DisposeBag()

    var playbackSpeedText: String {
        if playbackSpeed.rounded() == playbackSpeed {
            return String(format: "%.0fx", playbackSpeed)
        }
        return String(format: "%.2fx", playbackSpeed)
            .replacingOccurrences(of: "0x", with: "x")
    }

    /// 是否为 YouTube 视频
    var isYouTube: Bool { video.isYouTube }

    /// 当前播放页可用于处理的 YouTube URL
    var youtubeSourceURL: String? {
        if let pendingYouTubeURL, !pendingYouTubeURL.isEmpty {
            return pendingYouTubeURL
        }
        guard video.isYouTube, !video.videoURL.isEmpty else { return nil }
        return video.videoURL
    }

    var shouldShowYouTubeProcessButton: Bool {
        youtubeSourceURL != nil && hasResolvedTranslationState && !hasCompletedYouTubeTranslation
    }

    var youtubeProcessButtonTitle: String {
        isProcessingYouTubePipeline ? "video_player_process_in_progress".localized() : "video_player_process_start".localized()
    }

    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    private var hasPreparedPlaybackData = false

    init(video: VideoItem, pendingYouTubeURL: String? = nil) {
        self.video = video
        self.pendingYouTubeURL = pendingYouTubeURL
    }

    /// 替换当前 video（YouTube 流水线获取真实信息后调用）
    func updateVideo(_ newVideo: VideoItem) {
        self.video = newVideo
        hasPreparedPlaybackData = false
        hasResolvedTranslationState = false
        preparePlaybackDataIfNeeded(forceReload: true)
    }

    // MARK: - 设置播放器

    func setupPlayer() {
        preparePlaybackDataIfNeeded()
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

    private func preparePlaybackDataIfNeeded(forceReload: Bool = false) {
        if hasPreparedPlaybackData && !forceReload {
            return
        }
        hasPreparedPlaybackData = true
        hasResolvedTranslationState = false

        let videoId = video.id
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let loadedSubtitles: [SubtitleItem]
            if let asrSubtitles = SubtitleManager.shared.loadSubtitlesFromASRFile(videoId: videoId) {
                loadedSubtitles = asrSubtitles
                print("✅ 从 ASR 文件加载字幕成功，共 \(loadedSubtitles.count) 条")
            } else if let subtitleData = SubtitleManager.shared.loadSubtitles(for: videoId) {
                loadedSubtitles = subtitleData.subtitles
                print("✅ 从 UserDefaults 加载字幕成功，共 \(loadedSubtitles.count) 条")
            } else {
                loadedSubtitles = []
                print("📭 没有找到字幕数据")
            }

            let hasCompletedTranslation = self.areSubtitlesFullyTranslated(loadedSubtitles)

            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.video.id == videoId else { return }
                self.applyLoadedSubtitles(loadedSubtitles, hasCompletedTranslation: hasCompletedTranslation)
            }
        }
    }

    private func applyLoadedSubtitles(_ loadedSubtitles: [SubtitleItem], hasCompletedTranslation: Bool) {
        subtitles = loadedSubtitles
        hasCompletedYouTubeTranslation = hasCompletedTranslation
        hasResolvedTranslationState = true

        if hasCompletedTranslation && !isProcessingYouTubePipeline {
            pipelineStatusMessage = ""
        }

        if !subtitles.isEmpty {
            currentSubtitle = subtitles[0]
            currentSubtitleIndex = 0
        } else {
            generateDefaultSubtitles()
        }
    }

    // MARK: - 生成默认字幕

    private func generateDefaultSubtitles() {
        subtitles = []
        currentSubtitle = nil
        currentSubtitleIndex = -1
    }

    private func areSubtitlesFullyTranslated(_ subtitles: [SubtitleItem]) -> Bool {
        var foundTranslatableWord = false

        for subtitle in subtitles {
            guard let words = subtitle.words, !words.isEmpty else {
                continue
            }

            foundTranslatableWord = true

            let hasMissingAnnotations = words.contains { word in
                let trimmedOriginal = word.word.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedOriginal.isEmpty {
                    return false
                }

                let punctuationOnly = trimmedOriginal.trimmingCharacters(
                    in: CharacterSet.punctuationCharacters
                        .union(.symbols)
                        .union(.whitespacesAndNewlines)
                ).isEmpty
                if punctuationOnly {
                    return false
                }

                let translation = (word.translation ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let reading = (word.reading ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let furigana = (word.furigana ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

                return translation.isEmpty || reading.isEmpty || furigana.isEmpty
            }

            if hasMissingAnnotations {
                return false
            }
        }

        return foundTranslatableWord
    }

    // MARK: - 更新当前字幕

    private func updateCurrentSubtitle(at time: Double) {
        // 找当前时间匹配的字幕
        if let index = subtitles.firstIndex(where: { $0.isActive(at: time) }) {
            let newSubtitle = subtitles[index]
            if newSubtitle.id != currentSubtitle?.id {
                currentSubtitle = newSubtitle
                currentSubtitleIndex = index
                print("📝 字幕切换: [\(index + 1)/\(subtitles.count)] \(String(format: "%.1f", time))s")
            }
            return
        }

        // 没有活跃字幕时，找下一个即将播放的字幕（第一个 endTime > currentTime）
        if let nextIndex = subtitles.firstIndex(where: { $0.endTime > time }) {
            if currentSubtitleIndex != nextIndex {
                currentSubtitle = subtitles[nextIndex]
                currentSubtitleIndex = nextIndex
            }
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
        let targetTime: Double
        if duration > 0 {
            targetTime = max(0, min(duration, time))
        } else {
            targetTime = max(0, time)
        }

        currentTime = targetTime
        updateCurrentSubtitle(at: targetTime)

        if isYouTube {
            youtubeController.currentTime = targetTime
            youtubeController.seek(to: targetTime)
        } else {
            let cmTime = CMTime(seconds: targetTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
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

    // MARK: - YouTube URL 流水线（首页输入 URL → 播放页完成全部流程）

    /// 点击按钮后启动完整流程：重置 → yt_audio → 下载音频 → ASR → 轮询 → 翻译
    func startYouTubePipelineFromButton() {
        guard !isProcessingYouTubePipeline, let url = youtubeSourceURL else { return }
        resetYouTubePipelineState()
        startYouTubePipeline(url: url)
    }

    private func startYouTubePipeline(url: String) {
        DispatchQueue.main.async { [weak self] in
            self?.isProcessingYouTubePipeline = true
            self?.pipelineStatusMessage = "video_player_process_youtube_start_message".localized()
        }

        // 1) 调 yt_audio 拿音频信息 + COS URL
        appApi.rx.request(.ytAudio(url: url))
            .asObservable()
            .mapObject(YTAudioModel.self)
            .subscribe(onNext: { [weak self] model in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.handleYoutubeAudioResult(model: model, originalURL: url)
                }
            }, onError: { [weak self] error in
                DispatchQueue.main.async {
                    self?.isProcessingYouTubePipeline = false
                    self?.pipelineStatusMessage = "yt_audio 失败：\(error.localizedDescription)"
                    print("❌ YouTube 流水线失败: \(error.localizedDescription)")
                }
            })
            .disposed(by: disposeBag)
    }

    private func handleYoutubeAudioResult(model: YTAudioModel, originalURL: String) {
        guard model.status == "ok" else {
            isProcessingYouTubePipeline = false
            pipelineStatusMessage = "yt_audio 返回 status != ok"
            print("❌ YouTube 流水线 status: \(model.status)")
            return
        }

        let videoName = model.title.isEmpty ? Self.fallbackYoutubeTitle(from: originalURL) : model.title
        pipelineStatusMessage = "已获取音频信息：\(videoName)"

        // 2) 下载音频到本地
        if let audioRemoteURL = URL(string: model.url) {
            pipelineStatusMessage = "开始下载音频…"
            downloadYoutubeAudio(from: audioRemoteURL, videoId: video.id)
        } else {
            isProcessingYouTubePipeline = false
            print("❌ YouTube 音频 URL 无效，无法下载")
            pipelineStatusMessage = "音频 URL 无效，无法下载"
            return
        }

        print("✅ 已拿到 YouTube 音频信息: \(videoName), COS音频URL: \(model.url)")
        pipelineStatusMessage = "正在启动 ASR 识别…"

        // 3) 启动 ASR
        startASRRecognition(cosAudioURL: model.url, videoId: video.id)
    }

    /// 复用首页的下音频逻辑
    private func downloadYoutubeAudio(from remoteURL: URL, videoId: String) {
        let destinationURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("\(videoId).opus")
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            print("📁 音频文件已存在: \(destinationURL.path)")
            DispatchQueue.main.async {
                self.pipelineStatusMessage = "音频已准备完成，继续识别…"
            }
            return
        }
        let task = URLSession.shared.downloadTask(with: remoteURL) { localURL, response, error in
            if let error = error {
                print("❌ 下载音频失败: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.pipelineStatusMessage = "下载音频失败：\(error.localizedDescription)"
                }
                return
            }
            guard let localURL = localURL else { return }
            do {
                try FileManager.default.moveItem(at: localURL, to: destinationURL)
                print("✅ 音频下载成功: \(destinationURL.path)")
                DispatchQueue.main.async {
                    self.pipelineStatusMessage = "音频下载完成，等待识别结果…"
                }
            } catch {
                print("❌ 移动音频文件失败: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.pipelineStatusMessage = "保存音频失败：\(error.localizedDescription)"
                }
            }
        }
        task.resume()
    }

    // MARK: - 抽取的 ASR 流程（与首页等价）

    private func startASRRecognition(cosAudioURL: String, videoId: String) {
        print("🎤 开始 ASR 识别 - videoId: \(videoId), cosURL: \(cosAudioURL)")
        let asrService = ASRManagerFactory.shared.getService()
        asrService.createRecognitionTask(audioURL: cosAudioURL) { [weak self] result in
            switch result {
            case .success(let taskId):
                print("✅ ASR 任务创建成功，TaskId: \(taskId)")
                DispatchQueue.main.async {
                    self?.pipelineStatusMessage = "ASR 任务已创建，开始轮询结果…"
                }
                self?.pollRecognitionResult(taskId: taskId, videoId: videoId)
            case .failure(let error):
                print("❌ 创建 ASR 任务失败: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.isProcessingYouTubePipeline = false
                    self?.pipelineStatusMessage = "ASR 创建失败：\(error.localizedDescription)"
                }
            }
        }
    }

    private func pollRecognitionResult(taskId: Int, videoId: String, retryCount: Int = 0) {
        let maxRetries = 60

        guard retryCount < maxRetries else {
            print("❌ 语音识别超时")
            DispatchQueue.main.async {
                self.pipelineStatusMessage = "语音识别超时"
                self.isProcessingYouTubePipeline = false
            }
            return
        }

        let asrService = ASRManagerFactory.shared.getService()
        asrService.queryRecognitionResult(taskId: taskId) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let taskResult):
                    print("📊 识别状态: \(taskResult.statusStr)")

                    switch taskResult.status {
                    case 2: // 成功
                        if let recognizedText = taskResult.result {
                            print("✅ 识别成功，长度: \(recognizedText.count)")
                            self?.saveRawRecognitionJSON(
                                videoId: videoId,
                                rawJSON: taskResult.rawJSON,
                                recognizedText: recognizedText
                            )
                        } else {
                            print("⚠️ 识别成功但结果为空")
                            self?.pipelineStatusMessage = "识别成功但无结果"
                            self?.isProcessingYouTubePipeline = false
                        }

                    case 3: // 失败
                        print("❌ 识别失败: \(taskResult.errorMsg ?? "未知错误")")
                        self?.pipelineStatusMessage = "识别失败：\(taskResult.errorMsg ?? "未知错误")"
                        self?.isProcessingYouTubePipeline = false

                    case 0, 1: // 等待 / 执行中
                        self?.pipelineStatusMessage = "语音识别中…"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                            self?.pollRecognitionResult(
                                taskId: taskId,
                                videoId: videoId,
                                retryCount: retryCount + 1
                            )
                        }

                    default:
                        print("⚠️ 未知状态: \(taskResult.status)")
                        self?.pipelineStatusMessage = "识别状态未知：\(taskResult.status)"
                        self?.isProcessingYouTubePipeline = false
                    }

                case .failure(let error):
                    print("❌ 查询识别结果失败: \(error.localizedDescription)")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        self?.pollRecognitionResult(
                            taskId: taskId,
                            videoId: videoId,
                            retryCount: retryCount + 1
                        )
                    }
                }
            }
        }
    }

    private func saveRawRecognitionJSON(videoId: String, rawJSON: Data, recognizedText: String) {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsDirectory.appendingPathComponent("\(videoId).json")

        do {
            try rawJSON.write(to: fileURL)
            print("💾 ASR JSON 已保存：\(fileURL.path)")
            DispatchQueue.main.async {
                self.pipelineStatusMessage = "识别成功，开始翻译…"
            }
            // 自动触发翻译
            self.translateRecognitionResult(videoId: videoId, recognizedText: recognizedText)
        } catch {
            print("❌ 保存原始 JSON 失败: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.pipelineStatusMessage = "保存识别结果失败：\(error.localizedDescription)"
                self.isProcessingYouTubePipeline = false
            }
        }
    }

    // MARK: - 翻译流程（与首页等价）

    private func translateRecognitionResult(videoId: String, recognizedText: String) {
        print("🌐 开始翻译 - videoId: \(videoId), text length=\(recognizedText.count)")

        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let jsonFileURL = documentsDirectory.appendingPathComponent("\(videoId).json")

        guard let jsonData = try? Data(contentsOf: jsonFileURL) else {
            print("❌ 无法读取 JSON 文件")
            DispatchQueue.main.async {
                self.pipelineStatusMessage = "无法读取识别 JSON"
                self.isProcessingYouTubePipeline = false
            }
            return
        }

        TencentMTManager.shared.translateASRJSON(jsonData: jsonData, progress: { _, _, _ in
        }) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let enrichedData):
                    do {
                        try enrichedData.write(to: jsonFileURL)
                        print("✅ 翻译结果已写回 JSON 文件: \(jsonFileURL.path)")
                        self?.hasCompletedYouTubeTranslation = true
                        self?.isProcessingYouTubePipeline = false
                        self?.pipelineStatusMessage = ""
                        self?.hasPreparedPlaybackData = false
                        self?.preparePlaybackDataIfNeeded(forceReload: true)
                    } catch {
                        print("❌ 写回 JSON 文件失败: \(error.localizedDescription)")
                        self?.pipelineStatusMessage = "写回 JSON 失败：\(error.localizedDescription)"
                        self?.isProcessingYouTubePipeline = false
                    }

                case .failure(let error):
                    print("❌ 翻译失败: \(error.localizedDescription)")
                    self?.pipelineStatusMessage = "翻译失败：\(error.localizedDescription)"
                    self?.isProcessingYouTubePipeline = false
                }
            }
        }
    }

    private func resetYouTubePipelineState() {
        let fileManager = FileManager.default
        [video.audioURL, video.recognitionURL, video.translationURL].forEach { url in
            guard fileManager.fileExists(atPath: url.path) else { return }
            do {
                try fileManager.removeItem(at: url)
                print("🧹 已删除旧文件: \(url.lastPathComponent)")
            } catch {
                print("❌ 删除旧文件失败: \(url.lastPathComponent), \(error.localizedDescription)")
            }
        }

        subtitles = []
        currentSubtitle = nil
        currentSubtitleIndex = -1
        hasCompletedYouTubeTranslation = false
        hasResolvedTranslationState = true
        pipelineStatusMessage = "video_player_process_reset_message".localized()
    }

    // MARK: - 工具

    static func extractYoutubeVideoId(from urlString: String) -> String? {
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

    static func fallbackYoutubeTitle(from urlString: String) -> String {
        if let id = extractYoutubeVideoId(from: urlString) {
            return "YouTube - \(id)"
        }
        return "YouTube"
    }
}

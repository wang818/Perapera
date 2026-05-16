import SwiftUI
import WebKit

// MARK: - YouTube 播放器控制器

/// 管理与 YouTube iframe 播放器的双向通信
class YouTubePlayerController: NSObject, ObservableObject {
    @Published var isReady = false
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var errorMessage: String?

    weak var webView: WKWebView?

    // MARK: - 控制方法

    func play() {
        webView?.evaluateJavaScript("if(window.player && window.player.playVideo) player.playVideo();") { _, error in
            if let error = error {
                print("❌ YouTube play error: \(error.localizedDescription)")
            }
        }
    }

    func pause() {
        webView?.evaluateJavaScript("if(window.player && window.player.pauseVideo) player.pauseVideo();") { _, error in
            if let error = error {
                print("❌ YouTube pause error: \(error.localizedDescription)")
            }
        }
    }

    func togglePlayPause() {
        if isPlaying { pause() } else { play() }
    }

    func seek(to seconds: Double) {
        webView?.evaluateJavaScript("if(window.player && window.player.seekTo) player.seekTo(\(seconds), true);") { _, error in
            if let error = error {
                print("❌ YouTube seek error: \(error.localizedDescription)")
            }
        }
    }

    func stopVideo() {
        webView?.evaluateJavaScript("if(window.player && window.player.stopVideo) player.stopVideo();") { _, error in
            if let error = error {
                print("❌ YouTube stop error: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - YouTubePlayerView (SwiftUI)

struct YouTubePlayerView: UIViewRepresentable {
    let videoID: String
    let controller: YouTubePlayerController

    /// 使用 bundle identifier 作为 origin URL（与官方 youtube-ios-player-helper 相同的策略）
    /// YouTube 接受任何 http(s):// origin，关键是要保持一致
    private var originURL: URL {
        let bundleId = (Bundle.main.bundleIdentifier ?? "com.app.youtubeplayer").lowercased()
        return URL(string: "http://\(bundleId)")!
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller, originURL: originURL)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsAirPlayForMediaPlayback = true

        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        config.defaultWebpagePreferences = preferences

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.backgroundColor = .black
        webView.isOpaque = true
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        // 使用 bundle identifier 作为 baseURL，与官方 YT helper 库相同
        let html = Self.buildHTML(videoID: videoID, originURL: originURL.absoluteString)
        webView.loadHTMLString(html, baseURL: originURL)

        context.coordinator.webView = webView
        controller.webView = webView

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    // MARK: - HTML 模板（基于官方 YTPlayerView-iframe-player.html）

    private static func buildHTML(videoID: String, originURL: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, minimum-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <style>
            body { margin: 0; width: 100%; height: 100%; background-color: #000000; }
            html { width: 100%; height: 100%; background-color: #000000; }
            .embed-container iframe,
            .embed-container object,
            .embed-container embed {
                position: absolute;
                top: 0;
                left: 0;
                width: 100% !important;
                height: 100% !important;
            }
            #player { width: 100%; height: 100%; }
        </style>
        </head>
        <body>
        <div class="embed-container">
            <div id="player"></div>
        </div>
        <script src="https://www.youtube.com/iframe_api"
                onerror="window.location.href='ytplayer://onYouTubeIframeAPIFailedToLoad'"></script>
        <script>
        var player;
        var hadError = false;

        function onYouTubeIframeAPIReady() {
            player = new YT.Player('player', {
                width: '100%',
                height: '100%',
                videoId: '\(videoID)',
                playerVars: {
                    'playsinline': 1,
                    'controls': 1,
                    'rel': 0,
                    'modestbranding': 1,
                    'iv_load_policy': 3,
                    'fs': 1,
                    'enablejsapi': 1,
                    'origin': '\(originURL)'
                },
                events: {
                    'onReady': onPlayerReady,
                    'onStateChange': onPlayerStateChange,
                    'onError': onPlayerError
                }
            });
        }

        function onPlayerReady(event) {
            try {
                var dur = player.getDuration();
                if (dur && isFinite(dur) && dur > 0) {
                    window.location.href = 'ytplayer://onDurationUpdate?data=' + dur;
                }
            } catch (e) {}
            window.location.href = 'ytplayer://onReady?data=ready';

            // 周期性更新进度
            setInterval(function() {
                if (!player || !player.getCurrentTime) return;
                try {
                    var state = player.getPlayerState();
                    if (state === YT.PlayerState.PLAYING) {
                        var t = player.getCurrentTime();
                        window.location.href = 'ytplayer://onTimeUpdate?data=' + t;
                    }
                } catch (e) {}
            }, 250);
        }

        function onPlayerStateChange(event) {
            if (hadError) {
                hadError = false;
                return;
            }
            window.location.href = 'ytplayer://onStateChange?data=' + event.data;

            if (event.data === YT.PlayerState.PLAYING) {
                try {
                    var dur = player.getDuration();
                    if (dur && isFinite(dur) && dur > 0) {
                        window.location.href = 'ytplayer://onDurationUpdate?data=' + dur;
                    }
                } catch (e) {}
            }
        }

        function onPlayerError(event) {
            if (event.data === 100 || event.data === 101 || event.data === 150) {
                hadError = true;
            }
            window.location.href = 'ytplayer://onError?data=' + event.data;
        }
        </script>
        </body>
        </html>
        """
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let controller: YouTubePlayerController
        let originURL: URL
        weak var webView: WKWebView?

        init(controller: YouTubePlayerController, originURL: URL) {
            self.controller = controller
            self.originURL = originURL
        }

        // MARK: - WKNavigationDelegate

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            // 拦截 ytplayer:// 自定义 scheme，作为 JS -> Swift 通信
            if url.scheme == "ytplayer" {
                handleCallbackURL(url)
                decisionHandler(.cancel)
                return
            }

            // 允许 about: 等内置 scheme
            if url.scheme == "about" || url.scheme == "blob" || url.scheme == "data" {
                decisionHandler(.allow)
                return
            }

            // http(s) 处理
            if url.scheme == "http" || url.scheme == "https" {
                if handleHTTPNavigation(to: url) {
                    decisionHandler(.allow)
                } else {
                    // 在外部浏览器打开，比如用户点击 "Watch on YouTube" 链接
                    decisionHandler(.cancel)
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
                return
            }

            decisionHandler(.allow)
        }

        /// 判断 http(s) URL 是否应该在 WebView 内加载
        private func handleHTTPNavigation(to url: URL) -> Bool {
            // 允许加载我们的 originURL（loadHTMLString 时 WebView 会请求它）
            if url.host?.lowercased() == originURL.host?.lowercased() {
                return true
            }

            let absoluteString = url.absoluteString

            // YouTube embed URL
            if absoluteString.range(of: "^https?://(www\\.)?youtube(-nocookie)?\\.com/embed/.*",
                                    options: .regularExpression) != nil {
                return true
            }

            // YouTube 内部资源
            if let host = url.host {
                let allowedHosts = ["youtube.com", "www.youtube.com",
                                    "youtube-nocookie.com", "www.youtube-nocookie.com",
                                    "ytimg.com", "i.ytimg.com", "s.ytimg.com",
                                    "googlevideo.com", "googleads.g.doubleclick.net",
                                    "pubads.g.doubleclick.net",
                                    "content.googleapis.com",
                                    "tpc.googlesyndication.com",
                                    "static.doubleclick.net",
                                    "google.com", "accounts.google.com",
                                    "play.google.com",
                                    "fonts.googleapis.com", "fonts.gstatic.com",
                                    "gstatic.com", "www.gstatic.com"]
                for allowed in allowedHosts {
                    if host == allowed || host.hasSuffix("." + allowed) {
                        return true
                    }
                }
            }

            // 其它链接（比如点击视频标题跳到 youtube.com/watch）— 阻止内嵌，外部打开
            return false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("❌ YouTube navigation failed: \(error.localizedDescription)")
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            let nsError = error as NSError
            // -999 (cancelled) 是正常的，比如我们 cancel 了 ytplayer:// 导航
            if nsError.code != NSURLErrorCancelled {
                print("❌ YouTube provisional navigation failed: \(error.localizedDescription)")
            }
        }

        // MARK: - WKUIDelegate

        // 处理 JS 中的 window.open 等
        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = navigationAction.request.url {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
            return nil
        }

        // MARK: - JS 回调处理

        /// 处理 ytplayer://action?data=value 形式的回调
        private func handleCallbackURL(_ url: URL) {
            let action = url.host ?? ""
            // 解析 query 参数 data=...
            let data: String? = {
                guard let query = url.query else { return nil }
                let parts = query.components(separatedBy: "=")
                guard parts.count >= 2 else { return nil }
                let raw = parts[1...].joined(separator: "=")
                return raw.removingPercentEncoding ?? raw
            }()

            switch action {
            case "onReady":
                DispatchQueue.main.async {
                    self.controller.isReady = true
                    print("✅ YouTube IFrame player ready")
                }

            case "onStateChange":
                guard let raw = data, let code = Int(raw) else { return }
                DispatchQueue.main.async {
                    let wasPlaying = self.controller.isPlaying
                    switch code {
                    case YTPlayerState.playing.rawValue:
                        self.controller.isPlaying = true
                    case YTPlayerState.paused.rawValue,
                         YTPlayerState.ended.rawValue,
                         YTPlayerState.unstarted.rawValue,
                         YTPlayerState.cued.rawValue:
                        self.controller.isPlaying = false
                    default:
                        break
                    }
                    if wasPlaying != self.controller.isPlaying {
                        print("🎬 YouTube state: \(YTPlayerState.name(for: code))")
                    }
                }

            case "onTimeUpdate":
                guard let raw = data, let time = Double(raw), time.isFinite else { return }
                DispatchQueue.main.async {
                    self.controller.currentTime = time
                }

            case "onDurationUpdate":
                guard let raw = data, let dur = Double(raw), dur.isFinite, dur > 0 else { return }
                DispatchQueue.main.async {
                    self.controller.duration = dur
                }

            case "onError":
                guard let raw = data else { return }
                let desc = YTPlayerError.description(for: raw)
                print("❌ YouTube error \(raw): \(desc)")
                DispatchQueue.main.async {
                    self.controller.errorMessage = desc
                }

            case "onYouTubeIframeAPIFailedToLoad":
                print("❌ YouTube IFrame API failed to load")
                DispatchQueue.main.async {
                    self.controller.errorMessage = "Failed to load YouTube player"
                }

            default:
                break
            }
        }
    }
}

// MARK: - YouTube 状态/错误常量

private enum YTPlayerState: Int {
    case unstarted = -1
    case ended = 0
    case playing = 1
    case paused = 2
    case buffering = 3
    case cued = 5

    static func name(for code: Int) -> String {
        switch code {
        case -1: return "unstarted"
        case 0:  return "ended"
        case 1:  return "playing"
        case 2:  return "paused"
        case 3:  return "buffering"
        case 5:  return "cued"
        default: return "unknown(\(code))"
        }
    }
}

private enum YTPlayerError {
    static func description(for code: String) -> String {
        switch Int(code) {
        case 2:   return "Invalid parameter"
        case 5:   return "HTML5 player error"
        case 100: return "Video not found"
        case 101: return "Embedding not allowed"
        case 150: return "Embedding not allowed"
        default:  return "Unknown error (\(code))"
        }
    }
}

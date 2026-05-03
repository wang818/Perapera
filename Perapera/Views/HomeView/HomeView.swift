import SwiftUI
import UniformTypeIdentifiers
import PhotosUI
import Photos
import AVFoundation

struct Movie: Transferable {
    let url: URL
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let fileName = received.file.lastPathComponent
            let copy = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            
            if FileManager.default.fileExists(atPath: copy.path) {
                try FileManager.default.removeItem(at: copy)
            }
            
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Self.init(url: copy)
        }
    }
}

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var videos: [VideoItem] = []
    @State private var refreshID = UUID() // 用于强制刷新视图
    @State private var showingSheet = false
    @State private var showingYoutubeAlert = false
    @State private var showingFileImporter = false
    @State private var showingPhotoPicker = false
    @State private var selectedVideoItem: PhotosPickerItem?
    @State private var youtubeUrl = ""
    @State private var uploadProgress: Double = 0.0
    @State private var isUploading: Bool = false
    @State private var asrTaskId: Int?
    @State private var recognitionText: String = ""
    @State private var isRecognizing: Bool = false
    @State private var isConverting: Bool = false
    @State private var conversionProgress: Double = 0.0
    @State private var currentConvertingVideoId: String?
    @State private var currentRecognizingVideoId: String?
    @State private var currentTranslatingVideoId: String?

    var body: some View {
        ZStack {
            NavigationStack {
                Group {
                    if videos.isEmpty {
                        // 空状态
                        VStack(spacing: 20) {
                            Image(systemName: "video.slash")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            Text("暂无视频")
                                .font(.headline)
                                .foregroundColor(.gray)
                            Text("点击右上角 + 添加视频")
                                .font(.subheadline)
                                .foregroundColor(.gray.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // 视频列表
                        List {
                            ForEach(videos) { video in
                                VideoRowView(
                                    video: video,
                                    onDelete: {
                                        deleteVideo(video)
                                    },
                                    onConvertAudio: {
                                        convertAudioForVideo(video)
                                    },
                                    onStartRecognition: {
                                        startRecognitionForVideo(video)
                                    },
                                    onStartTranslation: {
                                        startTranslationForVideo(video)
                                    }
                                )
                                .background(
                                    NavigationLink(destination: VideoPlayerView(video: video)) {
                                        EmptyView()
                                    }
                                    .opacity(0)
                                )
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
                                .id("\(video.id)-\(refreshID)") // 强制刷新视图
                            }
                            .onDelete(perform: deleteVideos)
                        }
                        .scrollContentBackground(.hidden)
                    }
                }
                .navigationTitle("home_navigationTitle".localized())
                .onAppear {
                    loadVideos()
                    
                    // 检查并更新旧视频的时长
                    DispatchQueue.global(qos: .background).async {
                        VideoStorageManager.shared.refreshVideoDurations()
                        DispatchQueue.main.async {
                            loadVideos() // 重新加载以显示时长
                        }
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showingSheet = true
                        }) {
                            Image(systemName: "plus")
                                .foregroundStyle(.black)
                        }
                    }
                }
                .sheet(isPresented: $showingSheet) {
                    VStack(alignment: .leading) {
                        Text("home_sheet_title".localized())
                            .foregroundColor(.ex.text1)
                            .font(.headline)
                            .padding(.top, 40)
                            .padding(.leading, 25)
                        Text("home_sheet_subtitle".localized())
                            .foregroundColor(.ex.text1)
                            .font(.subheadline)
                            .padding(.leading, 25)
                            .padding(.bottom, 20)
                        
                        // 3 Views
                        VStack(spacing: 20) {
                            Button(action: {
                                print("Item 1 tapped")
                                showingSheet = false
                                // Delay slightly to show custom alert smoothly after sheet dismiss
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    showingYoutubeAlert = true
                                }
                            }) {
                                HStack(spacing: 15) {
                                    Image(systemName: "photo")
                                        .resizable()
                                        .frame(width: 25, height: 25)
                                        .foregroundColor(.blue)
                                    VStack(alignment: .leading) {
                                        Text("home_sheet_list_title1".localized())
                                            .font(.headline)
                                            .foregroundColor(.ex.text1)
                                        Text("home_sheet_list_subtitle1".localized())
                                            .font(.subheadline)
                                            .foregroundColor(.ex.text2)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 10)
                                .background(Color.ex("bg2"))
                                .cornerRadius(10)
                            }
                            .padding(.horizontal, 25)
                            
                            Button(action: {
                                print("Item 2 tapped")
                                showingSheet = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    showingFileImporter = true
                                }
                            }) {
                                HStack(spacing: 15) {
                                    Image(systemName: "mic")
                                        .resizable()
                                        .frame(width: 25, height: 25)
                                        .foregroundColor(.green)
                                    VStack(alignment: .leading) {
                                        Text("home_sheet_list_title2".localized())
                                            .font(.headline)
                                            .foregroundColor(.ex.text1)
                                        Text("home_sheet_list_subtitle2".localized())
                                            .font(.subheadline)
                                            .foregroundColor(.ex.text2)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 10)
                                .background(Color.ex("bg2"))
                                .cornerRadius(10)
                            }
                            .padding(.horizontal, 25)
                            
                            Button(action: {
                                print("Network Test tapped")
                                showingSheet = false
                                //viewModel.getZendeskNotice()
                            }) {
                                HStack(spacing: 15) {
                                    Image(systemName: "network")
                                        .resizable()
                                        .frame(width: 25, height: 25)
                                        .foregroundColor(.purple)
                                    VStack(alignment: .leading) {
                                        Text("Network Test")
                                            .font(.headline)
                                            .foregroundColor(.ex.text1)
                                        Text("Check API connection")
                                            .font(.subheadline)
                                            .foregroundColor(.ex.text2)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 10)
                                .background(Color.ex("bg2"))
                                .cornerRadius(10)
                            }
                            .padding(.horizontal, 25)
                            
                            Button(action: {
                                print("Item 3 tapped")
                                showingSheet = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    showingPhotoPicker = true
                                }
                            }) {
                                HStack(spacing: 15) {
                                    Image(systemName: "doc")
                                        .resizable()
                                        .frame(width: 25, height: 25)
                                        .foregroundColor(.orange)
                                    VStack(alignment: .leading) {
                                        Text("home_sheet_list_title3".localized())
                                            .font(.headline)
                                            .foregroundColor(.ex.text1)
                                        Text("home_sheet_list_subtitle3".localized())
                                            .font(.subheadline)
                                            .foregroundColor(.ex.text2)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 10)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(10)
                            }
                            .padding(.horizontal, 25)
                        }
                    }
                    .padding(.bottom, 30)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .presentationDetents([.height(420)])
                    .presentationDragIndicator(.visible)
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
                            loadVideos()
                            currentConvertingVideoId = newVideo.id
                            
                            // 开始转换视频为音频
                            convertVideoToAudio(videoURL: newVideo.localVideoURL, videoId: newVideo.id)
                        }
                        
                    case .failure(let error):
                        print("File selection error: \(error.localizedDescription)")
                    }
                }
                .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedVideoItem, matching: .videos)
                .onChange(of: selectedVideoItem) { newItem in
                    if let newItem = newItem {
                        Task {
                            do {
                                // 尝试从 PHAsset 获取原始文件名
                                var originalName: String?
                                if let assetId = newItem.itemIdentifier {
                                    let result = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
                                    if let asset = result.firstObject {
                                        let resources = PHAssetResource.assetResources(for: asset)
                                        if let resource = resources.first {
                                            originalName = (resource.originalFilename as NSString).deletingPathExtension
                                        }
                                    }
                                }
                                
                                // 尝试加载视频文件
                                if let movie = try? await newItem.loadTransferable(type: Movie.self) {
                                    // 优先使用原始文件名，否则使用文件路径中的文件名
                                    let videoName = originalName ?? movie.url.deletingPathExtension().lastPathComponent
                                    let sourceURL = movie.url
                                    
                                    // 生成缩略图
                                    let thumbnail = generateVideoThumbnail(url: sourceURL)
                                    
                                    // 保存到 Documents 目录
                                    let newVideo = VideoStorageManager.shared.addLocalVideo(
                                        name: videoName,
                                        posterImage: thumbnail,
                                        sourceURL: sourceURL
                                    )
                                    
                                    // 删除临时文件
                                    try? FileManager.default.removeItem(at: sourceURL)
                                    
                                    await MainActor.run {
                                        loadVideos()
                                        
                                        if let newVideo = newVideo {
                                            currentConvertingVideoId = newVideo.id
                                            
                                            // 开始转换视频为音频
                                            convertVideoToAudio(videoURL: newVideo.localVideoURL, videoId: newVideo.id)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            if isUploading {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    ProgressView(value: uploadProgress)
                        .progressViewStyle(.linear)
                        .tint(.blue)
                    
                    Text("上传中... \(Int(uploadProgress * 100))%")
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
                    
                    Text("转换音频中... \(Int(conversionProgress * 100))%")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("正在将视频转换为 Opus 格式")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(40)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 10)
                .padding(.horizontal, 40)
            }
            
            if isRecognizing {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(1.5)
                    
                    Text("语音识别中...")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if let taskId = asrTaskId {
                        Text("任务ID: \(taskId)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(40)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 10)
                .padding(.horizontal, 40)
            }
            
            if viewModel.isTranslating {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(1.5)
                    
                    Text("正在翻译...")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("使用混元大模型翻译中")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(40)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 10)
                .padding(.horizontal, 40)
            }
            
            if !recognitionText.isEmpty && !isRecognizing {
                VStack {
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("识别结果")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Button(action: {
                                recognitionText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        ScrollView {
                            Text(recognitionText)
                                .font(.body)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 200)
                        
                        Button(action: {
                            UIPasteboard.general.string = recognitionText
                        }) {
                            HStack {
                                Image(systemName: "doc.on.doc")
                                Text("复制文本")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }
                    .padding(20)
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 10)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            
            if !viewModel.translationResult.isEmpty && !viewModel.isTranslating {
                VStack {
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("翻译结果")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Button(action: {
                                viewModel.translationResult = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        ScrollView {
                            Text(viewModel.translationResult)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 300)
                        
                        Button(action: {
                            UIPasteboard.general.string = viewModel.translationResult
                        }) {
                            HStack {
                                Image(systemName: "doc.on.doc")
                                Text("复制结果")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }
                    .padding(20)
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 10)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
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
                    
                    HStack(spacing: 20) {
                        Button(action: {
                            showingYoutubeAlert = false
                        }) {
                            Text("关闭")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                                .foregroundColor(.primary)
                        }
                        
                        Button(action: {
                            // 保存 YouTube 视频
                            if !youtubeUrl.isEmpty {
                                saveYoutubeVideo(url: youtubeUrl)
                                youtubeUrl = ""
                            }
                            showingYoutubeAlert = false
                        }) {
                            Text("保存")
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
        }
    }
    
    // MARK: - Helper Methods
    
    /// 加载视频列表
    private func loadVideos() {
        videos = VideoStorageManager.shared.loadVideos()
        refreshID = UUID() // 触发视图刷新
        printVideosInfo()
    }
    
    /// 输出 videos 变量信息到控制台
    private func printVideosInfo() {
        print("\n" + String(repeating: "=", count: 70))
        print("📹 当前视频列表 (共 \(videos.count) 个)")
        print(String(repeating: "=", count: 70))
        
        if videos.isEmpty {
            print("📭 列表为空")
        } else {
            for (index, video) in videos.enumerated() {
                print("\n[\(index + 1)] 视频信息:")
                print("  🆔 ID: \(video.id)")
                print("  📝 名称: \(video.name)")
                print("  🎬 视频路径: \(video.videoURL)")
                
                print("  🕐 创建时间: \(formatDateForConsole(video.createdAt))")
                
                if let posterImage = video.posterImage {
                    let size = posterImage.size
                    print("  🖼️  海报图: 有 (\(Int(size.width))x\(Int(size.height)))")
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
                print("  📊 文件状态:")
                print("    🎵 音频文件: \(video.hasAudio ? "✅ 已转换" : "❌ 未转换") - \(video.audioURL.path)")
                print("    📝 识别结果: \(video.hasRecognition ? "✅ 已识别" : "❌ 未识别") - \(video.recognitionURL.path)")
                print("    🌐 翻译结果: \(video.hasTranslation ? "✅ 已翻译" : "❌ 未翻译") - \(video.translationURL.path)")
                
                print("  " + String(repeating: "-", count: 66))
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
        print("🎵 开始转换音频: \(video.name)")
        currentConvertingVideoId = video.id
        convertVideoToAudio(videoURL: video.actualVideoURL, videoId: video.id)
    }
    
    /// 开始识别
    private func startRecognitionForVideo(_ video: VideoItem) {
        guard video.hasAudio else {
            print("❌ 音频文件不存在，无法识别")
            return
        }
        
        print("🎤 开始语音识别: \(video.name)")
        currentRecognizingVideoId = video.id
        
        // 上传音频到 COS
        COSUploadManager.shared.uploadFile(fileURL: video.audioURL) { result in
            switch result {
            case .success(let cosURL):
                print("✅ 音频上传成功: \(cosURL)")
                
                // 开始语音识别
                isRecognizing = true
                ASRManager.shared.createRecognitionTask(audioURL: cosURL) { result in
                    switch result {
                    case .success(let taskId):
                        print("✅ 识别任务创建成功，TaskId: \(taskId)")
                        
                        // 开始轮询查询识别结果
                        pollRecognitionResult(taskId: taskId, videoId: video.id)
                        
                    case .failure(let error):
                        print("❌ 创建识别任务失败: \(error.localizedDescription)")
                        isRecognizing = false
                        currentRecognizingVideoId = nil
                    }
                }
                
            case .failure(let error):
                print("❌ 音频上传失败: \(error.localizedDescription)")
                currentRecognizingVideoId = nil
            }
        }
    }
    
    /// 开始翻译
    private func startTranslationForVideo(_ video: VideoItem) {
        guard video.hasRecognition else {
            print("❌ 识别结果不存在，无法翻译")
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
    
    /// 保存 YouTube 视频
    private func saveYoutubeVideo(url: String) {
        // 从 URL 提取视频名称
        let videoName = extractVideoName(from: url)
        
        // 使用默认海报图
        let defaultPoster = UIImage(systemName: "video.fill")
        
        let _ = VideoStorageManager.shared.addVideo(
            name: videoName,
            posterImage: defaultPoster,
            videoURL: url,
            isYouTube: true
        )
        
        loadVideos()
        print("✅ YouTube 视频已保存: \(videoName)")
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
        return "未命名视频"
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
                conversionProgress = progress
            },
            completion: { result in
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
        )
    }
    
    /// 上传音频并进行语音识别
    private func uploadAudioAndRecognize(audioURL: URL, videoId: String) {
        isUploading = true
        uploadProgress = 0.0
        
        COSUploadManager.shared.uploadFile(
            fileURL: audioURL,
            progress: { progress in
                uploadProgress = progress
                print("上传进度: \(Int(progress * 100))%")
            },
            completion: { result in
                isUploading = false
                switch result {
                case .success(let cosURL):
                    print("✅ 音频上传成功!")
                    print("COS访问地址: \(cosURL)")
                    
                    // 开始语音识别
                    isRecognizing = true
                    ASRManager.shared.createRecognitionTask(audioURL: cosURL) { result in
                        switch result {
                        case .success(let taskId):
                            print("✅ 语音识别任务创建成功! TaskId: \(taskId)")
                            asrTaskId = taskId
                            // 开始轮询查询识别结果
                            pollRecognitionResult(taskId: taskId, videoId: videoId)
                        case .failure(let error):
                            print("❌ 创建语音识别任务失败: \(error.localizedDescription)")
                            isRecognizing = false
                        }
                    }
                    
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
            isRecognizing = false
            return
        }
        
        ASRManager.shared.queryRecognitionResult(taskId: taskId) { result in
            switch result {
            case .success(let (taskResult, rawJSON)):
                print("📊 识别状态: \(taskResult.StatusStr)")
                
                switch taskResult.Status {
                case 2: // 成功
                    if let recognizedText = taskResult.Result {
                        print("✅ 识别成功!")
                        print("识别结果: \(recognizedText)")
                        recognitionText = recognizedText
                        isRecognizing = false
                        
                        // 直接保存原始 JSON 响应
                        saveRawRecognitionJSON(videoId: videoId, rawJSON: rawJSON, recognizedText: recognizedText)
                    }
                    
                case 3: // 失败
                    print("❌ 识别失败: \(taskResult.ErrorMsg ?? "未知错误")")
                    isRecognizing = false
                    
                case 0, 1: // 等待中或执行中
                    // 5 秒后继续轮询
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        pollRecognitionResult(taskId: taskId, videoId: videoId, retryCount: retryCount + 1)
                    }
                    
                default:
                    print("⚠️ 未知状态: \(taskResult.Status)")
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
        print("🚀 开始翻译识别结果（词级别）")
        print(String(repeating: "🌟", count: 40) + "\n")
        
        viewModel.isTranslating = true
        
        // 读取 JSON 文件获取 words 数组
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let jsonFileURL = documentsDirectory.appendingPathComponent("\(videoId).json")
        
        guard let jsonData = try? Data(contentsOf: jsonFileURL) else {
            print("❌ 无法读取 JSON 文件")
            viewModel.isTranslating = false
            return
        }
        
        // 解析 JSON 获取所有 words
        guard let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let response = jsonObject["Response"] as? [String: Any],
              let data = response["Data"] as? [String: Any],
              let resultDetail = data["ResultDetail"] as? [[String: Any]] else {
            print("❌ 无法解析 JSON 结构")
            viewModel.isTranslating = false
            return
        }
        
        // 收集所有 words
        var allWords: [String] = []
        for detail in resultDetail {
            if let words = detail["Words"] as? [[String: Any]] {
                let wordValues = words.compactMap { $0["Word"] as? String }
                allWords.append(contentsOf: wordValues)
            }
        }
        
        if allWords.isEmpty {
            print("❌ 没有找到 words 数组")
            viewModel.isTranslating = false
            return
        }
        
        print("📝 准备翻译 \(allWords.count) 个单词...")
        
        // 调用翻译 API
        HunyuanManager.shared.translateWords(allWords) { result in
            DispatchQueue.main.async {
                viewModel.isTranslating = false
                
                switch result {
                case .success(let translatedWords):
                    print("✅ 翻译成功，共 \(translatedWords.count) 个日文单词")
                    
                    // 保存翻译结果为简单文本格式
                    self.saveTranslationResultToTxt(
                        videoId: videoId,
                        originalWords: allWords,
                        translatedWords: translatedWords
                    )
                    
                    viewModel.translationResult = "翻译完成：\(translatedWords.count) 个单词"
                    
                case .failure(let error):
                    print("❌ 翻译失败: \(error.localizedDescription)")
                    viewModel.translationResult = "翻译失败: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// 保存翻译结果为简单文本格式
    private func saveTranslationResultToTxt(videoId: String, originalWords: [String], translatedWords: [String]) {
        do {
            // 获取 Documents 目录
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            
            // 生成文件名：videoId_translation.txt
            let fileName = "\(videoId)_translation.txt"
            let fileURL = documentsDirectory.appendingPathComponent(fileName)
            
            // 构建简单的文本内容：每行一个翻译后的词
            let content = translatedWords.joined(separator: "\n")
            
            // 写入文件
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            
            print("\n" + String(repeating: "=", count: 60))
            print("💾 翻译结果已保存为 TXT 文件")
            print(String(repeating: "=", count: 60))
            print("📝 文件名: \(fileName)")
            print("📂 文件路径: \(fileURL.path)")
            print("📊 单词数量: \(translatedWords.count)")
            print(String(repeating: "=", count: 60) + "\n")
            print(String(repeating: "=", count: 60) + "\n")
            
            // 更新视频的翻译结果路径
            // 刷新列表（翻译结果文件已保存，状态会自动更新）
            loadVideos()
            
        } catch {
            print("❌ 保存翻译结果 TXT 文件失败: \(error.localizedDescription)")
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 视频海报
            Group {
                if let posterImage = video.posterImage {
                    Image(uiImage: posterImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        Color.gray.opacity(0.1)
                        Image(systemName: "video.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .foregroundColor(.gray)
                            .frame(width: 60, height: 60)
                    }
                }
            }
            .frame(height: 130)
            .frame(maxWidth: .infinity)
            .clipped()
            
            // 视频信息
            VStack(alignment: .leading, spacing: 8) {
                // 视频时长
                if let duration = video.duration {
                    Text(formatDuration(duration))
                        .font(.caption)
                        .foregroundColor(.ex.text2)
                        .padding(.top, 8)
                }
                
                // 视频名称
                Text(video.name)
                    .font(.headline)
                    .foregroundColor(.ex.text1)
                    .lineLimit(2)
                
                HStack(alignment: .center) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            if video.isYouTube {
                                HStack(spacing: 4) {
                                    Image(systemName: "play.rectangle.fill")
                                        .font(.caption)
                                    Text("YouTube")
                                        .font(.caption)
                                }
                                .foregroundColor(.red)
                            } else {
                                HStack(spacing: 4) {
                                    Image(systemName: "doc.fill")
                                        .font(.caption)
                                    Text("本地视频")
                                        .font(.caption)
                                }
                                .foregroundColor(.blue)
                            }
                            
                            // 音频状态标签
                            if video.hasAudio {
                                HStack(spacing: 4) {
                                    Image(systemName: "waveform")
                                        .font(.caption)
                                    Text("已转换")
                                        .font(.caption)
                                }
                                .foregroundColor(.green)
                            } else {
                                Button(action: onConvertAudio) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "waveform")
                                            .font(.caption)
                                        Text("未转换")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(4)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            // 识别状态标签
//                            if video.hasRecognition {
//                                HStack(spacing: 4) {
//                                    Image(systemName: "text.bubble")
//                                        .font(.caption)
//                                    Text("已识别")
//                                        .font(.caption)
//                                }
//                                .foregroundColor(.orange)
//                            } else if video.hasAudio {
//                                Button(action: onStartRecognition) {
//                                    HStack(spacing: 4) {
//                                        Image(systemName: "text.bubble")
//                                            .font(.caption)
//                                        Text("识别")
//                                            .font(.caption)
//                                    }
//                                    .foregroundColor(.blue)
//                                    .padding(.horizontal, 8)
//                                    .padding(.vertical, 4)
//                                    .background(Color.blue.opacity(0.1))
//                                    .cornerRadius(4)
//                                }
//                                .buttonStyle(.plain)
//                            } else {
//                                HStack(spacing: 4) {
//                                    Image(systemName: "text.bubble")
//                                        .font(.caption)
//                                    Text("未识别")
//                                        .font(.caption)
//                                }
//                                .foregroundColor(.gray)
//                            }
                            
                            // 翻译状态标签
//                            if video.hasRecognition && !video.hasTranslation {
//                                Button(action: onStartTranslation) {
//                                    HStack(spacing: 4) {
//                                        Image(systemName: "globe")
//                                            .font(.caption)
//                                        Text("翻译")
//                                            .font(.caption)
//                                    }
//                                    .foregroundColor(.purple)
//                                    .padding(.horizontal, 8)
//                                    .padding(.vertical, 4)
//                                    .background(Color.purple.opacity(0.1))
//                                    .cornerRadius(4)
//                                }
//                                .buttonStyle(.plain)
//                            }
                        }
                    }
                }
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 16)
        }
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let seconds = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    HomeView()
}

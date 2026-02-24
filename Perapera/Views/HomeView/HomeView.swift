import SwiftUI
import UniformTypeIdentifiers
import PhotosUI
import AVFoundation

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var videos: [VideoItem] = []
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
                                NavigationLink(destination: VideoPlayerView(video: video)) {
                                    VideoRowView(video: video, onDelete: {
                                        deleteVideo(video)
                                    })
                                }
                                .listRowInsets(EdgeInsets())
                            }
                            .onDelete(perform: deleteVideos)
                        }
                        .scrollContentBackground(.hidden)
                    }
                }
                .navigationTitle("home_navigationTitle".localized())
                .onAppear {
                    loadVideos()
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
                        print("Selected media file: \(url.lastPathComponent)")
                        
                        // 保存视频到列表（先不设置音频路径）
                        let videoName = url.deletingPathExtension().lastPathComponent
                        VideoStorageManager.shared.addVideo(
                            name: videoName,
                            posterImage: UIImage(systemName: "video.fill"),
                            videoURL: url.path,
                            audioURL: nil
                        )
                        loadVideos()
                        
                        // 获取刚添加的视频 ID
                        if let newVideo = videos.first {
                            currentConvertingVideoId = newVideo.id
                            
                            // 开始转换视频为音频
                            convertVideoToAudio(videoURL: url, videoId: newVideo.id)
                        }
                        
                    case .failure(let error):
                        print("File selection error: \(error.localizedDescription)")
                    }
                }
                .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedVideoItem, matching: .videos)
                .onChange(of: selectedVideoItem) { newItem in
                    if let newItem = newItem {
                        Task {
                            // 加载视频
                            if let data = try? await newItem.loadTransferable(type: Data.self) {
                                // 保存到临时目录
                                let tempURL = FileManager.default.temporaryDirectory
                                    .appendingPathComponent(UUID().uuidString)
                                    .appendingPathExtension("mov")
                                
                                try? data.write(to: tempURL)
                                
                                // 生成缩略图
                                let thumbnail = generateVideoThumbnail(url: tempURL)
                                
                                // 保存到视频列表
                                VideoStorageManager.shared.addVideo(
                                    name: "相册视频 - \(Date().formatted())",
                                    posterImage: thumbnail,
                                    videoURL: tempURL.path,
                                    audioURL: nil
                                )
                                
                                await MainActor.run {
                                    loadVideos()
                                    
                                    // 获取刚添加的视频 ID
                                    if let newVideo = videos.first {
                                        currentConvertingVideoId = newVideo.id
                                        
                                        // 开始转换视频为音频
                                        convertVideoToAudio(videoURL: tempURL, videoId: newVideo.id)
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
    
    /// 保存 YouTube 视频
    private func saveYoutubeVideo(url: String) {
        // 从 URL 提取视频名称
        let videoName = extractVideoName(from: url)
        
        // 使用默认海报图
        let defaultPoster = UIImage(systemName: "video.fill")
        
        VideoStorageManager.shared.addVideo(
            name: videoName,
            posterImage: defaultPoster,
            videoURL: url
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
                    
                    // 更新视频的音频路径
                    VideoStorageManager.shared.updateVideoAudioURL(
                        id: videoId,
                        audioURL: audioURL.path
                    )
                    
                    // 刷新列表
                    loadVideos()
                    
                    // 上传音频到 COS 并进行语音识别
                    uploadAudioAndRecognize(audioURL: audioURL)
                    
                case .failure(let error):
                    print("❌ 音频转换失败: \(error.localizedDescription)")
                    // TODO: 显示错误提示给用户
                }
                
                currentConvertingVideoId = nil
            }
        )
    }
    
    /// 上传音频并进行语音识别
    private func uploadAudioAndRecognize(audioURL: URL) {
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
                            pollRecognitionResult(taskId: taskId)
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
    
    /// 轮询查询语音识别结果
    private func pollRecognitionResult(taskId: Int, retryCount: Int = 0) {
        let maxRetries = 60 // 最多轮询 60 次（约 5 分钟）
        
        guard retryCount < maxRetries else {
            print("❌ 语音识别超时")
            isRecognizing = false
            return
        }
        
        ASRManager.shared.queryRecognitionResult(taskId: taskId) { result in
            switch result {
            case .success(let taskResult):
                print("📊 识别状态: \(taskResult.StatusStr)")
                
                switch taskResult.Status {
                case 2: // 成功
                    if let recognizedText = taskResult.Result {
                        print("✅ 识别成功!")
                        print("识别结果: \(recognizedText)")
                        recognitionText = recognizedText
                        isRecognizing = false
                    }
                    
                case 3: // 失败
                    print("❌ 识别失败: \(taskResult.ErrorMsg ?? "未知错误")")
                    isRecognizing = false
                    
                case 0, 1: // 等待中或执行中
                    // 5 秒后继续轮询
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        pollRecognitionResult(taskId: taskId, retryCount: retryCount + 1)
                    }
                    
                default:
                    print("⚠️ 未知状态: \(taskResult.Status)")
                    isRecognizing = false
                }
                
            case .failure(let error):
                print("❌ 查询识别结果失败: \(error.localizedDescription)")
                // 失败后重试
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    pollRecognitionResult(taskId: taskId, retryCount: retryCount + 1)
                }
            }
        }
    }
}

// MARK: - Video Row View
struct VideoRowView: View {
    let video: VideoItem
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 15) {
            // 视频海报
            Group {
                if let posterImage = video.posterImage {
                    Image(uiImage: posterImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: "video.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(.gray)
                        .padding(20)
                }
            }
            .frame(width: 120, height: 80)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
            .clipped()
            
            // 视频信息
            VStack(alignment: .leading, spacing: 5) {
                Text(video.name)
                    .font(.headline)
                    .foregroundColor(.ex.text1)
                    .lineLimit(2)
                
                Text(formatDate(video.createdAt))
                    .font(.caption)
                    .foregroundColor(.ex.text2)
                
                HStack(spacing: 8) {
                    if video.videoURL.contains("youtube") || video.videoURL.contains("youtu.be") {
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
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}

#Preview {
    HomeView()
}

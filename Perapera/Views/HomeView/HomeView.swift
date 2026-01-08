import SwiftUI
import UniformTypeIdentifiers
import PhotosUI

struct HomeView: View {
    // Sample data
    let items = Array(1...20).map { "Item \($0)" }

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

    var body: some View {
        ZStack {
            NavigationStack {
                List(items, id: \.self) { item in
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(Color.ex.text1)
                        Text(item)
                            .foregroundColor(.ex.main1)
                    }
                    .frame(height: 150)
                }
                .scrollContentBackground(.hidden)
                .navigationTitle("home_navigationTitle".localized())
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
                        
                        // 开始上传到腾讯云COS
                        isUploading = true
                        uploadProgress = 0.0
                        
                        COSUploadManager.shared.uploadFile(
                            fileURL: url,
                            progress: { progress in
                                uploadProgress = progress
                                print("上传进度: \(Int(progress * 100))%")
                            },
                            completion: { result in
                                isUploading = false
                                switch result {
                                case .success(let cosURL):
                                    print("✅ 文件上传成功!")
                                    print("COS访问地址: \(cosURL)")
                                    
                                    // 上传成功后，开始语音识别
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
                                    print("❌ 文件上传失败: \(error.localizedDescription)")
                                    // TODO: 显示错误提示给用户
                                }
                            }
                        )
                        
                    case .failure(let error):
                        print("File selection error: \(error.localizedDescription)")
                    }
                }
                .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedVideoItem, matching: .videos)
                .onChange(of: selectedVideoItem) { newItem in
                    if let newItem = newItem {
                        Task {
                            // Example of loading the video
                            // Note: Loading actual video data or URL might require more steps depending on needs
                            print("Selected video item: \(newItem)")
                            // Reset selection if needed or handle the file
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
                            // Handle save action
                            print("Saved URL: \(youtubeUrl)")
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

#Preview {
    HomeView()
}

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
                    allowedContentTypes: [.audio, .movie],
                    allowsMultipleSelection: false
                ) { result in
                    switch result {
                    case .success(let urls):
                        guard let url = urls.first else { return }
                        // Access the security-scoped resource
                        if url.startAccessingSecurityScopedResource() {
                            defer { url.stopAccessingSecurityScopedResource() }
                            print("Selected media file: \(url.absoluteString)")
                            // TODO: Handle the file (e.g., play it or import it)
                        }
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
}

#Preview {
    HomeView()
}

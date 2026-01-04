import SwiftUI

struct HomeView: View {
    // Sample data
    let items = Array(1...20).map { "Item \($0)" }

    @State private var showingSheet = false
    @State private var showingYoutubeAlert = false
    @State private var youtubeUrl = ""

    var body: some View {
        ZStack {
            NavigationStack {
                List(items, id: \.self) { item in
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(.blue)
                        Text(item)
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
                            .font(.headline)
                            .padding(.top, 40)
                            .padding(.leading, 25)
                        Text("home_sheet_subtitle".localized())
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
                                        Text("Youtube网址")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Text("在应用中播放Youtube视频，无需下载")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
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
                            
                            Button(action: {
                                print("Item 2 tapped")
                                showingSheet = false
                            }) {
                                HStack(spacing: 15) {
                                    Image(systemName: "mic")
                                        .resizable()
                                        .frame(width: 25, height: 25)
                                        .foregroundColor(.green)
                                    VStack(alignment: .leading) {
                                        Text("本地媒体")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Text("从您的本地存储导入媒体文件，无需复制")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
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
                            
                            Button(action: {
                                print("Item 3 tapped")
                                showingSheet = false
                            }) {
                                HStack(spacing: 15) {
                                    Image(systemName: "doc")
                                        .resizable()
                                        .frame(width: 25, height: 25)
                                        .foregroundColor(.orange)
                                    VStack(alignment: .leading) {
                                        Text("相册")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Text("从您的相册导入媒体文件")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
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

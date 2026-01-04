import SwiftUI

struct HomeView: View {
    // Sample data
    let items = Array(1...20).map { "Item \($0)" }

    @State private var showingSheet = false

    var body: some View {
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
                        }) {
                            HStack(spacing: 15) {
                                Image(systemName: "photo")
                                    .resizable()
                                    .frame(width: 25, height: 25)
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading) {
                                    Text("home_sheet_list_title1".localized())
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text("home_sheet_list_subtitle1".localized())
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
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
                        }) {
                            HStack(spacing: 15) {
                                Image(systemName: "mic")
                                    .resizable()
                                    .frame(width: 25, height: 25)
                                    .foregroundColor(.green)
                                VStack(alignment: .leading) {
                                    Text("home_sheet_list_title2".localized())
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text("home_sheet_list_subtitle2".localized())
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
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
                        }) {
                            HStack(spacing: 15) {
                                Image(systemName: "doc")
                                    .resizable()
                                    .frame(width: 25, height: 25)
                                    .foregroundColor(.orange)
                                VStack(alignment: .leading) {
                                    Text("home_sheet_list_title3".localized())
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text("home_sheet_list_subtitle3".localized())
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
                .presentationDetents([.height(330)])
                .presentationDragIndicator(.visible)
            }
        }
    }
}

#Preview {
    HomeView()
}

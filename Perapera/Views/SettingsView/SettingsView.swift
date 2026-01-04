import SwiftUI

struct SettingsView: View {
    @State private var showingLoginView = false

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("settings_account_header".localized()).foregroundColor(Color.ex.main)
                    .font(.title2)) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("settings_account_not_logged_in".localized())
                                .font(.headline)
                                .foregroundColor(.Ex.text1)
                            Text("settings_account_login_description".localized())
                                .font(.subheadline)
                                .foregroundColor(.Ex.text2)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            // Handle login action
                            print("Login tapped")
                            showingLoginView = true
                        }) {
                            Text("settings_account_login_button".localized())
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.Ex.main)
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle()) // Prevent list row selection
                    }
                    .padding(.vertical, 6)
                    
                    
                }
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("加入 Perapera Pro")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("用AI解锁全部功能")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.ex.main)
                    .cornerRadius(10)
                    .listRowInsets(EdgeInsets()) // Remove default list row padding
                    .listRowBackground(Color.clear) // Remove default list row background
                }
                
                
                
                Section(header: Text("About")) {
                    Text("Version 1.0.0")
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingLoginView) {
                LoginView()
            }
        }
    }
}

#Preview {
    SettingsView()
}

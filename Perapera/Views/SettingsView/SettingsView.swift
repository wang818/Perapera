import SwiftUI

struct SettingsView: View {
    @State private var showingLoginView = false

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("settings_account_header".localized())) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("settings_account_not_logged_in".localized())
                                .font(.headline)
                            Text("settings_account_login_description".localized())
                                .font(.subheadline)
                                .foregroundColor(.secondary)
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
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle()) // Prevent list row selection
                    }
                    .padding(.vertical, 6)
                    
                    
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

import SwiftUI

struct SettingsView: View {
    @State private var showingLoginView = false
    @State private var showLanguageSettings = false

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
                    VStack(alignment: .center, spacing: 8) {
                        Text("settings_pro_title".localized())
                            .font(.headline)
                            .foregroundColor(.Ex.text1)
                        Text("settings_pro_subtitle".localized())
                            .font(.subheadline)
                            .foregroundColor(.Ex.text2)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                    .background(Color.ex.main)
                    .cornerRadius(10)
                    .listRowInsets(EdgeInsets()) // Remove default list row padding
                    .listRowBackground(Color.clear) // Remove default list row background
                }
                
                Section(header: Text("settings_general_header".localized())) {
                    SettingsRowView(imageName: "globe", title: "settings_language_title".localized(), subtitle: "settings_language_subtitle".localized()) {
                        showLanguageSettings = true
                    }
                    SettingsRowView(imageName: "textformat", title: "settings_alphabet_title".localized(), subtitle: "settings_alphabet_subtitle".localized()) {
                        print("Alphabet tapped")
                    }
                    SettingsRowView(imageName: "paintbrush.fill", title: "settings_theme_title".localized(), subtitle: "settings_theme_subtitle".localized()) {
                        print("Theme tapped")
                    }
                }
                
                
                Section(header: Text("About")) {
                    Text("Version 1.0.0")
                }
                
                
                
            }
            .navigationTitle("Settings")
            .background(
                NavigationLink(
                    destination: LanguageSettingsView(),
                    isActive: $showLanguageSettings
                ) { EmptyView() }
            )
            .sheet(isPresented: $showingLoginView) {
                LoginView()
            }
        }
    }
}

#Preview {
    SettingsView()
}

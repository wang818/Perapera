import SwiftUI
import RxSwift
import Moya
import HandyJSON

class SettingsViewModel: ObservableObject {
    private let disposeBag = DisposeBag()
    
    func fetchSupportLanguages() {
        appApi.rx.request(.supportLang)
            .asObservable()
            .mapArray(SupportLanguageModel.self)
            .subscribe(onNext: { models in
                // Save to local
                LanguageManager.updateSupportLanguages(models)
            }, onError: { error in
            })
            .disposed(by: disposeBag)
    }
}

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @ObservedObject private var userManager = UserManager.shared
    @State private var showingLoginView = false
    @State private var showLanguageSettings = false
    @State private var showThemeSettings = false
    @State private var showPurchaseView = false

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("settings_account_header".localized()).foregroundColor(Color.ex.main)
                    .font(.title2)) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            if userManager.isLoggedIn {
                                Text(userManager.userEmail ?? "")
                                    .font(.headline)
                                    .foregroundColor(.Ex.text1)
                            } else {
                                Text("settings_account_not_logged_in".localized())
                                    .font(.headline)
                                    .foregroundColor(.Ex.text1)
                                Text("settings_account_login_description".localized())
                                    .font(.subheadline)
                                    .foregroundColor(.Ex.text2)
                            }
                        }
                        
                        Spacer()
                        
                        if !userManager.isLoggedIn {
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
                        } else {
                             Button(action: {
                                 userManager.logout()
                             }) {
                                 Text("logout".localized())
                                     .fontWeight(.medium)
                                     .foregroundColor(.white)
                                     .padding(.horizontal, 16)
                                     .padding(.vertical, 8)
                                     .background(Color.gray)
                                     .cornerRadius(8)
                             }
                             .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.vertical, 6)
                }
                
                Section {
                    Button(action: {
                        showPurchaseView = true
                    }) {
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
                    }
                    .buttonStyle(PlainButtonStyle())
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
                        showThemeSettings = true
                    }
                }
                
                
                Section(header: Text("settings_feedback_header".localized())) {
                    SettingsRowView(imageName: "envelope.fill", title: "settings_email_title".localized(), subtitle: "settings_email_subtitle".localized()) {
                        print("Email tapped")
                        if let url = URL(string: "mailto:support@perapera.com") {
                            UIApplication.shared.open(url)
                        }
                    }
                }
                
                Section(header: Text("settings_help".localized())) {
                    SettingsRowView(imageName: "questionmark.circle", title: "settings_faq_title".localized(), subtitle: "") {
                        if let url = URL(string: "https://www.perapera.com/faq") {
                            UIApplication.shared.open(url)
                        }
                    }
                    
                    SettingsRowView(imageName: "info.circle", title: "settings_about_perapera_title".localized(), subtitle: "") {
                        if let url = URL(string: "https://www.perapera.com/about") {
                            UIApplication.shared.open(url)
                        }
                    }
                    
                }
                
                
                
            }
            .navigationTitle("settings_title".localized())
            .background(
                Group {
                    NavigationLink(
                        destination: LanguageSettingsView(),
                        isActive: $showLanguageSettings
                    ) { EmptyView() }
                    
                    NavigationLink(
                        destination: ThemeSettingsView(),
                        isActive: $showThemeSettings
                    ) { EmptyView() }
                }
            )
            .onAppear {
                viewModel.fetchSupportLanguages()
            }
            .fullScreenCover(isPresented: $showingLoginView) {
                LoginView()
            }
            .fullScreenCover(isPresented: $showPurchaseView) {
                PurchaseView()
            }
        }
    }
}

#Preview {
    SettingsView()
}

struct ThemeSettingsView: View {
    @AppStorage("AppTheme") private var selectedTheme: AppTheme = .system
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            ForEach(AppTheme.allCases) { theme in
                Button(action: {
                    selectedTheme = theme
                }) {
                    HStack {
                        Text(theme.localizedName)
                            .foregroundColor(.primary)
                        Spacer()
                        if selectedTheme == theme {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .navigationTitle("settings_theme_title".localized())
        // Hide default back button to remove text
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        // Ensure the back button color matches the navigation bar tint
                        .foregroundColor(.primary)
                }
            }
        }
        .toolbar(.hidden, for: .tabBar)
    }
}


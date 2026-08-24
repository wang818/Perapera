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
    @ObservedObject private var purchaseManager = PurchaseManager.shared
    @State private var showingLoginView = false
    @State private var showLanguageSettings = false
    @State private var showThemeSettings = false
    @State private var showSubtitleSettings = false
    // @State private var showCloudProviderSettings = false
    @State private var showPurchaseView = false
    @State private var showDeleteAccountConfirm = false

    var body: some View {
        NavigationView {
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
//
                Section {
                    Button(action: {
                        showPurchaseView = true
                    }) {
                        VStack(alignment: .center, spacing: 8) {
                            if let userInfo = userManager.currentUserInfo,
                               userInfo.hasActivePro || userInfo.hasRemainingCardMinutes {
                                Text("Perapera Pro".localized())
                                    .font(.headline)
                                    .foregroundColor(.Ex.text1)
                                if !userInfo.currentMonthRemainingDescription.isEmpty {
                                    Text(userInfo.currentMonthRemainingDescription)
                                        .font(.subheadline)
                                        .foregroundColor(.Ex.text1)
                                }
                            } else {
                                Text("settings_pro_title".localized())
                                    .font(.headline)
                                    .foregroundColor(.Ex.text1)
                                Text(purchaseManager.currentPlanDisplayName ?? "settings_pro_subtitle".localized())
                                    .font(.subheadline)
                                    .foregroundColor(.Ex.text2)
                            }
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
                    // TODO: 暂时屏蔽「字幕首选项」入口（不删除代码，恢复时去掉下方注释即可）
                    /*
                    SettingsRowView(imageName: "textformat", title: "settings_alphabet_title".localized(), subtitle: "settings_alphabet_subtitle".localized()) {
                        showSubtitleSettings = true
                    }
                    */
                    SettingsRowView(imageName: "paintbrush.fill", title: "settings_theme_title".localized(), subtitle: "settings_theme_subtitle".localized()) {
                        showThemeSettings = true
                    }
                    // SettingsRowView(imageName: "cloud.fill", title: "cloud_provider_title".localized(), subtitle: "cloud_provider_subtitle".localized()) {
                    //     showCloudProviderSettings = true
                    // }
                }
                
                
                Section(header: Text("settings_feedback_header".localized())) {
                    SettingsRowView(imageName: "envelope.fill", title: "settings_email_title".localized(), subtitle: "settings_email_subtitle".localized()) {
                        print("Email tapped")
                        if let url = URL(string: "mailto:support@perapera.cc") {
                            UIApplication.shared.open(url)
                        }
                    }
                }
                
                Section(header: Text("settings_help".localized())) {
                    SettingsRowView(imageName: "questionmark.circle", title: "settings_faq_title".localized(), subtitle: "") {
                        if let url = URL(string: "https://www.perapera.cc/faq") {
                            UIApplication.shared.open(url)
                        }
                    }
                    
                    SettingsRowView(imageName: "info.circle", title: "settings_about_perapera_title".localized(), subtitle: "") {
                        if let url = URL(string: "https://www.perapera.cc") {
                            UIApplication.shared.open(url)
                        }
                    }

                }

                Section {
                    Button(action: {
                        showDeleteAccountConfirm = true
                    }) {
                        HStack {
                            Spacer()
                            Text("settings_delete_account_title".localized())
                                .font(.headline)
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .alert(isPresented: $showDeleteAccountConfirm) {
                    Alert(
                        title: Text("settings_delete_account_title".localized()),
                        message: Text("settings_delete_account_message".localized()),
                        primaryButton: .destructive(Text("settings_delete_account_confirm".localized())) {
                            userManager.deleteAccount { _, _ in
                            }
                        },
                        secondaryButton: .cancel(Text("colse".localized()))
                    )
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
                    
                    NavigationLink(
                        destination: SubtitleSettingsView(),
                        isActive: $showSubtitleSettings
                    ) { EmptyView() }

                    // NavigationLink(
                    //     destination: CloudProviderSettingsView(),
                    //     isActive: $showCloudProviderSettings
                    // ) { EmptyView() }
                }
            )
            .onAppear {
                // TODO: 用户界面（设置语言相关界面）数据源固定为 LanguageManager.nativeLanguageNames，
                // 不再拉取 support_lang 接口（该接口数据只供目标语言选择界面使用，恢复时去掉注释即可）
                // viewModel.fetchSupportLanguages()
                purchaseManager.loadProducts()
                purchaseManager.refreshEntitlements()
                userManager.fetchCurrentUser()
            }
            .fullScreenCover(isPresented: $showingLoginView) {
                LoginView()
            }
            .fullScreenCover(isPresented: $showPurchaseView) {
                PurchaseView()
            }
            .alert(isPresented: $showDeleteAccountConfirm) {
                Alert(
                    title: Text("settings_delete_account_title".localized()),
                    message: Text("settings_delete_account_message".localized()),
                    primaryButton: .destructive(Text("settings_delete_account_confirm".localized())) {
                        print("Delete account confirmed")
                    },
                    secondaryButton: .cancel(Text("colse".localized()))
                )
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
    }
}

// MARK: - Cloud Provider Settings View

struct CloudProviderSettingsView: View {
    @StateObject private var providerManager = CloudProviderManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(CloudProvider.allCases) { provider in
                Button(action: {
                    providerManager.currentProvider = provider
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(provider.displayName)
                                .foregroundColor(.primary)
                            Text(providerDescription(provider))
                                .font(.caption)
                                .foregroundColor(.Ex.text2)
                        }
                        Spacer()
                        if providerManager.currentProvider == provider {
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
        .navigationTitle("cloud_provider_title".localized())
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                }
            }
        }
    }

    private func providerDescription(_ provider: CloudProvider) -> String {
        switch provider {
        case .tencent:
            return "cloud_provider_tencent_desc".localized()
        case .aliyun:
            return "cloud_provider_aliyun_desc".localized()
        }
    }
}

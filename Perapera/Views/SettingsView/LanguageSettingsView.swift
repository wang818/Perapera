import SwiftUI
import Combine

struct LanguageManager {
    static let languageNames: [String: String] = [
        "en": "English",
        "zh-Hans": "简体中文",
        "zh-Hant": "繁體中文",
        "ja": "日本語",
        "ko": "한국어",
        "vi": "Tiếng Việt"
    ]
    
    static func setAppLanguage(_ code: String) {
        PUserDefault.setValueForKey(code, key: "AppLanguage")
    }
    
    static func getCurrentAppLanguage() -> String {
        // 1. Check if user has manually set a language in UserDefaults
        if let storedLanguageCode = UserDefaults.standard.string(forKey: "AppLanguage"),
           let languageName = languageNames[storedLanguageCode] {
            return languageName
        }
        
        // 2. Fallback to the language the App is currently running in
        let resolvedLanguage = Bundle.main.preferredLocalizations.first ?? "en"
        
        // Logic: If the app resolved to English, but the user's phone language is NOT English,
        // it means the user's phone language is not supported by the app.
        // In this case, we default to English and save it as the App's setting.
        if resolvedLanguage == "en" {
            // Check user's primary preferred language (e.g. "fr-FR", "zh-Hans-CN")
            if let primaryLang = Locale.preferredLanguages.first,
               !primaryLang.lowercased().hasPrefix("en") {
                // Phone language not supported -> Set default to en
                setAppLanguage("en")
                return languageNames["en"] ?? "English"
            }
        }
        
        return languageNames[resolvedLanguage] ?? "English"
    }
}

struct LanguageSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Placeholder states for current languages
    // In a real app, these would come from UserDefaults or a view model
    @State private var appLanguage = LanguageManager.getCurrentAppLanguage()
    @State private var aiLanguage = "American"
    @State private var sourceLanguage = "English"
    @State private var learningLanguage = "Japanese"
    
    var body: some View {
        List {
            Section {
                languageRow(
                    title: "settings_lang_app_title".localized(),
                    subtitle: "settings_lang_app_subtitle".localized(),
                    currentValue: appLanguage
                ) {
                    // Action for App Language
                    print("App Language tapped")
                }
                
                languageRow(
                    title: "settings_lang_ai_title".localized(),
                    subtitle: "settings_lang_ai_subtitle".localized(),
                    currentValue: aiLanguage
                ) {
                    // Action for AI Explanation Language
                    print("AI Explanation Language tapped")
                }
                
                languageRow(
                    title: "settings_lang_source_title".localized(),
                    subtitle: "settings_lang_source_subtitle".localized(),
                    currentValue: sourceLanguage
                ) {
                    // Action for Second Subtitle (Source Language)
                    print("Second Subtitle tapped")
                }
                
                languageRow(
                    title: "settings_lang_learn_title".localized(),
                    subtitle: "settings_lang_learn_subtitle".localized(),
                    currentValue: learningLanguage
                ) {
                    // Action for Target Language (Learning Language)
                    print("Target Language tapped")
                }
            }
        }
        .navigationTitle("settings_language_title".localized())
        .listStyle(InsetGroupedListStyle())
        .toolbarRole(.editor)
    }
    
    private func languageRow(title: String, subtitle: String, currentValue: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(.ex.text1)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.ex.text2)
                }
                
                Spacer()
                
                Text(currentValue)
                    .font(.subheadline)
                    .foregroundColor(.ex.text2)
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.ex.text2.opacity(0.5))
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    NavigationStack {
        LanguageSettingsView()
    }
}

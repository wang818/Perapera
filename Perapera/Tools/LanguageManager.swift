import Foundation

class LanguageManager {
    static let shared = LanguageManager()
    
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
    
    static func currentLanguageCode() -> String {
         if let storedLanguageCode = UserDefaults.standard.string(forKey: "AppLanguage") {
            return storedLanguageCode
        }
        // Fallback logic
        let resolvedLanguage = Bundle.main.preferredLocalizations.first ?? "en"
         if resolvedLanguage == "en" {
             if let primaryLang = Locale.preferredLanguages.first,
                !primaryLang.lowercased().hasPrefix("en") {
                 return "en"
             }
         }
         return resolvedLanguage
    }

    static func getCurrentAppLanguage() -> String {
        let code = currentLanguageCode()
        return languageNames[code] ?? "English"
    }
    
    static func currentBundle() -> Bundle {
        let code = currentLanguageCode()
        if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return Bundle.main
    }
}

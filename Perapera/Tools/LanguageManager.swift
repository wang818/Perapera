import Foundation

class LanguageManager {
    static let shared = LanguageManager()
    
    static var languageNames: [String: String] = {
        if let saved = UserDefaults.standard.dictionary(forKey: AppKeys.appLanguage) as? [String: String], !saved.isEmpty {
            return saved
        }
        return [
            "en": "English",
            "zh-Hans": "简体中文",
            "zh-Hant": "繁體中文",
            "ja": "日本語",
            "ko": "한국어",
            "vi": "Tiếng Việt"
        ]
    }()
    
    static var supportLanguages: [SupportLanguageModel] = []
    
    static func updateSupportLanguages(_ models: [SupportLanguageModel]) {
        supportLanguages = models
        var newLanguages: [String: String] = [:]
        for model in models {
             if !model.lang.isEmpty && !model.name.isEmpty {
                 newLanguages[model.lang] = model.name
             }
        }
        
        guard !newLanguages.isEmpty else { return }
        
        // Update memory
        languageNames = newLanguages
        
        // Save to local
        PUserDefault.setValueForKey(newLanguages, key: AppKeys.savedLanguageNames)
    }
    
    static func setAppLanguage(_ code: String) {
        PUserDefault.setValueForKey(code, key: AppKeys.appLanguage)
    }
    
    static func setAILanguage(_ code: String) {
        PUserDefault.setValueForKey(code, key: AppKeys.aiLanguage)
    }
    
    static func getAILanguage() -> String {
        if let stored = PUserDefault.getVauleForKey(key: AppKeys.aiLanguage) as? String, !stored.isEmpty {
            
            return languageNames[stored] ?? "English"
        }
        return getCurrentAppLanguage()
    }
    
    static func setSourceLanguage(_ code: String) {
        PUserDefault.setValueForKey(code, key: AppKeys.sourceLanguage)
    }
    
    static func getSourceLanguage() -> String {
        if let stored = PUserDefault.getVauleForKey(key: AppKeys.sourceLanguage) as? String, !stored.isEmpty {
            return languageNames[stored] ?? "English"
        }
        return getCurrentAppLanguage()
    }
    
    static func setLearningLanguage(_ code: String) {
        PUserDefault.setValueForKey(code, key: AppKeys.learningLanguage)
    }
    
    static func getLearningLanguage() -> String {
        if let stored = PUserDefault.getVauleForKey(key: AppKeys.learningLanguage) as? String, !stored.isEmpty {
            return languageNames[stored] ?? "English"
        }
        return getCurrentAppLanguage()
    }
    
    static func currentLanguageCode() -> String {
         if let storedLanguageCode = UserDefaults.standard.string(forKey: AppKeys.appLanguage) {
            return storedLanguageCode
        }
        
        // 如果没有手动设置过，则获取系统首选语言
        // Bundle.main.preferredLocalizations 会自动返回 App 支持的、且最匹配用户系统语言的本地化代码
        // 如果系统语言 App 不支持，它会自动回退到 Info.plist 中的 Development Language (通常是 en)
        let resolvedLanguage = Bundle.main.preferredLocalizations.first ?? "en"
        
        return resolvedLanguage
    }

    static func getCurrentAppLanguage() -> String {
        let code = currentLanguageCode()
        return languageNames[code] ?? "English"
    }
    
    static func currentBundle() -> Bundle {
        var code = currentLanguageCode()
        
        // Map server codes to iOS bundle names
        let mapping: [String: String] = [
            "zh-CN": "zh-Hans",
            "pt": "pt-PT"
        ]
        
        if let mappedCode = mapping[code] {
            code = mappedCode
        }
        
        if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return Bundle.main
    }
}

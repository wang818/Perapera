import Foundation

class LanguageManager {
    static let shared = LanguageManager()
    
    /// 语言代码 → 语言原文名（每种语言的母语写法）。
    /// 这份表是固定的，不受服务端 supportLang 返回的本地化名影响，
    /// 供「App Language」行右侧展示使用（选择什么语言就显示该语言的原文，不做多语言适配）。
    static let nativeLanguageNames: [String: String] = [
        "en": "English",
        "zh-Hans": "简体中文",
        "zh-Hant": "繁體中文",
        "ja": "日本語",
        "ko": "한국어",
        "vi": "Tiếng Việt",
        "ar": "العربية",
        "de": "Deutsch",
        "es": "Español",
        "fr": "Français",
        "pt-PT": "Português (Portugal)",
        "pl": "Polski",
        "tr": "Türkçe",
        "th": "ไทย",
        "fil": "Filipino",
        "my": "မြန်မာဘာသာ",
        "ms": "Bahasa Melayu",
        "id": "Bahasa Indonesia",
        "ru": "Русский"
    ]

    static var languageNames: [String: String] = {
        if let saved = UserDefaults.standard.dictionary(forKey: AppKeys.appLanguage) as? [String: String], !saved.isEmpty {
            return saved
        }
        return nativeLanguageNames
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
        let normalized = normalizeCode(code)
        let finalCode = isSupportedBundleCode(normalized) ? normalized : "en"
        PUserDefault.setValueForKey(finalCode, key: AppKeys.appLanguage)
    }
    
    static func setAILanguage(_ code: String) {
        PUserDefault.setValueForKey(code, key: AppKeys.aiLanguage)
    }
    
    static func getAILanguage() -> String {
        if let stored = PUserDefault.getVauleForKey(key: AppKeys.aiLanguage) as? String, !stored.isEmpty {
            return languageNames[stored] ?? localizedLanguageName(stored)
        }
        return getCurrentAppLanguage()
    }
    
    static func setSourceLanguage(_ code: String) {
        PUserDefault.setValueForKey(code, key: AppKeys.sourceLanguage)
    }
    
    static func getSourceLanguage() -> String {
        if let stored = PUserDefault.getVauleForKey(key: AppKeys.sourceLanguage) as? String, !stored.isEmpty {
            return languageNames[stored] ?? localizedLanguageName(stored)
        }
        return getCurrentAppLanguage()
    }
    
    static func setLearningLanguage(_ code: String) {
        PUserDefault.setValueForKey(code, key: AppKeys.learningLanguage)
    }
    
    static func getLearningLanguage() -> String {
        if let stored = PUserDefault.getVauleForKey(key: AppKeys.learningLanguage) as? String, !stored.isEmpty {
            return languageNames[stored] ?? localizedLanguageName(stored)
        }
        return getCurrentAppLanguage()
    }
    
    static func currentLanguageCode() -> String {
         if let storedLanguageCode = UserDefaults.standard.string(forKey: AppKeys.appLanguage) {
            let normalized = normalizeCode(storedLanguageCode)
            return isSupportedBundleCode(normalized) ? normalized : "en"
        }
        
        let resolvedLanguage = Bundle.main.preferredLocalizations.first ?? "en"
        let normalized = normalizeCode(resolvedLanguage)
        return isSupportedBundleCode(normalized) ? normalized : "en"
    }

    static func getCurrentAppLanguage() -> String {
        let code = currentLanguageCode()
        return languageNames[code] ?? localizedLanguageName(code)
    }

    /// 当前 App 语言的**原文名**（母语写法，不做多语言适配）。
    /// 固定用 nativeLanguageNames，不受服务端本地化名覆盖影响。
    static func getCurrentAppLanguageNative() -> String {
        let code = currentLanguageCode()
        return nativeLanguageName(for: code)
    }

    /// 指定设置项（aiLanguage / sourceLanguage / learningLanguage）当前语言的**原文名**。
    /// 数据源固定为 nativeLanguageNames，不受 support_lang 接口数据影响；
    /// 未设置过时回退当前 App 语言原文名。
    /// 设置界面各行的显示统一走这里（与目标语言选择界面的接口数据完全独立）。
    static func nativeName(forSettingKey settingKey: String) -> String {
        if let stored = PUserDefault.getVauleForKey(key: settingKey) as? String, !stored.isEmpty {
            return nativeLanguageName(for: stored)
        }
        return getCurrentAppLanguageNative()
    }

    /// 语言代码 → 语言原文名（母语写法）。
    /// 优先 nativeLanguageNames；表外代码用语言名原样兜底（本地化兜底仅作最后手段）。
    static func nativeLanguageName(for code: String) -> String {
        let normalized = normalizeCode(code)
        if let native = nativeLanguageNames[normalized] {
            return native
        }
        if let name = languageNames[normalized], !name.isEmpty {
            return name
        }
        return localizedLanguageName(normalized)
    }
    
    static func currentBundle() -> Bundle {
        let code = normalizeCode(currentLanguageCode())
        
        if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return Bundle.main
    }

    static func localizedLanguageName(_ code: String) -> String {
        let mapping: [String: String] = [
            "zh-Hans": "简体中文",
            "zh-Hant": "繁體中文"
        ]
        if let mapped = mapping[code] {
            return mapped
        }
        if let name = Locale.current.localizedString(forIdentifier: code) {
            return name.capitalized
        }
        if let name2 = Locale.current.localizedString(forLanguageCode: code) {
            return name2.capitalized
        }
        return "English"
    }

    static func normalizeCode(_ code: String) -> String {
        let mapping: [String: String] = [
            "zh-CN": "zh-Hans",
            "pt": "pt-PT"
        ]
        if let mapped = mapping[code] {
            return mapped
        }
        return code
    }

    static func isSupportedBundleCode(_ code: String) -> Bool {
        if let path = Bundle.main.path(forResource: code, ofType: "lproj"), !path.isEmpty {
            return true
        }
        return false
    }
}

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

    // MARK: - 第二字幕语言（与字幕设置界面的 subtitle_second_language 共用同一存储）
    /// 该设置同时被「语言设置」与「字幕设置」两处编辑，二者读写的是同一个值。
    /// 存储格式为 nativeLanguageNames 的「原文名」（如「简体中文」「English」「日本語」），
    /// 便于界面直接展示，需要时再反向映射回语言代码供翻译目标使用。
    private static let secondSubtitleKey = "subtitle_second_language"

    /// 读取第二字幕语言（原文名），缺省回退「简体中文」
    static func getSecondSubtitleLanguageName() -> String {
        guard let stored = PUserDefault.getVauleForKey(key: secondSubtitleKey) as? String, !stored.isEmpty else {
            return "简体中文"
        }
        return stored
    }

    /// 写入第二字幕语言（原文名）
    static func setSecondSubtitleLanguageName(_ name: String) {
        PUserDefault.setValueForKey(name, key: secondSubtitleKey)
    }

    /// 第二字幕语言对应的语言代码（供翻译目标语言映射使用）
    static func getSecondSubtitleLanguageCode() -> String {
        let name = getSecondSubtitleLanguageName()
        if let entry = nativeLanguageNames.first(where: { $0.value == name }) {
            return entry.key
        }
        return "zh-Hans"
    }

    // MARK: - 第二字幕默认值（首次启动按设备系统语言初始化）
    /// 根据「本机系统语言」推导第二字幕的默认语言（原文名）。
    /// 直接取系统首选语言在 nativeLanguageNames 中对应的母语写法
    /// （如 法语→Français、德语→Deutsch、简体中文→简体中文）；
    /// 仅当系统语言完全不在应用支持的语言列表内时，才回落「简体中文」兜底。
    private static func deviceLanguageBasedSecondSubtitleName() -> String {
        let raw = Locale.preferredLanguages.first ?? "en"
        // 完整匹配（如 zh-Hans / zh-Hant / pt-PT）
        if let name = nativeLanguageNames[raw] {
            return name
        }
        // 仅取语言码匹配（如 fr-FR → fr → Français）
        let base = raw.components(separatedBy: "-").first?.lowercased() ?? raw.lowercased()
        if let name = nativeLanguageNames[base] {
            return name
        }
        // 系统语言不在应用支持列表内时的兜底（通常不会触发）
        return "简体中文"
    }

    /// 首次启动时为第二字幕写入「设备系统语言」对应的默认值，并持久化到本地。
    /// - 仅当本地尚未存储过该值（全新安装）时写入；已存过（含用户改过的）一律跳过，绝不覆盖。
    /// - 需在 App 启动最早阶段（PeraperaApp.init）调用一次。
    static func ensureSecondSubtitleDefault() {
        guard let stored = PUserDefault.getVauleForKey(key: secondSubtitleKey) as? String,
              !stored.isEmpty else {
            let defaultName = deviceLanguageBasedSecondSubtitleName()
            PUserDefault.setValueForKey(defaultName, key: secondSubtitleKey)
            return
        }
        // 已存在值，保持不动（包含用户后续修改过的结果）
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

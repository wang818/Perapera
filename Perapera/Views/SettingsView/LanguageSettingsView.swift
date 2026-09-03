import SwiftUI
import Combine
import RxSwift
import Moya

/// 目标语言选择界面的接口数据源：
/// GET https://www.perapera.cc/api/v1/common/target_lang，返回 [{"name": "日本語", "lang": "ja"}]
/// 本地缓存优先：进入界面先展示上次缓存的数据，再请求接口刷新到最新并覆盖缓存；
/// 接口数据只存在本 VM 内、只供目标语言列表使用，绝不回写 LanguageManager；
/// 设置界面各行的显示固定读 LanguageManager.nativeLanguageNames，两套数据不共享。
final class LearningLanguageAPIViewModel: ObservableObject {
    /// 接口返回的语言列表（仅本界面使用）
    @Published var supportLangs: [SupportLanguageModel] = []
    private let disposeBag = DisposeBag()
    private let cacheKey = "cache_target_lang"

    /// 进入界面时调用：先展示本地缓存（无缓存则为空，等接口返回），再请求接口更新到最新
    func fetchIfNeeded() {
        if let cached = LearningLanguageAPIViewModel.loadCache(cacheKey), !cached.isEmpty {
            supportLangs = cached
        }
        appApi.rx.request(.targetLang)
            .asObservable()
            .mapArray(SupportLanguageModel.self)
            .subscribe(onNext: { [weak self] models in
                guard let self = self, !models.isEmpty else { return }
                self.supportLangs = models
                LearningLanguageAPIViewModel.saveCache(models, cacheKey)
            }, onError: { _ in
            })
            .disposed(by: disposeBag)
    }

    // MARK: - 本地缓存（JSON Data 形式存入 UserDefaults）
    private static func loadCache(_ key: String) -> [SupportLanguageModel]? {
        guard let data = PUserDefault.getVauleForKey(key: key) as? Data,
              let array = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else {
            return nil
        }
        return array.compactMap { dict -> SupportLanguageModel? in
            let model = SupportLanguageModel()
            model.name = dict["name"] as? String ?? ""
            model.lang = dict["lang"] as? String ?? ""
            return model
        }
    }

    private static func saveCache(_ models: [SupportLanguageModel], _ key: String) {
        let array: [[String: Any]] = models.map { ["name": $0.name, "lang": $0.lang] }
        guard let data = try? JSONSerialization.data(withJSONObject: array) else { return }
        PUserDefault.setValueForKey(data, key: key)
    }
}

/// User interface（App Language）选择界面的接口数据源：
/// GET https://www.perapera.cc/api/v1/common/support_lang，返回 [{"name": "日本語", "lang": "ja"}]
/// 本地缓存优先：进入界面先展示上次缓存的数据，再请求接口刷新到最新并覆盖缓存。
final class AppLanguageSupportViewModel: ObservableObject {
    /// 接口返回的语言列表（仅本界面使用）
    @Published var supportLangs: [SupportLanguageModel] = []
    private let disposeBag = DisposeBag()
    private let cacheKey = "cache_support_lang"

    /// 进入界面时调用：先展示本地缓存（无缓存则为空，等接口返回），再请求接口更新到最新
    func fetchIfNeeded() {
        if let cached = AppLanguageSupportViewModel.loadCache(cacheKey), !cached.isEmpty {
            supportLangs = cached
        }
        appApi.rx.request(.supportLang)
            .asObservable()
            .mapArray(SupportLanguageModel.self)
            .subscribe(onNext: { [weak self] models in
                guard let self = self, !models.isEmpty else { return }
                self.supportLangs = models
                AppLanguageSupportViewModel.saveCache(models, cacheKey)
            }, onError: { _ in
            })
            .disposed(by: disposeBag)
    }

    // MARK: - 本地缓存（JSON Data 形式存入 UserDefaults）
    private static func loadCache(_ key: String) -> [SupportLanguageModel]? {
        guard let data = PUserDefault.getVauleForKey(key: key) as? Data,
              let array = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else {
            return nil
        }
        return array.compactMap { dict -> SupportLanguageModel? in
            let model = SupportLanguageModel()
            model.name = dict["name"] as? String ?? ""
            model.lang = dict["lang"] as? String ?? ""
            return model
        }
    }

    private static func saveCache(_ models: [SupportLanguageModel], _ key: String) {
        let array: [[String: Any]] = models.map { ["name": $0.name, "lang": $0.lang] }
        guard let data = try? JSONSerialization.data(withJSONObject: array) else { return }
        PUserDefault.setValueForKey(data, key: key)
    }
}

/// Second Subtitle（第二字幕语言）选择界面的接口数据源：
/// GET https://www.perapera.cc/api/v1/common/support_second_lang，返回 [{"name": "日本語", "lang": "ja"}]
/// 本地缓存优先：进入界面先展示上次缓存的数据，再请求接口刷新到最新并覆盖缓存。
final class SecondSubtitleSupportViewModel: ObservableObject {
    /// 接口返回的语言列表（仅本界面使用）
    @Published var supportLangs: [SupportLanguageModel] = []
    private let disposeBag = DisposeBag()
    private let cacheKey = "cache_support_second_lang"

    /// 进入界面时调用：先展示本地缓存（无缓存则为空，等接口返回），再请求接口更新到最新
    func fetchIfNeeded() {
        if let cached = SecondSubtitleSupportViewModel.loadCache(cacheKey), !cached.isEmpty {
            supportLangs = cached
        }
        appApi.rx.request(.supportSecondLang)
            .asObservable()
            .mapArray(SupportLanguageModel.self)
            .subscribe(onNext: { [weak self] models in
                guard let self = self, !models.isEmpty else { return }
                self.supportLangs = models
                SecondSubtitleSupportViewModel.saveCache(models, cacheKey)
            }, onError: { _ in
            })
            .disposed(by: disposeBag)
    }

    // MARK: - 本地缓存（JSON Data 形式存入 UserDefaults）
    private static func loadCache(_ key: String) -> [SupportLanguageModel]? {
        guard let data = PUserDefault.getVauleForKey(key: key) as? Data,
              let array = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else {
            return nil
        }
        return array.compactMap { dict -> SupportLanguageModel? in
            let model = SupportLanguageModel()
            model.name = dict["name"] as? String ?? ""
            model.lang = dict["lang"] as? String ?? ""
            return model
        }
    }

    private static func saveCache(_ models: [SupportLanguageModel], _ key: String) {
        let array: [[String: Any]] = models.map { ["name": $0.name, "lang": $0.lang] }
        guard let data = try? JSONSerialization.data(withJSONObject: array) else { return }
        PUserDefault.setValueForKey(data, key: key)
    }
}

struct LanguageSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    // 各行右侧的显示数据源统一为 LanguageManager.nativeLanguageNames（本地固定表），
    // 与目标语言选择界面的 support_lang 接口数据完全独立、不共享。
    // App Language 行右侧显示语言原文（不做多语言适配，选择什么就显示什么）
    @State private var appLanguage = LanguageManager.getCurrentAppLanguageNative()
    @State private var aiLanguage = LanguageManager.nativeName(forSettingKey: AppKeys.aiLanguage)
    @State private var sourceLanguage = LanguageManager.getSecondSubtitleLanguageName()
    @State private var learningLanguage = LanguageManager.nativeName(forSettingKey: AppKeys.learningLanguage)
    
    @State private var showAppLanguageSelection = false
    @State private var showAILanguageSelection = false
    @State private var showSourceLanguageSelection = false
    @State private var showLearningLanguageSelection = false
    
    var body: some View {
        List {
            Section {
                languageRow(
                    title: "settings_lang_app_title".localized(),
                    subtitle: "settings_lang_app_subtitle".localized(),
                    currentValue: appLanguage
                ) {
                    // Action for App Language
                    showAppLanguageSelection = true
                }
                
                // TODO: 暂时屏蔽「AI 讲解」选项（不删除代码，恢复时去掉下方注释即可）
                /*
                languageRow(
                    title: "settings_lang_ai_title".localized(),
                    subtitle: "settings_lang_ai_subtitle".localized(),
                    currentValue: aiLanguage
                ) {
                    // Action for AI Explanation Language
                    showAILanguageSelection = true
                }
                */
                
                languageRow(
                    title: "settings_lang_source_title".localized(),
                    subtitle: "settings_lang_source_subtitle".localized(),
                    currentValue: sourceLanguage
                ) {
                    // Action for Second Subtitle (Source Language)
                    showSourceLanguageSelection = true
                }
                
                languageRow(
                    title: "settings_lang_learn_title".localized(),
                    subtitle: "settings_lang_learn_subtitle".localized(),
                    currentValue: learningLanguage
                ) {
                    // Action for Target Language (Learning Language)
                    showLearningLanguageSelection = true
                }
            }
        }
        .navigationTitle("settings_language_title".localized())
        .listStyle(InsetGroupedListStyle())
        .onAppear {
            appLanguage = LanguageManager.getCurrentAppLanguageNative()
            aiLanguage = LanguageManager.nativeName(forSettingKey: AppKeys.aiLanguage)
            sourceLanguage = LanguageManager.getSecondSubtitleLanguageName()
            learningLanguage = LanguageManager.nativeName(forSettingKey: AppKeys.learningLanguage)
        }
        .sheet(isPresented: $showAppLanguageSelection) {
            LanguageSelectionSheet(
                isPresented: $showAppLanguageSelection,
                currentLanguage: $appLanguage,
                type: .app
            )
        }
        .sheet(isPresented: $showAILanguageSelection) {
            LanguageSelectionSheet(
                isPresented: $showAILanguageSelection,
                currentLanguage: $aiLanguage,
                type: .ai
            )
        }
        .sheet(isPresented: $showSourceLanguageSelection) {
            LanguageSelectionSheet(
                isPresented: $showSourceLanguageSelection,
                currentLanguage: $sourceLanguage,
                type: .source
            )
        }
        .sheet(isPresented: $showLearningLanguageSelection) {
            LanguageSelectionSheet(
                isPresented: $showLearningLanguageSelection,
                currentLanguage: $learningLanguage,
                type: .learning
            )
        }
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

enum LanguageSelectionType {
    case app
    case ai
    case source
    case learning
    case youtube
    case secondSubtitle
}

/// 列表行数据模型：封装语言代码与显示名，遵循 Identifiable 以直接用于 ForEach
private struct LanguageOption: Identifiable {
    let id: String    // 语言代码（lang），作唯一标识
    let key: String   // 语言代码
    let value: String // 显示名
}

struct LanguageSelectionSheet: View {
    @Binding var isPresented: Bool
    @Binding var currentLanguage: String
    var type: LanguageSelectionType = .app

    // 目标语言（.learning）专用接口数据源，与本地数据不共享
    @StateObject private var learningVM = LearningLanguageAPIViewModel()
    // User interface（.app）专用接口数据源（本地缓存优先 + 后台刷新）
    @StateObject private var appSupportVM = AppLanguageSupportViewModel()
    // Second Subtitle（.source）专用接口数据源（本地缓存优先 + 后台刷新）
    @StateObject private var secondSubVM = SecondSubtitleSupportViewModel()

    private var languages: [LanguageOption] {
        switch type {
        case .app:
            // User interface：数据来自 common/support_lang 接口（本地优先 + 后台刷新）
            return appSupportVM.supportLangs.map { LanguageOption(id: $0.lang, key: $0.lang, value: $0.name) }
        case .source:
            // Second Subtitle：数据来自 common/support_second_lang 接口（本地优先 + 后台刷新）
            return secondSubVM.supportLangs.map { LanguageOption(id: $0.lang, key: $0.lang, value: $0.name) }
        case .learning:
            // 目标语言：数据来自 common/target_lang 接口（本地优先 + 后台刷新）
            return learningVM.supportLangs.map { LanguageOption(id: $0.lang, key: $0.lang, value: $0.name) }
        default:
            // 其余类型（AI / YouTube / 第二字幕设置等）：数据一律来自本地 nativeLanguageNames。
            // 注意：不读 LanguageManager.supportLanguages / languageNames ——
            // 这两份数据会被 support_lang 接口回写污染，用户界面不能用。
            return LanguageManager.nativeLanguageNames.sorted(by: { $0.key < $1.key }).map { LanguageOption(id: $0.key, key: $0.key, value: $0.value) }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(titleForType(type))
                .foregroundColor(.ex.text1)
                .font(.headline)
                .padding(.top, 40)
                .padding(.leading, 25)
            
            Text(subtitleForType(type))
                .foregroundColor(.ex.text1)
                .font(.subheadline)
                .padding(.leading, 25)
                .padding(.bottom, 20)
            
            ScrollView {
                VStack(spacing: 15) {
                    ForEach(languages, id: \.id) { option in
                        LanguageOptionRow(
                            option: option,
                            type: type,
                            currentLanguage: $currentLanguage,
                            isPresented: $isPresented,
                            onSelect: {
                                updateLanguage(key: option.key, type: type)
                                // App Language / 目标语言：行右侧显示数据源为 nativeLanguageNames（语言原文），
                                // 与列表来源（本地表或接口）无关，保证用户界面数据始终来自本地；
                                // 其余类型（AI / YouTube / 第二字幕设置）保持列表展示名（本地化名）。
                                currentLanguage = (type == .app || type == .learning || type == .source)
                                    ? LanguageManager.nativeLanguageName(for: option.key)
                                    : option.value
                                isPresented = false
                            }
                        )
                    }
                }
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            // User interface：进入即展示本地缓存，同时请求接口更新到最新
            if type == .app {
                appSupportVM.fetchIfNeeded()
            } else if type == .source {
                // Second Subtitle：进入即展示本地缓存，同时请求接口更新到最新
                secondSubVM.fetchIfNeeded()
            } else if type == .learning {
                // 目标语言：进入即展示本地缓存，同时请求接口更新到最新
                learningVM.fetchIfNeeded()
            }
        }
    }
    
    private func titleForType(_ type: LanguageSelectionType) -> String {
        switch type {
        case .app: return "settings_lang_app_title".localized()
        case .ai: return "settings_lang_ai_title".localized()
        case .source: return "settings_lang_source_title".localized()
        case .learning: return "settings_lang_learn_title".localized()
        case .youtube: return "settings_subtitle_youtube_title".localized()
        case .secondSubtitle: return "settings_subtitle_second_title".localized()
        }
    }
    
    private func subtitleForType(_ type: LanguageSelectionType) -> String {
        switch type {
        case .app: return "settings_lang_app_subtitle".localized()
        case .ai: return "settings_lang_ai_subtitle".localized()
        case .source: return "settings_lang_source_subtitle".localized()
        case .learning: return "settings_lang_learn_subtitle".localized()
        case .youtube: return "settings_subtitle_youtube_subtitle".localized()
        case .secondSubtitle: return "settings_subtitle_second_subtitle".localized()
        }
    }
    
    private func updateLanguage(key: String, type: LanguageSelectionType) {
        switch type {
        case .app:
            LanguageManager.setAppLanguage(key)
        case .ai:
            LanguageManager.setAILanguage(key)
        case .source:
            // 第二字幕语言：与字幕设置界面共用 subtitle_second_language（存原文名）
            LanguageManager.setSecondSubtitleLanguageName(LanguageManager.nativeLanguageName(for: key))
        case .learning:
            LanguageManager.setLearningLanguage(key)
        case .youtube, .secondSubtitle:
            // Handled via Binding in SubtitleSettingsView, no global manager update needed here
            // or if we want to sync with UserDefaults keys manually:
            break
        }
    }
}

/// 语言选择列表的单个行（抽出为独立 View，避免 ForEach 内容闭包过大
/// 触发 SwiftUI 类型推断退化到 Binding 重载的已知编译问题）。
private struct LanguageOptionRow: View {
    let option: LanguageOption
    let type: LanguageSelectionType
    @Binding var currentLanguage: String
    @Binding var isPresented: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Text(option.value)
                    .font(.headline)
                    .foregroundColor(.ex.text1)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color.ex("bg2"))
            .cornerRadius(10)
        }
        .padding(.horizontal, 25)
    }

    private var isSelected: Bool {
        switch type {
        case .app:
            return LanguageManager.currentLanguageCode() == option.key
        case .source:
            // 第二字幕语言：按已存的语言代码比对
            return LanguageManager.getSecondSubtitleLanguageCode() == option.key
        case .learning:
            return (PUserDefault.getVauleForKey(key: AppKeys.learningLanguage) as? String) == option.key
        default:
            return currentLanguage == option.value
        }
    }
}

#Preview {
    NavigationView {
        LanguageSettingsView()
    }
}

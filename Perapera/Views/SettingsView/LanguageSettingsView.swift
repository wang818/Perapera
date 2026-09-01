import SwiftUI
import Combine
import RxSwift
import Moya

/// 目标语言选择界面的接口数据源：
/// GET https://www.perapera.cc/api/v1/common/support_lang，返回 [{"name": "日本語", "lang": "ja"}]
/// 接口数据只存在本 VM 内、只供目标语言列表使用，绝不回写 LanguageManager；
/// 设置界面各行的显示固定读 LanguageManager.nativeLanguageNames，两套数据不共享。
final class LearningLanguageAPIViewModel: ObservableObject {
    /// 接口返回的语言列表（仅本界面使用）
    @Published var supportLangs: [SupportLanguageModel] = []
    private let disposeBag = DisposeBag()
    private var hasFetched = false

    /// 请求接口；成功后只刷新本界面列表，失败静默保持本地兜底
    func fetchIfNeeded() {
        guard !hasFetched, supportLangs.isEmpty else {
            hasFetched = true
            return
        }
        hasFetched = true
        appApi.rx.request(.supportLang)
            .asObservable()
            .mapArray(SupportLanguageModel.self)
            .subscribe(onNext: { [weak self] models in
                guard let self = self, !models.isEmpty else { return }
                self.supportLangs = models
            }, onError: { _ in
            })
            .disposed(by: disposeBag)
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

struct LanguageSelectionSheet: View {
    @Binding var isPresented: Bool
    @Binding var currentLanguage: String
    var type: LanguageSelectionType = .app

    // 目标语言（.learning）专用接口数据源，与本地数据不共享
    @StateObject private var learningVM = LearningLanguageAPIViewModel()

    private var languages: [(key: String, value: String)] {
        // 目标语言：数据只来自 support_lang 接口，不读本地任何数据。
        // 接口未返回前列表为空（无本地兜底），返回后直接渲染接口数据。
        if type == .learning {
            return learningVM.supportLangs.map { ($0.lang, $0.name) }
        }
        // 其余类型：数据一律来自本地 nativeLanguageNames。
        // 注意：不读 LanguageManager.supportLanguages / languageNames ——
        // 这两份数据会被 support_lang 接口回写污染，用户界面不能用。
        return LanguageManager.nativeLanguageNames.sorted(by: { $0.key < $1.key })
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
                    ForEach(languages, id: \.key) { key, value in
                        Button(action: {
                            updateLanguage(key: key, type: type)
                            // App Language / 目标语言：行右侧显示数据源为 nativeLanguageNames（语言原文），
                            // 与列表来源（本地表或接口）无关，保证用户界面数据始终来自本地；
                            // 其余类型保持列表展示名（本地化名）。
                            currentLanguage = (type == .app || type == .learning)
                                ? LanguageManager.nativeLanguageName(for: key)
                                : value
                            isPresented = false
                        }) {
                            HStack {
                                Text(value)
                                    .font(.headline)
                                    .foregroundColor(.ex.text1)
                                Spacer()
                                // 勾选判断用语言代码比对：
                                // App Language → 当前 App 语言代码；目标语言 → 已存语言代码；
                                // 其余类型保持显示名比对
                                let isSelected = (type == .app)
                                    ? (LanguageManager.currentLanguageCode() == key)
                                    : (type == .learning)
                                        ? ((PUserDefault.getVauleForKey(key: AppKeys.learningLanguage) as? String) == key)
                                        : (currentLanguage == value)
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
                }
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            // 只有目标语言界面调用 support_lang 接口（数据不共享、不回写）
            if type == .learning {
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

#Preview {
    NavigationView {
        LanguageSettingsView()
    }
}

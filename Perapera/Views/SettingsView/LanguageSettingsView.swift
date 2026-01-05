import SwiftUI
import Combine

struct LanguageSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Placeholder states for current languages
    // In a real app, these would come from UserDefaults or a view model
    @State private var appLanguage = LanguageManager.getCurrentAppLanguage()
    @State private var aiLanguage = LanguageManager.getAILanguage()
    @State private var sourceLanguage = LanguageManager.getSourceLanguage()
    @State private var learningLanguage = LanguageManager.getLearningLanguage()
    
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
                
                languageRow(
                    title: "settings_lang_ai_title".localized(),
                    subtitle: "settings_lang_ai_subtitle".localized(),
                    currentValue: aiLanguage
                ) {
                    // Action for AI Explanation Language
                    showAILanguageSelection = true
                }
                
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
        .toolbarRole(.editor)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            appLanguage = LanguageManager.getCurrentAppLanguage()
            aiLanguage = LanguageManager.getAILanguage()
            sourceLanguage = LanguageManager.getSourceLanguage()
            learningLanguage = LanguageManager.getLearningLanguage()
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
}

struct LanguageSelectionSheet: View {
    @Binding var isPresented: Bool
    @Binding var currentLanguage: String
    var type: LanguageSelectionType = .app
    
    private var languages: [(key: String, value: String)] {
        if !LanguageManager.supportLanguages.isEmpty {
            return LanguageManager.supportLanguages.map { ($0.lang, $0.name) }
        }
        return LanguageManager.languageNames.sorted(by: { $0.key < $1.key })
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
                            currentLanguage = value
                            isPresented = false
                        }) {
                            HStack {
                                Text(value)
                                    .font(.headline)
                                    .foregroundColor(.ex.text1)
                                Spacer()
                                if currentLanguage == value {
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
        .presentationDetents([.height(500)])
        .presentationDragIndicator(.visible)
    }
    
    private func titleForType(_ type: LanguageSelectionType) -> String {
        switch type {
        case .app: return "settings_lang_app_title".localized()
        case .ai: return "settings_lang_ai_title".localized()
        case .source: return "settings_lang_source_title".localized()
        case .learning: return "settings_lang_learn_title".localized()
        }
    }
    
    private func subtitleForType(_ type: LanguageSelectionType) -> String {
        switch type {
        case .app: return "settings_lang_app_subtitle".localized()
        case .ai: return "settings_lang_ai_subtitle".localized()
        case .source: return "settings_lang_source_subtitle".localized()
        case .learning: return "settings_lang_learn_subtitle".localized()
        }
    }
    
    private func updateLanguage(key: String, type: LanguageSelectionType) {
        switch type {
        case .app:
            LanguageManager.setAppLanguage(key)
        case .ai:
            LanguageManager.setAILanguage(key)
        case .source:
            LanguageManager.setSourceLanguage(key)
        case .learning:
            LanguageManager.setLearningLanguage(key)
        }
    }
}

#Preview {
    NavigationStack {
        LanguageSettingsView()
    }
}

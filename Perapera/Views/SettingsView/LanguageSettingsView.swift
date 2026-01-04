import SwiftUI
import Combine

struct LanguageSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Placeholder states for current languages
    // In a real app, these would come from UserDefaults or a view model
    @State private var appLanguage = LanguageManager.getCurrentAppLanguage()
    @State private var aiLanguage = "American"
    @State private var sourceLanguage = "English"
    @State private var learningLanguage = "Japanese"
    
    @State private var showAppLanguageSelection = false
    
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
                    showAppLanguageSelection = true
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
        .sheet(isPresented: $showAppLanguageSelection) {
            LanguageSelectionSheet(
                isPresented: $showAppLanguageSelection,
                currentLanguage: $appLanguage
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

struct LanguageSelectionSheet: View {
    @Binding var isPresented: Bool
    @Binding var currentLanguage: String
    
    // Sort languages to ensure consistent order
    private let languages = LanguageManager.languageNames.sorted(by: { $0.key < $1.key })
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("settings_lang_app_title".localized())
                .foregroundColor(.ex.text1)
                .font(.headline)
                .padding(.top, 40)
                .padding(.leading, 25)
            
            Text("settings_lang_app_subtitle".localized())
                .foregroundColor(.ex.text1)
                .font(.subheadline)
                .padding(.leading, 25)
                .padding(.bottom, 20)
            
            ScrollView {
                VStack(spacing: 15) {
                    ForEach(languages, id: \.key) { key, value in
                        Button(action: {
                            LanguageManager.setAppLanguage(key)
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
}

#Preview {
    NavigationStack {
        LanguageSettingsView()
    }
}

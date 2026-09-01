import SwiftUI

struct SubtitleSettingsView: View {
    @AppStorage("subtitle_youtube_language") private var youtubeLanguage: String = "English"
    @AppStorage("subtitle_second_language") private var secondLanguage: String = "简体中文"
    @AppStorage("subtitle_show_two") private var showTwoSubtitles: Bool = true
    @AppStorage("subtitle_font_size") private var fontSize: String = "normal"
    
    @AppStorage("subtitle_focus_mode") private var focusMode: Bool = true
    
    @AppStorage("subtitle_show_romaji") private var showRomaji: Bool = true
    @AppStorage("subtitle_show_furigana") private var showFurigana: Bool = true
    @AppStorage("subtitle_show_pos") private var showPOS: Bool = true

    @AppStorage("subtitle_show_pinyin") private var showPinyin: Bool = false
    @AppStorage("subtitle_chinese_char_type") private var chineseCharType: String = "简体字"
    
    @State private var showYoutubeLanguageSelection = false
    @State private var showSecondLanguageSelection = false
    @State private var showFontSizeSelection = false
    
    private var availableLanguages: [(key: String, value: String)] {
        if !LanguageManager.supportLanguages.isEmpty {
            return LanguageManager.supportLanguages.map { ($0.lang, $0.name) }
        }
        return LanguageManager.languageNames.sorted(by: { $0.key < $1.key }).map { ($0.key, $0.value) }
    }
    
    /// 将存储的字体大小 key 映射为当前语言的显示标题
    private func fontSizeTitle(for key: String) -> String {
        switch key {
        case "small":  return "settings_subtitle_font_size_small".localized()
        case "medium": return "settings_subtitle_font_size_medium".localized()
        case "large":  return "settings_subtitle_font_size_large".localized()
        default:       return "settings_subtitle_font_size_normal".localized()
        }
    }
    
    var body: some View {
        List {
            // Section 1: General
            Section(header: Text("settings_subtitle_general_header".localized())) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("settings_subtitle_youtube_title".localized())
                            .font(.headline)
                        Text("settings_subtitle_youtube_subtitle".localized())
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Button(action: {
                        showYoutubeLanguageSelection = true
                    }) {
                        HStack {
                            Text(youtubeLanguage)
                                .foregroundColor(.gray)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("settings_subtitle_second_title".localized())
                            .font(.headline)
                        Text("settings_subtitle_second_subtitle".localized())
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Button(action: {
                        showSecondLanguageSelection = true
                    }) {
                        HStack {
                            Text(secondLanguage)
                                .foregroundColor(.gray)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Toggle(isOn: $showTwoSubtitles) {
                    VStack(alignment: .leading) {
                        Text("settings_subtitle_show_both_title".localized())
                            .font(.headline)
                        Text("settings_subtitle_show_both_subtitle".localized())
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .tint(.green)
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("settings_subtitle_font_size_title".localized())
                            .font(.headline)
                        Text(fontSizeTitle(for: fontSize))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    showFontSizeSelection = true
                }
            }
            
            // Section 2: Accessibility
            Section(header: Text("settings_subtitle_accessibility_header".localized())) {
                Toggle(isOn: $focusMode) {
                    VStack(alignment: .leading) {
                        Text("settings_subtitle_focus_mode_title".localized())
                            .font(.headline)
                        Text("settings_subtitle_focus_mode_subtitle".localized())
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .tint(.green)
            }
            
            // Section 3: Japanese Subtitles
            Section(header: Text("settings_subtitle_japanese_header".localized())) {
                Toggle(isOn: $showRomaji) {
                    VStack(alignment: .leading) {
                        Text("settings_subtitle_romaji_title".localized())
                            .font(.headline)
                        Text("settings_subtitle_romaji_subtitle".localized())
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .tint(.green)
                
                Toggle(isOn: $showFurigana) {
                    VStack(alignment: .leading) {
                        Text("settings_subtitle_furigana_title".localized())
                            .font(.headline)
                        Text("settings_subtitle_furigana_subtitle".localized())
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .tint(.green)
                
                Toggle(isOn: $showPOS) {
                    VStack(alignment: .leading) {
                        Text("settings_subtitle_pos_title".localized())
                            .font(.headline)
                        Text("settings_subtitle_pos_subtitle".localized())
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .tint(.green)
            }
            
            // Section 4: Chinese Subtitles
            Section(header: Text("settings_subtitle_chinese_header".localized())) {
                Toggle(isOn: $showPinyin) {
                    VStack(alignment: .leading) {
                        Text("settings_subtitle_pinyin_title".localized())
                            .font(.headline)
                        Text("settings_subtitle_pinyin_subtitle".localized())
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .tint(.green)
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("settings_subtitle_chinese_char_title".localized())
                            .font(.headline)
                        Text("settings_subtitle_chinese_char_subtitle".localized())
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Menu {
                        Button("简体字", action: { chineseCharType = "简体字" })
                        Button("繁體字", action: { chineseCharType = "繁體字" })
                    } label: {
                        HStack {
                            Text(chineseCharType)
                                .foregroundColor(.gray)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
        }
        .navigationTitle("settings_subtitle_title".localized())
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showYoutubeLanguageSelection) {
            LanguageSelectionSheet(
                isPresented: $showYoutubeLanguageSelection,
                currentLanguage: $youtubeLanguage,
                type: .youtube
            )
        }
        .sheet(isPresented: $showSecondLanguageSelection) {
            LanguageSelectionSheet(
                isPresented: $showSecondLanguageSelection,
                currentLanguage: $secondLanguage,
                type: .secondSubtitle
            )
        }
        .sheet(isPresented: $showFontSizeSelection) {
            FontSizeSelectionView(selectedFontSize: $fontSize)
        }
    }
}

#Preview {
    SubtitleSettingsView()
}

// MARK: - 字体大小选择界面
struct FontSizeSelectionView: View {
    @Binding var selectedFontSize: String
    @Environment(\.dismiss) private var dismiss
    
    private let options: [(key: String, titleKey: String)] = [
        ("small",  "settings_subtitle_font_size_small"),
        ("medium", "settings_subtitle_font_size_medium"),
        ("normal", "settings_subtitle_font_size_normal"),
        ("large",  "settings_subtitle_font_size_large")
    ]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("settings_subtitle_font_size_title".localized())
                .foregroundColor(.ex.text1)
                .font(.headline)
                .padding(.top, 40)
                .padding(.leading, 25)
            
            Text("settings_subtitle_font_size_subtitle".localized())
                .foregroundColor(.ex.text1)
                .font(.subheadline)
                .padding(.leading, 25)
                .padding(.bottom, 20)
            
            ScrollView {
                VStack(spacing: 15) {
                    ForEach(options, id: \.key) { option in
                        Button(action: {
                            selectedFontSize = option.key
                            dismiss()
                        }) {
                            HStack {
                                Text(option.titleKey.localized())
                                    .font(.headline)
                                    .foregroundColor(.ex.text1)
                                Spacer()
                                if selectedFontSize == option.key {
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
    }
}

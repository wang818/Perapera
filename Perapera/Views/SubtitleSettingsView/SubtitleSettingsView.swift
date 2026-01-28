import SwiftUI

struct SubtitleSettingsView: View {
    @AppStorage("subtitle_youtube_language") private var youtubeLanguage: String = "English"
    @AppStorage("subtitle_second_language") private var secondLanguage: String = "简体中文"
    @AppStorage("subtitle_show_two") private var showTwoSubtitles: Bool = true
    @AppStorage("subtitle_font_size") private var fontSize: String = "正常"
    
    @AppStorage("subtitle_focus_mode") private var focusMode: Bool = true
    
    @AppStorage("subtitle_show_romaji") private var showRomaji: Bool = true
    @AppStorage("subtitle_show_furigana") private var showFurigana: Bool = true
    @AppStorage("subtitle_show_pos") private var showPOS: Bool = true
    @AppStorage("subtitle_show_semantics") private var showSemantics: Bool = true
    @AppStorage("subtitle_enable_gaya") private var enableGaya: Bool = false
    
    @AppStorage("subtitle_show_pinyin") private var showPinyin: Bool = false
    @AppStorage("subtitle_chinese_char_type") private var chineseCharType: String = "简体字"
    
    @State private var showYoutubeLanguageSelection = false
    @State private var showSecondLanguageSelection = false
    
    private var availableLanguages: [(key: String, value: String)] {
        if !LanguageManager.supportLanguages.isEmpty {
            return LanguageManager.supportLanguages.map { ($0.lang, $0.name) }
        }
        return LanguageManager.languageNames.sorted(by: { $0.key < $1.key }).map { ($0.key, $0.value) }
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
                        Text(fontSize)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
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
                
                Toggle(isOn: $showSemantics) {
                    VStack(alignment: .leading) {
                        Text("settings_subtitle_semantics_title".localized())
                            .font(.headline)
                        Text("settings_subtitle_semantics_subtitle".localized())
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .tint(.green)
                
                Toggle(isOn: $enableGaya) {
                    VStack(alignment: .leading) {
                        Text("settings_subtitle_gaya_title".localized())
                            .font(.headline)
                        Text("settings_subtitle_gaya_subtitle".localized())
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
    }
}

#Preview {
    SubtitleSettingsView()
}

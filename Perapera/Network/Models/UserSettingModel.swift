//
//  UserSettingModel.swift
//  Perapera
//
//  Maps the PeraperaServer `UserSettingResponse` / `UserSettingUpdate` schemas.
//  Field names are kept snake_case to match the backend JSON directly.
//

import Foundation
import HandyJSON

class UserSettingModel: HandyJSON {
    // Identity (always present in GET responses)
    var id: Int = 0
    var user_uuid: String = ""
    var created_at: String = ""

    // Language settings (the four consumed by the Language settings page)
    var app_lang: String = "en"                 // App / UI language
    var app_explan_lang: String = "en"         // AI explanation language
    var app_second_subtitle: String = "en"     // Second subtitle language
    var app_target_lang: String = "en"         // Target / learning language

    // Subtitle settings
    var sub_youtube: String = "en"
    var sub_second: String = "en"
    var sub_both: Bool = true
    var sub_font_size: String = "regular"      // small | regular | medium | large
    var sub_focus_mode: Bool = false
    var sub_jp_romaji: Bool = true
    var sub_jp_furigana: Bool = true
    var sub_jp_speech_part: Bool = true
    var sub_jp_semantic: Bool = true
    var sub_jp_gaya: Bool = true
    var sub_zh_pinyin: Bool = true
    var sub_zh_character: String = "simplified" // simplified | traditional

    // Echo settings
    var echo_listen: Bool = false
    var echo_echo: Bool = false
    var echo_delay: Bool = false
    var echo_speak: Bool = false
    var echo_play: Bool = false

    // Appearance
    var theme: String = "system"               // system | light | dark

    required init() {}
}

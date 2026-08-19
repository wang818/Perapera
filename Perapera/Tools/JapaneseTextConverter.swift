//
//  JapaneseTextConverter.swift
//  Perapera
//
//  Created by Perapera on 2025.
//

import Foundation

/// 日文文本 → 罗马音 / 假名的机械转换器
/// 使用 CFStringTokenizer 获取拉丁转写（romaji），再通过 CFStringTransform 转为平假名（furigana）
class JapaneseTextConverter {
    static let shared = JapaneseTextConverter()

    private init() {}

    // MARK: - Public Methods

    /// 将日文文本转换为罗马音（romaji）
    /// - Parameter text: 日文文本（可包含汉字、平假名、片假名）
    /// - Returns: 罗马音字符串
    func toRomaji(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        // 标点符号等非日文字符直接返回原文
        if isPunctuationOrSymbol(trimmed) {
            return trimmed
        }

        let locale = NSLocale(localeIdentifier: "ja") as CFLocale
        let range = CFRangeMake(0, trimmed.utf16.count)
        guard let tokenizer = CFStringTokenizerCreate(nil, trimmed as CFString, range, kCFStringTokenizerUnitWord, locale) else {
            return trimmed
        }

        var result = ""
        var tokenType = CFStringTokenizerGoToTokenAtIndex(tokenizer, 0)

        while tokenType != [] {
            if let latin = CFStringTokenizerCopyCurrentTokenAttribute(tokenizer, kCFStringTokenizerAttributeLatinTranscription) as? String {
                result += latin
            }
            tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer)
        }

        return result.isEmpty ? trimmed : result
    }

    /// 将日文文本转换为平假名（furigana）
    /// 流程：日文 → romaji → katakana → hiragana
    /// - Parameter text: 日文文本
    /// - Returns: 平假名字符串
    func toHiragana(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        if isPunctuationOrSymbol(trimmed) {
            return trimmed
        }

        let romaji = toRomaji(trimmed)
        return romajiToHiragana(romaji)
    }

    /// 将日文文本转换为片假名（katakana）
    /// 流程：日文 → romaji → katakana（不转平假名）
    /// - Parameter text: 日文文本
    /// - Returns: 片假名字符串
    func toKatakana(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        if isPunctuationOrSymbol(trimmed) {
            return trimmed
        }

        let romaji = toRomaji(trimmed)
        let mutable = NSMutableString(string: romaji.lowercased())
        // 罗马音 → 片假名（不做平假名转换）
        CFStringTransform(mutable, nil, kCFStringTransformLatinKatakana, false)
        return mutable as String
    }

    // MARK: - Private Methods

    /// 将罗马音转换为平假名
    /// romaji → katakana → hiragana
    private func romajiToHiragana(_ romaji: String) -> String {
        let mutable = NSMutableString(string: romaji.lowercased())
        // 第一步：罗马音 → 片假名
        CFStringTransform(mutable, nil, kCFStringTransformLatinKatakana, false)
        // 第二步：片假名 → 平假名
        CFStringTransform(mutable, nil, kCFStringTransformHiraganaKatakana, true)
        return mutable as String
    }

    /// 判断字符串是否仅包含标点符号或空白
    private func isPunctuationOrSymbol(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(
            in: CharacterSet.punctuationCharacters
                .union(.symbols)
                .union(.whitespacesAndNewlines)
        )
        return trimmed.isEmpty
    }
}

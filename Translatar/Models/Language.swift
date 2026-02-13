// Language.swift
// Translatar - AI实时翻译耳机应用
//
// 定义支持的语言列表和语言数据模型
// 每种语言包含显示名称、语言代码和对应的国旗Emoji

import Foundation

/// 支持的语言枚举
/// 初期支持10种主流语言，覆盖全球主要旅行目的地
enum SupportedLanguage: String, CaseIterable, Identifiable, Codable {
    case english = "en"
    case chinese = "zh"
    case japanese = "ja"
    case korean = "ko"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case portuguese = "pt"
    case russian = "ru"
    
    var id: String { rawValue }
    
    /// 语言的本地化显示名称
    var displayName: String {
        switch self {
        case .english: return "English"
        case .chinese: return "中文"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .spanish: return "Español"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .italian: return "Italiano"
        case .portuguese: return "Português"
        case .russian: return "Русский"
        }
    }
    
    /// 语言的中文名称（方便用户理解）
    var chineseName: String {
        switch self {
        case .english: return "英语"
        case .chinese: return "中文"
        case .japanese: return "日语"
        case .korean: return "韩语"
        case .spanish: return "西班牙语"
        case .french: return "法语"
        case .german: return "德语"
        case .italian: return "意大利语"
        case .portuguese: return "葡萄牙语"
        case .russian: return "俄语"
        }
    }
    
    /// 对应的国旗/地区Emoji
    var flag: String {
        switch self {
        case .english: return "🇺🇸"
        case .chinese: return "🇨🇳"
        case .japanese: return "🇯🇵"
        case .korean: return "🇰🇷"
        case .spanish: return "🇪🇸"
        case .french: return "🇫🇷"
        case .german: return "🇩🇪"
        case .italian: return "🇮🇹"
        case .portuguese: return "🇧🇷"
        case .russian: return "🇷🇺"
        }
    }
    
    /// 用于OpenAI API的完整语言名称（英文）
    var englishName: String {
        switch self {
        case .english: return "English"
        case .chinese: return "Chinese (Mandarin)"
        case .japanese: return "Japanese"
        case .korean: return "Korean"
        case .spanish: return "Spanish"
        case .french: return "French"
        case .german: return "German"
        case .italian: return "Italian"
        case .portuguese: return "Portuguese"
        case .russian: return "Russian"
        }
    }
}

/// 翻译配置模型
/// 存储用户选择的源语言和目标语言
struct TranslationConfig: Codable {
    var sourceLanguage: SupportedLanguage  // 对方说的语言（需要被翻译的语言）
    var targetLanguage: SupportedLanguage  // 用户的母语（翻译成的语言）
    
    /// 默认配置：英语 → 中文
    static let defaultConfig = TranslationConfig(
        sourceLanguage: .english,
        targetLanguage: .chinese
    )
}

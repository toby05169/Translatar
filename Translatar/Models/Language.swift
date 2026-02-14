// Language.swift
// Translatar - AI实时翻译耳机应用
//
// 定义支持的语言列表和语言数据模型
// 每种语言包含显示名称、语言代码、对应的国旗Emoji和文字标签
// 支持30+种主流语言和小语种，覆盖全球主要旅行目的地

import Foundation

/// 支持的语言枚举
/// 覆盖主流语言、亚洲语言、中文方言、欧洲语言、中东语言等
enum SupportedLanguage: String, CaseIterable, Identifiable, Codable {
    // === 东亚语言 ===
    case chinese = "zh"           // 中文（普通话）
    case cantonese = "yue"        // 粤语（广东话）
    case hokkien = "nan"          // 闽南语（福建话/台语）
    case japanese = "ja"          // 日语
    case korean = "ko"            // 韩语
    
    // === 东南亚语言 ===
    case thai = "th"              // 泰语
    case vietnamese = "vi"        // 越南语
    case burmese = "my"           // 缅甸语
    case indonesian = "id"        // 印尼语
    case malay = "ms"             // 马来语
    case tagalog = "tl"           // 菲律宾语（他加禄语）
    case khmer = "km"             // 柬埔寨语（高棉语）
    case lao = "lo"               // 老挝语
    
    // === 南亚语言 ===
    case hindi = "hi"             // 印地语
    case bengali = "bn"           // 孟加拉语
    case tamil = "ta"             // 泰米尔语
    case urdu = "ur"              // 乌尔都语
    
    // === 欧美语言 ===
    case english = "en"           // 英语
    case spanish = "es"           // 西班牙语
    case portuguese = "pt"        // 葡萄牙语
    case french = "fr"            // 法语
    case german = "de"            // 德语
    case italian = "it"           // 意大利语
    case russian = "ru"           // 俄语
    case dutch = "nl"             // 荷兰语
    case polish = "pl"            // 波兰语
    case turkish = "tr"           // 土耳其语
    case greek = "el"             // 希腊语
    case swedish = "sv"           // 瑞典语
    
    // === 中东/非洲语言 ===
    case arabic = "ar"            // 阿拉伯语
    case hebrew = "he"            // 希伯来语
    case persian = "fa"           // 波斯语
    case swahili = "sw"           // 斯瓦希里语
    
    var id: String { rawValue }
    
    /// 语言的本地化显示名称（该语言的母语写法）
    var displayName: String {
        switch self {
        case .chinese: return "中文"
        case .cantonese: return "粵語"
        case .hokkien: return "閩南語"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .thai: return "ไทย"
        case .vietnamese: return "Tiếng Việt"
        case .burmese: return "မြန်မာ"
        case .indonesian: return "Bahasa Indonesia"
        case .malay: return "Bahasa Melayu"
        case .tagalog: return "Filipino"
        case .khmer: return "ខ្មែរ"
        case .lao: return "ລາວ"
        case .hindi: return "हिन्दी"
        case .bengali: return "বাংলা"
        case .tamil: return "தமிழ்"
        case .urdu: return "اردو"
        case .english: return "English"
        case .spanish: return "Español"
        case .portuguese: return "Português"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .italian: return "Italiano"
        case .russian: return "Русский"
        case .dutch: return "Nederlands"
        case .polish: return "Polski"
        case .turkish: return "Türkçe"
        case .greek: return "Ελληνικά"
        case .swedish: return "Svenska"
        case .arabic: return "العربية"
        case .hebrew: return "עברית"
        case .persian: return "فارسی"
        case .swahili: return "Kiswahili"
        }
    }
    
    /// 语言的中文名称（方便中文用户理解）
    var chineseName: String {
        switch self {
        case .chinese: return "中文"
        case .cantonese: return "粤语"
        case .hokkien: return "闽南语"
        case .japanese: return "日语"
        case .korean: return "韩语"
        case .thai: return "泰语"
        case .vietnamese: return "越南语"
        case .burmese: return "缅甸语"
        case .indonesian: return "印尼语"
        case .malay: return "马来语"
        case .tagalog: return "菲律宾语"
        case .khmer: return "柬埔寨语"
        case .lao: return "老挝语"
        case .hindi: return "印地语"
        case .bengali: return "孟加拉语"
        case .tamil: return "泰米尔语"
        case .urdu: return "乌尔都语"
        case .english: return "英语"
        case .spanish: return "西班牙语"
        case .portuguese: return "葡萄牙语"
        case .french: return "法语"
        case .german: return "德语"
        case .italian: return "意大利语"
        case .russian: return "俄语"
        case .dutch: return "荷兰语"
        case .polish: return "波兰语"
        case .turkish: return "土耳其语"
        case .greek: return "希腊语"
        case .swedish: return "瑞典语"
        case .arabic: return "阿拉伯语"
        case .hebrew: return "希伯来语"
        case .persian: return "波斯语"
        case .swahili: return "斯瓦希里语"
        }
    }
    
    /// 对应的国旗/地区Emoji
    var flag: String {
        switch self {
        case .chinese: return "🇨🇳"
        case .cantonese: return "🇭🇰"
        case .hokkien: return "🇹🇼"
        case .japanese: return "🇯🇵"
        case .korean: return "🇰🇷"
        case .thai: return "🇹🇭"
        case .vietnamese: return "🇻🇳"
        case .burmese: return "🇲🇲"
        case .indonesian: return "🇮🇩"
        case .malay: return "🇲🇾"
        case .tagalog: return "🇵🇭"
        case .khmer: return "🇰🇭"
        case .lao: return "🇱🇦"
        case .hindi: return "🇮🇳"
        case .bengali: return "🇧🇩"
        case .tamil: return "🇱🇰"
        case .urdu: return "🇵🇰"
        case .english: return "🇺🇸"
        case .spanish: return "🇪🇸"
        case .portuguese: return "🇧🇷"
        case .french: return "🇫🇷"
        case .german: return "🇩🇪"
        case .italian: return "🇮🇹"
        case .russian: return "🇷🇺"
        case .dutch: return "🇳🇱"
        case .polish: return "🇵🇱"
        case .turkish: return "🇹🇷"
        case .greek: return "🇬🇷"
        case .swedish: return "🇸🇪"
        case .arabic: return "🇸🇦"
        case .hebrew: return "🇮🇱"
        case .persian: return "🇮🇷"
        case .swahili: return "🇰🇪"
        }
    }
    
    /// 本地化的语言名称（根据App当前语言显示对应文字）
    var localizedName: String {
        let locale = Locale.current
        switch self {
        case .cantonese:
            return String(localized: "lang.name.cantonese", defaultValue: "粤语")
        case .hokkien:
            return String(localized: "lang.name.hokkien", defaultValue: "闽南语")
        default:
            if let name = locale.localizedString(forLanguageCode: self.rawValue) {
                return name.prefix(1).uppercased() + name.dropFirst()
            }
            return chineseName
        }
    }
    
    /// 国旗+文字的组合显示（用于UI中确保用户能识别语言）
    var flagWithName: String {
        return "\(flag) \(localizedName)"
    }
    
    /// 用于OpenAI API的完整语言名称（英文）
    var englishName: String {
        switch self {
        case .chinese: return "Chinese (Mandarin)"
        case .cantonese: return "Chinese (Cantonese)"
        case .hokkien: return "Chinese (Hokkien/Taiwanese)"
        case .japanese: return "Japanese"
        case .korean: return "Korean"
        case .thai: return "Thai"
        case .vietnamese: return "Vietnamese"
        case .burmese: return "Burmese (Myanmar)"
        case .indonesian: return "Indonesian"
        case .malay: return "Malay"
        case .tagalog: return "Filipino (Tagalog)"
        case .khmer: return "Khmer (Cambodian)"
        case .lao: return "Lao"
        case .hindi: return "Hindi"
        case .bengali: return "Bengali"
        case .tamil: return "Tamil"
        case .urdu: return "Urdu"
        case .english: return "English"
        case .spanish: return "Spanish"
        case .portuguese: return "Portuguese"
        case .french: return "French"
        case .german: return "German"
        case .italian: return "Italian"
        case .russian: return "Russian"
        case .dutch: return "Dutch"
        case .polish: return "Polish"
        case .turkish: return "Turkish"
        case .greek: return "Greek"
        case .swedish: return "Swedish"
        case .arabic: return "Arabic"
        case .hebrew: return "Hebrew"
        case .persian: return "Persian (Farsi)"
        case .swahili: return "Swahili"
        }
    }
    
    /// 语言分组（用于UI中分组显示，方便用户查找）
    var group: LanguageGroup {
        switch self {
        case .chinese, .cantonese, .hokkien, .japanese, .korean:
            return .eastAsia
        case .thai, .vietnamese, .burmese, .indonesian, .malay, .tagalog, .khmer, .lao:
            return .southeastAsia
        case .hindi, .bengali, .tamil, .urdu:
            return .southAsia
        case .english, .spanish, .portuguese, .french, .german, .italian, .russian, .dutch, .polish, .turkish, .greek, .swedish:
            return .europeAmericas
        case .arabic, .hebrew, .persian, .swahili:
            return .middleEastAfrica
        }
    }
}

/// 语言分组枚举
enum LanguageGroup: String, CaseIterable {
    case eastAsia = "eastAsia"
    case southeastAsia = "southeastAsia"
    case southAsia = "southAsia"
    case europeAmericas = "europeAmericas"
    case middleEastAfrica = "middleEastAfrica"
    
    var displayName: String {
        switch self {
        case .eastAsia: return String(localized: "group.eastAsia", defaultValue: "东亚语言")
        case .southeastAsia: return String(localized: "group.southeastAsia", defaultValue: "东南亚语言")
        case .southAsia: return String(localized: "group.southAsia", defaultValue: "南亚语言")
        case .europeAmericas: return String(localized: "group.europeAmericas", defaultValue: "欧美语言")
        case .middleEastAfrica: return String(localized: "group.middleEastAfrica", defaultValue: "中东/非洲语言")
        }
    }
    
    /// 获取该分组下的所有语言
    var languages: [SupportedLanguage] {
        SupportedLanguage.allCases.filter { $0.group == self }
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

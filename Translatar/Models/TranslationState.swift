// TranslationState.swift
// Translatar - AI实时翻译耳机应用
//
// 定义翻译过程中的各种状态和数据模型

import Foundation

/// 翻译会话的连接状态
enum ConnectionState: Equatable {
    case disconnected       // 未连接
    case connecting         // 正在连接
    case connected          // 已连接，准备就绪
    case translating        // 正在翻译中
    case error(String)      // 发生错误
    
    var displayText: String {
        switch self {
        case .disconnected:
            return NSLocalizedString("status.disconnected", comment: "")
        case .connecting:
            return NSLocalizedString("status.connecting", comment: "")
        case .connected:
            return NSLocalizedString("status.connected", comment: "")
        case .translating:
            return NSLocalizedString("status.translating", comment: "")
        case .error(let message):
            let format = NSLocalizedString("status.error", comment: "")
            return String(format: format, message)
        }
    }
    
    var isActive: Bool {
        switch self {
        case .connected, .translating:
            return true
        default:
            return false
        }
    }
}

/// 翻译模式
enum TranslationMode: String, CaseIterable, Identifiable {
    case conversation = "conversation"  // 对话模式：你一句我一句
    case outdoor = "outdoor"            // 户外模式：按住说话，适合嘈杂环境
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .conversation: return NSLocalizedString("mode.conversation", comment: "")
        case .outdoor: return NSLocalizedString("mode.outdoor", comment: "")
        }
    }
    
    var description: String {
        switch self {
        case .conversation: return NSLocalizedString("mode.conversation.desc", comment: "")
        case .outdoor: return NSLocalizedString("mode.outdoor.desc", comment: "")
        }
    }
    
    var iconName: String {
        switch self {
        case .conversation: return "person.2.fill"
        case .outdoor: return "figure.walk"
        }
    }
}

/// 翻译记录条目
/// 用于在界面上显示翻译历史
struct TranslationEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let originalText: String     // 原始语言文本
    let translatedText: String   // 翻译后的文本
    let sourceLanguage: SupportedLanguage
    let targetLanguage: SupportedLanguage
}

/// 音频电平数据（用于UI波形显示）
struct AudioLevel {
    let level: Float    // 0.0 ~ 1.0
    let timestamp: Date
}

/// 户外模式中按住说话的说话者标识
enum OutdoorSpeaker {
    case me       // 用户自己（语言A）
    case other    // 对方（语言B）
}

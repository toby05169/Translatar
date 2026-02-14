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
            return String(localized: "status.disconnected")
        case .connecting:
            return String(localized: "status.connecting")
        case .connected:
            return String(localized: "status.connected")
        case .translating:
            return String(localized: "status.translating")
        case .error(let message):
            return String(localized: "status.error \(message)")
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
    case immersive = "immersive"        // 沉浸模式：持续监听环境音
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .conversation: return String(localized: "mode.conversation")
        case .immersive: return String(localized: "mode.immersive")
        }
    }
    
    var description: String {
        switch self {
        case .conversation: return String(localized: "mode.conversation.desc")
        case .immersive: return String(localized: "mode.immersive.desc")
        }
    }
    
    var iconName: String {
        switch self {
        case .conversation: return "person.2.fill"
        case .immersive: return "ear.fill"
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

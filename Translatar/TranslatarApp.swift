// TranslatarApp.swift
// Translatar - AI实时翻译耳机应用
//
// 应用程序入口文件
// 负责初始化应用并设置根视图

import SwiftUI

@main
struct TranslatarApp: App {
    // 使用 StateObject 持有全局的翻译服务 ViewModel
    @StateObject private var translationVM = TranslationViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(translationVM)
        }
    }
}

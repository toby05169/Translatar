// HistoryView.swift
// Translatar - AI实时翻译耳机应用
//
// 翻译历史详情页
// 独立的全屏历史记录页面，支持搜索、分享、删除

import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var viewModel: TranslationViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedEntry: TranslationEntry?
    @State private var showShareSheet = false
    
    /// 过滤后的历史记录
    private var filteredHistory: [TranslationEntry] {
        if searchText.isEmpty {
            return viewModel.translationHistory
        }
        return viewModel.translationHistory.filter { entry in
            entry.originalText.localizedCaseInsensitiveContains(searchText) ||
            entry.translatedText.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0F0F1A")
                    .ignoresSafeArea()
                
                if viewModel.translationHistory.isEmpty {
                    emptyStateView
                } else {
                    historyListView
                }
            }
            .navigationTitle(NSLocalizedString("history.title", value: "翻译记录", comment: ""))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        if !viewModel.translationHistory.isEmpty {
                            // 导出按钮
                            Button {
                                exportHistory()
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.cyan)
                            }
                            
                            // 清空按钮
                            Button {
                                viewModel.clearHistory()
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red.opacity(0.7))
                            }
                        }
                        
                        Button(NSLocalizedString("common.close", value: "关闭", comment: "")) {
                            dismiss()
                        }
                        .foregroundColor(.cyan)
                    }
                }
            }
            .searchable(text: $searchText, prompt: NSLocalizedString("history.search", value: "搜索翻译记录", comment: ""))
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - 空状态
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.15))
            
            Text(NSLocalizedString("history.empty.title", value: "暂无翻译记录", comment: ""))
                .font(.title3)
                .foregroundColor(.white.opacity(0.4))
            
            Text(NSLocalizedString("history.empty.subtitle", value: "开始翻译后，对话记录将自动保存在这里", comment: ""))
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.25))
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - 历史列表
    
    private var historyListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // 统计信息
                HStack {
                    Text(NSLocalizedString("history.count", value: "共", comment: "") + " \(viewModel.translationHistory.count) " + NSLocalizedString("history.count.suffix", value: "条记录", comment: ""))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.4))
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                
                ForEach(filteredHistory) { entry in
                    HistoryEntryCard(entry: entry)
                        .onTapGesture {
                            selectedEntry = entry
                        }
                        .contextMenu {
                            Button {
                                copyToClipboard(entry)
                            } label: {
                                Label(NSLocalizedString("history.copy", value: "复制翻译", comment: ""), systemImage: "doc.on.doc")
                            }
                            
                            Button {
                                shareEntry(entry)
                            } label: {
                                Label(NSLocalizedString("history.share", value: "分享", comment: ""), systemImage: "square.and.arrow.up")
                            }
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - 辅助方法
    
    private func copyToClipboard(_ entry: TranslationEntry) {
        let text = "\(entry.originalText)\n→ \(entry.translatedText)"
        UIPasteboard.general.string = text
    }
    
    private func shareEntry(_ entry: TranslationEntry) {
        selectedEntry = entry
        showShareSheet = true
    }
    
    private func exportHistory() {
        var exportText = NSLocalizedString("history.export.header", value: "Translatar 翻译记录", comment: "") + "\n"
        exportText += NSLocalizedString("history.export.time", value: "导出时间", comment: "") + "：\(Date().formatted())\n"
        exportText += String(repeating: "=", count: 40) + "\n\n"
        
        for entry in viewModel.translationHistory {
            exportText += "[\(entry.timestamp.formatted(date: .abbreviated, time: .shortened))]\n"
            exportText += "\(entry.sourceLanguage.flag) \(entry.originalText)\n"
            exportText += "→ \(entry.targetLanguage.flag) \(entry.translatedText)\n\n"
        }
        
        UIPasteboard.general.string = exportText
    }
}

// MARK: - 历史记录卡片（详细版）

struct HistoryEntryCard: View {
    let entry: TranslationEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 头部：语言和时间
            HStack {
                HStack(spacing: 6) {
                    Text(entry.sourceLanguage.flag)
                        .font(.title3)
                    Text(entry.sourceLanguage.localizedName)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                    
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.3))
                    
                    Text(entry.targetLanguage.flag)
                        .font(.title3)
                    Text(entry.targetLanguage.localizedName)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
                
                Text(entry.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.3))
            }
            
            // 分隔线
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)
            
            // 原文
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("history.original", value: "原文", comment: ""))
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.3))
                Text(entry.originalText)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // 翻译
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("history.translated", value: "翻译", comment: ""))
                    .font(.caption2)
                    .foregroundColor(.cyan.opacity(0.5))
                Text(entry.translatedText)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.cyan.opacity(0.9))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

#Preview {
    HistoryView()
        .environmentObject(TranslationViewModel())
}

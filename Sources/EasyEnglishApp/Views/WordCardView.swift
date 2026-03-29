import SwiftUI
import Foundation
import AppKit

/// 单词卡片视图 - 显示单词详细信息
/// 
/// 包含：
/// - 单词文本、音标、发音按钮
/// - 词根/助记 popover
/// - 例句 popover
/// - 释义显示
struct WordCardView: View {
    let word: WordData
    @Binding var showMeanings: Bool
    
    @State private var showExamplesPopover: Bool = false
    @EnvironmentObject var sessionManager: LearningSessionManager // ✅ 添加环境对象
    
    var body: some View {
        VStack(alignment: .center, spacing: 24) {
            // 单词文本和音标
            HStack(alignment: .center) {
                Spacer()
                VStack(alignment: .center, spacing: 4) {
                    Text(word.text)
                        .font(.system(size: 50, weight: .bold))
                        .textSelection(.enabled) // ✅ 启用文本选择
                        .contextMenu { // ✅ 添加右键菜单
                            Button("复制单词") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(word.text, forType: .string)
                            }
                            
                            Button("朗读单词") {
                                TTSManager.shared.speak(word.text)
                            }
                            
                            if let roots = word.roots, !roots.isEmpty {
                                Button("查看词根") {
                                    NotificationCenter.default.post(
                                        name: NSNotification.Name("ShowWordRootsDetail"),
                                        object: word
                                    )
                                }
                            }
                            
                            Divider()
                            
                            Button("加入生词本") {
                                // TODO: 实现加入生词本功能
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // ✅ 点击单词打开词根/助记详情页面 (使用通知机制)
                            if word.roots != nil && !word.roots!.isEmpty {
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("ShowWordRootsDetail"),
                                    object: word
                                )
                            }
                        }
                    
                    // 音标和发音按钮在同一行
                    HStack(alignment: .center, spacing: 8) {
                        if let ipa = word.ipa {
                            Text(ipa)
                                .foregroundColor(.secondary)
                                .font(.system(size: 16))
                        }
                        
                        Button(action: { TTSManager.shared.speak(word.text) }) {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // ✅ 词根/助记按钮
                    Button(action: {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("ShowWordRootsDetail"),
                            object: word
                        )
                    }) {
                        HStack {
                            Image(systemName: "book.fill")
                                .foregroundColor(word.roots != nil && !word.roots!.isEmpty ? .orange : .gray.opacity(0.5))
                            Text("词根/助记")
                                .fontWeight(.medium)
                                .foregroundColor(word.roots != nil && !word.roots!.isEmpty ? .primary : .gray.opacity(0.5))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(word.roots != nil && !word.roots!.isEmpty ? Color.gray.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(word.roots == nil || word.roots!.isEmpty)
                    .padding(.top, 4)
                }
                Spacer()
            }
            
            // 释义
            if let meanings = word.meanings {
                GroupBox {
                    Text(meanings)
                        .font(.system(size: 16))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled) // ✅ 启用文本选择
                        .contextMenu { // ✅ 添加右键菜单
                            Button("复制释义") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(meanings, forType: .string)
                            }
                            
                            Button("朗读释义") {
                                TTSManager.shared.speak(meanings)
                            }
                        }
                }
                .opacity(showMeanings ? 1 : 0)
            }
            
            // 例句
            if let examples = word.examples {
                GroupBox {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(formatExamples(examples))
                            .font(.system(size: 16))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled) // ✅ 启用文本选择
                            .contextMenu { // ✅ 添加右键菜单
                                Button("复制例句") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(formatExamples(examples), forType: .string)
                                }
                                
                                Button("朗读例句") {
                                    TTSManager.shared.speak(examples)
                                }
                            }
                        
                        // 填充空行到 5 行
                        ForEach(0..<calculateEmptyLines(examples), id: \.self) { _ in
                            Text(" ")
                                .font(.system(size: 16))
                                .lineSpacing(4)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(5)
                    .onHover { isHovering in
                        showExamplesPopover = isHovering && word.chineseExamples != nil
                    }
                    .popover(isPresented: $showExamplesPopover, content: {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("中文例句")
                                    .font(.system(size: 14))
                                Text(formatExamples(word.chineseExamples ?? ""))
                                    .font(.system(size: 14))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .lineLimit(5)
                            }
                            .padding()
                            .frame(maxWidth: 600)
                        }
                        .frame(minWidth: 300)
                    })
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - 辅助方法
    
    private func formatExamples(_ text: String) -> String {
        let pattern = "([.!?。？！])\\s*"
        let replaced = (try? NSRegularExpression(pattern: pattern))?.stringByReplacingMatches(
            in: text,
            options: [],
            range: NSRange(text.startIndex..., in: text),
            withTemplate: "$1\n"
        ) ?? text
        
        let lines = replaced
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        return lines.joined(separator: "\n")
    }
    
    private func calculateEmptyLines(_ examples: String) -> Int {
        let formattedText = formatExamples(examples)
        let actualLines = formattedText
            .split(separator: "\n", omittingEmptySubsequences: true)
            .count
        
        return max(0, 5 - actualLines)
    }
}

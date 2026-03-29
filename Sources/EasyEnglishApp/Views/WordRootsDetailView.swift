import SwiftUI

/// 词根/助记详情视图 - 与主界面风格一致
/// 
/// 功能：
/// - 展示单词的词根/助记内容
/// - 提供返回按钮继续学习
/// - 支持滚动查看长内容
struct WordRootsDetailView: View {
    let word: WordData
    var onBack: () -> Void
    
    @State private var scrollPosition: CGFloat = 0
    
    var body: some View {
        VStack(alignment: .center, spacing: 40) {
            // 单词标题和音标区域
            wordHeaderSection
            
            // 词根/助记内容区域
            rootsContentSection
            
            // 返回按钮
            Button(action: onBack) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("返回学习")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 1.0, green: 0.65, blue: 0.25),
                            Color(red: 0.95, green: 0.55, blue: 0.15)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(10)
                .shadow(color: Color(red: 1.0, green: 0.6, blue: 0.2).opacity(0.3), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(PlainButtonStyle())
            .keyboardShortcut(.escape, modifiers: [])
            
            Spacer()
        }
        .padding(.horizontal, 80)
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 子视图


    /// 主内容区域 - 现在直接在 body 中使用 wordHeaderSection 和 rootsContentSection
    private var contentArea: some View {
        ScrollView(showsIndicators: true) {
            VStack(alignment: .center, spacing: 32) {
                // 单词标题和音标
                wordHeaderSection
                
                // 词根/助记内容
                rootsContentSection
            }
            .padding(32)
        }
    }
    
    /// 单词标题区域
    private var wordHeaderSection: some View {
        VStack(alignment: .center, spacing: 16) {
            Text(word.text)
                .font(.system(size: 60, weight: .bold))
                .foregroundColor(.primary)
                .textSelection(.enabled)
            
            HStack(alignment: .center, spacing: 20) {
                if let ipa = word.ipa {
                    Text(ipa)
                        .foregroundColor(.secondary)
                        .font(.system(size: 20))
                }
                
                Button(action: { TTSManager.shared.speak(word.text) }) {
                    HStack(spacing: 8) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 16))
                        Text("播放发音")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(Color(red: 1.0, green: 0.7, blue: 0.3))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(NSColor.controlBackgroundColor).opacity(0.8))
                    )
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 32)
    }
    
    /// 词根/助记内容区域（与主界面卡片风格一致）
    private var rootsContentSection: some View {
        VStack(alignment: .center, spacing: 24) {
            // 标题栏
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(red: 1.0, green: 0.6, blue: 0.2))
                    
                    Text("词根 / 助记")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: 800, alignment: .leading)
            }
            
            // 词根内容卡片（使用自定义卡片样式）
            VStack(alignment: .center, spacing: 0) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.8))
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                    .overlay {
                        if let roots = word.roots, !roots.isEmpty {
                            // 美化后的词根文本显示
                            Text(formattedRootsText(roots))
                                .font(.system(size: 18))
                                .lineSpacing(8)
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled) // ✅ 启用文本选择
                                .contextMenu { // ✅ 添加右键菜单
                                    Button("复制词根") {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(formattedRootsText(roots), forType: .string)
                                    }
                                    
                                    Button("朗读词根") {
                                        TTSManager.shared.speak(roots)
                                    }
                                    
                                    Divider()
                                    
                                    Button("返回学习") {
                                        onBack()
                                    }
                                }
                                .padding(32)
                        } else {
                            VStack(spacing: 20) {
                                Image(systemName: "questionmark.circle")
                                    .font(.system(size: 48))
                                    .foregroundColor(Color(red: 1.0, green: 0.7, blue: 0.3))
                                
                                Text("暂无词根/助记信息")
                                    .font(.system(size: 18))
                                    .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.6))
                                    .italic()
                            }
                            .frame(maxWidth: .infinity, minHeight: 200)
                            .padding(.vertical, 40)
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(maxWidth: 800)
            }
        }
    }
    
    // MARK: - 辅助方法
    
    /// ✅ 美化词根文本显示
    private func formattedRootsText(_ roots: String) -> String {
        // 对常见的分隔符进行优化处理
        var formatted = roots
        
        // ✅ 第一步：提取词根信息（找到包含 → 的行）
        let lines = formatted
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        // 找到包含词根信息的行（通常包含 → 符号或词根相关关键词）
        var rootLines: [String] = []
        var foundRoots = false
        
        for line in lines {
            // 检查是否包含词根标记
            let hasRootMarker = line.contains("→") || 
                               line.contains("词根") || 
                               line.contains("词缀") || 
                               line.contains("前缀") || 
                               line.contains("后缀") ||
                               line.contains("来自") ||
                               line.contains("源于") ||
                               line.contains("构成") ||
                               line.contains("组成")
            
            // 检查是否是无关的单词信息
            let isIrrelevant = line.contains("adj.") ||
                              line.contains("n.") ||
                              line.contains("v.") ||
                              line.contains("adv.") ||
                              line.contains("prep.") ||
                              line.contains("conj.") ||
                              line.contains("pron.") ||
                              line.contains("det.") ||
                              line.contains("UK") ||
                              line.contains("US") ||
                              line.contains("verb") ||
                              line.contains("noun") ||
                              line.contains("adjective") ||
                              line.contains("adverb") ||
                              line.contains("preposition") ||
                              line.contains("conjunction") ||
                              line.contains("pronoun") ||
                              line.contains("determiner") ||
                              line.contains("例句") ||
                              line.contains("例：") ||
                              line.contains("例如") ||
                              line.contains("近义词") ||
                              line.contains("反义词") ||
                              line.contains("同义词")
            
            if hasRootMarker && !isIrrelevant {
                rootLines.append(line)
                foundRoots = true
            } else if foundRoots && !isIrrelevant {
                // 如果已经找到词根信息，继续添加后续行
                rootLines.append(line)
            }
        }
        
        // 如果没有找到词根信息，使用原始文本
        if rootLines.isEmpty {
            rootLines = lines.filter { !$0.contains("adj.") && !$0.contains("n.") && !$0.contains("v.") }
        }
        
        formatted = rootLines.joined(separator: "\n")
        
        // ✅ 第二步：去掉 [] 中的内容（包括括号本身）
        // 匹配 [...] 模式，非贪婪匹配
        formatted = formatted.replacingOccurrences(
            of: "\\[[^\\]]*\\]",
            with: "",
            options: .regularExpression
        )
        
        // ✅ 第三步：清理可能残留的单独括号
        formatted = formatted.replacingOccurrences(of: "[", with: "")
        formatted = formatted.replacingOccurrences(of: "]", with: "")
        
        // 在箭头符号前后增加空格（如果还没有）
        formatted = formatted.replacingOccurrences(of: "\\s*→\\s*", with: " → ", options: .regularExpression)
        
        // 在加号前后增加空格
        formatted = formatted.replacingOccurrences(of: "\\s*\\+\\s*", with: " + ", options: .regularExpression)
        
        // 在等号前后增加空格
        formatted = formatted.replacingOccurrences(of: "\\s*=\\s*", with: " = ", options: .regularExpression)
        
        // ✅ 在中文句号、问号后添加换行符
        formatted = formatted.replacingOccurrences(
            of: "([.!?。！？])",
            with: "$1\n",
            options: .regularExpression
        )
        
        // 清理多余的空行和首尾空格
        let finalLines = formatted
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        return finalLines.joined(separator: "\n")
    }
}

// MARK: - 预览
#Preview {
    let sampleWord = WordData(
        id: UUID(),
        text: "example",
        ipa: "/ɪgˈzæmpəl/",
        meanings: "例子；榜样；例证",
        examples: "This is a good example of how to use the API. She set an example for others to follow.",
        chineseExamples: "这是一个很好的 API 使用示例。她为他人树立了榜样。",
        roots: "ex-(出) + am(周围) + ple → 拿出来给大家看 → 例子"
    )
    
    WordRootsDetailView(word: sampleWord, onBack: {})
}

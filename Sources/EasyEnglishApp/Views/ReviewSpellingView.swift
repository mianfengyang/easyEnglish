import SwiftUI
import Foundation
import AppKit

// MARK: - Supporting Types

enum LetterStatus {
    case pending
    case correct
    case incorrect
}

/// 复习拼写视图 - 重新实现版本
struct ReviewSpellingView: View {
    @EnvironmentObject var sessionManager: LearningSessionManager
    @Environment(\.presentationMode) private var presentationMode
    
    // 学习到的单词列表（从学习页面添加的单词）
    let learnedWords: [WordData]
    
    // ✅ 添加回调闭包，用于通知父视图显示统计
    var onShowStatistics: (() -> Void)?
    
    // ✅ 听写模式标志
    let isDictationMode: Bool
    
    // MARK: - State Properties
    @State private var currentWordIndex: Int = 0  // 当前单词在 learnedWords 中的索引
    @State private var currentLetterIndex: Int = 0  // 当前正在拼写的字母索引
    @State private var userInput: String = ""  // 用户输入
    @State private var letterStates: [LetterStatus] = []  // 字母状态数组
    @State private var isProcessing: Bool = false  // 是否正在处理输入
    @State private var isComplete: Bool = false  // 是否完成拼写
    @State private var startTime: Date = Date()  // 开始时间
    
    // 统计信息
    @State private var totalAttempts: Int = 0
    @State private var correctAttempts: Int = 0
    @State private var incorrectAttempts: Int = 0
    
    @FocusState private var isInputFocused: Bool  // 输入焦点
    
    // MARK: - Computed Properties
    private var currentWord: WordData? {
        guard currentWordIndex < learnedWords.count else { return nil }
        return learnedWords[currentWordIndex]
    }
    
    private var wordLetters: [Character] {
        guard let word = currentWord else { return [] }
        return Array(word.text.lowercased())
    }
    
    var body: some View {
        VStack(spacing: 30) {
            // 主要内容区域
            if let word = currentWord {
                mainContentSection(word: word)
            }
            
            Spacer()
        }
        .padding(.horizontal, 80)
        .padding(.vertical, 40)
        .frame(minWidth: 600, maxWidth: .infinity, minHeight: 500, maxHeight: .infinity)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(NSColor.windowBackgroundColor).opacity(0.9),
                    Color(NSColor.windowBackgroundColor)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .onAppear {
            // 延迟一点时间确保视图完全渲染后再设置焦点
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                initializeCurrentWord()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DictationModeStarted"))) { _ in
            // 监听听写模式开始的通知，确保输入焦点
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isInputFocused = true
            }
        }
        .onTapGesture {
            // 点击界面时重新获取输入焦点
            isInputFocused = true
        }
        .overlay(
            hiddenInputField
        )
    }
    
    // MARK: - Subviews
    

    private func mainContentSection(word: WordData) -> some View {
        VStack(spacing: 32) {
            // 中文释义
            meaningSection(word: word)
            
            // 音标和发音
            pronunciationSection(word: word)
            
            // 拼写区域
            spellingSection(word: word)
            
            // 导航按钮
            navigationButtonsSection
        }
    }
    
    private func meaningSection(word: WordData) -> some View {
        Group {
            if let meanings = word.meanings {
                VStack(spacing: 8) {
                    Text("释义")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                    Text(meanings)
                        .font(.system(size: 16, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.6))
                                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                        )
                }
            }
        }
    }
    
    private func pronunciationSection(word: WordData) -> some View {
        HStack(spacing: 16) {
            if let ipa = word.ipa {
                Text(ipa)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(.secondary)
            }
            
            Button(action: { TTSManager.shared.speak(word.text) }) {
                HStack(spacing: 6) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 14))
                    Text("播放发音")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(Color(red: 1.0, green: 0.7, blue: 0.3))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.6))
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.top, 8)
    }
    
    private func spellingSection(word: WordData) -> some View {
        VStack(spacing: 20) {
            // 拼写显示区域
            HStack(spacing: 0) {
                ForEach(0..<wordLetters.count, id: \.self) { index in
                    let letterStatus = letterStates.indices.contains(index) ? letterStates[index] : .pending
                    let isCurrentPosition = index == currentLetterIndex
                    
                    Text(String(wordLetters[index]))
                        .font(.system(size: 80, weight: .bold))
                        .foregroundColor(letterColor(for: letterStatus, isCurrentPosition: isCurrentPosition))
                        .fixedSize()
                        .overlay(
                            Group {
                                if isDictationMode && letterStatus == .pending {
                                    Rectangle()
                                        .fill(Color.primary.opacity(0.5))
                                        .frame(height: 3)
                                        .offset(y: 40)
                                } else {
                                    EmptyView()
                                }
                            }
                        )
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
    
    private func letterColor(for status: LetterStatus, isCurrentPosition: Bool) -> Color {
        switch status {
        case .correct:
            return .green
        case .incorrect:
            return .red
        case .pending:
            // 听写模式下，未输入的字母与背景色一致，实现不可见效果
            return isDictationMode ? Color(NSColor.windowBackgroundColor) : (isCurrentPosition ? .gray.opacity(0.4) : .gray.opacity(0.2))
        }
    }
    
    /// ✅ 导航按钮区域（与学习界面样式一致）
    private var navigationButtonsSection: some View {
        HStack(spacing: 16) {
            Button(action: { goToPrevious() }) {
                HStack {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("上一个")
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
            .disabled(currentWordIndex <= 0)
            
            Text("\(currentWordIndex + 1)/\(learnedWords.count)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 1.0, green: 0.9, blue: 0.8),
                            Color(red: 1.0, green: 0.85, blue: 0.75)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(10)
            
            Button(action: { goToNext() }) {
                HStack {
                    Text("下一个")
                        .font(.system(size: 15, weight: .semibold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
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
            .disabled(currentWordIndex >= learnedWords.count - 1 || isComplete)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
    }
    
    private var hiddenInputField: some View {
        TextField("", text: $userInput)
            .opacity(0.01)
            .frame(width: 100, height: 100)
            .position(x: 0, y: 0) // 保持在屏幕内但透明
            .textFieldStyle(PlainTextFieldStyle())
            .focused($isInputFocused)
            .textContentType(.oneTimeCode)
            .disableAutocorrection(true)
            .onChange(of: userInput) { newValue in
                handleInputChange(newValue)
            }
    }
    
    // MARK: - Input Handling
    
    private func handleInputChange(_ newValue: String) {
        guard !isProcessing && !isComplete else {
            if newValue.count > 0 {
                userInput = ""
            }
            return
        }
        
        if newValue.count > 0, let lastChar = newValue.last {
            isProcessing = true
            processInput(lastChar)
            userInput = ""
        }
    }
    
    private func processInput(_ input: Character) {
        guard let word = currentWord else {
            isProcessing = false
            return
        }
        
        let targetChar = wordLetters[currentLetterIndex]
        
        if input.lowercased() == targetChar.lowercased() {
            handleCorrectInput()
        } else {
            handleIncorrectInput(word: word)
        }
    }
    
    private func handleCorrectInput() {
        // 标记当前字母为正确
        if letterStates.indices.contains(currentLetterIndex) {
            letterStates[currentLetterIndex] = .correct
        } else {
            letterStates.append(.correct)
        }
        
        // 移动到下一个位置
        currentLetterIndex += 1
        
        // 检查是否完成拼写
        if currentLetterIndex >= wordLetters.count {
            completeSpelling()
        } else {
            isProcessing = false
        }
    }
    
    private func handleIncorrectInput(word: WordData) {
        // 标记当前字母为错误
        if letterStates.indices.contains(currentLetterIndex) {
            letterStates[currentLetterIndex] = .incorrect
        } else {
            letterStates.append(.incorrect)
        }
        
        // 发出警告音
        NSSound.beep()
        
        // 更新统计
        incorrectAttempts += 1
        totalAttempts += 1
        
        // 禁用输入
        isInputFocused = false
        isProcessing = false
        
        // 延迟后重置当前单词的拼写状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            resetCurrentWordSpelling()
        }
    }
    
    private func completeSpelling() {
        isComplete = true
        
        // 更新统计
        correctAttempts += 1
        totalAttempts += 1
        
        // 记录学习数据
        let timeSpent = Date().timeIntervalSince(startTime)
        sessionManager.review(word: currentWord!, quality: 5, attemptType: "review_spelling_complete", timeSpent: timeSpent, answer: currentWord!.text)
        
        // 延迟后进入下一个单词或完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isComplete = false
            isProcessing = false
            
            if currentWordIndex < learnedWords.count - 1 {
                currentWordIndex += 1
                initializeCurrentWord()
            } else {
                // 所有单词完成
                onShowStatistics?()
            }
        }
    }
    
    private func resetCurrentWordSpelling() {
        // 重置当前单词的拼写状态
        letterStates = []
        currentLetterIndex = 0
        userInput = ""
        isProcessing = false
        
        // 重新启用输入
        isInputFocused = true
    }
    
    // MARK: - Actions
    
    private func initializeCurrentWord() {
        guard currentWord != nil else { return }
        
        // 重置状态
        letterStates = []
        currentLetterIndex = 0
        userInput = ""
        isProcessing = false
        isComplete = false
        startTime = Date()
        
        // 自动播放单词发音
        TTSManager.shared.speak(currentWord!.text)
        
        // 设置输入焦点
        isInputFocused = true
    }
    
    private func goToPrevious() {
        guard currentWordIndex > 0 else { return }
        currentWordIndex -= 1
        initializeCurrentWord()
    }
    
    private func goToNext() {
        guard currentWordIndex < learnedWords.count - 1 && !isComplete else { return }
        currentWordIndex += 1
        initializeCurrentWord()
    }
}

// MARK: - Preview

#if DEBUG
struct ReviewSpellingView_Previews: PreviewProvider {
    static var previews: some View {
        let mockWords = [
            WordData(id: UUID(), text: "example", ipa: "/ɪgˈzæmpəl/", meanings: "n.例子；榜样", examples: nil, chineseExamples: nil, roots: nil),
            WordData(id: UUID(), text: "learning", ipa: "/ˈlɜːrnɪŋ/", meanings: "n.学习；知识", examples: nil, chineseExamples: nil, roots: nil),
            WordData(id: UUID(), text: "practice", ipa: "/ˈpræktɪs/", meanings: "n.练习；实践", examples: nil, chineseExamples: nil, roots: nil)
        ]
        return ReviewSpellingView(learnedWords: mockWords, isDictationMode: false)
            .environmentObject(LearningSessionManager.shared)
            .frame(width: 700, height: 600)
    }
}
#endif

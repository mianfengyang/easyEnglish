import SwiftUI
import AppKit

enum SpellingLetterStatus {
    case pending
    case correct
    case incorrect
}

struct SpellingView: View {
    @ObservedObject var viewModel: SpellingViewModel
    let isDictationMode: Bool
    var onComplete: (() -> Void)?
    
    @State private var userInput: String = ""
    @State private var isComplete: Bool = false
    @State private var letterStates: [SpellingLetterStatus] = []
    
    private var currentWordText: String {
        viewModel.currentWord?.text ?? ""
    }
    
    private var wordLettersArray: [String] {
        currentWordText.lowercased().map { String($0) }
    }
    
    var body: some View {
        VStack(spacing: 30) {
            if viewModel.learnedWords.isEmpty {
                emptyStateView
            } else if viewModel.currentWord != nil {
                mainContentSection
            } else {
                Text("加载中...")
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 80)
        .padding(.vertical, 40)
        .frame(minWidth: 600, maxWidth: .infinity, minHeight: 500, maxHeight: .infinity)
        .background(Theme.background)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                initializeCurrentWord()
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "keyboard")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            Text("还没有已学习的单词")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
            Text("请先完成单词学习后再进行拼写练习")
                .font(.system(size: 14))
                .foregroundColor(.secondary.opacity(0.7))
        }
    }
    
    private var mainContentSection: some View {
        VStack(spacing: 32) {
            meaningSection
            pronunciationSection
            
            if isDictationMode {
                dictationInputSection
            } else {
                spellingSection
            }
            
            navigationButtonsSection
        }
    }
    
    private var meaningSection: some View {
        VStack(spacing: 8) {
            Text("释义")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            Text(viewModel.currentWord?.meanings ?? "")
                .font(.system(size: 18, weight: .semibold))
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.secondaryBackground.opacity(0.6)))
        }
    }
    
    private var pronunciationSection: some View {
        HStack(spacing: 16) {
            if let ipa = viewModel.currentWord?.ipa {
                Text(ipa)
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            }
            
            Button(action: { 
                if let text = viewModel.currentWord?.text {
                    TTSManager.shared.speak(text)
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 14))
                    Text("播放发音")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(Theme.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Theme.primary.opacity(0.1))
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var dictationInputSection: some View {
        VStack(spacing: 20) {
            Text("直接在键盘上按字母")
                .font(.system(size: 13))
                .foregroundColor(.secondary.opacity(0.7))
            
            dictationAnswerDisplayView
            
            hiddenKeyInputView
        }
    }
    
    private var dictationAnswerDisplayView: some View {
        HStack(spacing: 0) {
            ForEach(0..<wordLettersArray.count, id: \.self) { index in
                let status: SpellingLetterStatus = index < letterStates.count ? letterStates[index] : .pending
                let letter = wordLettersArray[index]
                
                Text(letter)
                    .font(.system(size: 80, weight: .bold))
                    .foregroundColor(dictationLetterColor(for: status))
            }
        }
    }
    
    private func dictationLetterColor(for status: SpellingLetterStatus) -> Color {
        switch status {
        case .correct: return .green
        case .incorrect: return .red
        case .pending: return .clear
        }
    }
    
    private var hiddenKeyInputView: some View {
        HiddenKeyboardHandlerView { key in
            handleDictationKeyPress(key)
        }
    }
    
    private func handleDictationKeyPress(_ key: String) {
        guard isDictationMode else { return }
        guard !isComplete else { return }
        guard letterStates.count < wordLettersArray.count else { return }
        
        let expectedChar = wordLettersArray[letterStates.count]
        
        if key.lowercased() == expectedChar.lowercased() {
            letterStates.append(.correct)
            SoundManager.shared.playKeyClick()
            checkDictationComplete()
        } else {
            letterStates.append(.incorrect)
            SoundManager.shared.playError()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.letterStates = []
            }
        }
    }
    
    private func checkDictationComplete() {
        guard let word = viewModel.currentWord else { return }
        if letterStates.count >= wordLettersArray.count {
            if letterStates.contains(.incorrect) {
                return
            }
            isComplete = true
            viewModel.review(word: word, quality: 5)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                moveToNextWord()
            }
        }
    }
    
    private var spellingSection: some View {
        VStack(spacing: 20) {
            answerDisplayView
            
            Text("直接在键盘上按字母")
                .font(.system(size: 13))
                .foregroundColor(.secondary.opacity(0.7))
            
            keyInputView
        }
    }
    
    private var answerDisplayView: some View {
        HStack(spacing: 0) {
            ForEach(0..<wordLettersArray.count, id: \.self) { index in
                let status: SpellingLetterStatus = index < letterStates.count ? letterStates[index] : .pending
                let letter = wordLettersArray[index]
                
                Text(letter)
                    .font(.system(size: 80, weight: .bold))
                    .foregroundColor(letterColor(for: status))
            }
        }
    }
    
    private func letterColor(for status: SpellingLetterStatus) -> Color {
        switch status {
        case .correct: return .green
        case .incorrect: return .red
        case .pending: return .gray.opacity(0.15)
        }
    }
    
    private var keyInputView: some View {
        HiddenKeyboardHandlerView { key in
            handleKeyPress(key)
        }
    }
    
    private func handleKeyPress(_ key: String) {
        guard !isDictationMode else { return }
        guard !isComplete else { return }
        guard letterStates.count < wordLettersArray.count else { return }
        
        let expectedChar = wordLettersArray[letterStates.count]
        
        if key.lowercased() == expectedChar.lowercased() {
            letterStates.append(.correct)
            SoundManager.shared.playKeyClick()
            checkIfComplete()
        } else {
            letterStates.append(.incorrect)
            SoundManager.shared.playError()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.letterStates = []
            }
        }
    }
    
    private func checkIfComplete() {
        guard let word = viewModel.currentWord else { return }
        if letterStates.count >= wordLettersArray.count {
            if letterStates.contains(.incorrect) {
                return
            }
            isComplete = true
            viewModel.review(word: word, quality: 5)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                moveToNextWord()
            }
        }
    }
    
    private func moveToNextWord() {
        letterStates = []
        userInput = ""
        isComplete = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if self.viewModel.currentIndex < self.viewModel.learnedWords.count - 1 {
                self.viewModel.currentIndex += 1
                self.initializeCurrentWord()
            } else {
                self.onComplete?()
            }
        }
    }
    
    private func initializeCurrentWord() {
        letterStates = []
        userInput = ""
        isComplete = false
        
        if let word = viewModel.currentWord {
            TTSManager.shared.speak(word.text)
        }
    }
    
    private var navigationButtonsSection: some View {
        let currentIndex = viewModel.currentIndex
        let totalCount = viewModel.learnedWords.count
        let canGoPrevious = currentIndex > 0
        let canGoNext = currentIndex < totalCount - 1
        
        return HStack(spacing: 16) {
            Button(action: {
                if viewModel.currentIndex > 0 {
                    viewModel.currentIndex -= 1
                    initializeCurrentWord()
                }
            }) {
                HStack {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("上一个")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(Theme.primary)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Theme.primary.opacity(0.1))
                .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())
            .opacity(canGoPrevious ? 1.0 : 0.5)
            .disabled(!canGoPrevious)
            
            Text("\(currentIndex + 1)/\(totalCount)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Theme.secondaryBackground)
                .cornerRadius(10)
            
            Button(action: {
                if viewModel.currentIndex < viewModel.learnedWords.count - 1 {
                    viewModel.currentIndex += 1
                    initializeCurrentWord()
                }
            }) {
                HStack {
                    Text("下一个")
                        .font(.system(size: 15, weight: .semibold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(Theme.primary)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Theme.primary.opacity(0.1))
                .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())
            .opacity(canGoNext ? 1.0 : 0.5)
            .disabled(!canGoNext)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
    }
}

struct HiddenKeyboardHandlerView: NSViewRepresentable {
    var onKeyPress: (String) -> Void
    
    func makeNSView(context: Context) -> KeyboardCaptureView {
        let view = KeyboardCaptureView()
        view.onKeyPress = onKeyPress
        view.startMonitoring()
        return view
    }
    
    func updateNSView(_ nsView: KeyboardCaptureView, context: Context) {
    }
    
    static func dismantleNSView(_ nsView: KeyboardCaptureView, coordinator: ()) {
        nsView.stopMonitoring()
    }
}

class KeyboardCaptureView: NSView {
    var onKeyPress: ((String) -> Void)?
    var eventMonitor: Any?
    
    override var acceptsFirstResponder: Bool { true }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }
    
    func startMonitoring() {
        stopMonitoring()
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
            return event
        }
    }
    
    func stopMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
        guard let characters = event.characters, !characters.isEmpty else { return }
        
        let key = characters.lowercased()
        if key.first?.isLetter == true {
            onKeyPress?(key)
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        bounds.fill()
    }
}
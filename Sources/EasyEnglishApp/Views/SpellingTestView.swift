import SwiftUI

struct SpellingTestView: View {
    // initial word to start from; exercises iterate through sessionWords
    var initialWord: WordData
    @EnvironmentObject var sessionManager: LearningSessionManager
    @Environment(\.presentationMode) private var presentationMode

    @State private var index: Int = 0
    @State private var answer: String = ""
    @State private var startTime: Date = Date()
    @State private var dictationMode: Bool = false

    private var currentWord: WordData {
        if sessionManager.sessionWords.indices.contains(index) {
            return sessionManager.sessionWords[index]
        }
        return initialWord
    }

    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            HStack {
                VStack(alignment: .center) {
                    Text("拼写测试").font(.title2).bold()
                    Text(dictationMode ? "听写模式（先播放发音）" : "看释义后输入拼写")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: { TTSManager.shared.speak(currentWord.text) }) {
                    Image(systemName: "speaker.wave.2.fill")
                }
                .help("播放单词发音")
            }

            Toggle("听写模式", isOn: $dictationMode)
                .frame(maxWidth: .infinity, alignment: .center)

            if !dictationMode, let meanings = currentWord.meanings {
                GroupBox(label: Text("释义")) {
                    Text(meanings)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            TextField("在此输入拼写", text: $answer)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.title)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button("提交") { submit() }
                    .keyboardShortcut(.defaultAction)

                Button("跳过") {
                    let timeSpent = Date().timeIntervalSince(startTime)
                    // use review to persist log and update SRS; mark attempt type according to mode
                    let attempt = dictationMode ? "dictation_skip" : "spelling_skip"
                    sessionManager.review(word: currentWord, quality: 2, attemptType: attempt, timeSpent: timeSpent, answer: nil)
                    goToNextOrExit()
                }

                Spacer()

                Button("关闭") { presentationMode.wrappedValue.dismiss() }
            }
            .frame(maxWidth: .infinity)

            Spacer()
        }
        .padding()
        .frame(minWidth: 420, minHeight: 320)
        .onAppear {
            // initialize index to position of initialWord in sessionWords
            if let idx = sessionManager.sessionWords.firstIndex(where: { $0.id == initialWord.id }) {
                index = idx
            } else {
                index = 0
            }
            startTime = Date()
            if dictationMode {
                TTSManager.shared.speak(currentWord.text)
            }
        }
    }

    private func submit() {
        let correct = currentWord.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let guess = answer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let dist = levenshtein(a: correct, b: guess)

        let quality: Int
        if guess.isEmpty {
            quality = 0
        } else if dist == 0 {
            quality = 5
        } else if dist == 1 {
            quality = 4
        } else if dist == 2 {
            quality = 3
        } else {
            quality = 2
        }

        let timeSpent = Date().timeIntervalSince(startTime)
        let attempt = dictationMode ? "dictation" : "spelling"
        sessionManager.review(word: currentWord, quality: quality, attemptType: attempt, timeSpent: timeSpent, answer: answer)

        // ✅ 已移除反馈信息显示，直接跳转到下一个单词
        // feedback = "正确：\(currentWord.text)；你的答案：\(answer)；编辑距离：\(dist)；评分：\(quality)"
        // showFeedback = true

        // short delay then proceed to next
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            goToNextOrExit()
        }
    }

    private func goToNextOrExit() {
        let nextIndex = index + 1
        if sessionManager.sessionWords.indices.contains(nextIndex) {
            index = nextIndex
            answer = ""
            startTime = Date()
            if dictationMode {
                TTSManager.shared.speak(currentWord.text)
            }
        } else {
            presentationMode.wrappedValue.dismiss()
        }
    }

    // simple Levenshtein distance
    private func levenshtein(a: String, b: String) -> Int {
        let aChars = Array(a)
        let bChars = Array(b)
        let m = aChars.count
        let n = bChars.count
        if m == 0 { return n }
        if n == 0 { return m }

        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        for i in 0...m { dp[i][0] = i }
        for j in 0...n { dp[0][j] = j }

        for i in 1...m {
            for j in 1...n {
                if aChars[i-1] == bChars[j-1] {
                    dp[i][j] = dp[i-1][j-1]
                } else {
                    dp[i][j] = min(dp[i-1][j-1] + 1, min(dp[i-1][j] + 1, dp[i][j-1] + 1))
                }
            }
        }
        return dp[m][n]
    }
}

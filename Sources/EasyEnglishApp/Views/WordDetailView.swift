import SwiftUI

struct WordDetailView: View {
    let word: WordData
    @StateObject private var tts = TTSManager.shared
    @EnvironmentObject var sessionManager: LearningSessionManager
    @State private var showSpellingTest = false
    @State private var showRootsPopover: Bool = false
    @State private var showExamplesPopover: Bool = false

    var body: some View {
        VStack(alignment: .center, spacing: 24) {
            HStack(alignment: .top) {
                Spacer()
                VStack(alignment: .center, spacing: 4) {
                    Text(word.text)
                        .font(.system(size: 50, weight: .bold))
                        .onHover { isHovering in
                            showRootsPopover = isHovering && word.roots != nil
                        }
                        .popover(isPresented: $showRootsPopover) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("词根/助记")
                                    .font(.headline)
                                Text(word.roots ?? "")
                                    .font(.body)
                            }
                            .padding()
                            .frame(maxWidth: 300)
                        }
                    if let ipa = word.ipa { Text(ipa).foregroundColor(.secondary).font(.system(size: 16)) }
                }
                Spacer()
                Button(action: { tts.speak(word.text) }) {
                    Image(systemName: "speaker.wave.2.fill")
                }
                .help("播放发音")
                Button(action: { showSpellingTest = true }) {
                    Text("拼写测试")
                }
                .help("开始拼写题")
            }

            if let meanings = word.meanings {
                GroupBox {
                    Text(meanings)
                        .font(.system(size: 16))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let examples = word.examples {
                GroupBox {
                    Text(formatExamples(examples))
                        .font(.system(size: 16))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .onHover { isHovering in
                            showExamplesPopover = isHovering && word.chineseExamples != nil
                        }
                        .popover(isPresented: $showExamplesPopover) {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("中文例句")
                                        .font(.system(size: 14))
                                    Text(formatExamples(word.chineseExamples ?? ""))
                                        .font(.system(size: 14))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding()
                                .frame(maxWidth: 400)
                            }
                            .frame(minWidth: 300)
                        }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 80)
        .frame(minWidth: 400)
        .sheet(isPresented: $showSpellingTest) {
            SpellingTestView(initialWord: word).environmentObject(sessionManager)
        }
    }

    private func formatExamples(_ text: String) -> String {
        // Add newline after sentence terminators (., !, ?, 。, ？, ！)
        let pattern = "([.!?。？！])\\s*"
        let replaced = (try? NSRegularExpression(pattern: pattern))?.stringByReplacingMatches(in: text, options: [], range: NSRange(text.startIndex..., in: text), withTemplate: "$1\n") ?? text
        
        // Split by newlines and filter empty lines
        let lines = replaced
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return lines.joined(separator: "\n")
    }
}

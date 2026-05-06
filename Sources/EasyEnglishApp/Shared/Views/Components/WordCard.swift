import SwiftUI
import AppKit

struct WordCard: View {
    let word: Word
    @Binding var showMeanings: Bool
    
    @State private var showChinesePopover: Bool = false
    
    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            wordHeaderSection
            meaningsSection
            examplesSection
        }
        .padding(16)
        .background(Theme.secondaryBackground.opacity(0.4))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 4)
    }

    private var wordHeaderSection: some View {
        VStack(alignment: .center, spacing: 8) {
            Text(word.text)
                .font(.system(size: 52, weight: .bold))
                .textSelection(.enabled)
                .contextMenu {
                    Button("复制单词") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(word.text, forType: .string)
                    }
                    Button("朗读单词") {
                        TTSManager.shared.speak(word.text)
                    }
                    if word.roots != nil && !word.roots!.isEmpty {
                        Button("查看词根") {
                            NotificationCenter.default.post(name: NSNotification.Name("ShowWordRootsDetail"), object: word)
                        }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if word.roots != nil && !word.roots!.isEmpty {
                        NotificationCenter.default.post(name: NSNotification.Name("ShowWordRootsDetail"), object: word)
                    }
                }
            
            HStack(alignment: .center, spacing: 12) {
                if let ipa = word.ipa {
                    Text(ipa)
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
                
                IconButton(icon: "speaker.wave.2.fill", action: { TTSManager.shared.speak(word.text) }, color: Theme.primary)
            }
        }
    }
    
    @ViewBuilder
    private var meaningsSection: some View {
        if let meanings = word.meanings {
            VStack(alignment: .center, spacing: 8) {
                Text(meanings)
                    .font(.system(size: 15))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
                    .contextMenu {
                        Button("复制释义") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(meanings, forType: .string)
                        }
                        Button("朗读释义") {
                            TTSManager.shared.speak(meanings)
                        }
                    }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .center)
            .background(Theme.secondaryBackground.opacity(0.6))
            .cornerRadius(12)
            .opacity(showMeanings ? 1 : 0)
            .animation(.easeInOut(duration: 0.2), value: showMeanings)
        }
    }
    
    @ViewBuilder
    private var examplesSection: some View {
        if let examples = word.examples {
            VStack(alignment: .leading, spacing: 8) {
                let exampleLines = splitExamples(examples)
                ForEach(0..<3, id: \.self) { index in
                    Text(index < exampleLines.count ? exampleLines[index] : "")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .textSelection(.enabled)
            }
            .padding(16)
            .background(Theme.secondaryBackground.opacity(0.3))
            .cornerRadius(12)
            .onHover { hovering in
                if hovering {
                    let currentHover = hovering
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 150_000_000)
                        if currentHover {
                            showChinesePopover = true
                        }
                    }
                } else {
                    showChinesePopover = false
                }
            }
            .popover(isPresented: $showChinesePopover, arrowEdge: .top) {
                if let chineseExamples = word.chineseExamples {
                    VStack(alignment: .leading, spacing: 8) {
                        let exampleLines = splitExamples(chineseExamples)
                        ForEach(0..<3, id: \.self) { index in
                            Text(index < exampleLines.count ? exampleLines[index] : "")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .frame(minWidth: 200)
                }
            }
        }
    }

    private func splitExamples(_ text: String) -> [String] {
        let components = text.components(separatedBy: "(")
        return components.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }
}
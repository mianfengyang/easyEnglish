import SwiftUI

struct LearningView: View {
    @ObservedObject var viewModel: LearningViewModel
    var onEnterSpellingMode: () -> Void
    var onShowStatistics: () -> Void
    
    @State private var previousIndex: Int = 0
    
    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            if let word = viewModel.currentWord {
                WordCard(word: word, showMeanings: $viewModel.showMeanings)
                controlButtonsView(word: word)
                navigationView
                SearchView()
            } else if viewModel.isLoading {
                loadingStateView
            } else {
                emptyStateView
            }
        }
        .padding(.horizontal, 60)
        .padding(.top, 16)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.background)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                playCurrentWord()
            }
        }
        .onChange(of: viewModel.sessionIndex) { newIndex in
            if newIndex != previousIndex {
                previousIndex = newIndex
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    playCurrentWord()
                }
            }
        }
    }
    
    private func playCurrentWord() {
        if let word = viewModel.currentWord {
            TTSManager.shared.speak(word.text)
        }
    }
    
    private func controlButtonsView(word: Word) -> some View {
        HStack(spacing: 12) {
            AccentButton("词根", icon: "book.fill") {
                NotificationCenter.default.post(
                    name: NSNotification.Name("ShowWordRootsDetail"),
                    object: word
                )
            }

            AccentButton("认识", icon: "checkmark.circle.fill") {
                viewModel.showMeanings = false
                viewModel.review(word: word, quality: 4)
                viewModel.next()
            }
            
            GhostButton("不认识", icon: "xmark.circle") {
                viewModel.showMeanings = true
                viewModel.review(word: word, quality: 0)
            }
            
            GhostButton("忘记", icon: "arrow.counterclockwise") {
                viewModel.showMeanings = true
                viewModel.review(word: word, quality: 0)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var navigationView: some View {
        HStack(spacing: 12) {
            SecondaryActionButton("上一个", icon: "chevron.left") {
                viewModel.previous()
            }
            
            ProgressBadge(current: viewModel.sessionIndex + 1, total: viewModel.sessionWords.count)
            
            if viewModel.isLastWord {
                AccentButton("进入拼写", icon: "arrow.clockwise") {
                    onEnterSpellingMode()
                }
            } else {
                SecondaryActionButton("下一个", icon: "chevron.right") {
                    viewModel.next()
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.closed")
                .font(.system(size: 48))
                .foregroundColor(Theme.primary.opacity(0.5))
            Text("未加载到学习单词")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
            AccentButton("重新加载 20 个单词", icon: "arrow.clockwise") {
                Task { await viewModel.loadSession(count: 20) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var loadingStateView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("正在加载单词...")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
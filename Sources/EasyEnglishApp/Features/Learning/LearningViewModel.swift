import Foundation
import Combine

@MainActor
final class LearningViewModel: ObservableObject {
    @Published var sessionWords: [Word] = []
    @Published var sessionIndex: Int = 0
    @Published var isLoading: Bool = false
    @Published var showMeanings: Bool = false
    
    private let repository: WordRepositoryProtocol
    private let settings: SettingsStore
    private var cancellables = Set<AnyCancellable>()
    
    var currentWord: Word? {
        guard !sessionWords.isEmpty, sessionWords.indices.contains(sessionIndex) else { return nil }
        return sessionWords[sessionIndex]
    }
    
    var progress: String {
        "\(sessionIndex + 1)/\(max(1, sessionWords.count))"
    }
    
    var isLastWord: Bool {
        !sessionWords.isEmpty && sessionIndex == sessionWords.count - 1
    }
    
    init(repository: WordRepositoryProtocol, settings: SettingsStore) {
        self.repository = repository
        self.settings = settings
        setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: NSNotification.Name("dailyNewLimitChanged"))
            .compactMap { $0.userInfo?["newLimit"] as? Int }
            .sink { [weak self] newLimit in
                Task { await self?.loadSession(count: newLimit) }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: NSNotification.Name("selectedWordlistChanged"))
            .sink { [weak self] _ in
                Task { await self?.loadSession(count: self?.settings.dailyNewLimit ?? 20) }
            }
            .store(in: &cancellables)
    }
    
    func loadInitialSession() {
        Task {
            await loadSession(count: settings.dailyNewLimit)
        }
    }
    
    func loadSession(count: Int) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // 混合加载：70%新单词 + 30%复习单词（SM-2调度）
            var words = try await repository.getMixedWords(count: count, newWordRatio: 0.7)
            if words.isEmpty {
                words = try await repository.getRandomWords(count: count)
            }
            
            // 加载单词时立即标记为已学习
            for word in words {
                try await repository.updateLearningStatus(wordText: word.text, quality: 3)
            }
            
            sessionWords = words
            sessionIndex = 0
            showMeanings = false
            Logger.success("成功加载并标记 \(words.count) 个单词")
        } catch {
            Logger.error("加载会话失败: \(error)")
            sessionWords = []
        }
    }
    
    func loadMoreWords(count: Int) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            var newWords = try await repository.getNewWords(count: count)
            if newWords.count < count {
                let remaining = count - newWords.count
                let randomWords = try await repository.getRandomWords(count: remaining)
                let existingIds = Set(sessionWords.map { $0.id })
                let additional = randomWords.filter { !existingIds.contains($0.id) }
                newWords.append(contentsOf: additional)
            }
            
            for word in newWords {
                try await repository.updateLearningStatus(wordText: word.text, quality: 3)
            }
            
            sessionWords = newWords
            sessionIndex = 0
            showMeanings = false
        } catch {
            Logger.error("加载额外单词失败: \(error)")
        }
    }
    
    func review(word: Word, quality: Int) {
        Task {
            do {
                try await repository.updateLearningStatus(wordText: word.text, quality: quality)
                if let index = sessionWords.firstIndex(where: { $0.id == word.id }) {
                    var updated = sessionWords[index]
                    updated.isLearned = true
                    sessionWords[index] = updated
                }
                Logger.success("已更新单词 \(word.text) 的学习状态")
            } catch {
                Logger.error("更新学习状态失败: \(error)")
            }
        }
    }
    
    func next() {
        showMeanings = false
        if isLastWord {
            return
        }
        if sessionIndex + 1 < sessionWords.count {
            sessionIndex += 1
        }
    }
    
    func previous() {
        showMeanings = false
        if sessionIndex > 0 {
            sessionIndex -= 1
        }
    }
    
    func resetSession() {
        for i in 0..<sessionWords.count {
            sessionWords[i].isLearned = false
            sessionWords[i].learnedAt = nil
            sessionWords[i].masteryLevel = 0
        }
        sessionIndex = 0
    }
    
    func shouldAutoEnterSpelling() -> Bool {
        guard let word = currentWord else { return false }
        return word.isLearned && isLastWord
    }
}
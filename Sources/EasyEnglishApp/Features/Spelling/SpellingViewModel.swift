import Foundation
import Combine

@MainActor
final class SpellingViewModel: ObservableObject {
    @Published var learnedWords: [Word] = []
    @Published var currentIndex: Int = 0
    @Published var userInput: String = ""
    @Published var feedback: [CharacterFeedback] = []
    @Published var isComplete: Bool = false
    @Published var correctCount: Int = 0
    @Published var incorrectCount: Int = 0
    
    private let repository: WordRepositoryProtocol
    
    struct CharacterFeedback {
        let character: String
        let status: SpellingLetterStatus
    }
    
    var currentWord: Word? {
        guard !learnedWords.isEmpty, learnedWords.indices.contains(currentIndex) else { return nil }
        return learnedWords[currentIndex]
    }
    
    var progress: String {
        "\(currentIndex + 1)/\(learnedWords.count)"
    }
    
    init(repository: WordRepositoryProtocol) {
        self.repository = repository
    }
    
    func setWords(_ words: [Word]) {
        learnedWords = words
        currentIndex = 0
        isComplete = false
        correctCount = 0
        incorrectCount = 0
        userInput = ""
        feedback = []
    }
    
    enum SpellingLetterStatus {
        case pending
        case correct
        case incorrect
    }
    
    func checkSpelling() {
        guard let word = currentWord else { return }
        let target = word.text.lowercased()
        let input = userInput.lowercased().trimmingCharacters(in: .whitespaces)
        
        feedback = []
        var correct = 0
        
        for (index, char) in input.enumerated() {
            if index < target.count {
                let targetChar = target[target.index(target.startIndex, offsetBy: index)]
                if char == targetChar {
                    feedback.append(CharacterFeedback(character: String(char), status: SpellingLetterStatus.correct))
                    correct += 1
                } else {
                    feedback.append(CharacterFeedback(character: String(char), status: SpellingLetterStatus.incorrect))
                }
            }
        }
        
        for index in input.count..<target.count {
            let targetChar = target[target.index(target.startIndex, offsetBy: index)]
            feedback.append(CharacterFeedback(character: String(targetChar), status: SpellingLetterStatus.pending))
        }
        
        if input == target {
            correctCount += 1
        } else {
            incorrectCount += 1
        }
    }
    
    func next() {
        if currentIndex + 1 < learnedWords.count {
            currentIndex += 1
            userInput = ""
            feedback = []
        } else {
            isComplete = true
        }
    }
    
    func reset() {
        currentIndex = 0
        userInput = ""
        feedback = []
        isComplete = false
        correctCount = 0
        incorrectCount = 0
    }
    
    func review(word: Word, quality: Int) {
        Task {
            do {
                try await repository.updateLearningStatus(wordText: word.text, quality: quality)
            } catch {
                Logger.error("更新学习状态失败: \(error)")
            }
        }
    }
}
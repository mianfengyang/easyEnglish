import Foundation

protocol WordRepositoryProtocol {
    func getNewWords(count: Int) async throws -> [Word]
    func getRandomWords(count: Int) async throws -> [Word]
    func getReviewWords(count: Int) async throws -> [Word]
    func getMixedWords(count: Int, newWordRatio: Double) async throws -> [Word]
    func getWord(byId id: UUID) async throws -> Word?
    func getWord(byText text: String) async throws -> Word?
    func searchWords(query: String) async throws -> [Word]
    func updateLearningStatus(wordText: String, quality: Int) async throws
    func getTotalCount() async throws -> Int
    func getLearnedCount() async throws -> Int64
    func getDailyStats() async throws -> DailyStats
    func getMasteryDistribution() async throws -> [MasteryDistribution]
    func getWeeklyTrend(weeks: Int) async throws -> [WeeklyTrend]
    func getMasteryTrend() async throws -> MasteryTrend
    func getRecentWords(limit: Int) async throws -> [Word]
}

protocol LearningSessionProtocol {
    var sessionWords: [Word] { get }
    var sessionIndex: Int { get }
    var isLoading: Bool { get }
    
    func loadSession(count: Int) async
    func loadMoreWords(count: Int) async
    func review(word: Word, quality: Int) async
}

protocol SettingsRepositoryProtocol {
    var themeMode: ThemeMode { get }
    var dailyNewLimit: Int { get }
    var selectedWordlist: String { get }
    var autoPlayTTS: Bool { get }
    
    func setThemeMode(_ mode: ThemeMode)
    func setDailyNewLimit(_ limit: Int)
    func setSelectedWordlist(_ path: String)
    func setAutoPlayTTS(_ enabled: Bool)
}

protocol BackupServiceProtocol {
    func backup() async throws -> URL
    func restore(from url: URL) async throws
    func getBackupList() async throws -> [URL]
}

protocol TTSServiceProtocol {
    func speak(_ text: String)
    func stop()
    var isSpeaking: Bool { get }
}

enum DatabaseError: Error {
    case notInitialized
    case wordNotFound(String)
    case connectionFailed
}
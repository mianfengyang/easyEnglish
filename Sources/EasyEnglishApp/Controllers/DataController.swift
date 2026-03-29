import Foundation
import SwiftUI
import Combine
import os.log
import SQLite

/// 学习会话管理器 - 管理单词学习会话状态
/// 
/// 职责：
/// - 加载单词会话
/// - 管理当前学习进度
/// - 同步 UI 状态与数据库
/// 
/// 注意：这不是一个数据访问层（Repository），数据访问由 WordDatabaseManager 负责
final class LearningSessionManager: ObservableObject {
    static let shared = LearningSessionManager()
    
    @Published var sessionWords: [WordData] = []
    @Published var sessionIndex: Int = 0
    @Published var isLoadingSession: Bool = true
    
    private var dbInitialized = false
    private var cancellables = Set<AnyCancellable>()

    private init() {
        Logger.info("========== LearningSessionManager 初始化开始 ==========")
        Logger.debug("当前目录：\(FileManager.default.currentDirectoryPath)")
        Logger.debug("Bundle 路径：\(Bundle.main.resourcePath ?? "nil")")
        
        // 同步初始化数据库
        Logger.info("开始同步初始化数据库...")
        initializeDatabaseIfNeeded()
        
        Logger.success("数据库初始化完成")
        
        // 立即加载会话（同步）
        let count = SettingsStore.shared.dailyNewLimit
        Logger.info("主线程加载 \(count) 个单词...")
        loadRandomSession(count: count)
        
        // 验证加载结果
        Logger.info("========== 初始化完成后的状态检查 ==========")
        Logger.debug("sessionWords.count = \(sessionWords.count)")
        Logger.debug("sessionIndex = \(sessionIndex)")
        Logger.debug("isLoadingSession = \(isLoadingSession)")
        if !sessionWords.isEmpty {
            Logger.success("第一个单词：\(sessionWords[0].text)")
        } else {
            Logger.warning("sessionWords 为空！这会导致 UI 显示'未加载到学习单词'")
        }
        
        // 监听每日新词数量变化通知
        NotificationCenter.default.publisher(for: NSNotification.Name("dailyNewLimitChanged"))
            .compactMap { $0.userInfo?["newLimit"] as? Int }
            .sink { [weak self] newLimit in
                self?.handleDailyNewLimitChange(newLimit: newLimit)
            }
            .store(in: &cancellables)
    }
    
    /// 初始化数据库（仅首次启动时执行）
    private func initializeDatabaseIfNeeded() {
        Logger.info("LearningSessionManager: 开始数据库初始化...")
        
        defer {
            Logger.info("LearningSessionManager: 数据库初始化完成")
            dbInitialized = true
        }
        
        guard !dbInitialized else { 
            Logger.warning("数据库已经初始化过，跳过")
            return 
        }
        
        do {
            Logger.debug("调用 WordDatabaseManager.initializeDatabase()")
            try WordDatabaseManager.shared.initializeDatabase()
            Logger.success("WordDatabaseManager 初始化成功")
            
            // 验证数据库中是否有数据
            if let count = try? WordDatabaseManager.shared.getTotalWordCount() {
                if count == 0 {
                    Logger.warning("数据库为空，请先运行导入工具：swift run import_database")
                } else {
                    Logger.info("数据库包含 \(count) 个单词")
                }
            } else {
                Logger.error("无法获取数据库单词数量")
            }
            
            Logger.success("Database initialized successfully")
            
        } catch {
            Logger.error("Database initialization error", error: error)
        }
    }

    /// 从 SQLite 数据库加载随机单词会话（同步版本）
    func loadRandomSession(count: Int) {
        Logger.info("========== 开始加载单词会话 ==========")
        Logger.debug("请求加载单词数：\(count)")
        
        // 标记开始加载
        self.isLoadingSession = true
        
        do {
            Logger.info("尝试从 SQLite 加载未学习过的新单词...")
            
            var wordsData: [WordData] = []
            
            Logger.debug("调用 WordDatabaseManager.getNewUnlearnedWordsData(count: \(count))")
            wordsData = try WordDatabaseManager.shared.getNewUnlearnedWordsData(count: count)
            Logger.success("成功获取到 \(wordsData.count) 个单词")
            
            // 如果没有新单词，随机获取
            if wordsData.isEmpty {
                Logger.warning("未找到新单词，尝试从数据库随机加载...")
                wordsData = try WordDatabaseManager.shared.getRandomWordsData(count: count)
                Logger.success("getRandomWordsData 返回 \(wordsData.count) 个单词")
            }
            
            // 同步更新数据
            self.sessionWords = wordsData
            self.sessionIndex = 0
            self.isLoadingSession = false
            
            Logger.info("========== 单词加载完成 ==========")
            Logger.info("Loaded \(wordsData.count) words from SQLite")
            
            if wordsData.isEmpty {
                Logger.warning("没有加载到任何单词！")
            } else {
                Logger.debug("Session words: \(wordsData.prefix(3).map { $0.text }.joined(separator: ", "))...")
            }
            
        } catch {
            Logger.error("Error loading session", error: error)
            self.sessionWords = []
            self.sessionIndex = 0
            self.isLoadingSession = false
        }
    }
    
    /// 从数据库直接获取单词数据（不经过 CoreData）
    func getWordDataForSession(wordId: UUID) -> WordData? {
        do {
            return try WordDatabaseManager.shared.getWordDataById(id: wordId)
        } catch {
            Logger.error("获取单词数据失败", error: error)
            return nil
        }
    }
    
    /// 处理每日新词数量变化
    private func handleDailyNewLimitChange(newLimit: Int) {
        Logger.info("检测到每日新词数量变化：\(newLimit)，重新加载会话...")
        loadRandomSession(count: newLimit)
    }
    
    /// 更新单词的学习状态（直接写入 SQLite）
    func review(word: WordData, quality: Int, attemptType: String = "manual", timeSpent: TimeInterval = 0, answer: String? = nil) {
        do {
            try WordDatabaseManager.shared.updateWordLearningStatus(
                text: word.text,
                quality: quality,
                attemptType: attemptType
            )
            Logger.success("已更新单词 \(word.text) 的学习状态")
            
            // ✅ 关键修复：同时更新内存中的 sessionWords
            // 找到当前单词在数组中的位置并更新 isLearned
            if let index = sessionWords.firstIndex(where: { $0.id == word.id }) {
                var updatedWord = sessionWords[index]
                updatedWord.isLearned = true
                updatedWord.learnedAt = Date()
                sessionWords[index] = updatedWord
                
                Logger.debug("✅ 已更新内存中单词 \(word.text) 的 isLearned = true")
                Logger.debug("   sessionWords[\(index)].isLearned = \(sessionWords[index].isLearned)")
            } else {
                Logger.warning("⚠️ 在 sessionWords 中未找到单词 \(word.text)")
            }
        } catch {
            Logger.error("更新学习状态失败", error: error)
        }
    }
}

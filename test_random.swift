import Foundation
import SQLite

// 数据库路径
let dbPath = "/Users/mifyang/project/easyEnglish/Sources/EasyEnglishApp/Resources/wordlist.sqlite"

do {
    let connection = try Connection(dbPath, readonly: true)
    
    // 方法1: 使用 SQLite.swift Expression 方式
    let words = Table("words")
    let id = Expression<UUID>("id")
    let text = Expression<String>("text")
    let isLearned = Expression<Bool?>("is_learned")
    
    print("=== 方法1: 使用 SQLite.swift Expression RANDOM() ===")
    print("--- 第一次运行 ---")
    
    let query1 = words.filter(isLearned == nil || isLearned == false)
        .order(Expression<Int64>("RANDOM()"))
        .limit(10)
    
    let words1 = try connection.prepare(query1).map { row -> (UUID, String) in
        (row[id], row[text])
    }
    
    print("随机结果 1:", words1.map { $0.1 })
    
    try Thread.sleep(forTimeInterval: 0.1)
    
    let query2 = words.filter(isLearned == nil || isLearned == false)
        .order(Expression<Int64>("RANDOM()"))
        .limit(10)
    
    let words2 = try connection.prepare(query2).map { row -> (UUID, String) in
        (row[id], row[text])
    }
    
    print("随机结果 2:", words2.map { $0.1 })
    
    // 方法2: 使用原始 SQL
    print("\n=== 方法2: 使用原始 SQL RANDOM() ===")
    
    let query3 = "SELECT id, text FROM words WHERE is_learned IS NULL OR is_learned = 0 ORDER BY RANDOM() LIMIT 10"
    
    let words3 = try connection.prepare(query3).map { row -> (UUID, String) in
        (row[id], row[text])
    }
    
    print("原始SQL结果 1:", words3.map { $0.1 })
    
    try Thread.sleep(forTimeInterval: 0.1)
    
    let query4 = "SELECT id, text FROM words WHERE is_learned IS NULL OR is_learned = 0 ORDER BY RANDOM() LIMIT 10"
    let words4 = try connection.prepare(query4).map { row -> (UUID, String) in
        (row[id], row[text])
    }
    
    print("原始SQL结果 2:", words4.map { $0.1 })
    
    // 检查数据库中的单词总数
    let totalCount = try connection.scalar(words.count)
    print("\n总单词数: \(totalCount)")
    
    let learnedCount = try connection.scalar(
        words.filter(isLearned == true).count
    )
    print("已学习单词数: \(learnedCount)")
    
    let unlearnedCount = try connection.scalar(
        words.filter(isLearned == nil || isLearned == false).count
    )
    print("未学习单词数: \(unlearnedCount)")
    
    // 查看前20个单词的顺序（不使用随机）
    print("\n=== 不随机的顺序结果（前20个） ===")
    let orderedWords = try connection.prepare(words.order(text.asc).limit(20)).map { row -> (UUID, String) in
        (row[id], row[text])
    }
    print("顺序前20:", orderedWords.map { $0.1 })
    
} catch {
    print("错误: \(error)")
}

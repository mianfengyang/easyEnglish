import Foundation
import SQLite

let dbPath = "/Users/mifyang/project/easyEnglish/Sources/EasyEnglishApp/Resources/wordlist.sqlite"

do {
    let connection = try Connection(dbPath, readonly: true)
    
    // 测试 1: 使用 Expression<Int64>("RANDOM()") — 当前代码写法
    let words = Table("words")
    let isLearned = Expression<Bool?>("is_learned")
    
    print("=== 测试 1: 当前写法: Expression<Int64>(\"RANDOM()\") ===")
    let query1 = words.filter(isLearned == nil || isLearned == false)
        .order(Expression<Int64>("RANDOM()"))
        .limit(5)
    
    // 打印生成的 SQL（通过调试打印）
    let stmt1 = try connection.prepare(query1)
    for row in stmt1 {
        // 这里不处理结果，只执行一次
        print("(query executed)")
        break
    }
    
    // 测试 2: 使用原始 SQL
    print("\n=== 测试 2: 使用自定义 SQL ===")
    let query2 = "SELECT * FROM words WHERE is_learned IS NULL OR is_learned = 0 ORDER BY RANDOM() LIMIT 5"
    for row in try connection.prepare(query2) {
        if let text = row[Expression<String>("text")] {
            print(text)
        }
    }
    
    // 测试 3: 多次调用 Expression<Int64>("RANDOM()") 看是否真的随机
    print("\n=== 测试 3: 连续调用 10 次 Expression 方式 ===")
    for i in 1...10 {
        let query3 = words.filter(isLearned == nil || isLearned == false)
            .order(Expression<Int64>("RANDOM()"))
            .limit(3)
        
        let words3 = try connection.prepare(query3).compactMap { row -> String? in
            row[Expression<String>("text")]
        }
        print("调用 \(i): \(words3)")
    }
    
    // 测试 4: 多次调用原始 SQL 方式看是否随机
    print("\n=== 测试 4: 连续调用 10 次原始 SQL 方式 ===")
    for i in 1...10 {
        let query4 = "SELECT text FROM words WHERE is_learned IS NULL OR is_learned = 0 ORDER BY RANDOM() LIMIT 3"
        let words4 = try connection.prepare(query4).compactMap { row -> String? in
            row[Expression<String>("text")]
        }
        print("调用 \(i): \(words4)")
    }
    
} catch {
    print("错误: \(error)")
}

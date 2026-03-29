import Foundation
import SQLite

/// 独立数据库导入工具 - 用于在应用启动前预创建数据库
@main
struct DatabaseImporter {
    
    static func main() throws {
        print("🚀 EasyEnglish 数据库导入工具")
        print("================================\n")
        
        // 1. 确定路径
        let basePath = FileManager.default.currentDirectoryPath
        let wordlistsDir = URL(fileURLWithPath: basePath).appendingPathComponent("Data/wordlists")
        let dbPath = wordlistsDir.appendingPathComponent("wordlist.sqlite").path
        let jsonPath = wordlistsDir.appendingPathComponent("cet4.apkg.json").path
        
        print("📂 工作目录：\(basePath)")
        print("📂 目标目录：\(wordlistsDir.path)")
        print("📄 JSON 文件：\(jsonPath)")
        print("🗄️  数据库：\(dbPath)\n")
        
        // 2. 检查 JSON 文件是否存在
        guard FileManager.default.fileExists(atPath: jsonPath) else {
            print("❌ 错误：找不到 JSON 文件 \(jsonPath)")
            exit(1)
        }
        
        print("✅ JSON 文件存在")
        
        // 3. 检查是否已存在数据库
        if FileManager.default.fileExists(atPath: dbPath) {
            print("⚠️  数据库已存在：\(dbPath)")
            print("💡 如果要重新创建，请先删除现有数据库:")
            print("   rm \(dbPath)")
            
            // 显示现有数据库信息
            let attrs = try FileManager.default.attributesOfItem(atPath: dbPath)
            let size = attrs[.size] as? Int ?? 0
            print("   大小：\(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))")
            
            let count = try? getWordCount(dbPath: dbPath)
            print("   单词数：\(count ?? 0)")
            
            print("\n❓ 是否删除并重新创建？(y/N): ", terminator: "")
            if let input = readLine(), input.lowercased() == "y" {
                print("🗑️  删除旧数据库...")
                try FileManager.default.removeItem(atPath: dbPath)
                print("✅ 已删除\n")
            } else {
                print("👌 保留现有数据库，退出程序")
                return
            }
        }
        
        // 4. 创建目录
        print("📁 创建目录...")
        try FileManager.default.createDirectory(at: wordlistsDir, withIntermediateDirectories: true)
        print("✅ 目录就绪\n")
        
        // 5. 创建数据库连接
        print("🗄️  创建数据库...")
        let db = try Connection(dbPath)
        print("✅ 数据库连接成功\n")
        
        // 6. 创建表结构
        print("📋 创建表结构...")
        let words = Table("words")
        let id = Expression<UUID>("id")
        let text = Expression<String>("text")
        let ipa = Expression<String?>("ipa")
        let meanings = Expression<String?>("meanings")
        let examples = Expression<String?>("examples")
        let chineseExamples = Expression<String?>("chineseExamples")
        let roots = Expression<String?>("roots")
        
        try db.run(words.create { t in
            t.column(id, primaryKey: true)
            t.column(text, unique: true)
            t.column(ipa)
            t.column(meanings)
            t.column(examples)
            t.column(chineseExamples)
            t.column(roots)
            // 学习统计字段 - 可选类型，允许为 NULL
            t.column(Expression<Bool?>("is_learned"))
            t.column(Expression<Date?>("learned_at"))
            t.column(Expression<Int64?>("mastery_level"))
            t.column(Expression<Int64?>("review_count"))
            t.column(Expression<Int64?>("correct_count"))
            t.column(Expression<Int64?>("incorrect_count"))
            t.column(Expression<Date?>("last_reviewed_at"))
            t.column(Expression<Date?>("next_review_at"))
            t.column(Expression<Double?>("ef"))
            t.column(Expression<Int64?>("interval"))
            t.column(Expression<Int64?>("reps"))
        })

        // 创建索引
        try db.run(words.createIndex(text, unique: true))
        
        // 创建数据库统计信息表
        let databaseStats = Table("database_stats")
        let idStat = Expression<Int64>("id")
        let databaseName = Expression<String>("database_name")
        let totalWords = Expression<Int64>("total_words")
        let learnedWords = Expression<Int64>("learned_words")
        let unlearnedWords = Expression<Int64>("unlearned_words")
        let lastUpdated = Expression<Date>("last_updated")
        
        try db.run(databaseStats.create { t in
            t.column(idStat, primaryKey: true)
            t.column(databaseName)
            t.column(totalWords)
            t.column(learnedWords)
            t.column(unlearnedWords)
            t.column(lastUpdated)
        })
        
        print("✅ words 表创建完成")
        print("✅ database_stats 表创建完成\n")
        
        // 7. 读取 JSON 文件
        print("📖 读取 JSON 文件...")
        let jsonData = try Data(contentsOf: URL(fileURLWithPath: jsonPath))
        print("✅ JSON 加载成功")
        
        let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: [])
        var entries: [[String: Any]] = []
        
        if let arr = jsonObject as? [[String: Any]] {
            entries = arr
        } else if let dict = jsonObject as? [String: Any], let inner = dict["notes"] as? [[String: Any]] {
            entries = inner
        }
        
        print("📊 解析到 \(entries.count) 个单词条目\n")
        
        // 8. 批量插入数据
        print("📝 导入数据...")
        var imported = 0
        var failed = 0
        
        try db.transaction {
            for (index, item) in entries.enumerated() {
                let textVal = item["英语单词"] as? String ?? ""
                if textVal.trimmingCharacters(in: .whitespaces).isEmpty {
                    continue
                }
                
                let ipaVal = item["英美音标"] as? String
                let meaningsVal = item["中文释义"] as? String
                let examplesVal = item["英语例句"] as? String
                let chineseExamplesVal = item["中文例句"] as? String
                let rootsVal = item["Back"] as? String
                
                let uuid = UUID()
                
                do {
                    try db.run(words.insert(
                        id <- uuid,
                        text <- textVal,
                        ipa <- ipaVal,
                        meanings <- meaningsVal,
                        examples <- examplesVal,
                        chineseExamples <- chineseExamplesVal,
                        roots <- rootsVal
                    ))
                    imported += 1
                    
                    // 显示进度
                    if (index + 1) % 500 == 0 {
                        let percent = Double(index + 1) / Double(entries.count) * 100
                        print("   进度：\(index + 1)/\(entries.count) (\(String(format: "%.1f", percent))%)")
                    }
                } catch {
                    failed += 1
                    if failed <= 5 {
                        print("⚠️  导入失败：\(textVal) - \(error.localizedDescription)")
                    }
                }
            }
        }
        
        print("\n✅ 数据导入完成")
        print("   成功：\(imported) 个单词")
        print("   失败：\(failed) 个单词\n")
        
        // 9. 验证结果
        let count = try db.scalar(words.count)
        print("📊 数据库统计:")
        print("   总单词数：\(count)")
        
        // 10. 插入初始统计信息到 database_stats 表
        print("\n📝 写入统计信息...")
        let statsInsert = databaseStats.insert(
            idStat <- 1,
            databaseName <- "CET-4 词库",
            totalWords <- Int64(count),
            learnedWords <- 0,
            unlearnedWords <- Int64(count),
            lastUpdated <- Date()
        )
        try db.run(statsInsert)
        print("✅ 统计信息已写入\n")
        
        let size = try FileManager.default.attributesOfItem(atPath: dbPath)[.size] as? Int ?? 0
        print("   文件大小：\(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))")
        print("   路径：\(dbPath)\n")
        
        // 11. 显示示例数据
        print("📚 前 5 个单词示例:")
        let query = words.order(text).limit(5)
        for result in try db.prepare(query) {
            let word = result[text]
            let ipa = result[ipa] ?? "N/A"
            let meaning = result[meanings] ?? "N/A"
            print("   • \(word) | \(ipa) | \(meaning)")
        }
        
        print("\n================================")
        print("🎉 数据库创建成功！")
        print("================================\n")
        
        print("💡 下一步:")
        print("   运行应用：swift run EasyEnglish")
        print("   应用将从数据库加载未学习的新单词\n")
    }
    
    /// 获取数据库中的单词数量
    static func getWordCount(dbPath: String) throws -> Int {
        let db = try Connection(dbPath, readonly: true)
        let words = Table("words")
        return try db.scalar(words.count)
    }
}

import Foundation
import SQLite3

/// 词根信息更新工具 - 从网络抓取词根信息并更新数据库
struct RootsUpdater {
    // 定义 SQLite 常量
    static let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    
    // 缓存机制
    static var rootsCache: [String: String] = [:]
    
    static func main() {
        print("🚀 EasyEnglish 词根信息更新工具")
        print("===============================")
        
        // 1. 确定路径
        var basePath = FileManager.default.currentDirectoryPath
        // 如果当前在 scripts 目录下，切换到项目根目录
        if basePath.hasSuffix("scripts") {
            basePath = String(basePath.dropLast(7)) // 移除 "/scripts"
        }
        let wordlistsDir = URL(fileURLWithPath: basePath).appendingPathComponent("Data/wordlists")
        let dbPath = wordlistsDir.appendingPathComponent("wordlist.sqlite").path
        let cachePath = wordlistsDir.appendingPathComponent("roots_cache.json").path
        
        print("📂 工作目录：\(basePath)")
        print("🗄️  数据库：\(dbPath)")
        print("💾 缓存文件：\(cachePath)\n")
        
        // 加载缓存
        if FileManager.default.fileExists(atPath: cachePath) {
            print("📥 加载缓存...")
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: cachePath))
                if let cached = try JSONSerialization.jsonObject(with: data) as? [String: String] {
                    rootsCache = cached
                    print("✅ 缓存加载成功，包含 \(rootsCache.count) 个单词的词根信息")
                }
            } catch {
                print("⚠️  缓存加载失败：\(error.localizedDescription)")
            }
        }
        
        // 2. 检查数据库是否存在
        guard FileManager.default.fileExists(atPath: dbPath) else {
            print("❌ 错误：找不到数据库文件 \(dbPath)")
            print("💡 请先运行导入工具：swift run import_database")
            exit(1)
        }
        
        print("✅ 数据库存在")
        
        // 3. 连接数据库
        print("🗄️  连接数据库...")
        var db: OpaquePointer?
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("❌ 数据库连接失败")
            exit(1)
        }
        defer { sqlite3_close(db) }
        print("✅ 数据库连接成功\n")
        
        // 4. 获取所有单词
        print("📊 获取单词列表...")
        var wordsToUpdate: [(String, String, String?)] = []
        
        var stmt: OpaquePointer?
        let query = "SELECT id, text, roots FROM words"
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(stmt, 0))
                let text = String(cString: sqlite3_column_text(stmt, 1))
                var roots: String? = nil
                if let rootsData = sqlite3_column_text(stmt, 2) {
                    roots = String(cString: rootsData)
                }
                wordsToUpdate.append((id, text, roots))
            }
        }
        sqlite3_finalize(stmt)
        
        print("✅ 找到 \(wordsToUpdate.count) 个单词\n")
        
        // 5. 批量更新词根信息（多线程）
        print("📝 更新词根信息...")
        var updated = 0
        var failed = 0
        
        // 限制并发数，避免被网站封禁
        let maxConcurrent = 5
        let semaphore = DispatchSemaphore(value: maxConcurrent)
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "com.easyenglish.rootsupdater", qos: .userInitiated, attributes: .concurrent)
        
        // 线程安全的计数器和缓存更新
        let counterQueue = DispatchQueue(label: "com.easyenglish.counter")
        
        for (index, (wordId, wordText, _)) in wordsToUpdate.enumerated() {
            semaphore.wait()
            
            queue.async(group: group) {
                defer {
                    semaphore.signal()
                }
                
                print("   处理单词：\(wordText) (\(index + 1)/\(wordsToUpdate.count))")
                
                // 检查缓存
                if let cachedRoots = counterQueue.sync(execute: { rootsCache[wordText.lowercased()] }) {
                    print("   📥 从缓存获取词根信息")
                    counterQueue.sync {
                        var updateStmt: OpaquePointer?
                        let updateQuery = "UPDATE words SET roots = ? WHERE id = ?"
                        if sqlite3_prepare_v2(db, updateQuery, -1, &updateStmt, nil) == SQLITE_OK {
                            sqlite3_bind_text(updateStmt, 1, cachedRoots, -1, RootsUpdater.SQLITE_TRANSIENT)
                            sqlite3_bind_text(updateStmt, 2, wordId, -1, RootsUpdater.SQLITE_TRANSIENT)
                            if sqlite3_step(updateStmt) == SQLITE_DONE {
                                updated += 1
                                print("   ✅ 已更新：\(wordText)")
                            } else {
                                failed += 1
                                print("   ❌ 更新失败：\(wordText)")
                            }
                        }
                        sqlite3_finalize(updateStmt)
                    }
                    return
                }
                
                do {
                    // 从网络获取词根信息
                    if let rootInfo = try fetchRootInfo(for: wordText) {
                        // 更新缓存和数据库
                        counterQueue.sync {
                            rootsCache[wordText.lowercased()] = rootInfo
                            var updateStmt: OpaquePointer?
                            let updateQuery = "UPDATE words SET roots = ? WHERE id = ?"
                            if sqlite3_prepare_v2(db, updateQuery, -1, &updateStmt, nil) == SQLITE_OK {
                                sqlite3_bind_text(updateStmt, 1, rootInfo, -1, RootsUpdater.SQLITE_TRANSIENT)
                            sqlite3_bind_text(updateStmt, 2, wordId, -1, RootsUpdater.SQLITE_TRANSIENT)
                                if sqlite3_step(updateStmt) == SQLITE_DONE {
                                    updated += 1
                                    print("   ✅ 已更新：\(wordText)")
                                } else {
                                    failed += 1
                                    print("   ❌ 更新失败：\(wordText)")
                                }
                            }
                            sqlite3_finalize(updateStmt)
                        }
                    } else {
                        counterQueue.sync { failed += 1 }
                        print("   ⚠️  未找到词根信息：\(wordText)")
                    }
                    
                    // 避免请求过快被封禁
                    Thread.sleep(forTimeInterval: 0.2)
                    
                } catch {
                    counterQueue.sync { failed += 1 }
                    print("   ❌ 更新失败：\(wordText) - \(error.localizedDescription)")
                }
            }
        }
        
        // 等待所有任务完成
        group.wait()
        
        print("\n✅ 词根信息更新完成")
        print("   成功：\(updated) 个单词")
        print("   失败：\(failed) 个单词")
        print("   跳过：\(wordsToUpdate.count - updated - failed) 个单词（已有词根信息）\n")
        
        // 6. 显示示例数据
        print("📚 更新后的词根信息示例:")
        var exampleStmt: OpaquePointer?
        let exampleQuery = "SELECT text, roots FROM words WHERE roots IS NOT NULL ORDER BY text LIMIT 5"
        if sqlite3_prepare_v2(db, exampleQuery, -1, &exampleStmt, nil) == SQLITE_OK {
            while sqlite3_step(exampleStmt) == SQLITE_ROW {
                let word = String(cString: sqlite3_column_text(exampleStmt, 0))
                let rootInfo = String(cString: sqlite3_column_text(exampleStmt, 1))
                print("   • \(word): \(rootInfo)")
            }
        }
        sqlite3_finalize(exampleStmt)
        
        // 保存缓存
        let cacheURL = wordlistsDir.appendingPathComponent("roots_cache.json")
        
        print("\n💾 保存缓存...")
        do {
            let data = try JSONSerialization.data(withJSONObject: rootsCache, options: .prettyPrinted)
            try data.write(to: cacheURL)
            print("✅ 缓存保存成功，包含 \(rootsCache.count) 个单词的词根信息")
        } catch {
            print("⚠️  缓存保存失败：\(error.localizedDescription)")
        }
        
        print("\n===============================")
        print("🎉 词根信息更新工具完成！")
        print("===============================")
    }
    // 从网络获取词根信息
    static func fetchRootInfo(for word: String) throws -> String? {
        // 尝试从 quword.com 获取词根信息
        print("   尝试从 quword.com 获取...")
        if let rootInfo = try fetchFromQuWord(word) {
            return rootInfo
        }
        
        // 如果 quword.com 失败，尝试基于单词结构分析
        return try fetchFromWordAnalysis(word)
    }
    
    /// 从 quword.com 获取词根信息
    static func fetchFromQuWord(_ word: String) throws -> String? {
        let encodedWord = word.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? word
        let urlString = "https://www.quword.com/w/\(encodedWord)"
        
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "RootsUpdater", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        var rootInfo: String? = nil
        var error: Error? = nil
        
        let task = URLSession.shared.dataTask(with: url) { data, response, _ in
            defer { semaphore.signal() }
            
            guard let data = data, let html = String(data: data, encoding: .utf8) else {
                error = NSError(domain: "RootsUpdater", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"])
                return
            }
            
            // 解析 HTML 获取词根信息
            rootInfo = parseQuWordHTML(html)
        }
        
        task.resume()
        semaphore.wait()
        
        if let error = error {
            throw error
        }
        
        return rootInfo
    }
    
    /// 解析 quword.com 的 HTML 内容 - 只抓取助记提示和中文词源
    static func parseQuWordHTML(_ html: String) -> String? {
        var rootInfo = ""
        
        // 1. 抓取"助记提示"部分
        if let mnemonicRange = html.range(of: "助记提示") {
            let startIndex = mnemonicRange.upperBound
            // 找到助记提示内容的结束位置（下一个<h3>标签或<div class="section">或<div class="related">）
            let remainingHtml = String(html[startIndex...])
            
            // 提取助记提示的内容
            if let contentEndRange = remainingHtml.range(of: "<h3") ?? remainingHtml.range(of: "<div class=\"section\"") ?? remainingHtml.range(of: "<div class=\"related\"") {
                let content = String(remainingHtml[..<contentEndRange.lowerBound])
                // 提取纯文本
                var cleanText = content.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                // 清理特殊字符
                cleanText = cleanText.replacingOccurrences(of: "&nbsp;", with: " ")
                cleanText = cleanText.replacingOccurrences(of: "&quot;", with: "\"")
                cleanText = cleanText.replacingOccurrences(of: "&amp;", with: "&")
                cleanText = cleanText.replacingOccurrences(of: "&lt;", with: "<")
                cleanText = cleanText.replacingOccurrences(of: "&gt;", with: ">")
                
                // 过滤掉无关内容
                cleanText = filterIrrelevantContent(cleanText)
                
                let trimmed = cleanText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty && !isIrrelevantContent(trimmed) && !containsExcessiveWhitespace(trimmed) && !isLowQualityContent(trimmed) {
                    rootInfo += "【助记提示】\n" + trimmed + "\n\n"
                }
            }
        }
        
        // 2. 抓取"中文词源"部分
        if let etymologyRange = html.range(of: "中文词源") {
            let startIndex = etymologyRange.upperBound
            let remainingHtml = String(html[startIndex...])
            
            // 提取中文词源的内容
            if let contentEndRange = remainingHtml.range(of: "<h3") ?? remainingHtml.range(of: "<div class=\"section\"") ?? remainingHtml.range(of: "<div class=\"related\"") {
                let content = String(remainingHtml[..<contentEndRange.lowerBound])
                // 提取纯文本
                var cleanText = content.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                // 清理特殊字符
                cleanText = cleanText.replacingOccurrences(of: "&nbsp;", with: " ")
                cleanText = cleanText.replacingOccurrences(of: "&quot;", with: "\"")
                cleanText = cleanText.replacingOccurrences(of: "&amp;", with: "&")
                cleanText = cleanText.replacingOccurrences(of: "&lt;", with: "<")
                cleanText = cleanText.replacingOccurrences(of: "&gt;", with: ">")
                
                // 过滤掉无关内容
                cleanText = filterIrrelevantContent(cleanText)
                
                let trimmed = cleanText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty && !isIrrelevantContent(trimmed) && !containsExcessiveWhitespace(trimmed) && !isLowQualityContent(trimmed) {
                    rootInfo += "【中文词源】\n" + trimmed + "\n\n"
                }
            }
        }
        
        // 3. 如果没有找到助记提示和中文词源，尝试抓取词源信息
        if rootInfo.isEmpty {
            // 查找包含"词源"的部分
            if let etymologyRange = html.range(of: "词源") {
                let startIndex = etymologyRange.upperBound
                let remainingHtml = String(html[startIndex...])
                
                if let contentEndRange = remainingHtml.range(of: "<h3") ?? remainingHtml.range(of: "<div class=\"section\"") ?? remainingHtml.range(of: "<div class=\"related\"") {
                    let content = String(remainingHtml[..<contentEndRange.lowerBound])
                    var cleanText = content.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    // 清理特殊字符
                    cleanText = cleanText.replacingOccurrences(of: "&nbsp;", with: " ")
                    cleanText = cleanText.replacingOccurrences(of: "&quot;", with: "\"")
                    cleanText = cleanText.replacingOccurrences(of: "&amp;", with: "&")
                    cleanText = cleanText.replacingOccurrences(of: "&lt;", with: "<")
                    cleanText = cleanText.replacingOccurrences(of: "&gt;", with: ">")
                    
                    // 过滤掉无关内容
                    cleanText = filterIrrelevantContent(cleanText)
                    
                    let trimmed = cleanText.trimmingCharacters(in: .whitespacesAndNewlines)
                    // 更严格的过滤条件，确保内容是真正的词源信息
                    if !trimmed.isEmpty && trimmed.count > 100 && !isIrrelevantContent(trimmed) && !containsExcessiveWhitespace(trimmed) && !isLowQualityContent(trimmed) && containsMeaningfulContent(trimmed) {
                        rootInfo += "【词源】\n" + trimmed + "\n\n"
                    }
                }
            }
        }
        
        let finalResult = rootInfo.trimmingCharacters(in: .whitespacesAndNewlines)
        return finalResult.isEmpty ? nil : finalResult
    }
    
    /// 过滤掉无关内容
    static func filterIrrelevantContent(_ text: String) -> String {
        var filtered = text
        
        // 过滤掉常见的无关内容
        let irrelevantKeywords = [
            "词源字典", "词根词缀", "英文词源", "双语词典", "英语词典", "在线翻译",
            "图片搜索", "网页搜索", "影视搜索", "词汇量测试", "看图背单词",
            "单词拼写练习", "公众号", "小程序", "百度", "谷歌", "必应",
            "有道", "爱词霸", "海词", "搜狗", "好搜", "神马", "头条",
            "英文名", "英语新闻", "英语点津", "双语词典", "有道词典", "海词词典",
            "必应词典", "英文词典", "英语词源", "词根字典", "百度图片", "好搜图片",
            "搜狗图片", "必应图片", "爱奇艺搜索", "腾讯视频"
        ]
        
        for keyword in irrelevantKeywords {
            filtered = filtered.replacingOccurrences(of: keyword, with: "")
        }
        
        // 清理多余的空行和空格
        filtered = filtered.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        filtered = filtered.replacingOccurrences(of: " {3,}", with: " ", options: .regularExpression)
        
        return filtered
    }
    
    /// 检查内容是否包含无关信息
    static func isIrrelevantContent(_ text: String) -> Bool {
        let irrelevantKeywords = [
            "词源字典", "词根词缀", "英文词源", "双语词典", "英语词典", "在线翻译",
            "图片搜索", "网页搜索", "影视搜索", "词汇量测试", "看图背单词",
            "单词拼写练习", "公众号", "小程序", "百度", "谷歌", "必应",
            "有道", "爱词霸", "海词", "搜狗", "好搜", "神马", "头条",
            "英文名", "英语新闻", "英语点津", "双语词典", "有道词典", "海词词典",
            "必应词典", "英文词典", "英语词源", "词根字典", "百度图片", "好搜图片",
            "搜狗图片", "必应图片", "爱奇艺搜索", "腾讯视频"
        ]
        
        for keyword in irrelevantKeywords {
            if text.contains(keyword) {
                return true
            }
        }
        
        return false
    }
    
    /// 检查内容是否包含过多的空白字符
    static func containsExcessiveWhitespace(_ text: String) -> Bool {
        // 计算非空白字符的比例
        let nonWhitespaceCount = text.filter { !$0.isWhitespace }.count
        let totalCount = text.count
        
        // 如果非空白字符比例低于 20%，则认为包含过多空白
        if totalCount > 0 && Double(nonWhitespaceCount) / Double(totalCount) < 0.2 {
            return true
        }
        
        // 检查是否有连续的多个空行
        let lineCount = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
        let totalLines = text.components(separatedBy: .newlines).count
        
        // 如果有效行数比例低于 30%，则认为包含过多空白
        if totalLines > 0 && Double(lineCount) / Double(totalLines) < 0.3 {
            return true
        }
        
        return false
    }
    
    /// 检查内容是否为低质量内容
    static func isLowQualityContent(_ text: String) -> Bool {
        // 检查是否包含常见的无关关键词
        let lowQualityKeywords = [
            "词源字典", "词根词缀", "英文词源", "双语词典", "英语词典", "在线翻译",
            "图片搜索", "网页搜索", "影视搜索", "词汇量测试", "看图背单词",
            "单词拼写练习", "公众号", "小程序", "百度", "谷歌", "必应",
            "有道", "爱词霸", "海词", "搜狗", "好搜", "神马", "头条",
            "英文名", "英语新闻", "英语点津", "双语词典", "有道词典", "海词词典",
            "必应词典", "英文词典", "英语词源", "词根字典", "百度图片", "好搜图片",
            "搜狗图片", "必应图片", "爱奇艺搜索", "腾讯视频"
        ]
        
        for keyword in lowQualityKeywords {
            if text.contains(keyword) {
                return true
            }
        }
        
        // 检查内容是否主要由重复的关键词组成
        let words = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        if words.count > 0 {
            let uniqueWords = Set(words)
            if Double(uniqueWords.count) / Double(words.count) < 0.5 {
                return true
            }
        }
        
        // 检查内容长度是否过短
        if text.count < 10 {
            return true
        }
        
        return false
    }
    
    /// 检查内容是否包含有意义的词源信息
    static func containsMeaningfulContent(_ text: String) -> Bool {
        // 检查是否包含常见的词源相关词汇
        let meaningfulKeywords = [
            "来自", "源自", "源于", "词根", "词缀", "前缀", "后缀",
            "拉丁语", "希腊语", "古英语", "法语", "德语", "意大利语",
            "意思", "含义", "意义", "解释", "起源", "来源", "历史",
            "神话", "传说", "故事", "人物", "地名", "事件"
        ]
        
        for keyword in meaningfulKeywords {
            if text.contains(keyword) {
                return true
            }
        }
        
        // 检查是否包含标点符号，通常有意义的内容会包含标点
        let punctuationMarks = ["，", "。", "！", "？", ",", ".", "!", "?"]
        for mark in punctuationMarks {
            if text.contains(mark) {
                return true
            }
        }
        
        // 检查内容是否包含完整的句子结构
        let sentences = text.components(separatedBy: ["。", ".", "！", "!"]) .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if sentences.count > 0 {
            return true
        }
        
        return false
    }
    
    /// 从 Dictionary API 获取词根信息
    static func fetchFromDictionaryAPI(_ word: String) throws -> String? {
        let encodedWord = word.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? word
        let urlString = "https://api.dictionaryapi.dev/api/v2/entries/en/\(encodedWord)"
        
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "RootsUpdater", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        var rootInfo: String? = nil
        var error: Error? = nil
        
        let task = URLSession.shared.dataTask(with: url) { data, response, _ in
            defer { semaphore.signal() }
            
            guard let data = data else {
                error = NSError(domain: "RootsUpdater", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"])
                return
            }
            
            do {
                if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    for entry in jsonArray {
                        if let etymologies = entry["etymology"] as? [String] {
                            let etymologyText = etymologies.joined(separator: "\n")
                            rootInfo = etymologyText
                            break
                        }
                    }
                }
            } catch let jsonError {
                error = jsonError
            }
        }
        
        task.resume()
        semaphore.wait()
        
        if let error = error {
            throw error
        }
        
        return rootInfo
    }
    
    /// 从 EtymOnline API 获取词根信息（模拟）
    static func fetchFromEtymOnlineAPI(_ word: String) throws -> String? {
        // 这里是模拟实现，实际使用时需要替换为真实的 API 调用
        // 可以使用 https://www.etymonline.com/ 的 API 或其他 etymology API
        Thread.sleep(forTimeInterval: 0.5)
        return nil // 模拟未找到
    }
    
    /// 从 Oxford API 获取词根信息（模拟）
    static func fetchFromOxfordAPI(_ word: String) throws -> String? {
        // 这里是模拟实现，实际使用时需要替换为真实的 API 调用
        // 可以使用 Oxford Dictionary API
        Thread.sleep(forTimeInterval: 0.5)
        return nil // 模拟未找到
    }
    
    /// 基于单词结构分析获取词根信息
    static func fetchFromWordAnalysis(_ word: String) throws -> String? {
        // 基于常见前缀、后缀分析单词
        let prefixes: [String: String] = [
            "un": "否定前缀",
            "re": "再次",
            "in": "否定前缀",
            "im": "否定前缀",
            "ir": "否定前缀",
            "il": "否定前缀",
            "dis": "否定前缀",
            "en": "使...",
            "em": "使...",
            "non": "否定前缀",
            "over": "过度",
            "under": "不足",
            "pre": "之前",
            "post": "之后",
            "anti": "反对",
            "auto": "自动",
            "bi": "两个",
            "tri": "三个",
            "multi": "多个",
            "inter": "之间",
            "intra": "内部",
            "intro": "介绍",
            "extra": "外部",
            "super": "超级",
            "sub": "下面",
            "trans": "穿过",
            "com": "一起",
            "con": "一起",
            "col": "一起",
            "cor": "一起",
            "co": "一起",
            "fore": "前面",
            "mid": "中间",
            "out": "外面",
            "up": "向上",
            "down": "向下",
            "back": "后面",
            "forward": "向前",
            "backward": "向后",
            "side": "旁边",
            "cross": "交叉",
            "self": "自我",
            "half": "一半",
            "full": "全部",
            "whole": "整体",
            "all": "所有",
            "every": "每个",
            "each": "每个",
            "some": "一些",
            "any": "任何",
            "no": "没有",
            "not": "不",
            "never": "从不",
            "always": "总是",
            "often": "经常",
            "sometimes": "有时",
            "rarely": "很少",
            "seldom": "很少",
            "usually": "通常",
            "normally": "正常",
            "generally": "一般",
            "commonly": "常见",
            "typically": "典型",
            "frequently": "频繁"
        ]
        
        let suffixes: [String: String] = [
            "ly": "副词后缀",
            "er": "比较级/名词后缀",
            "est": "最高级",
            "ing": "现在分词/动名词",
            "ed": "过去分词",
            "s": "复数",
            "es": "复数",
            "ment": "名词后缀",
            "ness": "名词后缀",
            "ity": "名词后缀",
            "ty": "名词后缀",
            "al": "形容词后缀",
            "ial": "形容词后缀",
            "ic": "形容词后缀",
            "ical": "形容词后缀",
            "ful": "形容词后缀",
            "less": "形容词后缀",
            "ous": "形容词后缀",
            "ious": "形容词后缀",
            "ive": "形容词后缀",
            "ative": "形容词后缀",
            "tive": "形容词后缀",
            "able": "形容词后缀",
            "ible": "形容词后缀",
            "ant": "形容词后缀",
            "ent": "形容词后缀",
            "ist": "名词后缀",
            "ism": "名词后缀",
            "ian": "名词后缀",
            "an": "名词后缀",
            "or": "名词后缀",
            "ar": "名词后缀",
            "ator": "名词后缀"
        ]
        
        // 分析前缀
        for (prefix, meaning) in prefixes {
            if word.lowercased().hasPrefix(prefix) {
                let root = String(word.dropFirst(prefix.count))
                return "前缀 \(prefix)（\(meaning)） + 词根 \(root)"
            }
        }
        
        // 分析后缀
        for (suffix, meaning) in suffixes {
            if word.lowercased().hasSuffix(suffix) {
                let root = String(word.dropLast(suffix.count))
                return "词根 \(root) + 后缀 \(suffix)（\(meaning)）"
            }
        }
        
        // 常见词根分析
        let commonRoots: [String: String] = [
            "act": "做",
            "ag": "做",
            "vid": "看/分开",
            "vis": "看/分开",
            "spect": "看",
            "scrib": "写",
            "script": "写",
            "dict": "说",
            "dic": "说",
            "log": "说",
            "loqu": "说",
            "port": "携带",
            "fer": "携带",
            "tract": "拉",
            "draw": "拉",
            "mit": "送",
            "miss": "送",
            "tend": "伸展",
            "tens": "伸展",
            "tent": "伸展",
            "divid": "分开",
            "separ": "分开",
            "junct": "连接",
            "join": "连接",
            "connect": "连接",
            "fix": "固定",
            "stabil": "固定",
            "mov": "移动",
            "mot": "移动",
            "mob": "移动",
            "loc": "地方",
            "place": "地方",
            "pos": "放置",
            "put": "放置",
            "lay": "放置",
            "set": "放置",
            "stand": "站立",
            "stat": "站立",
            "sist": "站立",
            "live": "生活",
            "viv": "生活",
            "vita": "生活",
            "bio": "生命",
            "anim": "生命",
            "man": "手",
            "hand": "手",
            "ped": "脚",
            "foot": "脚",
            "arm": "手臂",
            "leg": "腿",
            "head": "头",
            "eye": "眼睛",
            "ear": "耳朵",
            "nose": "鼻子",
            "mouth": "嘴",
            "tooth": "牙齿",
            "tongue": "舌头",
            "heart": "心脏",
            "blood": "血液",
            "bone": "骨头",
            "muscle": "肌肉",
            "skin": "皮肤",
            "hair": "头发",
            "brain": "大脑",
            "nerve": "神经",
            "spine": "脊柱",
            "lung": "肺",
            "liver": "肝脏",
            "kidney": "肾脏",
            "stomach": "胃",
            "intestine": "肠",
            "bowel": "肠",
            "bladder": "膀胱",
            "uterus": "子宫",
            "testicle": "睾丸",
            "ovary": "卵巢",
            "breast": "乳房",
            "chest": "胸部",
            "back": "背部",
            "shoulder": "肩膀",
            "hip": "臀部",
            "thigh": "大腿",
            "calf": "小腿",
            "ankle": "脚踝",
            "wrist": "手腕",
            "palm": "手掌",
            "finger": "手指",
            "toe": "脚趾",
            "nail": "指甲",
            "joint": "关节",
            "tendon": "肌腱",
            "ligament": "韧带",
            "cartilage": "软骨",
            "skeleton": "骨骼",
            "skull": "头骨",
            "rib": "肋骨",
            "pelvis": "骨盆",
            "femur": "股骨",
            "tibia": "胫骨",
            "fibula": "腓骨",
            "humerus": "肱骨",
            "radius": "桡骨",
            "ulna": "尺骨",
            "carpal": "腕骨",
            "metacarpal": "掌骨",
            "phalanx": "指骨",
            "tarsal": "跗骨",
            "metatarsal": "跖骨",
            "vertebra": "椎骨",
            "cervical": "颈椎",
            "thoracic": "胸椎",
            "lumbar": "腰椎",
            "sacrum": "骶骨",
            "coccyx": "尾骨"
        ]
        
        // 检查常见词根
        for (root, meaning) in commonRoots {
            if word.lowercased().contains(root) {
                return "包含词根 \(root)（\(meaning)）"
            }
        }
        
        return nil
    }
}

// 传统的 main 函数
func main() {
    RootsUpdater.main()
}

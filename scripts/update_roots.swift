import Foundation
import SQLite

/// 词根信息更新工具 - 从网络抓取词根信息并更新数据库
@main
struct RootsUpdater {
    
    // 缓存机制
    static var rootsCache: [String: String] = [:]
    
    static func main() throws {
        print("🚀 EasyEnglish 词根信息更新工具")
        print("===============================")
        
        // 1. 确定路径
        let basePath = FileManager.default.currentDirectoryPath
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
        let db = try Connection(dbPath)
        print("✅ 数据库连接成功\n")
        
        // 4. 定义表结构
        let words = Table("words")
        let id = Expression<UUID>("id")
        let text = Expression<String>("text")
        let roots = Expression<String?>("roots")
        
        // 5. 获取所有单词
        print("📊 获取单词列表...")
        var wordsToUpdate: [(UUID, String, String?)] = []
        
        for result in try db.prepare(words.select(id, text, roots)) {
            let wordId = result[id]
            let wordText = result[text]
            let currentRoots = result[roots]
            
            wordsToUpdate.append((wordId, wordText, currentRoots))
        }
        
        print("✅ 找到 \(wordsToUpdate.count) 个单词\n")
        
        // 6. 批量更新词根信息
        print("📝 更新词根信息...")
        var updated = 0
        var failed = 0
        
        for (index, (wordId, wordText, currentRoots)) in wordsToUpdate.enumerated() {
            print("   处理单词：\(wordText) (\(index + 1)/\(wordsToUpdate.count))")
            
            // 检查缓存
            if let cachedRoots = rootsCache[wordText.lowercased()] {
                print("   📥 从缓存获取词根信息")
                let update = words.filter(id == wordId).update(roots <- cachedRoots)
                try db.run(update)
                updated += 1
                print("   ✅ 已更新：\(wordText)")
                continue
            }
            
            do {
                // 从网络获取词根信息
                if let rootInfo = try fetchRootInfo(for: wordText) {
                    // 更新缓存
                    rootsCache[wordText.lowercased()] = rootInfo
                    // 更新数据库
                    let update = words.filter(id == wordId).update(roots <- rootInfo)
                    try db.run(update)
                    updated += 1
                    print("   ✅ 已更新：\(wordText)")
                } else {
                    failed += 1
                    print("   ⚠️  未找到词根信息：\(wordText)")
                }
                
                // 避免请求过快被封禁
                Thread.sleep(forTimeInterval: 1.0)
                
            } catch {
                failed += 1
                print("   ❌ 更新失败：\(wordText) - \(error.localizedDescription)")
            }
        }
        
        print("\n✅ 词根信息更新完成")
        print("   成功：\(updated) 个单词")
        print("   失败：\(failed) 个单词")
        print("   跳过：\(wordsToUpdate.count - updated - failed) 个单词（已有词根信息）\n")
        
        // 7. 显示示例数据
        print("📚 更新后的词根信息示例:")
        let query = words.filter(roots != nil).order(text).limit(5)
        for result in try db.prepare(query) {
            let word = result[text]
            let rootInfo = result[roots] ?? "N/A"
            print("   • \(word): \(rootInfo)")
        }
        
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
    
    /// 从网络获取词根信息
    static func fetchRootInfo(for word: String) throws -> String? {
        // 尝试多个API源获取词根信息
        let apiSources: [(name: String, fetch: (String) throws -> String?)] = [
            ("Dictionary API", fetchFromDictionaryAPI),
            ("EtymOnline API", fetchFromEtymOnlineAPI),
            ("Oxford API", fetchFromOxfordAPI)
        ]
        
        for (apiName, fetchFunc) in apiSources {
            print("   尝试从 \(apiName) 获取...")
            do {
                if let rootInfo = try fetchFunc(word) {
                    return rootInfo
                }
            } catch {
                print("   ⚠️ \(apiName) 失败：\(error.localizedDescription)")
                // 继续尝试下一个API
                continue
            }
        }
        
        // 如果所有API都失败，尝试基于单词结构分析
        return try fetchFromWordAnalysis(word)
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
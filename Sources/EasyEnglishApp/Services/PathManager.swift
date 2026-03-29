import Foundation

/// 路径管理器 - 统一管理应用路径
/// 
/// 职责：
/// - 提供数据库路径
/// - 提供词库目录路径
/// - 区分开发环境和生产环境
final class PathManager {
    
    // MARK: - 单例
    
    static let shared = PathManager()
    
    private init() {}
    
    // MARK: - 路径属性
    
    /// 项目根目录（开发环境）
    var projectRoot: String {
        // 尝试从 Bundle 获取，如果存在则说明在开发环境
        if let bundlePath = Bundle.main.resourcePath,
           bundlePath.contains("easyEnglish") {
            // 开发环境：返回项目根目录
            return (bundlePath as NSString).deletingLastPathComponent
        }
        
        // 生产环境：返回 Application Support
        return applicationSupportDirectory
    }
    
    /// 词库目录
    var wordlistsDirectory: String {
        // 开发环境优先使用项目目录
        let devPath = "/Users/mfyang/project/easyEnglish/Data/wordlists"
        if FileManager.default.fileExists(atPath: devPath) {
            return devPath
        }
        
        // 生产环境使用 Application Support
        let prodPath = applicationSupportDirectory + "/wordlists"
        try? FileManager.default.createDirectory(atPath: prodPath, withIntermediateDirectories: true)
        return prodPath
    }
    
    /// 数据库文件路径
    var databasePath: String {
        return wordlistsDirectory + "/wordlist.sqlite"
    }
    
    /// 应用支持目录（生产环境）
    var applicationSupportDirectory: String {
        let paths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
        let bundleID = Bundle.main.bundleIdentifier ?? "com.easyenglish.app"
        
        if let base = paths.first {
            let appSupport = base + "/" + bundleID
            try? FileManager.default.createDirectory(atPath: appSupport, withIntermediateDirectories: true)
            return appSupport
        }
        
        return NSTemporaryDirectory() + bundleID
    }
    
    /// 生产环境数据库路径
    var productionDatabasePath: String {
        return applicationSupportDirectory + "/wordlist.sqlite"
    }
    
    // MARK: - 路径解析
    
    /// 获取当前环境数据库路径
    var currentDatabasePath: String {
        // 优先检查开发环境路径
        if FileManager.default.fileExists(atPath: databasePath) {
            Logger.debug("使用开发环境数据库：\(databasePath)")
            return databasePath
        }
        
        // 检查生产环境路径
        if FileManager.default.fileExists(atPath: productionDatabasePath) {
            Logger.debug("使用生产环境数据库：\(productionDatabasePath)")
            return productionDatabasePath
        }
        
        // 都不存在时，返回默认路径（会触发初始化）
        Logger.warning("数据库文件不存在，返回默认路径：\(databasePath)")
        return databasePath
    }
    
    /// 检查数据库文件是否存在
    var databaseExists: Bool {
        return FileManager.default.fileExists(atPath: currentDatabasePath)
    }
    
    /// 获取词库文件列表
    func availableWordlists() -> [String] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: wordlistsDirectory) else {
            return []
        }
        
        return items.filter { item in
            let lowercased = item.lowercased()
            return lowercased.hasSuffix(".json") ||
                   lowercased.hasSuffix(".apkg.json") ||
                   lowercased.hasSuffix(".sqlite")
        }.sorted()
    }
    
    /// 获取词库完整路径
    func pathForWordlist(_ name: String) -> String {
        return wordlistsDirectory + "/" + name
    }
}

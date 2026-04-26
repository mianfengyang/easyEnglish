import Foundation

/// 路径管理器 - 统一管理应用路径
final class PathManager {
    
    // MARK: - 单例
    static let shared = PathManager()
    private init() {}
    
    // MARK: - 基础路径定义
    
    /// 获取项目根目录 (用于开发环境)
    private var projectRoot: String {
        if let bundlePath = Bundle.main.resourcePath {
            let path = (bundlePath as NSString).deletingLastPathComponent
            if path.contains("project") || path.contains("easyEnglish") {
                return path
            }
        }
        let currentDir = FileManager.default.currentDirectoryPath
        if currentDir.contains("project") || currentDir.contains("easyEnglish") {
            return currentDir
        }
        return "" // 生产环境可能为空，由 applicationSupportDirectory 接管
    }

    /// 获取应用支持目录 (用户数据/生产环境)
    private var applicationSupportDirectory: String {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupport = paths.first!.path
        if !FileManager.default.fileExists(atPath: appSupport) {
            try? FileManager.default.createDirectory(atPath: appSupport, withIntermediateDirectories: true)
        }
        return appSupport
    }

    /// 核心资源目录 (存放内置的 .sqlite 和 .json 文件)
    private var resourceDirectory: String {
        // 1. 首先检查 Bundle 中的资源路径 (这是最可靠的)
        if let bundlePath = Bundle.main.resourcePath {
            // 检查是否存在 Resources 子目录 (针对 build_app.sh 的逻辑)
            let resPath = (bundlePath as NSString).appendingPathComponent("Resources")
            if FileManager.default.fileExists(atPath: resPath) {
                return resPath
            }
            // 如果没有 Resources 子目录，直接返回 bundlePath
            return bundlePath
        }
        // 2. 如果 Bundle 里没找到，尝试从项目根目录下的 Sources/.../Resources 查找
        let projectRoot = projectRoot
        if !projectRoot.isEmpty {
            let fallbackPath = (projectRoot as NSString).appendingPathComponent("Sources/EasyEnglishApp/Resources")
            if FileManager.default.fileExists(atPath: fallbackPath) {
                return fallbackPath
            }
        }
        // 3. 最后兜底到当前工作目录下的资源路径 (针对直接在命令行运行的情况)
        let currentDir = FileManager.default.currentDirectoryPath
        let directPath = (currentDir as NSString).appendingPathComponent("Sources/EasyEnglishApp/Resources")
        return FileManager.default.fileExists(atPath: directPath) ? directPath : ""
    }

    // MARK: - 业务路径属性
    
    /// 用户数据目录 (用于存放用户下载、修改后的词库)
    var userWordlistsDirectory: String {
        return applicationSupportDirectory + "/wordlists"
    }

    /// 词库目录 (用于 UI 展示和文件列表)
    var wordlistsDirectory: String {
        // 优先级：用户目录 > 开发/资源目录
        let userPath = userWordlistsDirectory
        if isDirectoryValid(path: userPath) { return userPath }

        let devPath = (projectRoot as NSString).appendingPathComponent("Data/wordlists")
        if isDirectoryValid(path: devPath) { return devPath }

        return resourceDirectory
    }

    /// 数据库文件路径 (用于写入/更新操作)
    var databasePath: String {
        return wordlistsDirectory + "/wordlist.sqlite"
    }

    /// 检查数据库文件是否存在且有效
    var databaseExists: Bool {
        return isSQLiteFileValid(path: currentDatabasePath)
    }

    /// 获取当前环境应该使用的数据库路径 (用于应用启动加载)
    var currentDatabasePath: String {
        // 1. 优先检查用户数据路径 (生产环境/用户修改)
        let userDB = userWordlistsDirectory + "/wordlist.sqlite"
        if isSQLiteFileValid(path: userDB) { return userDB }

        // 2. 检查开发环境路径 (Data/wordlists)
        let devDB = (projectRoot as NSString).appendingPathComponent("Data/wordlists/wordlist.sqlite")
        if isSQLiteFileValid(path: devDB) { return devDB }

        // 3. 检查资源路径 (内置初始数据库)
        let resDB = (resourceDirectory as NSString).appendingPathComponent("wordlist.sqlite")
        if isSQLiteFileValid(path: resDB) { return resDB }

        // 4. 如果都没有，返回一个默认的 fallback
        return (resourceDirectory as NSString).appendingPathComponent("wordlist.sqlite")
    }

    // MARK: - 辅助方法

    private func isDirectoryValid(path: String) -> Bool {
        guard !path.isEmpty, FileManager.default.fileExists(atPath: path) else { return false }
        if let items = try? FileManager.default.contentsOfDirectory(atPath: path) {
            return !items.isEmpty 
        }
        return false
    }

    private func isSQLiteFileValid(path: String) -> Bool {
        guard !path.isEmpty, FileManager.default.fileExists(atPath: path) else { return false }
        let attributes = try? FileManager.default.attributesOfItem(atPath: path)
        if let size = attributes?[.size] as? UInt64, size < 1024 {
            return false
        }
        return true
    }

    /// 获取所有可用的词库文件列表 (用于 Settings 界面)
    func availableWordlists() -> [String] {
        let fm = FileManager.default
        var allItems: Set<String> = []
        
        let searchPaths = [
            userWordlistsDirectory,
            (projectRoot as NSString).appendingPathComponent("Data/wordlists"),
            resourceDirectory
        ]
        
        for path in searchPaths {
            if let items = try? fm.contentsOfDirectory(atPath: path) {
                for item in items {
                    let lowercased = item.lowercased()
                    if lowercased.hasSuffix(".json") || 
                       lowercased.hasSuffix(".apkg.json") || 
                       lowercased.hasSuffix(".sqlite") {
                        allItems.insert(item)
                    }
                }
            }
        }
        return Array(allItems).sorted()
    }

    /// 获取词库完整路径 (用于打开特定文件)
    func pathForWordlist(_ name: String) -> String {
        let paths = [
            userWordlistsDirectory,
            (projectRoot as NSString).appendingPathComponent("Data/wordlists"),
            resourceDirectory
        ]
        for path in paths {
            let fullPath = (path as NSString).appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: fullPath) { return fullPath }
        }
        return ""
    }
}

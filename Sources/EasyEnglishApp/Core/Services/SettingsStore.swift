import Foundation
import Combine
import SwiftUI
import SQLite
import os.log

enum ThemeMode: String, CaseIterable, Identifiable {
    case light = "浅色"
    case dark = "深色"
    case system = "跟随系统"
    
    var id: String { rawValue }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()
    
    @Published var selectedWordlist: String? {
        didSet { 
            UserDefaults.standard.set(selectedWordlist, forKey: Self.keyWordlist)
            NotificationCenter.default.post(name: NSNotification.Name("selectedWordlistChanged"), object: nil)
            
            if let path = pathForSelected() {
                do {
                    try DatabaseManager.shared.switchToDatabase(at: path)
                    Logger.success("SettingsStore: 成功切换至词库路径：\(path)")
                } catch {
                    Logger.error("SettingsStore: 切换数据库失败: \(error)")
                }
            } else {
                Logger.warning("SettingsStore: 无法解析选中的词库路径")
            }
        }
    }

    @Published var dailyNewLimit: Int {
        didSet { 
            UserDefaults.standard.set(dailyNewLimit, forKey: Self.keyDailyNewLimit)
            NotificationCenter.default.post(name: NSNotification.Name("dailyNewLimitChanged"), object: nil, userInfo: ["newLimit": dailyNewLimit])
        }
    }

    @Published var themeMode: ThemeMode {
        didSet { 
            UserDefaults.standard.set(themeMode.rawValue, forKey: Self.keyThemeMode)
            NotificationCenter.default.post(name: NSNotification.Name("themeModeChanged"), object: nil)
        }
    }

    private static let keyWordlist = "selectedWordlist"
    private static let keyDailyNewLimit = "dailyNewLimit"
    private static let keyThemeMode = "themeMode"

    private var displayToFile: [String: String] = [:]

    private init() {
        let limit = UserDefaults.standard.integer(forKey: Self.keyDailyNewLimit)
        self.dailyNewLimit = limit == 0 ? 20 : limit
        
        if let themeRawValue = UserDefaults.standard.string(forKey: Self.keyThemeMode),
           let theme = ThemeMode(rawValue: themeRawValue) {
            self.themeMode = theme
        } else {
            self.themeMode = .system
        }

        _ = availableWordlists()
        self.selectedWordlist = UserDefaults.standard.string(forKey: Self.keyWordlist)
    }

    func availableWordlists() -> [String] {
        let fileNames = PathManager.shared.availableWordlists()
        var displayNames: [String] = []
        displayToFile.removeAll()
        
        for fileName in fileNames {
            let path = PathManager.shared.pathForWordlist(fileName)
            var displayName: String
            
            if fileName.lowercased().hasSuffix(".sqlite"),
               let dbName = WordDatabaseManager.getDatabaseName(from: path) {
                displayName = dbName
            } else {
                displayName = WordDatabaseManager.getDefaultWordlistName(from: fileName)
            }
            
            displayNames.append(displayName)
            displayToFile[displayName] = fileName
        }
        
        return displayNames
    }

    func pathForSelected() -> String? {
        guard let displayName = selectedWordlist,
              let fileName = displayToFile[displayName] else { 
            return nil 
        }
        return PathManager.shared.pathForWordlist(fileName)
    }
}

class WordDatabaseManager {
    static func getDatabaseName(from path: String) -> String? {
        let fileName = (path as NSString).lastPathComponent
        do {
            let conn = try Connection(path, readonly: true)
            let statsTable = Table("database_stats")
            let nameCol = Expression<String>("database_name")
            if let row = try conn.pluck(statsTable.select(nameCol).limit(1)) {
                let name = row[nameCol]
                if !name.isEmpty { return name }
            }
        } catch {
            Logger.warning("从数据库 \(path) 读取名称失败：\(error)")
        }
        return getDefaultWordlistName(from: fileName)
    }

    static func getDefaultWordlistName(from fileName: String) -> String {
        let stem = (fileName as NSString).deletingPathExtension
        switch stem.lowercased() {
        case "cet4", "cet-4": return "CET-4 词库"
        case "cet6", "cet-6": return "CET-6 词库"
        case "toefl", "toefl-ibt": return "TOEFL 词库"
        case "ielts": return "IELTS 词库"
        case "gaokao": return "高考词库"
        case "zhongkao": return "中考词库"
        case "gre", "gre-general": return "GRE 词库"
        case "sat": return "SAT 词库"
        default:
            let components = stem.components(separatedBy: "-")
            return components.count > 1 ? components[0].capitalized + " " + (components.count > 1 ? components[1...] .joined(separator: " ") : "") : stem.capitalized
        }
    }
}
import Foundation
import Combine
import SwiftUI

// 主题模式枚举
enum ThemeMode: String, CaseIterable, Identifiable {
    case light = "浅色"
    case dark = "深色"
    case system = "跟随系统"
    
    var id: String { rawValue }
    
    // 获取对应的 SwiftUI 色彩方案
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
        didSet { UserDefaults.standard.set(selectedWordlist, forKey: Self.keyWordlist) }
    }
    @Published var dailyNewLimit: Int {
        didSet { 
            UserDefaults.standard.set(dailyNewLimit, forKey: Self.keyDailyNewLimit)
            // 当每日新词数量改变时，通知 DataController 重新加载会话
            NotificationCenter.default.post(name: NSNotification.Name("dailyNewLimitChanged"), object: nil, userInfo: ["newLimit": dailyNewLimit])
        }
    }
    @Published var themeMode: ThemeMode {
        didSet { 
            UserDefaults.standard.set(themeMode.rawValue, forKey: Self.keyThemeMode)
            // 通知应用更新主题
            NotificationCenter.default.post(name: NSNotification.Name("themeModeChanged"), object: nil)
        }
    }

    private static let keyWordlist = "selectedWordlist"
    private static let keyDailyNewLimit = "dailyNewLimit"
    private static let keyThemeMode = "themeMode"

    private init() {
        self.selectedWordlist = UserDefaults.standard.string(forKey: Self.keyWordlist)
        let limit = UserDefaults.standard.integer(forKey: Self.keyDailyNewLimit)
        self.dailyNewLimit = limit == 0 ? 20 : limit
        
        // 加载主题设置，默认为跟随系统
        if let themeRawValue = UserDefaults.standard.string(forKey: Self.keyThemeMode),
           let theme = ThemeMode(rawValue: themeRawValue) {
            self.themeMode = theme
        } else {
            // 兼容旧的"自动"设置
            if UserDefaults.standard.string(forKey: Self.keyThemeMode) == "自动" {
                self.themeMode = .system
            } else {
                self.themeMode = .system
            }
        }
    }

    func availableWordlists() -> [String] {
        return PathManager.shared.availableWordlists()
    }

    func pathForSelected() -> String? {
        guard let name = selectedWordlist else { return nil }
        return PathManager.shared.pathForWordlist(name)
    }
}

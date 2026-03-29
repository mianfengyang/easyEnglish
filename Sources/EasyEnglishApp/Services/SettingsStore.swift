import Foundation
import Combine

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

    private static let keyWordlist = "selectedWordlist"
    private static let keyDailyNewLimit = "dailyNewLimit"

    private init() {
        self.selectedWordlist = UserDefaults.standard.string(forKey: Self.keyWordlist)
        let limit = UserDefaults.standard.integer(forKey: Self.keyDailyNewLimit)
        self.dailyNewLimit = limit == 0 ? 20 : limit
    }

    func availableWordlists() -> [String] {
        return PathManager.shared.availableWordlists()
    }

    func pathForSelected() -> String? {
        guard let name = selectedWordlist else { return nil }
        return PathManager.shared.pathForWordlist(name)
    }
}

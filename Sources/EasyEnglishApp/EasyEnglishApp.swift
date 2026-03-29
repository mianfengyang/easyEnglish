import SwiftUI

@main
struct EasyEnglishApp: App {
    @StateObject private var sessionManager = LearningSessionManager.shared
    @StateObject private var settings = SettingsStore.shared
    @State private var colorScheme: ColorScheme? = nil

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sessionManager)
                .environmentObject(settings)
                .preferredColorScheme(colorScheme)
                .onAppear {
                    // 初始化主题
                    updateColorScheme()
                    
                    // 监听主题变化
                    NotificationCenter.default.addObserver(
                        forName: NSNotification.Name("themeModeChanged"),
                        object: nil,
                        queue: .main
                    ) { _ in
                        updateColorScheme()
                    }
                }
        }
    }
    
    private func updateColorScheme() {
        colorScheme = settings.themeMode.colorScheme
    }
}

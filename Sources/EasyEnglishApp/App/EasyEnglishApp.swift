import SwiftUI

@main
struct EasyEnglishApp: App {
    @StateObject private var settings = SettingsStore.shared
    @State private var colorScheme: ColorScheme? = nil
    
    var body: some Scene {
        WindowGroup {
            MainContentView()
                .environmentObject(settings)
                .preferredColorScheme(colorScheme)
                .onAppear {
                    updateColorScheme()
                    setupThemeObserver()
                }
        }
    }
    
    private func updateColorScheme() {
        colorScheme = settings.themeMode.colorScheme
    }
    
    private func setupThemeObserver() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("themeModeChanged"),
            object: nil,
            queue: .main
        ) { _ in
            updateColorScheme()
        }
    }
}
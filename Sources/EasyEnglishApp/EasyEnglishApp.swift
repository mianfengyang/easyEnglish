import SwiftUI

@main
struct EasyEnglishApp: App {
    @StateObject private var sessionManager = LearningSessionManager.shared
    @StateObject private var settings = SettingsStore.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sessionManager)
                .environmentObject(settings)
        }
    }
}

import SwiftUI

@main
struct POSApp: App {
    @StateObject private var container = AppContainer()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(container)
                .environmentObject(container.settings)
                .environmentObject(container.thermalPrinter)
        }
        .onChange(of: scenePhase) { phase in
            // 進入背景時自動備份（對應 Android onPause 觸發備份）。
            if phase == .background, container.settings.autoBackupEnabled {
                try? BackupManager.autoBackup(container.database)
            }
        }
    }
}

/// App 版本資訊（顯示於登入頁與設定頁）。
enum AppInfo {
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    static var versionLabel: String { "v\(version) (\(build))" }
}

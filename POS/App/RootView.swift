import SwiftUI

/// 根視圖：未登入顯示 LoginView，PIN 驗證通過後顯示 HomeView（六分頁）。
/// 對應 Android NavGraph：Login →(成功)→ Home。
struct RootView: View {
    @EnvironmentObject var container: AppContainer
    @EnvironmentObject var settings: SettingsStore

    @State private var isLoggedIn = false

    var body: some View {
        Group {
            if isLoggedIn {
                HomeView()
            } else {
                LoginView(settings: settings) {
                    withAnimation { isLoggedIn = true }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

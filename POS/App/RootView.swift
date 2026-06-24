import SwiftUI

/// 根視圖：Login ↔ Home 切換（M2 會接上 PIN 登入與六分頁導航）。
/// 目前為 M0/M1 佔位畫面，用於驗證資料層與專案骨架可建置。
struct RootView: View {
    @EnvironmentObject var container: AppContainer

    var body: some View {
        VStack(spacing: 12) {
            Text("火鍋 POS")
                .font(.largeTitle).bold()
            Text("資料層就緒 ✓")
                .foregroundColor(.secondary)
            Text(AppInfo.versionLabel)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

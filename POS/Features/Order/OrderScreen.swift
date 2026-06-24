import SwiftUI

/// 記帳點餐（M3 實作）。
struct OrderScreen: View {
    var onGoSettings: () -> Void = {}

    var body: some View {
        PlaceholderScreen(title: "記帳", emoji: "🛒")
    }
}

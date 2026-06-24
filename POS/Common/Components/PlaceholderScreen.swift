import SwiftUI

/// 里程碑開發中的佔位畫面，後續會逐頁以實作取代。
struct PlaceholderScreen: View {
    let title: String
    let emoji: String
    var note: String = "（建置中）"

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 10) {
                Text(emoji).font(.system(size: 44))
                Text(title)
                    .font(.title2).bold()
                    .foregroundColor(Theme.text)
                Text(note)
                    .font(.subheadline)
                    .foregroundColor(Theme.textMuted)
            }
        }
    }
}

import SwiftUI

/// 各管理頁共用頂列，對應 Android PosTopBar 樣式。
struct ScreenHeader<Trailing: View>: View {
    let title: String
    var subtitle: String = "火鍋店 POS"
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2).fill(Theme.accent).frame(width: 4, height: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 16, weight: .bold)).foregroundColor(Theme.text)
                    Text(subtitle).font(.system(size: 10)).foregroundColor(Theme.textMuted)
                }
            }
            Spacer()
            trailing()
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .background(Theme.topbar)
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(title: String, subtitle: String = "火鍋店 POS") {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

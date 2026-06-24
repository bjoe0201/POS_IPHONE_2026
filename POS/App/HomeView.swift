import SwiftUI

/// 對應 Android HomeWithBottomNav：自繪底部六分頁，依設定動態顯示/隱藏。
struct HomeView: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var settings: SettingsStore

    @State private var selected: AppTab = .order

    private var visibleTabs: [AppTab] {
        AppTab.ordered.filter { $0.isVisible(in: settings) }
    }

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider().background(Theme.border)
            bottomBar
        }
        .background(Theme.bg.ignoresSafeArea())
        .onChange(of: visibleTabs) { tabs in
            // 目前分頁被停用時跳回記帳（對應 Android 行為）。
            if !tabs.contains(selected) { selected = .order }
        }
    }

    // MARK: - 內容區
    @ViewBuilder
    private var content: some View {
        switch selected {
        case .order:       OrderScreen(container: container, onGoSettings: { selected = .settings })
        case .reservation: ReservationScreen()
        case .menu:        MenuManagementScreen(container: container)
        case .table:       TableSettingScreen(container: container)
        case .report:      ReportScreen(onGoSettings: { selected = .settings })
        case .settings:    SettingsScreen()
        }
    }

    // MARK: - 底部導航
    private var bottomBar: some View {
        HStack(spacing: 0) {
            ForEach(visibleTabs) { tab in
                let isSelected = tab == selected
                Button {
                    selected = tab
                } label: {
                    ZStack(alignment: .top) {
                        if isSelected {
                            Theme.accent
                                .frame(height: 3)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 24)
                        }
                        VStack(spacing: 3) {
                            Text(tab.emoji).font(.system(size: 20))
                            Text(tab.label)
                                .font(.system(size: 11,
                                               weight: isSelected ? .bold : .regular))
                                .foregroundColor(isSelected ? Theme.accent : Theme.textMuted)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 56)
        .background(Theme.topbar)
    }
}

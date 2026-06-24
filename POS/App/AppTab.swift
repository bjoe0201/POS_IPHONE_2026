import Foundation

/// 底部分頁定義，對應 Android NavGraph 的 Screen / BottomTab。
enum AppTab: String, CaseIterable, Identifiable {
    case order        // 記帳
    case reservation  // 訂位
    case menu         // 菜單管理
    case table        // 桌號設定
    case report       // 報表
    case settings     // 設定

    var id: String { rawValue }

    var label: String {
        switch self {
        case .order: return "記帳"
        case .reservation: return "訂位"
        case .menu: return "菜單管理"
        case .table: return "桌號設定"
        case .report: return "報表"
        case .settings: return "設定"
        }
    }

    var emoji: String {
        switch self {
        case .order: return "🛒"
        case .reservation: return "📅"
        case .menu: return "🥩"
        case .table: return "🪑"
        case .report: return "📊"
        case .settings: return "⚙️"
        }
    }

    /// 顯示順序，與 Android bottomTabs 一致。
    static let ordered: [AppTab] = [.order, .reservation, .menu, .table, .report, .settings]

    /// 此分頁是否依設定開關顯示；記帳與設定永遠顯示。
    func isVisible(in settings: SettingsStore) -> Bool {
        switch self {
        case .order, .settings: return true
        case .reservation: return settings.tabReservationEnabled
        case .menu: return settings.tabMenuEnabled
        case .table: return settings.tabTableEnabled
        case .report: return settings.tabReportEnabled
        }
    }
}

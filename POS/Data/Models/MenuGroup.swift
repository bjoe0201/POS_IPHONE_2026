import Foundation
import GRDB

/// 對應 Android `menu_groups` 資料表（MenuGroupEntity）。
/// code 為主鍵（String），非自動遞增。
struct MenuGroup: Codable, Identifiable, Hashable, FetchableRecord, PersistableRecord {
    var code: String
    var name: String
    var sortOrder: Int = 0
    var isActive: Bool = true

    var id: String { code }

    static let databaseTableName = "menu_groups"

    enum Columns: String, ColumnExpression {
        case code, name, sortOrder, isActive
    }
}

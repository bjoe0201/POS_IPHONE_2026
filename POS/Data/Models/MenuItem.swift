import Foundation
import GRDB

/// 對應 Android `menu_items` 資料表（MenuItemEntity）。
struct MenuItem: Codable, Identifiable, Hashable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var name: String
    var price: Double
    var category: String
    var isAvailable: Bool = true
    var sortOrder: Int = 0

    static let databaseTableName = "menu_items"

    enum Columns: String, ColumnExpression {
        case id, name, price, category, isAvailable, sortOrder
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

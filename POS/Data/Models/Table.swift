import Foundation
import GRDB

/// 對應 Android `tables` 資料表（TableEntity）。tableName ≤ 20 字。
struct DiningTable: Codable, Identifiable, Hashable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var tableName: String
    var seats: Int? = nil
    var remark: String? = nil
    var isActive: Bool = true
    var sortOrder: Int = 0

    static let databaseTableName = "tables"

    enum Columns: String, ColumnExpression {
        case id, tableName, seats, remark, isActive, sortOrder
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

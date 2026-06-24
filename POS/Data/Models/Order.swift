import Foundation
import GRDB

/// 對應 Android `orders` 資料表（OrderEntity）。
/// createdAt / closedAt 為毫秒 epoch（與 Android System.currentTimeMillis() 一致）。
/// tableName 為快照欄位，桌號改名/刪除後仍保持可讀。
struct Order: Codable, Identifiable, Hashable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var tableId: Int64
    var tableName: String
    var remark: String = ""
    var createdAt: Int64 = Date.nowMillis
    var closedAt: Int64? = nil
    var status: String = OrderStatus.open.rawValue
    var isDeleted: Bool = false

    static let databaseTableName = "orders"

    enum Columns: String, ColumnExpression {
        case id, tableId, tableName, remark, createdAt, closedAt, status, isDeleted
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

enum OrderStatus: String {
    case open = "OPEN"
    case paid = "PAID"
    case cancelled = "CANCELLED"
}

extension Date {
    /// 毫秒 epoch，對齊 Android System.currentTimeMillis()。
    static var nowMillis: Int64 { Int64(Date().timeIntervalSince1970 * 1000) }
}

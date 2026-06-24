import Foundation
import GRDB

/// 對應 Android `order_items` 資料表（OrderItemEntity）。
/// name / price / menuGroupCode / menuGroupName 皆為下單當下的快照。
struct OrderItem: Codable, Identifiable, Hashable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var orderId: Int64
    var menuItemId: Int64
    var name: String
    var price: Double
    var menuGroupCode: String
    var menuGroupName: String
    var quantity: Int

    var lineTotal: Double { price * Double(quantity) }

    static let databaseTableName = "order_items"

    enum Columns: String, ColumnExpression {
        case id, orderId, menuItemId, name, price, menuGroupCode, menuGroupName, quantity
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

import Foundation
import Combine
import GRDB

/// 對應 Android OrderRepository（OrderDao + OrderItemDao 合併）。
final class OrderRepository {
    private let dbQueue: DatabaseQueue
    init(dbQueue: DatabaseQueue) { self.dbQueue = dbQueue }

    // MARK: - Reactive reads

    func openOrderForTablePublisher(tableId: Int64) -> AnyPublisher<Order?, Error> {
        ValueObservation
            .tracking { db in
                try Order
                    .filter(Order.Columns.status == OrderStatus.open.rawValue
                            && Order.Columns.tableId == tableId)
                    .fetchOne(db)
            }
            .publisher(in: dbQueue, scheduling: .immediate)
            .eraseToAnyPublisher()
    }

    func allOpenOrdersPublisher() -> AnyPublisher<[Order], Error> {
        ValueObservation
            .tracking { db in
                try Order.filter(Order.Columns.status == OrderStatus.open.rawValue).fetchAll(db)
            }
            .publisher(in: dbQueue, scheduling: .immediate)
            .eraseToAnyPublisher()
    }

    func allOrdersPublisher() -> AnyPublisher<[Order], Error> {
        ValueObservation
            .tracking { db in
                try Order.order(Order.Columns.createdAt.desc).fetchAll(db)
            }
            .publisher(in: dbQueue, scheduling: .immediate)
            .eraseToAnyPublisher()
    }

    func itemsForOrderPublisher(orderId: Int64) -> AnyPublisher<[OrderItem], Error> {
        ValueObservation
            .tracking { db in
                try OrderItem.filter(OrderItem.Columns.orderId == orderId).fetchAll(db)
            }
            .publisher(in: dbQueue, scheduling: .immediate)
            .eraseToAnyPublisher()
    }

    // MARK: - Writes

    @discardableResult
    func createOrder(tableId: Int64, tableName: String,
                     createdAt: Int64 = Date.nowMillis) throws -> Int64 {
        try dbQueue.write { db in
            var order = Order(id: nil, tableId: tableId, tableName: tableName, createdAt: createdAt)
            try order.insert(db)
            return order.id ?? db.lastInsertedRowID
        }
    }

    /// 對應 Android addOrUpdateItem：依 delta 增減；歸零則刪除，刪光則自動取消空訂單。
    func addOrUpdateItem(orderId: Int64, menuItemId: Int64, name: String, price: Double,
                         menuGroupCode: String, menuGroupName: String, delta: Int) throws {
        try dbQueue.write { db in
            let existing = try OrderItem
                .filter(OrderItem.Columns.orderId == orderId
                        && OrderItem.Columns.menuItemId == menuItemId)
                .fetchOne(db)

            if existing == nil {
                if delta > 0 {
                    var item = OrderItem(id: nil, orderId: orderId, menuItemId: menuItemId,
                                         name: name, price: price,
                                         menuGroupCode: menuGroupCode, menuGroupName: menuGroupName,
                                         quantity: delta)
                    try item.insert(db)
                }
            } else if var item = existing {
                let newQty = item.quantity + delta
                if newQty <= 0 {
                    _ = try item.delete(db)
                    try Self.cancelOrderIfEmpty(db, orderId: orderId)
                } else {
                    item.quantity = newQty
                    try item.update(db)
                }
            }
        }
    }

    func removeItem(_ item: OrderItem) throws {
        try dbQueue.write { db in
            _ = try item.delete(db)
            try Self.cancelOrderIfEmpty(db, orderId: item.orderId)
        }
    }

    func payOrder(orderId: Int64, remark: String = "") throws {
        try closeOrder(orderId: orderId, status: .paid, remark: remark)
    }

    func cancelOrder(orderId: Int64) throws {
        try closeOrder(orderId: orderId, status: .cancelled, remark: "")
    }

    private func closeOrder(orderId: Int64, status: OrderStatus, remark: String) throws {
        try dbQueue.write { db in
            try db.execute(sql: "UPDATE orders SET status = ?, closedAt = ?, remark = ? WHERE id = ?",
                           arguments: [status.rawValue, Date.nowMillis, remark, orderId])
        }
    }

    /// 啟動清理：取消所有沒有品項的 OPEN 訂單（孤兒空訂單）。
    func cancelEmptyOpenOrders() throws {
        try dbQueue.write { db in
            try db.execute(sql: """
                UPDATE orders SET status = 'CANCELLED', closedAt = ?
                WHERE status = 'OPEN'
                  AND id NOT IN (SELECT DISTINCT orderId FROM order_items)
                """, arguments: [Date.nowMillis])
        }
    }

    func softDeleteOrder(orderId: Int64) throws {
        try dbQueue.write { db in
            try db.execute(sql: "UPDATE orders SET isDeleted = 1 WHERE id = ?", arguments: [orderId])
        }
    }

    func restoreOrder(orderId: Int64) throws {
        try dbQueue.write { db in
            try db.execute(sql: "UPDATE orders SET isDeleted = 0 WHERE id = ?", arguments: [orderId])
        }
    }

    func allOrderItems() throws -> [OrderItem] {
        try dbQueue.read { db in try OrderItem.fetchAll(db) }
    }

    func itemsForOrder(orderId: Int64) throws -> [OrderItem] {
        try dbQueue.read { db in
            try OrderItem.filter(OrderItem.Columns.orderId == orderId).fetchAll(db)
        }
    }

    // MARK: - Helpers

    private static func cancelOrderIfEmpty(_ db: Database, orderId: Int64) throws {
        let count = try OrderItem.filter(OrderItem.Columns.orderId == orderId).fetchCount(db)
        if count == 0 {
            try db.execute(sql: "UPDATE orders SET status = 'CANCELLED', closedAt = ?, remark = '' WHERE id = ?",
                           arguments: [Date.nowMillis, orderId])
        }
    }
}

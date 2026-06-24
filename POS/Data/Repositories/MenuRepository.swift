import Foundation
import Combine
import GRDB

/// 對應 Android MenuRepository + MenuItemDao。
final class MenuRepository {
    private let dbQueue: DatabaseQueue
    init(dbQueue: DatabaseQueue) { self.dbQueue = dbQueue }

    func allItemsPublisher() -> AnyPublisher<[MenuItem], Error> {
        ValueObservation
            .tracking { db in
                try MenuItem
                    .order(MenuItem.Columns.category, MenuItem.Columns.sortOrder, MenuItem.Columns.name)
                    .fetchAll(db)
            }
            .publisher(in: dbQueue, scheduling: .immediate)
            .eraseToAnyPublisher()
    }

    func itemsByCategoryPublisher(_ category: String) -> AnyPublisher<[MenuItem], Error> {
        ValueObservation
            .tracking { db in
                try MenuItem
                    .filter(MenuItem.Columns.category == category && MenuItem.Columns.isAvailable == true)
                    .order(MenuItem.Columns.sortOrder, MenuItem.Columns.name)
                    .fetchAll(db)
            }
            .publisher(in: dbQueue, scheduling: .immediate)
            .eraseToAnyPublisher()
    }

    func item(id: Int64) throws -> MenuItem? {
        try dbQueue.read { db in try MenuItem.fetchOne(db, key: id) }
    }

    @discardableResult
    func insert(_ item: MenuItem) throws -> Int64 {
        try dbQueue.write { db in
            var copy = item
            try copy.insert(db, onConflict: .replace)
            return copy.id ?? db.lastInsertedRowID
        }
    }

    func update(_ item: MenuItem) throws {
        try dbQueue.write { db in try item.update(db) }
    }

    func delete(_ item: MenuItem) throws {
        try dbQueue.write { db in _ = try item.delete(db) }
    }

    func setAvailability(id: Int64, available: Bool) throws {
        try dbQueue.write { db in
            try db.execute(sql: "UPDATE menu_items SET isAvailable = ? WHERE id = ?",
                           arguments: [available, id])
        }
    }
}

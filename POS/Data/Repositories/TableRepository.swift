import Foundation
import Combine
import GRDB

/// 對應 Android TableRepository + TableDao。
final class TableRepository {
    private let dbQueue: DatabaseQueue
    init(dbQueue: DatabaseQueue) { self.dbQueue = dbQueue }

    func allTablesPublisher() -> AnyPublisher<[DiningTable], Error> {
        ValueObservation
            .tracking { db in
                try DiningTable
                    .order(DiningTable.Columns.sortOrder, DiningTable.Columns.tableName)
                    .fetchAll(db)
            }
            .publisher(in: dbQueue, scheduling: .immediate)
            .eraseToAnyPublisher()
    }

    func activeTablesPublisher() -> AnyPublisher<[DiningTable], Error> {
        ValueObservation
            .tracking { db in
                try DiningTable
                    .filter(DiningTable.Columns.isActive == true)
                    .order(DiningTable.Columns.sortOrder, DiningTable.Columns.tableName)
                    .fetchAll(db)
            }
            .publisher(in: dbQueue, scheduling: .immediate)
            .eraseToAnyPublisher()
    }

    @discardableResult
    func insert(_ table: DiningTable) throws -> Int64 {
        try dbQueue.write { db in
            var copy = table
            try copy.insert(db, onConflict: .replace)
            return copy.id ?? db.lastInsertedRowID
        }
    }

    func update(_ table: DiningTable) throws {
        try dbQueue.write { db in try table.update(db) }
    }

    func delete(_ table: DiningTable) throws {
        try dbQueue.write { db in _ = try table.delete(db) }
    }

    func setActive(id: Int64, active: Bool) throws {
        try dbQueue.write { db in
            try db.execute(sql: "UPDATE tables SET isActive = ? WHERE id = ?",
                           arguments: [active, id])
        }
    }

    func count() throws -> Int {
        try dbQueue.read { db in try DiningTable.fetchCount(db) }
    }
}

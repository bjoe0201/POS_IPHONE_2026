import Foundation
import Combine
import GRDB

/// 對應 Android MenuGroupRepository + MenuGroupDao。
final class MenuGroupRepository {
    private let dbQueue: DatabaseQueue
    init(dbQueue: DatabaseQueue) { self.dbQueue = dbQueue }

    func allGroupsPublisher() -> AnyPublisher<[MenuGroup], Error> {
        ValueObservation
            .tracking { db in
                try MenuGroup
                    .order(MenuGroup.Columns.sortOrder, MenuGroup.Columns.name)
                    .fetchAll(db)
            }
            .publisher(in: dbQueue, scheduling: .immediate)
            .eraseToAnyPublisher()
    }

    func activeGroupsPublisher() -> AnyPublisher<[MenuGroup], Error> {
        ValueObservation
            .tracking { db in
                try MenuGroup
                    .filter(MenuGroup.Columns.isActive == true)
                    .order(MenuGroup.Columns.sortOrder, MenuGroup.Columns.name)
                    .fetchAll(db)
            }
            .publisher(in: dbQueue, scheduling: .immediate)
            .eraseToAnyPublisher()
    }

    /// REPLACE 語意：以 code 為主鍵覆寫。
    func insert(_ group: MenuGroup) throws {
        try dbQueue.write { db in try group.insert(db, onConflict: .replace) }
    }

    func update(_ group: MenuGroup) throws {
        try dbQueue.write { db in try group.update(db) }
    }

    func delete(_ group: MenuGroup) throws {
        try dbQueue.write { db in _ = try group.delete(db) }
    }
}

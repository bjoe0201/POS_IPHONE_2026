import Foundation
import GRDB

/// GRDB 資料庫單例，對應 Android Room `AppDatabase`。
/// 資料表 schema 與欄位名稱刻意與 Android 版完全一致，
/// 讓 .zip 備份檔可跨平台還原（同一份 SQLite 結構）。
final class AppDatabase {

    let dbQueue: DatabaseQueue

    /// 預設資料庫檔名，與 Android 一致（pos_database）。
    static let databaseFileName = "pos_database"

    /// App 沙盒中的資料庫檔案位置（Application Support 目錄）。
    static func defaultURL() throws -> URL {
        let fm = FileManager.default
        let dir = try fm.url(for: .applicationSupportDirectory,
                             in: .userDomainMask,
                             appropriateFor: nil,
                             create: true)
        return dir.appendingPathComponent("\(databaseFileName).sqlite")
    }

    init(url: URL) throws {
        var config = Configuration()
        // 對齊 Android：synchronous=FULL，每次 commit 落地，斷電不易遺失交易。
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA synchronous=FULL")
        }
        dbQueue = try DatabaseQueue(path: url.path, configuration: config)
        try migrator.migrate(dbQueue)
        try seedIfNeeded()
    }

    convenience init() throws {
        try self.init(url: try AppDatabase.defaultURL())
    }

    // MARK: - Schema

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        // 對齊 Android Room version 4 的最終 schema。
        migrator.registerMigration("v4_schema") { db in
            try db.create(table: MenuGroup.databaseTableName) { t in
                t.column("code", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("sortOrder", .integer).notNull().defaults(to: 0)
                t.column("isActive", .integer).notNull().defaults(to: 1)
            }

            try db.create(table: MenuItem.databaseTableName) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("price", .double).notNull()
                t.column("category", .text).notNull()
                t.column("isAvailable", .integer).notNull().defaults(to: 1)
                t.column("sortOrder", .integer).notNull().defaults(to: 0)
            }

            try db.create(table: Order.databaseTableName) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("tableId", .integer).notNull()
                t.column("tableName", .text).notNull()
                t.column("remark", .text).notNull().defaults(to: "")
                t.column("createdAt", .integer).notNull()
                t.column("closedAt", .integer)
                t.column("status", .text).notNull().defaults(to: "OPEN")
                t.column("isDeleted", .integer).notNull().defaults(to: 0)
            }

            try db.create(table: OrderItem.databaseTableName) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("orderId", .integer).notNull()
                    .references(Order.databaseTableName, onDelete: .cascade)
                t.column("menuItemId", .integer).notNull()
                t.column("name", .text).notNull()
                t.column("price", .double).notNull()
                t.column("menuGroupCode", .text).notNull().defaults(to: "OTHER")
                t.column("menuGroupName", .text).notNull().defaults(to: "其他")
                t.column("quantity", .integer).notNull()
            }
            try db.create(index: "index_order_items_orderId",
                          on: OrderItem.databaseTableName,
                          columns: ["orderId"])

            try db.create(table: DiningTable.databaseTableName) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("tableName", .text).notNull()
                t.column("seats", .integer)
                t.column("remark", .text)
                t.column("isActive", .integer).notNull().defaults(to: 1)
                t.column("sortOrder", .integer).notNull().defaults(to: 0)
            }

            try db.create(table: Reservation.databaseTableName) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("tableId", .integer).notNull()
                t.column("tableName", .text).notNull()
                t.column("guestName", .text).notNull()
                t.column("guestPhone", .text).notNull()
                t.column("guestCount", .integer).notNull().defaults(to: 0)
                t.column("date", .text).notNull()
                t.column("startTime", .text).notNull()
                t.column("endTime", .text).notNull()
                t.column("importance", .integer).notNull().defaults(to: 0)
                t.column("remark", .text).notNull().defaults(to: "")
                t.column("createdAt", .integer).notNull()
            }
        }

        return migrator
    }

    // MARK: - Seeding（對齊 Android AppDatabase.seedDefaults）

    static let defaultMenuGroups: [MenuGroup] = [
        MenuGroup(code: "HOTPOT_BASE", name: "鍋底", sortOrder: 1),
        MenuGroup(code: "MEAT", name: "肉類", sortOrder: 2),
        MenuGroup(code: "SEAFOOD", name: "海鮮", sortOrder: 3),
        MenuGroup(code: "VEGETABLE", name: "蔬菜", sortOrder: 4),
        MenuGroup(code: "BEVERAGE", name: "飲料", sortOrder: 5),
        MenuGroup(code: "OTHER", name: "其他", sortOrder: 6)
    ]

    private static let defaultMenuItems: [MenuItem] = [
        MenuItem(id: nil, name: "鴛鴦鍋", price: 350, category: "HOTPOT_BASE", sortOrder: 1),
        MenuItem(id: nil, name: "麻辣鍋", price: 300, category: "HOTPOT_BASE", sortOrder: 2),
        MenuItem(id: nil, name: "清湯鍋", price: 250, category: "HOTPOT_BASE", sortOrder: 3),
        MenuItem(id: nil, name: "梅花豬肉片", price: 180, category: "MEAT", sortOrder: 1),
        MenuItem(id: nil, name: "五花肉", price: 160, category: "MEAT", sortOrder: 2),
        MenuItem(id: nil, name: "牛小排", price: 280, category: "MEAT", sortOrder: 3),
        MenuItem(id: nil, name: "鮮蝦", price: 220, category: "SEAFOOD", sortOrder: 1),
        MenuItem(id: nil, name: "透抽", price: 200, category: "SEAFOOD", sortOrder: 2),
        MenuItem(id: nil, name: "蛤蜊", price: 150, category: "SEAFOOD", sortOrder: 3),
        MenuItem(id: nil, name: "高麗菜", price: 60, category: "VEGETABLE", sortOrder: 1),
        MenuItem(id: nil, name: "茼蒿", price: 60, category: "VEGETABLE", sortOrder: 2),
        MenuItem(id: nil, name: "金針菇", price: 50, category: "VEGETABLE", sortOrder: 3),
        MenuItem(id: nil, name: "台灣啤酒", price: 60, category: "BEVERAGE", sortOrder: 1),
        MenuItem(id: nil, name: "可樂", price: 40, category: "BEVERAGE", sortOrder: 2),
        MenuItem(id: nil, name: "礦泉水", price: 30, category: "BEVERAGE", sortOrder: 3),
        MenuItem(id: nil, name: "白飯", price: 20, category: "OTHER", sortOrder: 1),
        MenuItem(id: nil, name: "沾醬", price: 10, category: "OTHER", sortOrder: 2)
    ]

    /// 僅在所有主檔皆為空時植入預設資料（對應 Room onCreate callback）。
    private func seedIfNeeded() throws {
        try dbQueue.write { db in
            let hasGroups = try MenuGroup.fetchCount(db) > 0
            let hasItems = try MenuItem.fetchCount(db) > 0
            let hasTables = try DiningTable.fetchCount(db) > 0
            guard !hasGroups && !hasItems && !hasTables else { return }

            for g in AppDatabase.defaultMenuGroups { try g.insert(db) }
            for var item in AppDatabase.defaultMenuItems { try item.insert(db) }
            for n in 1...8 {
                var t = DiningTable(id: nil, tableName: "\(n) 號桌", sortOrder: n)
                try t.insert(db)
            }
        }
    }

    /// 資料庫初始化：清空所有資料並重新植入預設（對應設定頁「資料庫管理 → 初始化」）。
    func resetToDefaults() throws {
        try dbQueue.write { db in
            try OrderItem.deleteAll(db)
            try Order.deleteAll(db)
            try Reservation.deleteAll(db)
            try MenuItem.deleteAll(db)
            try MenuGroup.deleteAll(db)
            try DiningTable.deleteAll(db)

            for g in AppDatabase.defaultMenuGroups { try g.insert(db) }
            for var item in AppDatabase.defaultMenuItems { try item.insert(db) }
            for n in 1...8 {
                var t = DiningTable(id: nil, tableName: "\(n) 號桌", sortOrder: n)
                try t.insert(db)
            }
        }
    }
}

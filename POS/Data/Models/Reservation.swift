import Foundation
import GRDB

/// 對應 Android `reservations` 資料表（ReservationEntity）。
/// date "yyyy-MM-dd"、startTime/endTime "HH:mm"、importance 0=一般 1=重要 2=非常重要。
struct Reservation: Codable, Identifiable, Hashable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var tableId: Int64
    var tableName: String
    var guestName: String
    var guestPhone: String
    var guestCount: Int = 0
    var date: String
    var startTime: String
    var endTime: String
    var importance: Int = 0
    var remark: String = ""
    var createdAt: Int64 = Date.nowMillis

    static let databaseTableName = "reservations"

    enum Columns: String, ColumnExpression {
        case id, tableId, tableName, guestName, guestPhone, guestCount
        case date, startTime, endTime, importance, remark, createdAt
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

enum ReservationImportance: Int, CaseIterable {
    case normal = 0
    case important = 1
    case veryImportant = 2

    var label: String {
        switch self {
        case .normal: return "一般"
        case .important: return "重要"
        case .veryImportant: return "非常重要"
        }
    }
}

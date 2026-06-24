import Foundation
import Combine
import GRDB

/// 對應 Android ReservationRepository + ReservationDao。
final class ReservationRepository {
    private let dbQueue: DatabaseQueue
    init(dbQueue: DatabaseQueue) { self.dbQueue = dbQueue }

    /// 指定日期（yyyy-MM-dd）的訂位，依開始時間排序。
    func byDatePublisher(_ date: String) -> AnyPublisher<[Reservation], Error> {
        ValueObservation
            .tracking { db in
                try Reservation
                    .filter(Reservation.Columns.date == date)
                    .order(Reservation.Columns.startTime.asc)
                    .fetchAll(db)
            }
            .publisher(in: dbQueue, scheduling: .immediate)
            .eraseToAnyPublisher()
    }

    /// 指定月份（yyyy-MM）的訂位。
    func byMonthPublisher(_ yearMonth: String) -> AnyPublisher<[Reservation], Error> {
        let prefix = yearMonth + "%"
        return ValueObservation
            .tracking { db in
                try Reservation
                    .filter(Reservation.Columns.date.like(prefix))
                    .order(Reservation.Columns.date.asc, Reservation.Columns.startTime.asc)
                    .fetchAll(db)
            }
            .publisher(in: dbQueue, scheduling: .immediate)
            .eraseToAnyPublisher()
    }

    /// REPLACE 語意 upsert。
    @discardableResult
    func upsert(_ reservation: Reservation) throws -> Int64 {
        try dbQueue.write { db in
            var copy = reservation
            try copy.insert(db, onConflict: .replace)
            return copy.id ?? db.lastInsertedRowID
        }
    }

    func delete(_ reservation: Reservation) throws {
        try dbQueue.write { db in _ = try reservation.delete(db) }
    }
}

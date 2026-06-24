import Foundation

/// 本機日界線換算工具。對應 Android OrderViewModel.startOfDay / nextDayStart。
/// iOS 直接用本機 Calendar，不需處理 Material3 DatePicker 的 UTC 偏移問題。
enum DateBoundary {
    /// 給定毫秒 epoch，回傳當日本機 00:00 的毫秒 epoch。
    static func startOfDay(_ millis: Int64) -> Int64 {
        let date = Date(timeIntervalSince1970: Double(millis) / 1000)
        let start = Calendar.current.startOfDay(for: date)
        return Int64(start.timeIntervalSince1970 * 1000)
    }

    /// 今日本機 00:00 的毫秒 epoch。
    static func todayStart() -> Int64 { startOfDay(Date.nowMillis) }

    /// 給定毫秒所屬日的 23:59:59.999 毫秒 epoch。
    static func endOfDay(_ millis: Int64) -> Int64 {
        nextDayStart(millis) - 1
    }

    /// 給定毫秒所屬日的「隔日」本機 00:00 毫秒 epoch。
    static func nextDayStart(_ millis: Int64) -> Int64 {
        let start = startOfDay(millis)
        let date = Date(timeIntervalSince1970: Double(start) / 1000)
        let next = Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date.addingTimeInterval(86_400)
        return Int64(next.timeIntervalSince1970 * 1000)
    }

    private static let mmddFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM/dd"
        return f
    }()

    /// 毫秒 epoch → "MM/dd"。
    static func mmdd(_ millis: Int64) -> String {
        mmddFormatter.string(from: Date(timeIntervalSince1970: Double(millis) / 1000))
    }

    /// Date ↔ 毫秒 epoch 互轉（供 SwiftUI DatePicker 使用）。
    static func date(fromMillis millis: Int64) -> Date {
        Date(timeIntervalSince1970: Double(millis) / 1000)
    }
    static func millis(from date: Date) -> Int64 {
        Int64(date.timeIntervalSince1970 * 1000)
    }
}

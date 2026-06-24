import Foundation

/// 數字 / 金額格式化，對應 Android 的 "%,d" 千分位顯示（v1.2.17）。
enum Formatters {
    private static let grouping: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        f.maximumFractionDigits = 0
        return f
    }()

    /// 1234 → "1,234"
    static func grouped(_ value: Int) -> String {
        grouping.string(from: NSNumber(value: value)) ?? "\(value)"
    }
    static func grouped(_ value: Double) -> String { grouped(Int(value)) }

    /// 1234 → "NT$1,234"
    static func money(_ value: Double) -> String { "NT$" + grouped(value) }
    static func money(_ value: Int) -> String { "NT$" + grouped(value) }
}

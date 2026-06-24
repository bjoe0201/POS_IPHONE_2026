import Foundation
import Combine

enum DateRange: CaseIterable {
    case today, yesterday, week, month, year, all, custom
    var label: String {
        switch self {
        case .today: return "今日"
        case .yesterday: return "昨天"
        case .week: return "本週"
        case .month: return "本月"
        case .year: return "今年"
        case .all: return "全部"
        case .custom: return "自訂"
        }
    }
    /// 快速篩選列顯示的選項（不含 custom，custom 另以日期選擇觸發）。
    static let quickOptions: [DateRange] = [.today, .yesterday, .week, .month, .year, .all]
}

struct OrderWithItems: Identifiable {
    let order: Order
    let items: [OrderItem]
    var id: Int64 { order.id ?? 0 }
    var total: Double { items.reduce(0) { $0 + $1.price * Double($1.quantity) } }
}

struct GroupSalesStat: Identifiable {
    let groupName: String
    let quantity: Int
    let revenue: Double
    var id: String { groupName }
}

/// 對應 Android ReportViewModel。
@MainActor
final class ReportViewModel: ObservableObject {
    @Published var dateRange: DateRange = .today
    @Published var customStartDate: Int64?
    @Published var customEndDate: Int64?
    @Published private(set) var showDeleted = false
    @Published private(set) var orders: [OrderWithItems] = []
    @Published private(set) var totalRevenue: Double = 0
    @Published private(set) var totalOrders = 0
    @Published private(set) var avgOrderValue: Double = 0
    @Published private(set) var itemRanking: [(name: String, qty: Int)] = []
    @Published private(set) var groupRanking: [GroupSalesStat] = []
    @Published private(set) var openOrders: [Order] = []
    @Published private(set) var isLoading = true
    @Published var message: String?

    private let orderRepo: OrderRepository
    private var cancellables = Set<AnyCancellable>()
    private let cal = Calendar.current
    /// 最近一次資料庫快照，篩選條件改變時用來重新計算而不需重查 DB。
    private var allOrdersCache: [Order] = []

    init(container: AppContainer) {
        self.orderRepo = container.orderRepository

        orderRepo.allOrdersPublisher()
            .replaceError(with: [])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] allOrders in
                self?.allOrdersCache = allOrders
                self?.recompute(allOrders)
            }
            .store(in: &cancellables)

        orderRepo.allOpenOrdersPublisher()
            .replaceError(with: [])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] open in self?.openOrders = open }
            .store(in: &cancellables)
    }

    // MARK: - 篩選操作
    func setDateRange(_ range: DateRange) { dateRange = range; reload() }
    func setCustomStart(_ millis: Int64) { customStartDate = millis; dateRange = .custom }
    func setCustomEnd(_ millis: Int64) { customEndDate = millis; dateRange = .custom }
    func applyCustomRange() {
        guard let s = customStartDate, let e = customEndDate else { return }
        if s > e { customStartDate = e; customEndDate = s }
        dateRange = .custom
        reload()
    }
    func toggleShowDeleted() { showDeleted.toggle(); reload() }
    func softDeleteOrder(_ id: Int64) { try? orderRepo.softDeleteOrder(orderId: id) }
    func restoreOrder(_ id: Int64) { try? orderRepo.restoreOrder(orderId: id) }
    func clearMessage() { message = nil }

    private func reload() {
        recompute(allOrdersCache)
    }

    // MARK: - 計算
    private func recompute(_ allOrders: [Order]) {
        isLoading = true
        let (start, end) = resolveBounds()
        let allItems = (try? orderRepo.allOrderItems()) ?? []
        let itemsByOrder = Dictionary(grouping: allItems, by: { $0.orderId })

        let paid = allOrders.filter {
            $0.status == OrderStatus.paid.rawValue
            && $0.createdAt >= start && $0.createdAt <= end
            && (showDeleted || !$0.isDeleted)
        }

        let owis = paid.map { OrderWithItems(order: $0, items: itemsByOrder[$0.id ?? -1] ?? []) }

        var itemMap: [String: Int] = [:]
        var groupMap: [String: (qty: Int, rev: Double)] = [:]
        for owi in owis {
            for item in owi.items {
                itemMap[item.name, default: 0] += item.quantity
                let g = item.menuGroupName.isEmpty ? "未分組" : item.menuGroupName
                let cur = groupMap[g] ?? (0, 0)
                groupMap[g] = (cur.qty + item.quantity, cur.rev + item.price * Double(item.quantity))
            }
        }

        let revenue = owis.reduce(0) { $0 + $1.total }
        orders = owis
        totalRevenue = revenue
        totalOrders = owis.count
        avgOrderValue = owis.isEmpty ? 0 : revenue / Double(owis.count)
        itemRanking = itemMap.sorted { $0.value > $1.value }.prefix(10).map { (name: $0.key, qty: $0.value) }
        groupRanking = groupMap.sorted { $0.value.rev > $1.value.rev }.prefix(10)
            .map { GroupSalesStat(groupName: $0.key, quantity: $0.value.qty, revenue: $0.value.rev) }
        isLoading = false
    }

    private func resolveBounds() -> (Int64, Int64) {
        let now = Date.nowMillis
        switch dateRange {
        case .today:
            return (DateBoundary.startOfDay(now), DateBoundary.endOfDay(now))
        case .yesterday:
            let y = now - 86_400_000
            return (DateBoundary.startOfDay(y), DateBoundary.endOfDay(y))
        case .week:
            return (DateBoundary.startOfDay(now - 6 * 86_400_000), DateBoundary.endOfDay(now))
        case .month:
            return (DateBoundary.startOfDay(now - 29 * 86_400_000), DateBoundary.endOfDay(now))
        case .year:
            var comps = DateComponents(); comps.year = cal.component(.year, from: Date()); comps.month = 1; comps.day = 1
            let jan1 = cal.date(from: comps).map { Int64($0.timeIntervalSince1970 * 1000) } ?? now
            return (DateBoundary.startOfDay(jan1), DateBoundary.endOfDay(now))
        case .all:
            return (0, Int64.max)
        case .custom:
            let from = customStartDate ?? 0
            let to = customEndDate ?? Int64.max
            let (a, b) = from <= to ? (from, to) : (to, from)
            return (DateBoundary.startOfDay(a), DateBoundary.endOfDay(b))
        }
    }

    /// 列印/匯出前是否需先詢問「列印明細 / 只印總覽」：超過 10 筆且範圍超過 1 天。
    var shouldConfirmDetail: Bool {
        guard orders.count > 10 else { return false }
        let (start, end) = resolveBounds()
        if end == Int64.max { return true }   // 全部
        return (end - start) > 86_400_000
    }

    // MARK: - 範圍文字
    func rangeText() -> (label: String, text: String) {
        let label = dateRange.label
        if dateRange == .all { return (label, "全部") }
        let (start, end) = resolveBounds()
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let s = f.string(from: DateBoundary.date(fromMillis: start))
        let e = f.string(from: DateBoundary.date(fromMillis: end))
        return (label, "\(s) ~ \(e)")
    }

    // MARK: - CSV（對應 Android buildReportCsv，UTF-8 BOM 由寫檔時加）
    func buildCsv(includeDetails: Bool) -> String {
        let dtf = DateFormatter(); dtf.dateFormat = "yyyy-MM-dd HH:mm"
        let (label, rangeStr) = rangeText()
        var sb = ""
        func line(_ cols: Any?...) {
            sb += cols.map { csvEscape(($0.map { "\($0)" }) ?? "") }.joined(separator: ",") + "\n"
        }
        line("報表匯出")
        line("日期區間", "\(label)（\(rangeStr)）")
        line("含已刪除", showDeleted ? "是" : "否")
        line("產生時間", dtf.string(from: Date()))
        sb += "\n"
        line("===== 總覽 =====")
        line("項目", "數值")
        line("總營業額", "NT$\(Int(totalRevenue))")
        line("總筆數", "\(totalOrders) 筆")
        line("平均客單", "NT$\(Int(avgOrderValue))")
        sb += "\n"
        line("===== 品項銷售排行 =====")
        line("排名", "品項", "數量")
        for (i, r) in itemRanking.enumerated() { line(i + 1, r.name, r.qty) }
        if itemRanking.isEmpty { line("（無資料）") }
        sb += "\n"
        line("===== 群組銷售排行 =====")
        line("排名", "群組", "數量", "營業額")
        for (i, g) in groupRanking.enumerated() { line(i + 1, g.groupName, g.quantity, "NT$\(Int(g.revenue))") }
        if groupRanking.isEmpty { line("（無資料）") }
        sb += "\n"
        if includeDetails {
            line("===== 訂單明細 =====")
            line("訂單ID", "桌號", "建立時間", "狀態", "已刪除", "品項", "群組", "數量", "單價", "小計")
            for owi in orders {
                let o = owi.order
                let created = dtf.string(from: DateBoundary.date(fromMillis: o.createdAt))
                let del = o.isDeleted ? "是" : ""
                if owi.items.isEmpty {
                    line(o.id ?? 0, o.tableName, created, o.status, del, "", "", "", "", "")
                } else {
                    for item in owi.items {
                        line(o.id ?? 0, o.tableName, created, o.status, del,
                             item.name, item.menuGroupName, item.quantity,
                             Int(item.price), Int(item.price * Double(item.quantity)))
                    }
                }
            }
        }
        return sb
    }

    private func csvEscape(_ s: String) -> String {
        if s.isEmpty { return "" }
        let needQuote = s.contains(",") || s.contains("\"") || s.contains("\n") || s.contains("\r")
        let escaped = s.replacingOccurrences(of: "\"", with: "\"\"")
        return needQuote ? "\"\(escaped)\"" : escaped
    }
}

import Foundation
import Combine

/// 分類順序與顯示名稱，對應 Android OrderViewModel.CATEGORIES。
/// 實際分類仍以資料庫 menu_groups 為準，此為預設後援。
let CATEGORIES: [(code: String, name: String)] = [
    ("HOTPOT_BASE", "鍋底"),
    ("MEAT", "肉類"),
    ("SEAFOOD", "海鮮"),
    ("VEGETABLE", "蔬菜"),
    ("BEVERAGE", "飲料"),
    ("OTHER", "其他")
]

/// 對應 Android OrderViewModel + OrderUiState。
@MainActor
final class OrderViewModel: ObservableObject {

    // MARK: - Published 狀態（對應 OrderUiState）
    @Published private(set) var groups: [MenuGroup] = []
    @Published private(set) var tables: [DiningTable] = []
    @Published private(set) var selectedTable: DiningTable?
    @Published private(set) var order: Order?
    @Published private(set) var orderItems: [OrderItem] = []
    @Published private(set) var menuItems: [MenuItem] = []
    @Published private(set) var selectedCategory: String = "HOTPOT_BASE"
    @Published var remark: String = ""
    @Published private(set) var openOrderTotals: [Int64: Double] = [:]
    @Published private(set) var selectedDate: Int64 = DateBoundary.todayStart()
    @Published private(set) var isBackfillMode: Bool = false
    @Published var errorMessage: String?

    /// 補登確認提示：非 nil 時 UI 顯示確認對話框，內容為日期文字（MM/dd）。
    @Published var backfillPrompt: String?

    // 設定（同步自 SettingsStore）
    var qtyRepeatIntervalMs: Int { settings.qtyRepeatIntervalMs }
    var qtyRepeatInitialDelayMs: Int { settings.qtyRepeatInitialDelayMs }
    var hapticEnabled: Bool { settings.hapticEnabled }
    var printCheckoutEnabled: Bool { settings.printCheckoutEnabled }
    var pdfPrinterEnabled: Bool { settings.pdfPrinterEnabled }

    // MARK: - 計算屬性
    var total: Double { orderItems.reduce(0) { $0 + $1.price * Double($1.quantity) } }
    var itemCount: Int { orderItems.reduce(0) { $0 + $1.quantity } }
    var openCount: Int { openOrderTotals.count }

    // MARK: - 相依
    private let orderRepo: OrderRepository
    private let menuGroupRepo: MenuGroupRepository
    private let menuRepo: MenuRepository
    private let tableRepo: TableRepository
    private let settings: SettingsStore

    private var cancellables = Set<AnyCancellable>()
    private var orderCancellable: AnyCancellable?
    private var menuCancellable: AnyCancellable?

    // 補登 / 日期計時器
    private var resetDateTask: Task<Void, Never>?
    private var rolloverTask: Task<Void, Never>?
    private var observedTodayStart = DateBoundary.todayStart()
    private var backfillConfirmed = false
    private var pendingAddItem: MenuItem?
    private let dateResetDelayNs: UInt64 = 3 * 60 * 1_000_000_000  // 3 分鐘

    init(container: AppContainer) {
        self.orderRepo = container.orderRepository
        self.menuGroupRepo = container.menuGroupRepository
        self.menuRepo = container.menuRepository
        self.tableRepo = container.tableRepository
        self.settings = container.settings
        start()
    }

    private func start() {
        // 啟用中的菜單群組
        menuGroupRepo.activeGroupsPublisher()
            .replaceError(with: [])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] groups in
                guard let self else { return }
                let category = groups.contains(where: { $0.code == self.selectedCategory })
                    ? self.selectedCategory
                    : (groups.first?.code ?? "")
                self.groups = groups
                self.selectedCategory = category
                self.observeMenu(category: category)
            }
            .store(in: &cancellables)

        // 啟用中的桌號
        tableRepo.activeTablesPublisher()
            .replaceError(with: [])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tables in
                guard let self else { return }
                let stillActive = tables.first { $0.id == self.selectedTable?.id }
                self.tables = tables
                self.selectedTable = stillActive ?? tables.first
                self.loadOrderForSelected()
            }
            .store(in: &cancellables)

        // 各桌未結金額
        orderRepo.openOrderTotalsPublisher()
            .replaceError(with: [:])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] totals in self?.openOrderTotals = totals }
            .store(in: &cancellables)

        // 設定變更時觸發 UI 重新讀取（@Published 計算屬性依賴 settings）
        settings.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        startDateRollover()

        // 啟動清理孤兒空訂單
        try? orderRepo.cancelEmptyOpenOrders()
    }

    // MARK: - 桌號 / 訂單

    func selectTable(_ table: DiningTable) {
        selectedTable = table
        order = nil
        orderItems = []
        loadOrderForSelected()
    }

    private func loadOrderForSelected() {
        guard let table = selectedTable, let tableId = table.id else { return }
        orderCancellable?.cancel()
        orderCancellable = orderRepo.openOrderForTablePublisher(tableId: tableId)
            .map { [orderRepo] order -> AnyPublisher<(Order?, [OrderItem]), Error> in
                guard let order, let oid = order.id else {
                    return Just<(Order?, [OrderItem])>((order, []))
                        .setFailureType(to: Error.self)
                        .eraseToAnyPublisher()
                }
                return orderRepo.itemsForOrderPublisher(orderId: oid)
                    .map { (order, $0) }
                    .eraseToAnyPublisher()
            }
            .switchToLatest()
            .replaceError(with: (nil, []))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] order, items in
                self?.order = order
                self?.orderItems = items
            }
    }

    // MARK: - 分類 / 菜單

    func selectCategory(_ category: String) {
        selectedCategory = category
        observeMenu(category: category)
    }

    private func observeMenu(category: String) {
        menuCancellable?.cancel()
        guard !category.isEmpty else { menuItems = []; return }
        menuCancellable = menuRepo.itemsByCategoryPublisher(category)
            .replaceError(with: [])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in self?.menuItems = items }
    }

    func quantityInOrder(menuItemId: Int64) -> Int {
        orderItems.first { $0.menuItemId == menuItemId }?.quantity ?? 0
    }

    // MARK: - 日期 / 補登

    func updateSelectedDate(_ millis: Int64) {
        let newDate = DateBoundary.startOfDay(millis)
        let today = DateBoundary.todayStart()
        selectedDate = newDate
        isBackfillMode = newDate != today
        if newDate != today {
            backfillConfirmed = false
            startResetDateTimer()
        } else {
            cancelResetDateTimer()
        }
    }

    func resetToToday() {
        cancelResetDateTimer()
        backfillConfirmed = false
        pendingAddItem = nil
        selectedDate = DateBoundary.todayStart()
        isBackfillMode = false
    }

    private func startResetDateTimer() {
        resetDateTask?.cancel()
        resetDateTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: self?.dateResetDelayNs ?? 0)
            if Task.isCancelled { return }
            await MainActor.run {
                guard let self else { return }
                self.selectedDate = DateBoundary.todayStart()
                self.isBackfillMode = false
                self.backfillConfirmed = false
                self.resetDateTask = nil
            }
        }
    }

    private func cancelResetDateTimer() {
        resetDateTask?.cancel()
        resetDateTask = nil
    }

    /// 使用者有互動時延長補登計時器（對應 touchResetDateTimer）。
    func touchResetDateTimer() {
        if resetDateTask != nil { startResetDateTimer() }
    }

    private func startDateRollover() {
        rolloverTask?.cancel()
        rolloverTask = Task { [weak self] in
            while !Task.isCancelled {
                let now = Date.nowMillis
                let wait = max(DateBoundary.nextDayStart(now) - now, 1_000)
                try? await Task.sleep(nanoseconds: UInt64(wait) * 1_000_000)
                if Task.isCancelled { return }
                await MainActor.run {
                    guard let self else { return }
                    let previous = self.observedTodayStart
                    let today = DateBoundary.todayStart()
                    guard today != previous else { return }
                    self.observedTodayStart = today
                    let wasAutoAdvanced = self.selectedDate == previous
                    if wasAutoAdvanced {
                        self.selectedDate = today
                        self.backfillConfirmed = false
                        self.pendingAddItem = nil
                        self.cancelResetDateTimer()
                    }
                    self.isBackfillMode = self.selectedDate != today
                }
            }
        }
    }

    // MARK: - 點餐

    func addItem(_ menuItem: MenuItem) {
        guard let table = selectedTable, let tableId = table.id else { return }
        touchResetDateTimer()

        let today = DateBoundary.todayStart()
        let date = selectedDate

        // 補登模式：第一次新增前需確認
        if date != today && !backfillConfirmed {
            pendingAddItem = menuItem
            backfillPrompt = DateBoundary.mmdd(date)
            return
        }

        do {
            let createdAt = (date == today) ? Date.nowMillis : date
            let orderId = try order?.id ?? orderRepo.createOrder(tableId: tableId,
                                                                 tableName: table.tableName,
                                                                 createdAt: createdAt)
            try orderRepo.addOrUpdateItem(orderId: orderId,
                                          menuItemId: menuItem.id ?? 0,
                                          name: menuItem.name,
                                          price: menuItem.price,
                                          menuGroupCode: menuItem.category,
                                          menuGroupName: resolveGroupName(menuItem.category),
                                          delta: 1)
        } catch {
            errorMessage = "新增品項失敗：\(error.localizedDescription)"
        }
    }

    func removeItem(_ menuItem: MenuItem) {
        touchResetDateTimer()
        guard let orderId = order?.id else { return }
        try? orderRepo.addOrUpdateItem(orderId: orderId,
                                       menuItemId: menuItem.id ?? 0,
                                       name: menuItem.name,
                                       price: menuItem.price,
                                       menuGroupCode: menuItem.category,
                                       menuGroupName: resolveGroupName(menuItem.category),
                                       delta: -1)
    }

    func deleteOrderItem(_ item: OrderItem) {
        touchResetDateTimer()
        try? orderRepo.removeItem(item)
    }

    func confirmBackfill() {
        backfillConfirmed = true
        backfillPrompt = nil
        guard let item = pendingAddItem else { return }
        pendingAddItem = nil
        addItem(item)
    }

    func cancelBackfill() {
        pendingAddItem = nil
        backfillPrompt = nil
    }

    // MARK: - 結帳 / 取消

    /// 對應 Android payOrder。成功後回呼帶出結帳快照（供音效 / 收據處理）。
    func payOrder(onDone: (CheckoutResult) -> Void) {
        guard let orderId = order?.id else {
            errorMessage = "無可結帳訂單，請重新選桌後再試"
            return
        }
        guard !orderItems.isEmpty else {
            errorMessage = "訂單無品項，無法結帳"
            return
        }
        let snapshot = CheckoutResult(
            orderId: orderId,
            tableName: selectedTable?.tableName ?? "",
            createdAt: order?.createdAt ?? Date.nowMillis,
            remark: remark,
            items: orderItems,
            total: total
        )
        do {
            try orderRepo.payOrder(orderId: orderId, remark: remark)
            remark = ""
            errorMessage = nil
            onDone(snapshot)
        } catch {
            errorMessage = "結帳寫入失敗：\(error.localizedDescription)"
        }
    }

    func cancelOrder() {
        guard let orderId = order?.id else { return }
        try? orderRepo.cancelOrder(orderId: orderId)
    }

    func clearError() { errorMessage = nil }

    /// 結帳成功後處理收據：依設定自動存 PDF 到資料夾、或 AirPrint 列印。
    /// 對應 Android 結帳時的 PDF 收據 / 印表機列印（iOS 以 AirPrint + 資料夾 bookmark 實作）。
    func handleReceipt(_ result: CheckoutResult) {
        let receipt = PdfReportBuilder.ReceiptData(
            orderId: result.orderId,
            tableName: result.tableName,
            createdAt: result.createdAt,
            remark: result.remark,
            items: result.items.map { ($0.name, $0.quantity, $0.price) },
            total: result.total
        )
        if settings.pdfPrinterEnabled && !settings.pdfPrinterTreeUri.isEmpty {
            let data = PdfReportBuilder.receiptPDF(receipt)
            FolderBookmark.write(data, filename: PdfReportBuilder.receiptFilename(receipt),
                                 token: settings.pdfPrinterTreeUri)
        }
        if settings.printCheckoutEnabled {
            Exporting.printPDF(PdfReportBuilder.receiptPDF(receipt), jobName: "收據 #\(result.orderId)")
        }
    }

    private func resolveGroupName(_ code: String) -> String {
        groups.first { $0.code == code }?.name ?? code
    }
}

/// 結帳成功快照，供音效 / 收據 PDF / AirPrint（M6 / M7）使用。
struct CheckoutResult {
    let orderId: Int64
    let tableName: String
    let createdAt: Int64
    let remark: String
    let items: [OrderItem]
    let total: Double
}

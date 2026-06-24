import Foundation
import Combine

/// 時間字串工具（"HH:mm" ↔ 分鐘）。對應 Android timeToMinutes / minutesToTime / addMinutes。
enum RTime {
    static func toMinutes(_ s: String) -> Int {
        let p = s.split(separator: ":")
        let h = Int(p.first ?? "0") ?? 0
        let m = p.count > 1 ? (Int(p[1]) ?? 0) : 0
        return h * 60 + m
    }
    static func toString(_ minutes: Int) -> String {
        String(format: "%02d:%02d", (minutes / 60) % 24, minutes % 60)
    }
    static func add(_ time: String, _ minutes: Int) -> String {
        toString(toMinutes(time) + minutes)
    }
}

/// 對應 Android ReservationViewModel。
@MainActor
final class ReservationViewModel: ObservableObject {
    @Published private(set) var year: Int
    @Published private(set) var month: Int            // 1...12
    @Published var selectedDate: Date?                // nil = 月曆視圖
    @Published private(set) var monthReservations: [Reservation] = []
    @Published private(set) var dayReservations: [Reservation] = []
    @Published private(set) var activeTables: [DiningTable] = []

    // 設定（同步自 SettingsStore）
    var bizStart: String { settings.bizStart }
    var bizEnd: String { settings.bizEnd }
    var breakStart: String { settings.breakStart }
    var breakEnd: String { settings.breakEnd }
    var defaultDuration: Int { settings.defaultDuration }
    var calendarChipsPerRow: Int { settings.calendarChipsPerRow }

    private let reservationRepo: ReservationRepository
    private let tableRepo: TableRepository
    private let settings: SettingsStore
    private var cancellables = Set<AnyCancellable>()
    private var monthCancellable: AnyCancellable?
    private var dayCancellable: AnyCancellable?

    private let cal = Calendar.current

    init(container: AppContainer) {
        self.reservationRepo = container.reservationRepository
        self.tableRepo = container.tableRepository
        self.settings = container.settings
        let now = Date()
        self.year = Calendar.current.component(.year, from: now)
        self.month = Calendar.current.component(.month, from: now)

        tableRepo.activeTablesPublisher()
            .replaceError(with: [])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tables in self?.activeTables = tables }
            .store(in: &cancellables)

        settings.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        observeMonth()
    }

    // MARK: - 日期字串
    var yearMonthString: String { String(format: "%04d-%02d", year, month) }

    func dateString(_ date: Date) -> String {
        String(format: "%04d-%02d-%02d",
               cal.component(.year, from: date),
               cal.component(.month, from: date),
               cal.component(.day, from: date))
    }

    var isCurrentMonth: Bool {
        let now = Date()
        return year == cal.component(.year, from: now) && month == cal.component(.month, from: now)
    }

    // MARK: - 月份切換
    func prevMonth() {
        if month == 1 { month = 12; year -= 1 } else { month -= 1 }
        observeMonth()
    }
    func nextMonth() {
        if month == 12 { month = 1; year += 1 } else { month += 1 }
        observeMonth()
    }
    func goToToday() {
        let now = Date()
        let ty = cal.component(.year, from: now)
        let tm = cal.component(.month, from: now)
        if year == ty && month == tm {
            selectDate(cal.startOfDay(for: now))
        } else {
            year = ty; month = tm
            observeMonth()
        }
    }

    func selectDate(_ date: Date) {
        selectedDate = date
        let y = cal.component(.year, from: date)
        let m = cal.component(.month, from: date)
        if y != year || m != month { year = y; month = m; observeMonth() }
        observeDay()
    }

    func clearSelectedDate() {
        selectedDate = nil
        dayCancellable?.cancel()
        dayReservations = []
    }

    // MARK: - 訂閱
    private func observeMonth() {
        monthCancellable = reservationRepo.byMonthPublisher(yearMonthString)
            .replaceError(with: [])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] list in self?.monthReservations = list }
    }

    private func observeDay() {
        guard let date = selectedDate else { return }
        let ds = dateString(date)
        dayCancellable = reservationRepo.byDatePublisher(ds)
            .replaceError(with: [])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] list in self?.dayReservations = list }
    }

    // MARK: - CRUD
    func upsert(_ reservation: Reservation) { try? reservationRepo.upsert(reservation) }
    func delete(_ reservation: Reservation) { try? reservationRepo.delete(reservation) }
}

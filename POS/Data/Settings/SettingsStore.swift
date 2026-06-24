import Foundation
import Combine
import CryptoKit

/// 對應 Android SettingsDataStore + SettingsRepository。
/// 以 UserDefaults 持久化，@Published 提供 SwiftUI 響應式更新。
final class SettingsStore: ObservableObject {

    static let defaultPin = "1234"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // 載入初始值（套用與 Android 相同的預設值）
        pinHash = defaults.string(forKey: K.pinHash) ?? SettingsStore.hashPin(SettingsStore.defaultPin)
        isDefaultPin = defaults.object(forKey: K.isDefaultPin) as? Bool ?? true
        tabMenuEnabled = defaults.object(forKey: K.tabMenu) as? Bool ?? true
        tabTableEnabled = defaults.object(forKey: K.tabTable) as? Bool ?? true
        tabReportEnabled = defaults.object(forKey: K.tabReport) as? Bool ?? true
        tabReservationEnabled = defaults.object(forKey: K.tabReservation) as? Bool ?? true
        bizStart = defaults.string(forKey: K.bizStart) ?? "11:00"
        bizEnd = defaults.string(forKey: K.bizEnd) ?? "22:00"
        breakStart = defaults.string(forKey: K.breakStart) ?? ""
        breakEnd = defaults.string(forKey: K.breakEnd) ?? ""
        defaultDuration = defaults.object(forKey: K.defaultDuration) as? Int ?? 90
        calendarChipsPerRow = defaults.object(forKey: K.calendarChips) as? Int ?? 2
        autoBackupEnabled = defaults.object(forKey: K.autoBackupEnabled) as? Bool ?? true
        autoBackupIdleMinutes = defaults.object(forKey: K.autoBackupIdle) as? Int ?? 5
        autoBackupRetentionDays = defaults.object(forKey: K.autoBackupRetention) as? Int ?? 3
        qtyRepeatIntervalMs = defaults.object(forKey: K.qtyInterval) as? Int ?? 100
        qtyRepeatInitialDelayMs = defaults.object(forKey: K.qtyDelay) as? Int ?? 1000
        hapticEnabled = defaults.object(forKey: K.haptic) as? Bool ?? true
        printCheckoutEnabled = defaults.object(forKey: K.printCheckout) as? Bool ?? false
        pdfPrinterEnabled = defaults.object(forKey: K.pdfEnabled) as? Bool ?? false
        pdfPrinterTreeUri = defaults.string(forKey: K.pdfTreeUri) ?? ""
    }

    // MARK: - PIN
    @Published private(set) var pinHash: String { didSet { defaults.set(pinHash, forKey: K.pinHash) } }
    @Published private(set) var isDefaultPin: Bool { didSet { defaults.set(isDefaultPin, forKey: K.isDefaultPin) } }

    // MARK: - 功能頁面開關
    @Published var tabMenuEnabled: Bool { didSet { defaults.set(tabMenuEnabled, forKey: K.tabMenu) } }
    @Published var tabTableEnabled: Bool { didSet { defaults.set(tabTableEnabled, forKey: K.tabTable) } }
    @Published var tabReportEnabled: Bool { didSet { defaults.set(tabReportEnabled, forKey: K.tabReport) } }
    @Published var tabReservationEnabled: Bool { didSet { defaults.set(tabReservationEnabled, forKey: K.tabReservation) } }

    // MARK: - 訂位設定
    @Published var bizStart: String { didSet { defaults.set(bizStart, forKey: K.bizStart) } }
    @Published var bizEnd: String { didSet { defaults.set(bizEnd, forKey: K.bizEnd) } }
    @Published var breakStart: String { didSet { defaults.set(breakStart, forKey: K.breakStart) } }
    @Published var breakEnd: String { didSet { defaults.set(breakEnd, forKey: K.breakEnd) } }
    @Published var defaultDuration: Int { didSet { defaults.set(defaultDuration, forKey: K.defaultDuration) } }
    @Published var calendarChipsPerRow: Int { didSet { defaults.set(calendarChipsPerRow, forKey: K.calendarChips) } }

    // MARK: - 自動備份
    @Published var autoBackupEnabled: Bool { didSet { defaults.set(autoBackupEnabled, forKey: K.autoBackupEnabled) } }
    @Published var autoBackupIdleMinutes: Int { didSet { defaults.set(autoBackupIdleMinutes, forKey: K.autoBackupIdle) } }
    @Published var autoBackupRetentionDays: Int { didSet { defaults.set(autoBackupRetentionDays, forKey: K.autoBackupRetention) } }

    // MARK: - 點餐長按連續加減
    @Published var qtyRepeatIntervalMs: Int { didSet { defaults.set(qtyRepeatIntervalMs.clamped(30, 500), forKey: K.qtyInterval) } }
    @Published var qtyRepeatInitialDelayMs: Int { didSet { defaults.set(qtyRepeatInitialDelayMs.clamped(300, 2000), forKey: K.qtyDelay) } }
    @Published var hapticEnabled: Bool { didSet { defaults.set(hapticEnabled, forKey: K.haptic) } }

    // MARK: - PDF 列印機（iOS：搭配 AirPrint）
    @Published var printCheckoutEnabled: Bool { didSet { defaults.set(printCheckoutEnabled, forKey: K.printCheckout) } }
    @Published var pdfPrinterEnabled: Bool { didSet { defaults.set(pdfPrinterEnabled, forKey: K.pdfEnabled) } }
    @Published var pdfPrinterTreeUri: String { didSet { defaults.set(pdfPrinterTreeUri, forKey: K.pdfTreeUri) } }

    // MARK: - PIN 操作
    func setPin(_ newPin: String) {
        pinHash = SettingsStore.hashPin(newPin)
        isDefaultPin = (newPin == SettingsStore.defaultPin)
    }

    func verifyPin(_ input: String) -> Bool {
        SettingsStore.hashPin(input) == pinHash
    }

    static func hashPin(_ pin: String) -> String {
        let digest = SHA256.hash(data: Data(pin.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Keys
    private enum K {
        static let pinHash = "pin_hash"
        static let isDefaultPin = "is_default_pin"
        static let tabMenu = "tab_menu_enabled"
        static let tabTable = "tab_table_enabled"
        static let tabReport = "tab_report_enabled"
        static let tabReservation = "tab_reservation_enabled"
        static let bizStart = "biz_start"
        static let bizEnd = "biz_end"
        static let breakStart = "break_start"
        static let breakEnd = "break_end"
        static let defaultDuration = "default_duration"
        static let calendarChips = "calendar_chips_per_row"
        static let autoBackupEnabled = "auto_backup_enabled"
        static let autoBackupIdle = "auto_backup_idle_minutes"
        static let autoBackupRetention = "auto_backup_retention_days"
        static let qtyInterval = "qty_repeat_interval_ms"
        static let qtyDelay = "qty_repeat_initial_delay_ms"
        static let haptic = "haptic_enabled"
        static let printCheckout = "print_checkout_enabled"
        static let pdfEnabled = "pdf_printer_enabled"
        static let pdfTreeUri = "pdf_printer_tree_uri"
    }
}

private extension Int {
    func clamped(_ lo: Int, _ hi: Int) -> Int { Swift.min(Swift.max(self, lo), hi) }
}

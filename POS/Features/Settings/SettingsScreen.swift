import SwiftUI
import UniformTypeIdentifiers

/// 設定。對應 Android SettingsScreen（手機版以 Form 呈現各區塊）。
struct SettingsScreen: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var printer: ThermalPrinterManager
    @StateObject private var vm: SettingsViewModel

    @State private var showPinSheet = false
    @State private var showResetConfirm = false
    @State private var shareItem: ShareItem?
    @State private var importPicker = false
    @State private var folderPicker = false

    init(container: AppContainer) {
        _vm = StateObject(wrappedValue: SettingsViewModel(container: container))
    }

    struct ShareItem: Identifiable { let id = UUID(); let url: URL }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "設定")
            Form {
                pinSection
                tabsSection
                orderOpsSection
                reservationSection
                thermalPrinterSection
                printerSection
                pdfSection
                backupSection
                autoBackupSection
                dbSection
                aboutSection
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .sheet(isPresented: $showPinSheet) { PinChangeSheet(vm: vm) }
        .sheet(item: $shareItem) { item in ShareSheet(items: [item.url]) }
        .sheet(isPresented: $importPicker) {
            DocumentPicker(contentTypes: [UTType.zip, UTType(filenameExtension: "zip") ?? .data]) { url in
                vm.importBackup(from: url)
            }
        }
        .sheet(isPresented: $folderPicker) {
            DocumentPicker(contentTypes: [.folder]) { url in vm.setPdfFolder(url) }
        }
        .confirmationDialog("確定要初始化資料庫？", isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("初始化（清除全部資料）", role: .destructive) { vm.resetDatabase() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("將清除全部訂單、菜單、桌號並恢復預設，建議先匯出備份。")
        }
        .alert("提示", isPresented: Binding(get: { vm.message != nil }, set: { if !$0 { vm.message = nil } })) {
            Button("好") { vm.message = nil }
        } message: { Text(vm.message ?? "") }
    }

    // MARK: - PIN
    private var pinSection: some View {
        Section("PIN 碼") {
            if settings.isDefaultPin {
                Text("目前使用預設密碼 1234，建議立即修改").font(.footnote).foregroundColor(Theme.warning)
            }
            Button("修改 PIN 碼") { showPinSheet = true }
        }
    }

    // MARK: - 功能頁面
    private var tabsSection: some View {
        Section("功能頁面") {
            Toggle("訂位", isOn: $settings.tabReservationEnabled)
            Toggle("菜單管理", isOn: $settings.tabMenuEnabled)
            Toggle("桌號設定", isOn: $settings.tabTableEnabled)
            Toggle("報表", isOn: $settings.tabReportEnabled)
            Text("記帳與設定為必要頁面，永遠顯示。").font(.footnote).foregroundColor(Theme.textMuted)
        }
        .tint(Theme.accent)
    }

    // MARK: - 點餐操作
    private var orderOpsSection: some View {
        Section("點餐操作") {
            Toggle("觸覺回饋（震動）", isOn: $settings.hapticEnabled).tint(Theme.accent)
            Stepper("長按連續間隔：\(settings.qtyRepeatIntervalMs) ms",
                    value: $settings.qtyRepeatIntervalMs, in: 30...500, step: 10)
            Stepper("長按啟動延遲：\(settings.qtyRepeatInitialDelayMs) ms",
                    value: $settings.qtyRepeatInitialDelayMs, in: 300...2000, step: 100)
        }
    }

    // MARK: - 訂位設定
    private var reservationSection: some View {
        Section("訂位設定") {
            timeRow("營業開始", get: settings.bizStart) { settings.bizStart = $0 }
            timeRow("營業結束", get: settings.bizEnd) { settings.bizEnd = $0 }
            timeRow("休息開始", get: settings.breakStart.isEmpty ? "00:00" : settings.breakStart) { settings.breakStart = $0 }
            timeRow("休息結束", get: settings.breakEnd.isEmpty ? "00:00" : settings.breakEnd) { settings.breakEnd = $0 }
            Stepper("預設用餐時長：\(settings.defaultDuration) 分", value: $settings.defaultDuration, in: 30...300, step: 15)
            Stepper("月曆每行時段數：\(settings.calendarChipsPerRow)", value: $settings.calendarChipsPerRow, in: 1...4)
        }
    }

    private func timeRow(_ label: String, get: String, set: @escaping (String) -> Void) -> some View {
        DatePicker(label, selection: Binding(
            get: { ReservationEditorTime.date(from: get) },
            set: { set(ReservationEditorTime.string(from: $0)) }
        ), displayedComponents: .hourAndMinute)
    }

    // MARK: - 熱感印表機（藍牙 BLE）
    private var thermalPrinterSection: some View {
        Section("熱感印表機（藍牙）") {
            if printer.isConnected {
                HStack {
                    Image(systemName: "printer.fill").foregroundColor(Theme.success)
                    Text("已連線：\(printer.savedName ?? "印表機")")
                        .font(.footnote).foregroundColor(Theme.textSub)
                    Spacer()
                    Button("中斷") { printer.disconnect() }.font(.caption).foregroundColor(Theme.error)
                }
                Button("測試列印") { printer.printTest() }
                Button("忘記此裝置") { printer.forget() }.foregroundColor(Theme.error)
            } else {
                if let name = printer.savedName {
                    Text("已記住：\(name)（不在範圍或未開機時無法連線）")
                        .font(.footnote).foregroundColor(Theme.textMuted)
                }
                Button(printer.state == .scanning ? "偵測中…停止" : "偵測藍牙印表機") {
                    if printer.state == .scanning { printer.stopScan() } else { printer.startScan() }
                }
                ForEach(printer.devices) { device in
                    Button {
                        printer.connect(device)
                    } label: {
                        HStack {
                            Image(systemName: "printer").foregroundColor(Theme.textSub)
                            Text(device.name).foregroundColor(Theme.text)
                            Spacer()
                            Text("\(device.rssi) dBm").font(.caption).foregroundColor(Theme.textMuted)
                        }
                    }
                }
                if printer.state == .scanning && printer.devices.isEmpty {
                    Text("搜尋中…請確認印表機已開機並開啟藍牙。")
                        .font(.footnote).foregroundColor(Theme.textMuted)
                }
            }
            if let msg = printer.statusMessage {
                Text(msg).font(.footnote).foregroundColor(Theme.textSub)
            }
        }
        .tint(Theme.accent)
    }

    // MARK: - 列印（AirPrint）
    private var printerSection: some View {
        Section("列印（AirPrint）") {
            Text("未連線熱感印表機時，可用 AirPrint 列印至任何相容印表機。")
                .font(.footnote).foregroundColor(Theme.textMuted)
            Toggle("收款後自動列印收據", isOn: $settings.printCheckoutEnabled).tint(Theme.accent)
            Button("列印測試頁") {
                Exporting.printPDF(vm.makeTestPdf(), jobName: "測試頁")
            }
        }
    }

    // MARK: - PDF 自動存檔
    private var pdfSection: some View {
        Section("PDF 自動存檔") {
            Toggle("啟用（收款後自動存收據 PDF）", isOn: $settings.pdfPrinterEnabled).tint(Theme.accent)
            if settings.pdfPrinterTreeUri.isEmpty {
                Button("選擇存檔資料夾") { folderPicker = true }
            } else {
                HStack {
                    Text("存檔資料夾：\(FolderBookmark.describe(settings.pdfPrinterTreeUri))")
                        .font(.footnote).foregroundColor(Theme.textSub)
                    Spacer()
                    Button("移除") { vm.clearPdfFolder() }.foregroundColor(Theme.error)
                }
                Button("測試存檔") {
                    let ok = FolderBookmark.write(vm.makeTestPdf(), filename: "test-\(Int(Date().timeIntervalSince1970)).pdf",
                                                  token: settings.pdfPrinterTreeUri)
                    vm.message = ok ? "測試 PDF 已存入資料夾" : "寫入失敗，請重新選擇資料夾"
                }
            }
        }
    }

    // MARK: - 資料備份
    private var backupSection: some View {
        Section("資料備份") {
            Button("備份匯出（分享 / 存到檔案）") {
                if let url = vm.makeBackupZip() { shareItem = ShareItem(url: url) }
            }
            Button("備份匯入（選擇 .zip 還原）") { importPicker = true }
            Text("匯入會覆蓋現有資料；還原前系統會在 App 內部建立一份安全備份。")
                .font(.footnote).foregroundColor(Theme.textMuted)
        }
    }

    // MARK: - 自動儲存
    private var autoBackupSection: some View {
        Section("自動儲存") {
            Toggle("啟用自動備份（進入背景時）", isOn: $settings.autoBackupEnabled).tint(Theme.accent)
            Stepper("保留份數天數參考：\(settings.autoBackupRetentionDays) 天",
                    value: $settings.autoBackupRetentionDays, in: 1...30)
            Button("立即備份一次") { vm.backupNow() }
            if vm.autoBackups.isEmpty {
                Text("尚無自動備份").font(.footnote).foregroundColor(Theme.textMuted)
            } else {
                ForEach(vm.autoBackups) { entry in
                    HStack {
                        Text(entry.name).font(.system(size: 12)).lineLimit(1)
                        Spacer()
                        Button("還原") { vm.restoreFromAuto(entry) }.font(.caption).foregroundColor(Theme.accent)
                        Button {
                            vm.deleteAuto(entry)
                        } label: { Image(systemName: "trash").foregroundColor(Theme.error) }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - 資料庫管理
    private var dbSection: some View {
        Section("資料庫管理") {
            Button("初始化（清除全部資料）", role: .destructive) { showResetConfirm = true }
        }
    }

    private var aboutSection: some View {
        Section {
            HStack { Text("版本"); Spacer(); Text(AppInfo.versionLabel).foregroundColor(Theme.textMuted) }
        }
    }
}

/// 時間字串 ↔ Date（供設定頁時間選擇器）。沿用 RTime 規則。
enum ReservationEditorTime {
    static func date(from time: String) -> Date {
        let cal = Calendar.current
        var c = cal.dateComponents([.year, .month, .day], from: Date())
        c.hour = RTime.toMinutes(time) / 60
        c.minute = RTime.toMinutes(time) % 60
        return cal.date(from: c) ?? Date()
    }
    static func string(from date: Date) -> String {
        let cal = Calendar.current
        return String(format: "%02d:%02d", cal.component(.hour, from: date), cal.component(.minute, from: date))
    }
}

// MARK: - 修改 PIN

private struct PinChangeSheet: View {
    @ObservedObject var vm: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var current = ""
    @State private var newPin = ""
    @State private var confirm = ""
    @State private var error: String?

    var body: some View {
        NavigationView {
            Form {
                Section("驗證") {
                    SecureField("目前 PIN 碼", text: $current).keyboardType(.numberPad)
                }
                Section("新 PIN 碼") {
                    SecureField("新 PIN 碼（4 位數）", text: $newPin).keyboardType(.numberPad)
                    SecureField("再次輸入新 PIN 碼", text: $confirm).keyboardType(.numberPad)
                }
                if let error { Text(error).foregroundColor(.red).font(.footnote) }
            }
            .navigationTitle("修改 PIN 碼")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        let (ok, msg) = vm.changePin(current: current, new: newPin, confirm: confirm)
                        if ok { vm.message = msg; dismiss() } else { error = msg }
                    }
                }
            }
        }
    }
}

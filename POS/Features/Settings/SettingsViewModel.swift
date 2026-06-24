import Foundation
import Combine

/// 設定頁動作（PIN、備份、初始化、PDF 目錄）。
/// 多數開關/數值由 View 直接綁定 SettingsStore，這裡只處理需要邏輯的動作。
@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var message: String?
    @Published private(set) var autoBackups: [BackupManager.BackupEntry] = []

    let settings: SettingsStore
    private let database: AppDatabase

    init(container: AppContainer) {
        self.settings = container.settings
        self.database = container.database
        refreshAutoBackups()
    }

    // MARK: - PIN
    /// 回傳 (成功, 訊息)。
    func changePin(current: String, new: String, confirm: String) -> (Bool, String) {
        if !settings.verifyPin(current) { return (false, "目前 PIN 碼錯誤") }
        if new.count != 4 || !new.allSatisfy(\.isNumber) { return (false, "新 PIN 碼需為 4 位數字") }
        if new != confirm { return (false, "兩次輸入不一致") }
        settings.setPin(new)
        return (true, "PIN 碼已更新")
    }

    // MARK: - 備份 / 還原
    /// 產生備份 zip 暫存檔（供分享 sheet）。
    func makeBackupZip() -> URL? {
        do { return try BackupManager.exportZip(database) }
        catch { message = "備份失敗：\(error.localizedDescription)"; return nil }
    }

    func importBackup(from url: URL) {
        do {
            try BackupManager.importZip(from: url, into: database)
            message = "還原成功，資料已更新"
        } catch {
            message = "還原失敗：\(error.localizedDescription)"
        }
    }

    func backupNow() {
        do {
            let entry = try BackupManager.autoBackup(database)
            message = "已建立備份：\(entry.name)"
            refreshAutoBackups()
        } catch {
            message = "備份失敗：\(error.localizedDescription)"
        }
    }

    func restoreFromAuto(_ entry: BackupManager.BackupEntry) {
        do {
            try BackupManager.importZip(from: entry.url, into: database)
            message = "已從備份還原"
        } catch {
            message = "還原失敗：\(error.localizedDescription)"
        }
    }

    func deleteAuto(_ entry: BackupManager.BackupEntry) {
        BackupManager.deleteAutoBackup(entry)
        refreshAutoBackups()
    }

    func refreshAutoBackups() { autoBackups = BackupManager.listAutoBackups() }

    // MARK: - 資料庫初始化
    func resetDatabase() {
        do {
            try database.resetToDefaults()
            message = "資料庫已初始化完成"
        } catch {
            message = "初始化失敗：\(error.localizedDescription)"
        }
    }

    // MARK: - PDF 存檔目錄
    func setPdfFolder(_ url: URL) {
        guard let token = FolderBookmark.makeToken(from: url) else {
            message = "無法存取所選資料夾"; return
        }
        settings.pdfPrinterTreeUri = token
        message = "已設定 PDF 存檔目錄：\(FolderBookmark.describe(token))"
    }
    func clearPdfFolder() {
        settings.pdfPrinterTreeUri = ""
        message = "已移除 PDF 存檔目錄（改用分享）"
    }

    /// 測試：產生一份報表測試 PDF 並存到目錄或分享。
    func makeTestPdf() -> Data {
        PdfReportBuilder.receiptPDF(.init(orderId: 0, tableName: "測試", createdAt: Date.nowMillis,
                                          remark: "PDF 存檔測試", items: [("測試品項", 1, 100)], total: 100))
    }
}

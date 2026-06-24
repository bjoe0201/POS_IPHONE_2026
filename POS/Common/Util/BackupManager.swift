import Foundation
import GRDB
import ZIPFoundation

/// SQLite 資料庫 ZIP 備份 / 還原。對應 Android util/BackupManager。
/// 與 Android 一致：zip 內含名為 `pos_database` 的 SQLite 檔，可跨平台還原。
/// iOS 還原採 GRDB 線上備份把資料覆蓋進「現用」資料庫，無需像 Android 那樣 kill process。
enum BackupManager {
    static let dbEntryName = "pos_database"

    struct BackupEntry: Identifiable {
        let url: URL
        let name: String
        let modified: Date
        var id: String { url.path }
    }

    enum BackupError: LocalizedError {
        case archiveCreate, archiveOpen, noDatabaseEntry, extractFailed
        var errorDescription: String? {
            switch self {
            case .archiveCreate: return "無法建立 ZIP 檔"
            case .archiveOpen: return "無法開啟 ZIP 檔"
            case .noDatabaseEntry: return "備份 ZIP 中找不到資料庫檔案"
            case .extractFailed: return "解壓失敗"
            }
        }
    }

    // MARK: - 匯出

    /// 將現用資料庫打包成 zip，回傳暫存檔 URL（供分享 sheet 儲存到「檔案」）。
    static func exportZip(_ db: AppDatabase) throws -> URL {
        let tmp = FileManager.default.temporaryDirectory
        let dbCopy = tmp.appendingPathComponent(dbEntryName)
        try? FileManager.default.removeItem(at: dbCopy)
        // GRDB 線上備份到乾淨的單檔，避免 -wal/-shm 不一致
        let dest = try DatabaseQueue(path: dbCopy.path)
        try db.dbQueue.backup(to: dest)

        let ts = timestamp()
        let zipURL = tmp.appendingPathComponent("POS備份-\(ts).zip")
        try? FileManager.default.removeItem(at: zipURL)
        guard let archive = Archive(url: zipURL, accessMode: .create) else { throw BackupError.archiveCreate }
        try archive.addEntry(with: dbEntryName, fileURL: dbCopy)
        try? FileManager.default.removeItem(at: dbCopy)
        return zipURL
    }

    /// 將現用資料庫備份寫入指定資料夾（自動備份 / 內部目錄使用）。
    @discardableResult
    static func exportZip(_ db: AppDatabase, toDirectory dir: URL) throws -> BackupEntry {
        let src = try exportZip(db)
        let ts = timestamp()
        let dest = dir.appendingPathComponent("POS備份-\(ts).zip")
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: src, to: dest)
        let mod = (try? dest.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
        return BackupEntry(url: dest, name: dest.lastPathComponent, modified: mod)
    }

    // MARK: - 匯入

    /// 從 zip 還原：解出 `pos_database` 後以 GRDB 線上備份覆蓋現用資料庫。
    /// 還原完成後 ValueObservation 會自動重新發佈，畫面即時更新。
    static func importZip(from url: URL, into db: AppDatabase) throws {
        let needsAccess = url.startAccessingSecurityScopedResource()
        defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }

        guard let archive = Archive(url: url, accessMode: .read) else { throw BackupError.archiveOpen }
        let entry = archive.first { $0.path == dbEntryName }
            ?? archive.first { $0.path.hasSuffix(dbEntryName) || $0.path.hasSuffix(".sqlite") || $0.path.hasSuffix(".db") }
        guard let dbEntry = entry else { throw BackupError.noDatabaseEntry }

        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("restore_\(UUID().uuidString)")
        try? FileManager.default.removeItem(at: tmp)
        _ = try archive.extract(dbEntry, to: tmp)

        let source = try DatabaseQueue(path: tmp.path)
        try source.backup(to: db.dbQueue)
        try? FileManager.default.removeItem(at: tmp)
    }

    // MARK: - 自動備份（App 內部目錄，含保留份數）

    static func autoBackupDirectory() -> URL {
        let docs = (try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask,
                                                 appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        let dir = docs.appendingPathComponent("auto_backup", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @discardableResult
    static func autoBackup(_ db: AppDatabase, keepLatest: Int = 5) throws -> BackupEntry {
        let entry = try exportZip(db, toDirectory: autoBackupDirectory())
        pruneAutoBackups(keepLatest: keepLatest)
        return entry
    }

    static func listAutoBackups() -> [BackupEntry] {
        let dir = autoBackupDirectory()
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        return urls
            .filter { $0.pathExtension.lowercased() == "zip" }
            .map { url in
                let mod = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return BackupEntry(url: url, name: url.lastPathComponent, modified: mod)
            }
            .sorted { $0.modified > $1.modified }
    }

    static func deleteAutoBackup(_ entry: BackupEntry) {
        try? FileManager.default.removeItem(at: entry.url)
    }

    private static func pruneAutoBackups(keepLatest: Int) {
        let all = listAutoBackups()
        guard all.count > keepLatest else { return }
        for entry in all.suffix(all.count - keepLatest) {
            try? FileManager.default.removeItem(at: entry.url)
        }
    }

    // MARK: -
    private static func timestamp() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyyMMdd-HHmmss"
        return f.string(from: Date())
    }
}

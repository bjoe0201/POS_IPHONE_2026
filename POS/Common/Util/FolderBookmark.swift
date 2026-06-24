import Foundation

/// 以 security-scoped bookmark 持久化使用者選定的資料夾（對應 Android SAF tree URI）。
/// bookmark data 以 base64 存進 SettingsStore.pdfPrinterTreeUri。
enum FolderBookmark {
    /// 由使用者選取的資料夾 URL 產生 bookmark base64 字串。
    static func makeToken(from url: URL) -> String? {
        let needsAccess = url.startAccessingSecurityScopedResource()
        defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? url.bookmarkData(options: .minimalBookmark,
                                               includingResourceValuesForKeys: nil,
                                               relativeTo: nil) else { return nil }
        return data.base64EncodedString()
    }

    /// 解析 token 取回資料夾 URL（呼叫端需自行 start/stop 存取）。
    static func resolve(_ token: String) -> URL? {
        guard !token.isEmpty, let data = Data(base64Encoded: token) else { return nil }
        var stale = false
        return try? URL(resolvingBookmarkData: data, options: [],
                        relativeTo: nil, bookmarkDataIsStale: &stale)
    }

    /// 在 token 指向的資料夾寫入一個檔案，best-effort。
    @discardableResult
    static func write(_ data: Data, filename: String, token: String) -> Bool {
        guard let dir = resolve(token) else { return false }
        let needsAccess = dir.startAccessingSecurityScopedResource()
        defer { if needsAccess { dir.stopAccessingSecurityScopedResource() } }
        let target = dir.appendingPathComponent(filename)
        do { try data.write(to: target); return true } catch { return false }
    }

    /// 顯示用簡短描述。
    static func describe(_ token: String) -> String {
        resolve(token)?.lastPathComponent ?? ""
    }
}

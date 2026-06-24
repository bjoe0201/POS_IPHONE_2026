import SwiftUI
import UIKit

/// 分享 / 匯出 / 列印工具。對應 Android 的 SAF CreateDocument + 列印。
enum Exporting {
    /// 將資料寫入暫存檔，回傳 URL（供分享 sheet 顯示正確檔名）。
    static func writeTemp(_ data: Data, filename: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do { try data.write(to: url); return url } catch { return nil }
    }

    /// 以 AirPrint 列印 PDF 資料（對應 Android USB 列印，iOS 改用 AirPrint）。
    static func printPDF(_ data: Data, jobName: String) {
        guard UIPrintInteractionController.isPrintingAvailable else { return }
        let info = UIPrintInfo(dictionary: nil)
        info.outputType = .general
        info.jobName = jobName
        let controller = UIPrintInteractionController.shared
        controller.printInfo = info
        controller.printingItem = data
        controller.present(animated: true, completionHandler: nil)
    }
}

/// UIActivityViewController 的 SwiftUI 包裝（用於 .sheet 分享 / 儲存到檔案 / 列印）。
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

import UIKit

/// 以 UIKit `UIGraphicsPDFRenderer` 將報表 / 收據渲染為 A4 PDF Data。
/// 對應 Android util/ReportPdfBuilder（PdfDocument）。
enum PdfReportBuilder {

    private static let pageW: CGFloat = 595   // A4 @72dpi
    private static let pageH: CGFloat = 842
    private static let margin: CGFloat = 40
    private static let lineH: CGFloat = 18
    private static let gap: CGFloat = 10

    /// 收據資料（對應 Android ReceiptData）。
    struct ReceiptData {
        let orderId: Int64
        let tableName: String
        let createdAt: Int64
        let remark: String
        let items: [(name: String, qty: Int, price: Double)]
        let total: Double
    }

    // MARK: - 報表 PDF
    /// 由 @MainActor 的 ReportViewModel 取值，故標記 @MainActor（只在畫面主執行緒呼叫）。
    @MainActor
    static func reportPDF(vm: ReportViewModel, includeDetails: Bool) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH))
        let dtf = DateFormatter(); dtf.dateFormat = "yyyy-MM-dd HH:mm"
        let (label, rangeStr) = vm.rangeText()

        return renderer.pdfData { ctx in
            let r = Pen(ctx: ctx, pageW: pageW, pageH: pageH, margin: margin, lineH: lineH, gap: gap)
            r.title("報表匯出")
            r.body("產生時間：\(dtf.string(from: Date()))")
            r.body("日期區間：\(label)（\(rangeStr)）")
            r.body("含已刪除：\(vm.showDeleted ? "是" : "否")")
            r.gap()

            r.section("總覽")
            r.row("總營業額", Formatters.money(vm.totalRevenue))
            r.row("總筆數", "\(vm.totalOrders) 筆")
            r.row("平均客單", Formatters.money(vm.avgOrderValue))
            r.gap()

            r.section("品項銷售排行")
            if vm.itemRanking.isEmpty { r.body("（無資料）") }
            else { for (i, it) in vm.itemRanking.enumerated() { r.row("\(i + 1). \(it.name)", "\(it.qty) 份") } }
            r.gap()

            r.section("群組銷售排行")
            if vm.groupRanking.isEmpty { r.body("（無資料）") }
            else { for (i, g) in vm.groupRanking.enumerated() {
                r.row("\(i + 1). \(g.groupName)（\(g.quantity)份）", Formatters.money(g.revenue))
            } }

            if includeDetails {
                r.gap(); r.section("訂單明細")
                for owi in vm.orders {
                    let o = owi.order
                    let tag = o.isDeleted ? "  【已刪除】" : ""
                    r.sub("#\(o.id ?? 0)  \(o.tableName)  \(dtf.string(from: DateBoundary.date(fromMillis: o.createdAt)))\(tag)")
                    for item in owi.items {
                        r.row("  \(item.name) × \(item.quantity)", Formatters.money(item.price * Double(item.quantity)))
                    }
                    r.row("  小計", Formatters.money(owi.total))
                    r.gap(4)
                }
            }
        }
    }

    // MARK: - 收據 PDF（M3 結帳使用）
    static func receiptPDF(_ data: ReceiptData) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH))
        let dtf = DateFormatter(); dtf.dateFormat = "yyyy-MM-dd HH:mm"
        return renderer.pdfData { ctx in
            let r = Pen(ctx: ctx, pageW: pageW, pageH: pageH, margin: margin, lineH: lineH, gap: gap)
            r.title("收款收據")
            r.body("訂單 #\(data.orderId)  \(data.tableName)")
            r.body("時間：\(dtf.string(from: DateBoundary.date(fromMillis: data.createdAt)))")
            if !data.remark.isEmpty { r.body("備註：\(data.remark)") }
            r.gap()
            r.section("品項明細")
            for it in data.items { r.row("  \(it.name) × \(it.qty)", Formatters.money(it.price * Double(it.qty))) }
            r.gap(4)
            r.row("合計", Formatters.money(data.total))
        }
    }

    /// 收據建議檔名（對應 Android receipt-yyyyMMdd-HHmmss-{orderId}-{tableName}.pdf）。
    static func receiptFilename(_ data: ReceiptData) -> String {
        let ts = DateFormatter(); ts.dateFormat = "yyyyMMdd-HHmmss"
        return "receipt-\(ts.string(from: Date()))-\(data.orderId)-\(sanitize(data.tableName)).pdf"
    }
    static func reportFilename() -> String {
        let ts = DateFormatter(); ts.dateFormat = "yyyyMMdd-HHmmss"
        return "report-\(ts.string(from: Date())).pdf"
    }
    private static func sanitize(_ s: String) -> String {
        s.replacingOccurrences(of: "[/\\\\:*?\"<>|]", with: "_", options: .regularExpression)
    }

    // MARK: - 渲染器（管理翻頁與語意化繪圖）
    private final class Pen {
        let ctx: UIGraphicsPDFRendererContext
        let pageW, pageH, margin, lineH, gap: CGFloat
        var y: CGFloat = 60

        init(ctx: UIGraphicsPDFRendererContext, pageW: CGFloat, pageH: CGFloat,
             margin: CGFloat, lineH: CGFloat, gap: CGFloat) {
            self.ctx = ctx; self.pageW = pageW; self.pageH = pageH
            self.margin = margin; self.lineH = lineH; self.gap = gap
            ctx.beginPage()
        }

        private func attrs(size: CGFloat, bold: Bool, color: UIColor = .black) -> [NSAttributedString.Key: Any] {
            [.font: bold ? UIFont.boldSystemFont(ofSize: size) : UIFont.systemFont(ofSize: size),
             .foregroundColor: color]
        }
        private func overflow(_ needed: CGFloat) {
            if y + needed > pageH - margin { ctx.beginPage(); y = 60 }
        }
        private func draw(_ text: String, x: CGFloat, _ a: [NSAttributedString.Key: Any]) {
            (text as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: a)
        }
        func title(_ t: String) { overflow(lineH + 8); draw(t, x: margin, attrs(size: 20, bold: true)); y += lineH + 8 }
        func section(_ t: String) { overflow(lineH + 4); draw("| \(t)", x: margin, attrs(size: 13, bold: true)); y += lineH + 4 }
        func sub(_ t: String) { overflow(lineH); draw(t, x: margin, attrs(size: 12, bold: true, color: .darkGray)); y += lineH }
        func body(_ t: String) { overflow(lineH); draw(t, x: margin, attrs(size: 11, bold: false)); y += lineH }
        func row(_ left: String, _ right: String) {
            overflow(lineH)
            let a = attrs(size: 11, bold: false)
            draw(left, x: margin, a)
            let w = (right as NSString).size(withAttributes: a).width
            draw(right, x: pageW - margin - w, a)
            y += lineH
        }
        func gap(_ extra: CGFloat = 10) { y += extra; overflow(lineH) }
    }
}

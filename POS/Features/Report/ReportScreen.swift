import SwiftUI

/// 報表。對應 Android ReportScreen，平板「左清單右圓餅」改為手機直式（清單在上、圓餅在下）。
struct ReportScreen: View {
    @StateObject private var vm: ReportViewModel
    let onGoSettings: () -> Void

    @State private var shareItem: ShareItem?
    @State private var pendingExport: ExportKind?
    @State private var showDetailChoice = false

    init(container: AppContainer, onGoSettings: @escaping () -> Void) {
        _vm = StateObject(wrappedValue: ReportViewModel(container: container))
        self.onGoSettings = onGoSettings
    }

    enum ExportKind { case print, csv, pdf }
    struct ShareItem: Identifiable { let id = UUID(); let url: URL }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "報表")
            filterBar
            Divider().background(Theme.border)
            content
        }
        .background(Theme.bg.ignoresSafeArea())
        .sheet(item: $shareItem) { item in ShareSheet(items: [item.url]) }
        .confirmationDialog("此區間資料較多", isPresented: $showDetailChoice, titleVisibility: .visible) {
            Button("列印明細") { runExport(includeDetails: true) }
            Button("只印總覽") { runExport(includeDetails: false) }
            Button("取消", role: .cancel) { pendingExport = nil }
        }
        .alert("提示", isPresented: Binding(get: { vm.message != nil }, set: { if !$0 { vm.clearMessage() } })) {
            Button("好") { vm.clearMessage() }
        } message: { Text(vm.message ?? "") }
    }

    // MARK: - 篩選列
    private var filterBar: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DateRange.quickOptions, id: \.self) { range in
                        chip(range.label, active: vm.dateRange == range) { vm.setDateRange(range) }
                    }
                    chip("自訂", active: vm.dateRange == .custom) { vm.setDateRange(.custom) }
                }
                .padding(.horizontal, 16)
            }
            if vm.dateRange == .custom { customDateRow }
            Toggle(isOn: Binding(get: { vm.showDeleted }, set: { _ in vm.toggleShowDeleted() })) {
                Text("顯示已刪除訂單").font(.system(size: 13)).foregroundColor(Theme.textSub)
            }
            .tint(Theme.accent)
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
        .background(Theme.surface)
    }

    private var customDateRow: some View {
        HStack(spacing: 8) {
            DatePicker("起", selection: Binding(
                get: { DateBoundary.date(fromMillis: vm.customStartDate ?? DateBoundary.todayStart()) },
                set: { vm.setCustomStart(DateBoundary.millis(from: $0)) }
            ), in: ...Date(), displayedComponents: .date).labelsHidden()
            Text("~").foregroundColor(Theme.textMuted)
            DatePicker("迄", selection: Binding(
                get: { DateBoundary.date(fromMillis: vm.customEndDate ?? DateBoundary.todayStart()) },
                set: { vm.setCustomEnd(DateBoundary.millis(from: $0)) }
            ), in: ...Date(), displayedComponents: .date).labelsHidden()
            Button("套用") { vm.applyCustomRange() }
                .font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Theme.accent).clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal, 16)
    }

    // MARK: - 內容
    private var content: some View {
        ScrollView {
            VStack(spacing: 12) {
                if !vm.openOrders.isEmpty {
                    Text("🔔 目前有 \(vm.openOrders.count) 桌尚未結帳，不列入報表統計")
                        .font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.error)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Theme.error.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                statCards
                rankingCard(title: "品項銷售排行",
                            rows: vm.itemRanking.map { ($0.name, "\($0.qty) 份", Double($0.qty)) })
                rankingCard(title: "群組銷售排行",
                            rows: vm.groupRanking.map { ($0.groupName, Formatters.money($0.revenue), $0.revenue) })
                orderDetailSection
                actionButtons
            }
            .padding(12)
        }
    }

    private var statCards: some View {
        HStack(spacing: 8) {
            statCard("總營業額", Formatters.money(vm.totalRevenue))
            statCard("總筆數", "\(vm.totalOrders) 筆")
            statCard("平均客單", Formatters.money(vm.avgOrderValue))
        }
    }

    private func statCard(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.system(size: 11)).foregroundColor(Theme.textMuted)
            Text(value).font(.system(size: 16, weight: .heavy)).foregroundColor(Theme.accent)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(Theme.card)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// 排行卡（清單在上、圓餅在下，對應手機直式）。
    private func rankingCard(title: String, rows: [(name: String, value: String, weight: Double)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 15, weight: .bold)).foregroundColor(Theme.text)
            if rows.isEmpty {
                Text("（無資料）").font(.system(size: 13)).foregroundColor(Theme.textMuted)
            } else {
                ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                    HStack(spacing: 8) {
                        Circle().fill(Theme.chartBars[idx % Theme.chartBars.count]).frame(width: 10, height: 10)
                        Text("\(idx + 1). \(row.name)").font(.system(size: 13)).foregroundColor(Theme.text)
                        Spacer()
                        Text(row.value).font(.system(size: 13, weight: .bold)).foregroundColor(Theme.accent)
                    }
                }
                PieChart(values: rows.map(\.weight), colors: Theme.chartBars)
                    .frame(height: 160)
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.card)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var orderDetailSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("訂單明細（\(vm.orders.count) 筆）")
                .font(.system(size: 15, weight: .bold)).foregroundColor(Theme.text)
            if vm.orders.isEmpty {
                Text("此期間無資料").font(.system(size: 13)).foregroundColor(Theme.textMuted)
            } else {
                ForEach(vm.orders) { owi in OrderDetailRow(owi: owi, vm: vm) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            actionButton("🖨 列印", filled: true) { trigger(.print) }
            actionButton("匯出CSV", filled: false) { trigger(.csv) }
            actionButton("匯出PDF", filled: false) { trigger(.pdf) }
        }
        .padding(.top, 4)
    }

    private func actionButton(_ label: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(.system(size: 14, weight: .bold))
                .foregroundColor(filled ? .white : Theme.accent)
                .frame(maxWidth: .infinity).padding(.vertical, 10)
                .background(filled ? Theme.accent : Color.clear)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.accent, lineWidth: filled ? 0 : 1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(vm.orders.isEmpty)
    }

    private func chip(_ label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: active ? .bold : .regular))
                .foregroundColor(active ? .white : Theme.textSub)
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(active ? Theme.accent : Theme.card)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(active ? Theme.accent : Theme.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }

    // MARK: - 匯出流程
    private func trigger(_ kind: ExportKind) {
        guard !vm.orders.isEmpty else { vm.message = "此期間無資料"; return }
        pendingExport = kind
        if vm.shouldConfirmDetail { showDetailChoice = true }
        else { runExport(includeDetails: true) }
    }

    private func runExport(includeDetails: Bool) {
        guard let kind = pendingExport else { return }
        pendingExport = nil
        switch kind {
        case .print:
            let data = PdfReportBuilder.reportPDF(vm: vm, includeDetails: includeDetails)
            Exporting.printPDF(data, jobName: "報表")
        case .pdf:
            let data = PdfReportBuilder.reportPDF(vm: vm, includeDetails: includeDetails)
            if let url = Exporting.writeTemp(data, filename: PdfReportBuilder.reportFilename()) {
                shareItem = ShareItem(url: url)
            }
        case .csv:
            let csv = vm.buildCsv(includeDetails: includeDetails)
            // UTF-8 BOM 讓 Excel 開啟中文不亂碼
            var data = Data([0xEF, 0xBB, 0xBF]); data.append(Data(csv.utf8))
            let ts = DateFormatter(); ts.dateFormat = "yyyyMMdd-HHmmss"
            if let url = Exporting.writeTemp(data, filename: "report-\(ts.string(from: Date())).csv") {
                shareItem = ShareItem(url: url)
            }
        }
    }
}

// MARK: - 訂單明細列（可展開 + 軟刪除）

private struct OrderDetailRow: View {
    let owi: OrderWithItems
    @ObservedObject var vm: ReportViewModel
    @State private var expanded = false
    private let dtf: DateFormatter = { let f = DateFormatter(); f.dateFormat = "MM/dd HH:mm"; return f }()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button { withAnimation { expanded.toggle() } } label: {
                    HStack(spacing: 6) {
                        Image(systemName: expanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 11)).foregroundColor(Theme.textMuted)
                        Text("#\(owi.order.id ?? 0) \(owi.order.tableName)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(owi.order.isDeleted ? Theme.textMuted : Theme.text)
                            .strikethrough(owi.order.isDeleted)
                        Text(dtf.string(from: DateBoundary.date(fromMillis: owi.order.createdAt)))
                            .font(.system(size: 11)).foregroundColor(Theme.textMuted)
                    }
                }
                .buttonStyle(.plain)
                Spacer()
                Text(Formatters.money(owi.total)).font(.system(size: 14, weight: .bold)).foregroundColor(Theme.accent)
                Button {
                    if owi.order.isDeleted { vm.restoreOrder(owi.order.id ?? 0) }
                    else { vm.softDeleteOrder(owi.order.id ?? 0) }
                } label: {
                    Image(systemName: owi.order.isDeleted ? "arrow.uturn.backward" : "trash")
                        .foregroundColor(owi.order.isDeleted ? Theme.occupied : Theme.error)
                }
                .buttonStyle(.plain)
            }
            if expanded {
                ForEach(owi.items) { item in
                    HStack {
                        Text("　\(item.name) × \(item.quantity)").font(.system(size: 12)).foregroundColor(Theme.textSub)
                        Spacer()
                        Text(Formatters.money(item.lineTotal)).font(.system(size: 12)).foregroundColor(Theme.textSub)
                    }
                }
            }
        }
        .padding(10)
        .background(Theme.card)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

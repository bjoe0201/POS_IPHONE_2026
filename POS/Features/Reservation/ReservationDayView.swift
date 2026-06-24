import SwiftUI

private let TIME_COL_W: CGFloat = 44
private let TABLE_COL_W: CGFloat = 84
private let HOUR_H: CGFloat = 60
private let HEADER_H: CGFloat = 36

private let importanceColors = [Color(rgb: 0x4CAF50), Color(rgb: 0xFFC107), Color(rgb: 0xF44336)]

/// 當日時段格線。對應 Android ReservationDayScreen。
/// 手機版以「點空格新增 / 點方塊編輯」取代拖曳換桌（編輯對話框可改桌次與時間）。
struct ReservationDayView: View {
    @ObservedObject var vm: ReservationViewModel
    @State private var editorConfig: EditorConfig?
    private let cal = Calendar.current

    private var date: Date { vm.selectedDate ?? Date() }
    private var bizStartMin: Int { RTime.toMinutes(vm.bizStart) }
    private var bizEndMin: Int { RTime.toMinutes(vm.bizEnd) }
    private var hours: [String] {
        var result: [String] = []
        var cur = bizStartMin
        while cur < bizEndMin { result.append(RTime.toString(cur)); cur += 60 }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider().background(Theme.border)
            if vm.activeTables.isEmpty {
                VStack { Spacer()
                    Text("尚無啟用中的桌次，請先至「桌號設定」新增")
                        .foregroundColor(Theme.textMuted).font(.system(size: 14))
                    Spacer() }
            } else {
                gridScroll
            }
        }
        .sheet(item: $editorConfig) { cfg in
            ReservationEditor(
                initial: cfg.reservation,
                date: date,
                defaultTableId: cfg.tableId,
                defaultStartTime: cfg.startTime,
                defaultDuration: vm.defaultDuration,
                tables: vm.activeTables,
                onSave: { vm.upsert($0) },
                onDelete: { vm.delete($0) }
            )
        }
    }

    private var topBar: some View {
        HStack {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 2).fill(Theme.accent).frame(width: 4, height: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(dateTitle).font(.system(size: 16, weight: .bold)).foregroundColor(Theme.text)
                    Text("點空格新增、點方塊編輯").font(.system(size: 11)).foregroundColor(Theme.textMuted)
                }
            }
            Spacer()
            Button("← 返回") { vm.clearSelectedDate() }
                .font(.system(size: 13)).foregroundColor(Theme.textSub)
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(Theme.topbar)
    }

    private var dateTitle: String {
        let y = cal.component(.year, from: date)
        let m = cal.component(.month, from: date)
        let d = cal.component(.day, from: date)
        let dow = ["日","一","二","三","四","五","六"][cal.component(.weekday, from: date) - 1]
        return "\(y) 年 \(m) 月 \(d) 日（\(dow)）"
    }

    private var gridScroll: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                // 表頭：桌名
                HStack(spacing: 0) {
                    Color.clear.frame(width: TIME_COL_W, height: HEADER_H)
                    ForEach(vm.activeTables) { tbl in
                        Text(tbl.tableName)
                            .font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.text)
                            .lineLimit(1)
                            .frame(width: TABLE_COL_W, height: HEADER_H)
                    }
                }
                .background(Theme.surface)
                Divider().background(Theme.border)

                // 內容：時間列 + 各桌欄
                HStack(alignment: .top, spacing: 0) {
                    timeColumn
                    ForEach(vm.activeTables) { tbl in
                        tableColumn(tbl)
                    }
                }
            }
        }
    }

    private var timeColumn: some View {
        VStack(spacing: 0) {
            ForEach(hours, id: \.self) { hour in
                Text(hour)
                    .font(.system(size: 10)).foregroundColor(Theme.textMuted)
                    .frame(width: TIME_COL_W, height: HOUR_H, alignment: .top)
                    .padding(.top, 2)
                    .border(Theme.border, width: 0.5)
            }
        }
        .background(Theme.surface)
    }

    private func tableColumn(_ tbl: DiningTable) -> some View {
        let breakStartMin = vm.breakStart.isEmpty ? -1 : RTime.toMinutes(vm.breakStart)
        let breakEndMin = vm.breakEnd.isEmpty ? -1 : RTime.toMinutes(vm.breakEnd)
        let tblRes = vm.dayReservations.filter { $0.tableId == tbl.id }
        return ZStack(alignment: .topLeading) {
            // 背景小時格（點擊新增）
            VStack(spacing: 0) {
                ForEach(hours, id: \.self) { hour in
                    let hourMin = RTime.toMinutes(hour)
                    let isBreak = breakStartMin >= 0 && breakEndMin >= 0 && hourMin >= breakStartMin && hourMin < breakEndMin
                    Rectangle()
                        .fill(isBreak ? Theme.border.opacity(0.4) : Theme.bg)
                        .frame(width: TABLE_COL_W, height: HOUR_H)
                        .border(Theme.border, width: 0.5)
                        .onTapGesture {
                            if !isBreak { editorConfig = EditorConfig(reservation: nil, tableId: tbl.id ?? 0, startTime: hour) }
                        }
                }
            }
            // 訂位方塊
            ForEach(tblRes) { res in
                reservationBlock(res)
            }
        }
        .frame(width: TABLE_COL_W)
    }

    private func reservationBlock(_ res: Reservation) -> some View {
        let startMin = RTime.toMinutes(res.startTime)
        let endMin = max(RTime.toMinutes(res.endTime), startMin + 15)
        let top = CGFloat(startMin - bizStartMin) / 60 * HOUR_H
        let height = max(CGFloat(endMin - startMin) / 60 * HOUR_H, 22)
        let color = importanceColors[min(max(res.importance, 0), 2)]
        return VStack(alignment: .leading, spacing: 1) {
            Text(res.guestName).font(.system(size: 11, weight: .bold)).foregroundColor(.white).lineLimit(1)
            if height > 36 {
                Text("\(res.startTime)–\(res.endTime)").font(.system(size: 9)).foregroundColor(.white.opacity(0.9)).lineLimit(1)
            }
        }
        .padding(4)
        .frame(width: TABLE_COL_W - 4, height: height - 4, alignment: .topLeading)
        .background(color.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .offset(x: 2, y: top + 2)
        .onTapGesture {
            editorConfig = EditorConfig(reservation: res, tableId: res.tableId, startTime: res.startTime)
        }
    }
}

/// 編輯器設定（sheet item）。
struct EditorConfig: Identifiable {
    let id = UUID()
    let reservation: Reservation?
    let tableId: Int64
    let startTime: String
}

import SwiftUI

/// 月曆總覽。對應 Android ReservationCalendarScreen。
struct ReservationCalendarView: View {
    @ObservedObject var vm: ReservationViewModel
    private let dowLabels = ["日", "一", "二", "三", "四", "五", "六"]
    private let cal = Calendar.current

    var body: some View {
        VStack(spacing: 0) {
            header
            dowHeader
            grid
        }
    }

    private var header: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(Theme.accent).frame(width: 4, height: 24)
            Text("訂位管理").font(.system(size: 16, weight: .bold)).foregroundColor(Theme.text)
            Spacer()
            Button("今天") { vm.goToToday() }
                .foregroundColor(vm.isCurrentMonth ? Color(rgb: 0xFDD835) : Theme.textMuted)
                .font(.system(size: 14, weight: .bold))
            Button("<") { vm.prevMonth() }.foregroundColor(Theme.accent).font(.system(size: 16, weight: .bold))
            Text("\(String(vm.year)) 年 \(vm.month) 月")
                .font(.system(size: 15, weight: .semibold)).foregroundColor(Theme.text)
                .frame(minWidth: 96)
            Button(">") { vm.nextMonth() }.foregroundColor(Theme.accent).font(.system(size: 16, weight: .bold))
        }
        .padding(.horizontal, 12)
        .frame(height: 56)
        .background(Theme.topbar)
    }

    private var dowHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array(dowLabels.enumerated()), id: \.offset) { idx, label in
                Text(label)
                    .frame(maxWidth: .infinity)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(idx == 0 ? Theme.error : (idx == 6 ? Theme.accent : Theme.textMuted))
            }
        }
        .padding(.vertical, 6)
        .background(Theme.surface)
    }

    private var grid: some View {
        let cells = monthCells()
        let weeks = stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<min($0 + 7, cells.count)]) }
        return VStack(spacing: 2) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 2) {
                    ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                        if let day {
                            DayCell(vm: vm, day: day)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
            }
        }
        .padding(2)
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 40).onEnded { value in
            if value.translation.width > 60 { vm.prevMonth() }
            else if value.translation.width < -60 { vm.nextMonth() }
        })
    }

    /// 產生月曆格子（前置空白 + 1...天數）。Sunday=0 對齊。
    private func monthCells() -> [Int?] {
        var comps = DateComponents(); comps.year = vm.year; comps.month = vm.month; comps.day = 1
        guard let first = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: first) else { return [] }
        let weekday = cal.component(.weekday, from: first) // 1=Sun
        let offset = weekday - 1
        var cells: [Int?] = Array(repeating: nil, count: offset)
        cells.append(contentsOf: (1...range.count).map { Optional($0) })
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }
}

private struct DayCell: View {
    @ObservedObject var vm: ReservationViewModel
    let day: Int
    private let cal = Calendar.current

    private var date: Date {
        var c = DateComponents(); c.year = vm.year; c.month = vm.month; c.day = day
        return cal.date(from: c) ?? Date()
    }
    private var isToday: Bool { cal.isDateInToday(date) }
    private var isSunday: Bool { cal.component(.weekday, from: date) == 1 }
    private var dayString: String { vm.dateString(date) }
    private var dayReservations: [Reservation] { vm.monthReservations.filter { $0.date == dayString } }

    var body: some View {
        let usedTables = Set(dayReservations.map(\.tableId)).count
        let total = vm.activeTables.count
        VStack(spacing: 2) {
            HStack {
                Text("\(day)")
                    .font(.system(size: 11, weight: isToday ? .bold : .regular))
                    .foregroundColor(isToday ? .white : (isSunday ? Theme.error : Theme.text))
                    .frame(width: 22, height: 22)
                    .background(isToday ? Theme.accent : Color.clear)
                    .clipShape(Circle())
                Spacer()
                Text("\(usedTables)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(usedTables == 0 ? Theme.textMuted : .white)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(usageColor(used: usedTables, total: total))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            // 時段摘要（依開始時間彙總桌數）
            VStack(spacing: 2) {
                ForEach(timeSlots(), id: \.time) { slot in
                    HStack(spacing: 1) {
                        Text(slot.time)
                            .font(.system(size: 7)).foregroundColor(Theme.text)
                            .lineLimit(1)
                            .padding(.horizontal, 3).padding(.vertical, 1)
                            .background(Color(rgb: 0x3D5A80).opacity(0.32))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                        Text("\(slot.count)")
                            .font(.system(size: 7)).foregroundColor(.white)
                            .padding(.horizontal, 3).padding(.vertical, 1)
                            .background(Color(rgb: 0x2A9D8F).opacity(0.86))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
        }
        .padding(3)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(isToday ? Theme.accentDim2 : Theme.card)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(isToday ? Theme.accent : Theme.border, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .onTapGesture { vm.selectDate(date) }
    }

    private func usageColor(used: Int, total: Int) -> Color {
        guard used > 0, total > 0 else { return Theme.textMuted.opacity(0.45) }
        let rate = Double(used) / Double(total)
        if rate < 0.6 { return Color(rgb: 0x2E7D32) }
        if rate < 0.8 { return Color(rgb: 0xF9A825) }
        return Color(rgb: 0xC62828)
    }

    private struct Slot { let time: String; let count: Int }
    private func timeSlots() -> [Slot] {
        Dictionary(grouping: dayReservations, by: { $0.startTime })
            .map { Slot(time: $0.key, count: Set($0.value.map(\.tableId)).count) }
            .sorted { $0.time < $1.time }
    }
}

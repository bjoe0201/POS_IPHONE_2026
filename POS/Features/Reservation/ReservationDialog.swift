import SwiftUI

/// 新增 / 編輯訂位。對應 Android ReservationDialog。
struct ReservationEditor: View {
    let initial: Reservation?
    let date: Date
    let defaultTableId: Int64
    let defaultStartTime: String
    let defaultDuration: Int
    let tables: [DiningTable]
    let onSave: (Reservation) -> Void
    let onDelete: (Reservation) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var guestName: String
    @State private var guestPhone: String
    @State private var guestCount: String
    @State private var remark: String
    @State private var importance: Int
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var selectedTableId: Int64
    @State private var showDeleteConfirm = false

    private let importanceLabels = ["一般", "重要", "非常重要"]
    private let importanceColors = [Color(rgb: 0x4CAF50), Color(rgb: 0xFFC107), Color(rgb: 0xF44336)]
    private let cal = Calendar.current

    init(initial: Reservation?, date: Date, defaultTableId: Int64, defaultStartTime: String,
         defaultDuration: Int, tables: [DiningTable],
         onSave: @escaping (Reservation) -> Void, onDelete: @escaping (Reservation) -> Void) {
        self.initial = initial
        self.date = date
        self.defaultTableId = defaultTableId
        self.defaultStartTime = defaultStartTime
        self.defaultDuration = defaultDuration
        self.tables = tables
        self.onSave = onSave
        self.onDelete = onDelete

        _guestName = State(initialValue: initial?.guestName ?? "")
        _guestPhone = State(initialValue: initial?.guestPhone ?? "")
        _guestCount = State(initialValue: (initial?.guestCount ?? 0) == 0 ? "" : String(initial!.guestCount))
        _remark = State(initialValue: initial?.remark ?? "")
        _importance = State(initialValue: initial?.importance ?? 0)
        let start = initial?.startTime ?? defaultStartTime
        let end = initial?.endTime ?? RTime.add(start, defaultDuration)
        _startTime = State(initialValue: ReservationEditor.dateFor(time: start, on: date))
        _endTime = State(initialValue: ReservationEditor.dateFor(time: end, on: date))
        _selectedTableId = State(initialValue: initial?.tableId ?? defaultTableId)
    }

    private var isNew: Bool { initial == nil }
    private var canSave: Bool {
        !guestName.trimmingCharacters(in: .whitespaces).isEmpty
        && !guestPhone.trimmingCharacters(in: .whitespaces).isEmpty
        && tables.contains { $0.id == selectedTableId }
    }

    var body: some View {
        NavigationView {
            Form {
                Section("客人") {
                    TextField("姓名 *", text: $guestName)
                    TextField("電話 *", text: $guestPhone).keyboardType(.phonePad)
                    TextField("人數（選填）", text: $guestCount).keyboardType(.numberPad)
                }
                Section("桌次與時間") {
                    Picker("桌次", selection: $selectedTableId) {
                        ForEach(tables) { tbl in Text(tbl.tableName).tag(tbl.id ?? -1) }
                    }
                    DatePicker("開始", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("結束", selection: $endTime, displayedComponents: .hourAndMinute)
                }
                Section("重要性") {
                    Picker("重要性", selection: $importance) {
                        ForEach(0..<importanceLabels.count, id: \.self) { i in
                            Text(importanceLabels[i]).tag(i)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("備註") {
                    // iOS 15 無 TextField(axis:)，改用 TextEditor 呈現多行備註。
                    TextEditor(text: $remark).frame(minHeight: 60)
                }
                if !isNew {
                    Section {
                        Button("刪除訂位", role: .destructive) { showDeleteConfirm = true }
                    }
                }
            }
            .navigationTitle(isNew ? "新增訂位" : "編輯訂位")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "新增" : "儲存") { save() }.disabled(!canSave)
                }
            }
            .alert("確認刪除訂位", isPresented: $showDeleteConfirm) {
                Button("確定刪除", role: .destructive) {
                    if let initial { onDelete(initial) }
                    dismiss()
                }
                Button("取消", role: .cancel) {}
            } message: {
                if let initial {
                    Text("確定刪除 \(initial.guestName) 的訂位（\(initial.tableName) \(initial.startTime)）？")
                }
            }
        }
    }

    private func save() {
        guard let tbl = tables.first(where: { $0.id == selectedTableId }), let tid = tbl.id else { return }
        let dateStr = String(format: "%04d-%02d-%02d",
                             cal.component(.year, from: date),
                             cal.component(.month, from: date),
                             cal.component(.day, from: date))
        let reservation = Reservation(
            id: initial?.id,
            tableId: tid,
            tableName: tbl.tableName,
            guestName: guestName.trimmingCharacters(in: .whitespaces),
            guestPhone: guestPhone.trimmingCharacters(in: .whitespaces),
            guestCount: Int(guestCount) ?? 0,
            date: initial?.date ?? dateStr,
            startTime: Self.timeString(from: startTime),
            endTime: Self.timeString(from: endTime),
            importance: importance,
            remark: remark.trimmingCharacters(in: .whitespaces),
            createdAt: initial?.createdAt ?? Date.nowMillis
        )
        onSave(reservation)
        dismiss()
    }

    private static func dateFor(time: String, on day: Date) -> Date {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: day)
        comps.hour = RTime.toMinutes(time) / 60
        comps.minute = RTime.toMinutes(time) % 60
        return cal.date(from: comps) ?? day
    }
    private static func timeString(from date: Date) -> String {
        let cal = Calendar.current
        return String(format: "%02d:%02d", cal.component(.hour, from: date), cal.component(.minute, from: date))
    }
}

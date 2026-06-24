import SwiftUI

/// 桌號設定。對應 Android TableSettingScreen。
struct TableSettingScreen: View {
    @StateObject private var vm: TableSettingViewModel

    @State private var editingTable: DiningTable?
    @State private var showEditor = false

    init(container: AppContainer) {
        _vm = StateObject(wrappedValue: TableSettingViewModel(container: container))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "桌號設定") {
                Button {
                    editingTable = nil; showEditor = true
                } label: {
                    Image(systemName: "plus.circle.fill").font(.system(size: 22)).foregroundColor(Theme.accent)
                }
            }

            if vm.tables.isEmpty {
                VStack { Spacer(); Text("尚無桌號，點右上角新增").foregroundColor(Theme.textMuted); Spacer() }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(vm.tables.enumerated()), id: \.element.id) { index, table in
                            TableRow(
                                table: table,
                                isFirst: index == 0,
                                isLast: index == vm.tables.count - 1,
                                onToggle: { vm.toggleActive(table) },
                                onEdit: { editingTable = table; showEditor = true },
                                onDelete: { vm.deleteTable(table) },
                                onUp: { vm.moveTableUp(table) },
                                onDown: { vm.moveTableDown(table) }
                            )
                        }
                    }
                    .padding(12)
                }
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .sheet(isPresented: $showEditor) {
            TableEditor(editing: editingTable) { name, seats, remark in
                vm.saveTable(name: name, seats: seats, remark: remark, editing: editingTable)
                showEditor = false
            }
        }
    }
}

private struct TableRow: View {
    let table: DiningTable
    let isFirst: Bool
    let isLast: Bool
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onUp: () -> Void
    let onDown: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(spacing: 2) {
                Button(action: onUp) { Image(systemName: "chevron.up") }
                    .disabled(isFirst).foregroundColor(isFirst ? Theme.textMuted : Theme.textSub)
                Button(action: onDown) { Image(systemName: "chevron.down") }
                    .disabled(isLast).foregroundColor(isLast ? Theme.textMuted : Theme.textSub)
            }
            .font(.system(size: 12)).buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(table.tableName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(table.isActive ? Theme.text : Theme.textMuted)
                HStack(spacing: 8) {
                    if let seats = table.seats { Text("\(seats) 人桌").font(.system(size: 12)).foregroundColor(Theme.textMuted) }
                    if let remark = table.remark, !remark.isEmpty {
                        Text(remark).font(.system(size: 12)).foregroundColor(Theme.textMuted).lineLimit(1)
                    }
                }
            }
            Spacer()

            Toggle("", isOn: Binding(get: { table.isActive }, set: { _ in onToggle() }))
                .labelsHidden().tint(Theme.occupied)
            Button(action: onEdit) { Image(systemName: "pencil").foregroundColor(Theme.textSub) }.buttonStyle(.plain)
            Button(action: onDelete) { Image(systemName: "trash").foregroundColor(Theme.error) }.buttonStyle(.plain)
        }
        .padding(12)
        .background(Theme.card)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct TableEditor: View {
    let editing: DiningTable?
    let onSave: (String, Int?, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var seatsText: String
    @State private var remark: String

    init(editing: DiningTable?, onSave: @escaping (String, Int?, String?) -> Void) {
        self.editing = editing
        self.onSave = onSave
        _name = State(initialValue: editing?.tableName ?? "")
        _seatsText = State(initialValue: editing?.seats.map(String.init) ?? "")
        _remark = State(initialValue: editing?.remark ?? "")
    }

    private var canSave: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && trimmed.count <= 20
    }

    var body: some View {
        NavigationView {
            Form {
                Section("桌號") {
                    TextField("名稱（最多 20 字）", text: $name)
                    TextField("座位數（選填）", text: $seatsText).keyboardType(.numberPad)
                    TextField("備註（選填）", text: $remark)
                }
            }
            .navigationTitle(editing == nil ? "新增桌號" : "編輯桌號")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        onSave(name.trimmingCharacters(in: .whitespaces),
                               Int(seatsText),
                               remark.trimmingCharacters(in: .whitespaces))
                    }.disabled(!canSave)
                }
            }
        }
    }
}

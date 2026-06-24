import SwiftUI

/// 菜單管理。對應 Android MenuManagementScreen。
struct MenuManagementScreen: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject private var vm: MenuManagementViewModel

    @State private var editingItem: MenuItem?
    @State private var showItemEditor = false
    @State private var showGroupManager = false

    init(container: AppContainer) {
        _vm = StateObject(wrappedValue: MenuManagementViewModel(container: container))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "菜單管理") {
                HStack(spacing: 12) {
                    Button("群組") { showGroupManager = true }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.accent)
                    Button {
                        editingItem = nil; showItemEditor = true
                    } label: {
                        Image(systemName: "plus.circle.fill").font(.system(size: 22)).foregroundColor(Theme.accent)
                    }
                }
            }

            categoryChips
            Divider().background(Theme.border)
            itemList
        }
        .background(Theme.bg.ignoresSafeArea())
        .sheet(isPresented: $showItemEditor) {
            MenuItemEditor(groups: vm.groups,
                           defaultCategory: vm.selectedCategory,
                           editing: editingItem) { name, price, category in
                vm.saveItem(name: name, price: price, category: category, editing: editingItem)
                showItemEditor = false
            }
        }
        .sheet(isPresented: $showGroupManager) {
            GroupManagerSheet(vm: vm)
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(vm.groups) { group in
                    let active = vm.selectedCategory == group.code
                    Text(group.name)
                        .font(.system(size: 13, weight: active ? .bold : .regular))
                        .foregroundColor(active ? .white : Theme.textSub)
                        .padding(.horizontal, 16).padding(.vertical, 6)
                        .background(active ? Theme.accent : Theme.card)
                        .overlay(RoundedRectangle(cornerRadius: 20)
                            .stroke(active ? Theme.accent : Theme.border, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .onTapGesture { vm.selectCategory(group.code) }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
        }
        .background(Theme.surface)
    }

    private var itemList: some View {
        Group {
            if vm.filteredItems.isEmpty {
                VStack { Spacer(); Text("此分類尚無品項").foregroundColor(Theme.textMuted); Spacer() }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(vm.filteredItems.enumerated()), id: \.element.id) { index, item in
                            MenuItemRow(
                                item: item,
                                isFirst: index == 0,
                                isLast: index == vm.filteredItems.count - 1,
                                onToggle: { vm.toggleAvailability(item) },
                                onEdit: { editingItem = item; showItemEditor = true },
                                onDelete: { vm.deleteItem(item) },
                                onUp: { vm.moveItemUp(item) },
                                onDown: { vm.moveItemDown(item) }
                            )
                        }
                    }
                    .padding(12)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 品項列

private struct MenuItemRow: View {
    let item: MenuItem
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
            .font(.system(size: 12))
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(item.isAvailable ? Theme.text : Theme.textMuted)
                    .strikethrough(!item.isAvailable)
                Text(Formatters.money(item.price))
                    .font(.system(size: 13, weight: .bold)).foregroundColor(Theme.accent)
            }
            Spacer()

            Toggle("", isOn: Binding(get: { item.isAvailable }, set: { _ in onToggle() }))
                .labelsHidden()
                .tint(Theme.occupied)

            Button(action: onEdit) { Image(systemName: "pencil").foregroundColor(Theme.textSub) }
                .buttonStyle(.plain)
            Button(action: onDelete) { Image(systemName: "trash").foregroundColor(Theme.error) }
                .buttonStyle(.plain)
        }
        .padding(12)
        .background(Theme.card)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - 品項編輯器

private struct MenuItemEditor: View {
    let groups: [MenuGroup]
    let defaultCategory: String
    let editing: MenuItem?
    let onSave: (String, Double, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var priceText: String
    @State private var category: String

    init(groups: [MenuGroup], defaultCategory: String, editing: MenuItem?,
         onSave: @escaping (String, Double, String) -> Void) {
        self.groups = groups
        self.defaultCategory = defaultCategory
        self.editing = editing
        self.onSave = onSave
        _name = State(initialValue: editing?.name ?? "")
        _priceText = State(initialValue: editing.map { String(Int($0.price)) } ?? "")
        _category = State(initialValue: editing?.category ?? defaultCategory)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (Double(priceText) ?? -1) >= 0
    }

    var body: some View {
        NavigationView {
            Form {
                Section("品項") {
                    TextField("名稱", text: $name)
                    TextField("價格", text: $priceText).keyboardType(.numberPad)
                    Picker("分類", selection: $category) {
                        ForEach(groups) { g in Text(g.name).tag(g.code) }
                    }
                }
            }
            .navigationTitle(editing == nil ? "新增品項" : "編輯品項")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        onSave(name.trimmingCharacters(in: .whitespaces), Double(priceText) ?? 0, category)
                    }.disabled(!canSave)
                }
            }
        }
    }
}

// MARK: - 群組管理

private struct GroupManagerSheet: View {
    @ObservedObject var vm: MenuManagementViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showGroupEditor = false
    @State private var editingGroup: MenuGroup?

    var body: some View {
        NavigationView {
            List {
                ForEach(Array(vm.groups.enumerated()), id: \.element.code) { index, group in
                    HStack(spacing: 10) {
                        VStack(spacing: 2) {
                            Button { vm.moveGroupUp(group) } label: { Image(systemName: "chevron.up") }
                                .disabled(index == 0)
                            Button { vm.moveGroupDown(group) } label: { Image(systemName: "chevron.down") }
                                .disabled(index == vm.groups.count - 1)
                        }
                        .font(.system(size: 12)).buttonStyle(.plain).foregroundColor(Theme.textSub)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(group.name).font(.system(size: 15, weight: .medium)).foregroundColor(Theme.text)
                            Text(group.code).font(.system(size: 11)).foregroundColor(Theme.textMuted)
                        }
                        Spacer()
                        Button { editingGroup = group; showGroupEditor = true } label: {
                            Image(systemName: "pencil").foregroundColor(Theme.textSub)
                        }.buttonStyle(.plain)
                        Button { vm.deleteGroup(group) } label: {
                            Image(systemName: "trash").foregroundColor(Theme.error)
                        }.buttonStyle(.plain)
                    }
                    .listRowBackground(Theme.card)
                }
            }
            .navigationTitle("群組管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("關閉") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button { editingGroup = nil; showGroupEditor = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showGroupEditor) {
                GroupEditor(editing: editingGroup) { code, name in
                    let (ok, _) = vm.saveGroup(code: code, name: name, editing: editingGroup)
                    return ok
                }
            }
        }
    }
}

private struct GroupEditor: View {
    let editing: MenuGroup?
    /// 回傳是否儲存成功（失敗時保留對話框）。
    let onSave: (String, String) -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var code: String
    @State private var name: String
    @State private var error: String?

    init(editing: MenuGroup?, onSave: @escaping (String, String) -> Bool) {
        self.editing = editing
        self.onSave = onSave
        _code = State(initialValue: editing?.code ?? "")
        _name = State(initialValue: editing?.name ?? "")
    }

    var body: some View {
        NavigationView {
            Form {
                Section("群組") {
                    if editing == nil {
                        TextField("代碼（英文，如 DESSERT）", text: $code)
                            .autocapitalization(.allCharacters)
                    } else {
                        HStack { Text("代碼"); Spacer(); Text(editing?.code ?? "").foregroundColor(.secondary) }
                    }
                    TextField("名稱", text: $name)
                }
                if let error { Text(error).foregroundColor(.red).font(.footnote) }
            }
            .navigationTitle(editing == nil ? "新增群組" : "編輯群組")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        if onSave(code, name) { dismiss() }
                        else { error = "代碼/名稱不可空白或重複" }
                    }
                }
            }
        }
    }
}

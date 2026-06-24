import Foundation
import Combine

/// 對應 Android MenuManagementViewModel。
@MainActor
final class MenuManagementViewModel: ObservableObject {
    @Published private(set) var groups: [MenuGroup] = []
    @Published private(set) var allItems: [MenuItem] = []
    @Published var selectedCategory: String = "MEAT"

    private let menuRepo: MenuRepository
    private let groupRepo: MenuGroupRepository
    private var cancellables = Set<AnyCancellable>()

    init(container: AppContainer) {
        self.menuRepo = container.menuRepository
        self.groupRepo = container.menuGroupRepository

        groupRepo.allGroupsPublisher()
            .replaceError(with: [])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] groups in
                guard let self else { return }
                let category = groups.contains(where: { $0.code == self.selectedCategory })
                    ? self.selectedCategory
                    : (groups.first?.code ?? "")
                self.groups = groups
                self.selectedCategory = category
            }
            .store(in: &cancellables)

        menuRepo.allItemsPublisher()
            .replaceError(with: [])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in self?.allItems = items }
            .store(in: &cancellables)
    }

    /// 目前分類的品項，依 sortOrder、name 排序。
    var filteredItems: [MenuItem] {
        allItems
            .filter { $0.category == selectedCategory }
            .sorted { ($0.sortOrder, $0.name) < ($1.sortOrder, $1.name) }
    }

    func selectCategory(_ code: String) { selectedCategory = code }

    // MARK: - 品項

    func saveItem(name: String, price: Double, category: String, editing: MenuItem?) {
        do {
            if var item = editing {
                item.name = name; item.price = price; item.category = category
                try menuRepo.update(item)
            } else {
                try menuRepo.insert(MenuItem(id: nil, name: name, price: price, category: category))
            }
        } catch { }
    }

    func deleteItem(_ item: MenuItem) { try? menuRepo.delete(item) }

    func toggleAvailability(_ item: MenuItem) {
        guard let id = item.id else { return }
        try? menuRepo.setAvailability(id: id, available: !item.isAvailable)
    }

    func moveItemUp(_ item: MenuItem) {
        let items = filteredItems
        guard let idx = items.firstIndex(where: { $0.id == item.id }), idx > 0 else { return }
        reorderItems(items, from: idx, to: idx - 1)
    }

    func moveItemDown(_ item: MenuItem) {
        let items = filteredItems
        guard let idx = items.firstIndex(where: { $0.id == item.id }), idx < items.count - 1 else { return }
        reorderItems(items, from: idx, to: idx + 1)
    }

    private func reorderItems(_ items: [MenuItem], from: Int, to: Int) {
        var reordered = items
        let moving = reordered.remove(at: from)
        reordered.insert(moving, at: to)
        for (index, var menuItem) in reordered.enumerated() {
            let newOrder = index + 1
            if menuItem.sortOrder != newOrder {
                menuItem.sortOrder = newOrder
                try? menuRepo.update(menuItem)
            }
        }
    }

    // MARK: - 群組

    /// 回傳 (成功, 錯誤訊息)。
    @discardableResult
    func saveGroup(code: String, name: String, editing: MenuGroup?) -> (Bool, String?) {
        let normalizedCode = code.trimmingCharacters(in: .whitespaces).uppercased()
        let normalizedName = name.trimmingCharacters(in: .whitespaces)
        let duplicate = groups.contains { $0.code == normalizedCode && $0.code != editing?.code }

        if normalizedName.isEmpty { return (false, "群組名稱不可空白") }
        if editing == nil && normalizedCode.isEmpty { return (false, "群組代碼不可空白") }
        if editing == nil && duplicate { return (false, "群組代碼不可重複") }

        do {
            if var group = editing {
                group.name = normalizedName
                try groupRepo.update(group)
            } else {
                let maxOrder = groups.map(\.sortOrder).max() ?? 0
                try groupRepo.insert(MenuGroup(code: normalizedCode, name: normalizedName,
                                               sortOrder: maxOrder + 1, isActive: true))
                if selectedCategory.isEmpty { selectedCategory = normalizedCode }
            }
            return (true, nil)
        } catch {
            return (false, "儲存失敗：\(error.localizedDescription)")
        }
    }

    func deleteGroup(_ group: MenuGroup) { try? groupRepo.delete(group) }

    func moveGroupUp(_ group: MenuGroup) {
        guard let idx = groups.firstIndex(where: { $0.code == group.code }), idx > 0 else { return }
        reorderGroups(from: idx, to: idx - 1)
    }

    func moveGroupDown(_ group: MenuGroup) {
        guard let idx = groups.firstIndex(where: { $0.code == group.code }), idx < groups.count - 1 else { return }
        reorderGroups(from: idx, to: idx + 1)
    }

    private func reorderGroups(from: Int, to: Int) {
        var reordered = groups
        let moving = reordered.remove(at: from)
        reordered.insert(moving, at: to)
        for (index, var group) in reordered.enumerated() {
            let newOrder = index + 1
            if group.sortOrder != newOrder {
                group.sortOrder = newOrder
                try? groupRepo.update(group)
            }
        }
    }
}

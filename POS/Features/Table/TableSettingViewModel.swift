import Foundation
import Combine

/// 對應 Android TableSettingViewModel。
@MainActor
final class TableSettingViewModel: ObservableObject {
    @Published private(set) var tables: [DiningTable] = []

    private let tableRepo: TableRepository
    private var cancellables = Set<AnyCancellable>()

    init(container: AppContainer) {
        self.tableRepo = container.tableRepository
        tableRepo.allTablesPublisher()
            .replaceError(with: [])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tables in self?.tables = tables }
            .store(in: &cancellables)
    }

    func saveTable(name: String, seats: Int?, remark: String?, editing: DiningTable?) {
        let cleanRemark = (remark?.isEmpty == true) ? nil : remark
        do {
            if var table = editing {
                table.tableName = name; table.seats = seats; table.remark = cleanRemark
                try tableRepo.update(table)
            } else {
                let maxOrder = tables.map(\.sortOrder).max() ?? 0
                try tableRepo.insert(DiningTable(id: nil, tableName: name, seats: seats,
                                                 remark: cleanRemark, sortOrder: maxOrder + 1))
            }
        } catch { }
    }

    func deleteTable(_ table: DiningTable) { try? tableRepo.delete(table) }

    func toggleActive(_ table: DiningTable) {
        guard let id = table.id else { return }
        try? tableRepo.setActive(id: id, active: !table.isActive)
    }

    func moveTableUp(_ table: DiningTable) {
        guard let idx = tables.firstIndex(where: { $0.id == table.id }), idx > 0 else { return }
        reorder(from: idx, to: idx - 1)
    }

    func moveTableDown(_ table: DiningTable) {
        guard let idx = tables.firstIndex(where: { $0.id == table.id }), idx < tables.count - 1 else { return }
        reorder(from: idx, to: idx + 1)
    }

    private func reorder(from: Int, to: Int) {
        var reordered = tables
        let moving = reordered.remove(at: from)
        reordered.insert(moving, at: to)
        for (index, var table) in reordered.enumerated() {
            let newOrder = index + 1
            if table.sortOrder != newOrder {
                table.sortOrder = newOrder
                try? tableRepo.update(table)
            }
        }
    }
}

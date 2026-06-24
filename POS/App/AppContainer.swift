import Foundation
import Combine

/// 輕量手動 DI 容器，取代 Android Hilt。
/// 持有資料庫、各 repository 與設定，於 App 啟動時建立並注入環境。
final class AppContainer: ObservableObject {
    let database: AppDatabase
    let settings: SettingsStore
    let thermalPrinter: ThermalPrinterManager

    let menuGroupRepository: MenuGroupRepository
    let menuRepository: MenuRepository
    let orderRepository: OrderRepository
    let reservationRepository: ReservationRepository
    let tableRepository: TableRepository

    init() {
        // 資料庫初始化失敗屬不可恢復錯誤，直接 crash（與 Room build() 失敗行為一致）。
        let db: AppDatabase
        do {
            db = try AppDatabase()
        } catch {
            fatalError("無法開啟資料庫：\(error)")
        }
        self.database = db
        self.settings = SettingsStore()
        self.thermalPrinter = ThermalPrinterManager()

        let queue = db.dbQueue
        self.menuGroupRepository = MenuGroupRepository(dbQueue: queue)
        self.menuRepository = MenuRepository(dbQueue: queue)
        self.orderRepository = OrderRepository(dbQueue: queue)
        self.reservationRepository = ReservationRepository(dbQueue: queue)
        self.tableRepository = TableRepository(dbQueue: queue)

        // 啟動清理：取消因異常中斷產生的孤兒空訂單（對應 Android 啟動流程）。
        try? orderRepository.cancelEmptyOpenOrders()
    }
}

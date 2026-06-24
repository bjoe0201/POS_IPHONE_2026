import Foundation
import CoreBluetooth
import Combine

/// 芯烨 XP-Q90EC 熱感印表機（藍牙 BLE + 文字模式）管理器。
/// 封裝 `XYPrinterBridge`（Objective-C 薄橋接 → XYSDK 的 XYBLEManager）。
/// 回呼皆已由橋接層切回主執行緒，故此處 @Published 更新安全。
final class ThermalPrinterManager: NSObject, ObservableObject {

    enum State: Equatable { case idle, scanning, connecting, connected }

    struct Device: Identifiable, Equatable {
        let id: String      // CBPeripheral.identifier.uuidString
        let name: String
        let rssi: Int
    }

    @Published private(set) var devices: [Device] = []
    @Published private(set) var state: State = .idle
    @Published private(set) var connectedId: String?
    @Published var statusMessage: String?

    private let bridge = XYPrinterBridge.shared()
    private var peripheralsById: [String: CBPeripheral] = [:]

    private let defaults = UserDefaults.standard
    private enum K {
        static let savedId = "thermal_printer_id"
        static let savedName = "thermal_printer_name"
    }

    var savedId: String? { defaults.string(forKey: K.savedId) }
    var savedName: String? { defaults.string(forKey: K.savedName) }
    var isConnected: Bool { connectedId != nil }

    override init() {
        super.init()
        bridge.delegate = self
    }

    // MARK: - 操作

    func startScan() {
        statusMessage = nil
        state = .scanning
        bridge.startScan()
    }

    func stopScan() {
        bridge.stopScan()
        if state == .scanning { state = isConnected ? .connected : .idle }
    }

    func connect(_ device: Device) {
        guard let peripheral = peripheralsById[device.id] else { return }
        state = .connecting
        statusMessage = "連線中…"
        bridge.connect(peripheral)
    }

    func disconnect() {
        bridge.disconnect()
    }

    /// 忘記已記住的裝置（並斷線）。
    func forget() {
        disconnect()
        defaults.removeObject(forKey: K.savedId)
        defaults.removeObject(forKey: K.savedName)
        connectedId = nil
    }

    /// 若已記住的裝置出現在掃描清單中且尚未連線，嘗試自動重連。
    func reconnectSavedIfAvailable() {
        guard !isConnected, let id = savedId, let peripheral = peripheralsById[id] else { return }
        state = .connecting
        bridge.connect(peripheral)
    }

    /// 送出測試列印（P1：ASCII，先驗證能否成功列印；中文留待 P2）。
    func printTest() {
        guard isConnected else { statusMessage = "尚未連線印表機"; return }
        bridge.write(EscPos.testReceipt())
        statusMessage = "已送出測試列印"
    }

    /// 送出已組好的 ESC/POS 指令資料。
    func send(_ data: Data) {
        bridge.write(data)
    }
}

extension ThermalPrinterManager: XYPrinterBridgeDelegate {

    func xyBridgeDidUpdateDevices(_ peripherals: [CBPeripheral], rssi: [NSNumber]) {
        var list: [Device] = []
        for (i, p) in peripherals.enumerated() {
            let id = p.identifier.uuidString
            peripheralsById[id] = p
            let r = i < rssi.count ? rssi[i].intValue : 0
            let name = (p.name?.isEmpty == false) ? p.name! : "未命名裝置"
            list.append(Device(id: id, name: name, rssi: r))
        }
        devices = list
    }

    func xyBridgeDidConnect(_ peripheral: CBPeripheral) {
        let id = peripheral.identifier.uuidString
        connectedId = id
        state = .connected
        let name = peripheral.name ?? "印表機"
        statusMessage = "已連線：\(name)"
        defaults.set(id, forKey: K.savedId)
        defaults.set(name, forKey: K.savedName)
    }

    func xyBridgeDidFail(toConnect peripheral: CBPeripheral, error: Error?) {
        connectedId = nil
        state = .idle
        statusMessage = "連線失敗：\(error?.localizedDescription ?? "未知錯誤")"
    }

    func xyBridgeDidDisconnect(_ peripheral: CBPeripheral) {
        if connectedId == peripheral.identifier.uuidString { connectedId = nil }
        state = .idle
        statusMessage = "已斷線"
    }

    func xyBridgeDidWriteWithError(_ error: Error?) {
        if let error = error { statusMessage = "列印失敗：\(error.localizedDescription)" }
    }
}

/// ESC/POS 文字指令組裝（透過 XYSDK 的 XYCommand 類）。
enum EscPos {
    static func testReceipt() -> Data {
        var d = Data()
        append(&d, XYCommand.initializePrinter())
        append(&d, XYCommand.selectAlignment(1))         // 置中
        append(&d, XYCommand.selectCharacterSize(0x11))   // 倍寬倍高
        d.appendText("POS TEST\n")
        append(&d, XYCommand.selectCharacterSize(0x00))   // 標準大小
        d.appendText("------------------------\n")
        append(&d, XYCommand.selectAlignment(0))         // 靠左
        d.appendText("Printer : XP-Q90EC\n")
        d.appendText("Mode    : BLE / Text\n")
        d.appendText("Numbers : 0123456789\n")
        d.appendText("Amount  : $1,234\n")
        d.appendText("------------------------\n")
        append(&d, XYCommand.selectAlignment(1))
        d.appendText("OK\n\n\n\n")
        return d
    }

    private static func append(_ d: inout Data, _ part: Data?) {
        if let part = part { d.append(part) }
    }
}

private extension Data {
    mutating func appendText(_ text: String) {
        if let bytes = text.data(using: .ascii) { append(bytes) }
    }
}

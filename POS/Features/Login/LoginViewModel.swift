import Foundation
import Combine

/// 對應 Android LoginViewModel。PIN 4 碼自動驗證、錯誤 3 次鎖定 30 秒。
@MainActor
final class LoginViewModel: ObservableObject {
    @Published private(set) var pin: String = ""
    @Published private(set) var isError: Bool = false
    @Published private(set) var failCount: Int = 0
    @Published private(set) var isLockedOut: Bool = false
    @Published private(set) var lockoutSecondsLeft: Int = 0

    /// 觸發畫面震動動畫用：每次驗證失敗 +1。
    @Published private(set) var shakeTrigger: Int = 0

    private let settings: SettingsStore
    private var lockoutTask: Task<Void, Never>?

    init(settings: SettingsStore) {
        self.settings = settings
    }

    var isDefaultPin: Bool { settings.isDefaultPin }

    func onDigit(_ digit: String) {
        guard !isLockedOut, pin.count < 4 else { return }
        pin += digit
        isError = false
    }

    func onBackspace() {
        guard !isLockedOut, !pin.isEmpty else { return }
        pin.removeLast()
        isError = false
    }

    func onClear() {
        pin = ""
        isError = false
    }

    /// 對應 Android verifyPin。輸入滿 4 碼時由畫面呼叫。
    func verify(onSuccess: () -> Void) {
        guard !isLockedOut, pin.count >= 4 else { return }
        if settings.verifyPin(pin) {
            pin = ""
            isError = false
            failCount = 0
            onSuccess()
        } else {
            let newFail = failCount + 1
            shakeTrigger += 1
            if newFail >= 3 {
                startLockout()
            } else {
                pin = ""
                isError = true
                failCount = newFail
            }
        }
    }

    private func startLockout() {
        pin = ""
        isError = false
        isLockedOut = true
        lockoutSecondsLeft = 30
        failCount = 0
        lockoutTask?.cancel()
        lockoutTask = Task { [weak self] in
            for elapsed in 0..<30 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                await MainActor.run { self?.lockoutSecondsLeft = 30 - elapsed - 1 }
            }
            await MainActor.run {
                self?.isLockedOut = false
                self?.lockoutSecondsLeft = 0
            }
        }
    }
}

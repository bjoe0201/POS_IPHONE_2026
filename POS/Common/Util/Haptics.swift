import UIKit

/// 觸覺回饋封裝，對應 Android LocalHapticFeedback。受設定 hapticEnabled 控制。
enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let success = UINotificationFeedbackGenerator()

    /// 對應 HapticFeedbackType.TextHandleMove（輕量點擊回饋）。
    static func tick(_ enabled: Bool) {
        guard enabled else { return }
        light.impactOccurred()
    }

    /// 對應 HapticFeedbackType.LongPress（進入連續模式較強回饋）。
    static func longPress(_ enabled: Bool) {
        guard enabled else { return }
        medium.impactOccurred()
    }

    /// 收款成功回饋。
    static func paymentSuccess(_ enabled: Bool = true) {
        guard enabled else { return }
        success.notificationOccurred(.success)
    }
}

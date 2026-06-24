import AudioToolbox

/// 音效封裝，對應 Android util/SoundEffects。
/// 第一版使用系統內建提示音；之後可換成 bundle 內自訂收款音效。
enum SoundEffects {
    /// 收款成功提示音。
    static func playPaymentSuccess() {
        // 1407 = 系統「Payment Success / Tweet」類提示音；無資產相依。
        AudioServicesPlaySystemSound(1407)
    }
}

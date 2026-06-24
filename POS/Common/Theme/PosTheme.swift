import SwiftUI

extension Color {
    /// 由 0xRRGGBB 整數建立顏色，可選 alpha。
    init(rgb: UInt32, alpha: Double = 1.0) {
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

/// 對應 Android PosColors（深夜煉獄 dark-red 主題）。
/// App 為單一深色主題，故以靜態命名空間提供，等同 Android 的 DefaultPosColors。
enum Theme {
    static let bg          = Color(rgb: 0x0D0D16)
    static let surface     = Color(rgb: 0x16162A)
    static let card        = Color(rgb: 0x1E1E35)
    static let cardHover   = Color(rgb: 0x252542)
    static let border      = Color(rgb: 0x2A2A48)
    static let topbar      = Color(rgb: 0x0A0A12)
    static let accent      = Color(rgb: 0xC62828)
    static let accentHov   = Color(rgb: 0xEF5350)
    static let accentDim   = Color(rgb: 0xC62828, alpha: 0x26 / 255.0)
    static let accentDim2  = Color(rgb: 0xC62828, alpha: 0x40 / 255.0)
    static let text        = Color(rgb: 0xF0F0FA)
    static let textSub     = Color(rgb: 0x9090B8)
    static let textMuted   = Color(rgb: 0x555580)
    static let occupied    = Color(rgb: 0x2E7D32)
    static let occupiedBg  = Color(rgb: 0x2E7D32, alpha: 0x26 / 255.0)
    static let success     = Color(rgb: 0x43A047)
    static let warning     = Color(rgb: 0xF9A825)
    static let error       = Color(rgb: 0xE53935)

    /// 報表圓餅圖 / 排行色點配色（對應 PosColors.chartBars）。
    static let chartBars: [Color] = [
        Color(rgb: 0xC62828), Color(rgb: 0xEF5350), Color(rgb: 0xFF8A80),
        Color(rgb: 0xFFCDD2), Color(rgb: 0xB71C1C)
    ]
}

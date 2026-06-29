import SwiftUI

/// 可長按連續觸發的按鈕，對應 Android RepeatableQtyButton / MenuCard 的長按邏輯。
/// - 按下立即觸發一次（onTrigger）+ 輕觸覺。
/// - 持續按住超過 initialDelayMs 後，以 intervalMs 間隔反覆觸發直到放開。
struct RepeatableButton<Label: View>: View {
    let intervalMs: Int
    let initialDelayMs: Int
    let hapticEnabled: Bool
    let onTrigger: () -> Void
    var onPressStart: () -> Void = {}
    var onPressEnd: () -> Void = {}
    @ViewBuilder var label: () -> Label

    @State private var pressing = false
    @State private var repeatTask: Task<Void, Never>?

    var body: some View {
        label()
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !pressing {
                            pressing = true
                            startPress()
                        }
                    }
                    .onEnded { _ in endPress() }
            )
            // 若按鈕在按住中被移出畫面（例如數量歸 0 後「−／＋」按鈕消失），
            // DragGesture 的 onEnded 不會觸發，repeatTask 會永遠跑下去造成持續振動與
            // 連續呼叫 onTrigger。這裡在 onDisappear 強制結束按壓並取消任務。
            .onDisappear { endPress() }
    }

    private func startPress() {
        onPressStart()
        Haptics.tick(hapticEnabled)
        onTrigger()
        repeatTask?.cancel()
        repeatTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(max(initialDelayMs, 0)) * 1_000_000)
            if Task.isCancelled { return }
            Haptics.longPress(hapticEnabled)
            var count = 0
            while !Task.isCancelled {
                onTrigger()
                count += 1
                if hapticEnabled && count % 5 == 0 { Haptics.tick(true) }
                try? await Task.sleep(nanoseconds: UInt64(max(intervalMs, 1)) * 1_000_000)
            }
        }
    }

    private func endPress() {
        repeatTask?.cancel()
        repeatTask = nil
        pressing = false
        onPressEnd()
    }
}

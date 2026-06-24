import SwiftUI

/// 對應 Android LoginScreen。
struct LoginView: View {
    @EnvironmentObject private var settings: SettingsStore
    @StateObject private var vm: LoginViewModel
    let onLoginSuccess: () -> Void

    @State private var shakeOffset: CGFloat = 0

    init(settings: SettingsStore, onLoginSuccess: @escaping () -> Void) {
        _vm = StateObject(wrappedValue: LoginViewModel(settings: settings))
        self.onLoginSuccess = onLoginSuccess
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            // 背景暈光
            GeometryReader { geo in
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [Theme.accentDim, .clear],
                                             center: .topLeading,
                                             startRadius: 0,
                                             endRadius: geo.size.width * 0.7))
                    Circle()
                        .fill(RadialGradient(colors: [Theme.accentDim, .clear],
                                             center: .bottomTrailing,
                                             startRadius: 0,
                                             endRadius: geo.size.width * 0.7))
                }
            }
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    logo
                    pinCard
                }
                .frame(maxWidth: 520)
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 56)
                .frame(maxWidth: .infinity)
            }

            VStack {
                Spacer()
                Text(AppInfo.versionLabel)
                    .font(.footnote)
                    .foregroundColor(Theme.textMuted)
                    .padding(.bottom, 8)
            }
        }
        .onChange(of: vm.pin) { newValue in
            if newValue.count == 4 { vm.verify(onSuccess: onLoginSuccess) }
        }
        .onChange(of: vm.shakeTrigger) { _ in
            withAnimation(.default) { shakeOffset = 0 }
            // 簡易左右抖動
            let keyframes: [CGFloat] = [-8, 8, -6, 6, 0]
            for (i, dx) in keyframes.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08 * Double(i)) {
                    withAnimation(.linear(duration: 0.08)) { shakeOffset = dx }
                }
            }
        }
    }

    private var logo: some View {
        VStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.accentDim2)
                .frame(width: 72, height: 72)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.accent, lineWidth: 2))
                .overlay(Text("🍲").font(.system(size: 32)))
            VStack(spacing: 6) {
                Text("火鍋店 POS 系統")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundColor(Theme.text)
                Text("餐飲管理系統")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textMuted)
            }
        }
    }

    private var pinCard: some View {
        VStack(spacing: 24) {
            VStack(spacing: 18) {
                Text("請輸入 PIN 碼")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textSub)

                HStack(spacing: 16) {
                    ForEach(0..<4, id: \.self) { i in
                        let filled = i < vm.pin.count
                        Circle()
                            .fill(dotColor(filled: filled))
                            .frame(width: 16, height: 16)
                    }
                }
                .offset(x: shakeOffset)

                statusMessage
                    .frame(minHeight: 32)
            }

            PinPad(locked: vm.isLockedOut,
                   onDigit: { vm.onDigit($0) },
                   onBackspace: { vm.onBackspace() },
                   onClear: { vm.onClear() })
        }
        .padding(28)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Theme.border, lineWidth: 1))
    }

    private func dotColor(filled: Bool) -> Color {
        if vm.isError && filled { return Theme.error }
        if filled { return Theme.accent }
        return Theme.border
    }

    @ViewBuilder
    private var statusMessage: some View {
        if vm.isLockedOut {
            Text("🔒 鎖定中，請等待 \(vm.lockoutSecondsLeft) 秒")
                .font(.system(size: 13))
                .foregroundColor(Theme.error)
                .padding(.horizontal, 16).padding(.vertical, 6)
                .background(Theme.error.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else if vm.isError {
            Text("PIN 碼錯誤，還剩 \(3 - vm.failCount) 次機會")
                .font(.system(size: 13))
                .foregroundColor(Theme.error)
        } else if vm.isDefaultPin {
            Text("目前使用預設密碼 1234，請至設定修改")
                .font(.system(size: 12))
                .foregroundColor(Theme.warning)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14).padding(.vertical, 5)
                .background(Theme.warning.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

/// 數字鍵盤，對應 Android PinPad / PinKey。
private struct PinPad: View {
    let locked: Bool
    let onDigit: (String) -> Void
    let onBackspace: () -> Void
    let onClear: () -> Void

    private let rows = [["1","2","3"], ["4","5","6"], ["7","8","9"], ["C","0","←"]]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { key in
                        PinKey(label: key, special: key == "C" || key == "←", disabled: locked) {
                            switch key {
                            case "←": onBackspace()
                            case "C": onClear()
                            default: onDigit(key)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: 320)
    }
}

private struct PinKey: View {
    let label: String
    let special: Bool
    let disabled: Bool
    let onClick: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: {
            guard !disabled else { return }
            withAnimation(.easeOut(duration: 0.06)) { pressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.easeOut(duration: 0.08)) { pressed = false }
            }
            onClick()
        }) {
            Text(label)
                .font(.system(size: special ? 20 : 22, weight: .bold))
                .foregroundColor(foreground)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(special ? Theme.error.opacity(0.4) : Theme.border, lineWidth: 1))
                .scaleEffect(pressed ? 0.94 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private var foreground: Color {
        if disabled { return Theme.textMuted }
        return special ? Theme.error : Theme.text
    }
    private var background: Color {
        if disabled { return special ? Theme.error.opacity(0.08) : Theme.surface.opacity(0.5) }
        return special ? Theme.error.opacity(0.15) : Theme.surface
    }
}

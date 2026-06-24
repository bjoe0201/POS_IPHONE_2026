import SwiftUI

/// 記帳點餐。對應 Android OrderScreen，版面由平板並排改為 iPhone 直式：
/// 桌號列 + 分類 Tab + 菜單格（捲動）+ 底部結帳列；訂單明細以 sheet 呈現。
struct OrderScreen: View {
    @StateObject private var vm: OrderViewModel
    let onGoSettings: () -> Void

    @State private var showDetail = false
    @State private var showCheckout = false
    @State private var showCancel = false
    @State private var showDatePicker = false
    @State private var lastCheckout: (name: String, total: Double)?

    init(container: AppContainer, onGoSettings: @escaping () -> Void) {
        _vm = StateObject(wrappedValue: OrderViewModel(container: container))
        self.onGoSettings = onGoSettings
    }

    private var isToday: Bool { vm.selectedDate == DateBoundary.todayStart() }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            if vm.isBackfillMode { backfillBanner }
            tableSelector
            Divider().background(Theme.border)
            categoryChips
            Divider().background(Theme.border)
            menuGrid
            checkoutBar
        }
        .background(Theme.bg.ignoresSafeArea())
        // 補登確認
        .alert("⚠️ 補登模式確認", isPresented: Binding(
            get: { vm.backfillPrompt != nil },
            set: { if !$0 { vm.cancelBackfill() } }
        )) {
            Button("確認補登", role: .destructive) { vm.confirmBackfill() }
            Button("取消", role: .cancel) { vm.cancelBackfill() }
        } message: {
            Text("您正在補登 \(vm.backfillPrompt ?? "") 的訂單。\n此訂單將記錄為該日期，今日報表看不到它。\n確認繼續補登？")
        }
        // 取消訂單
        .alert("取消訂單", isPresented: $showCancel) {
            Button("確定取消訂單", role: .destructive) { vm.cancelOrder() }
            Button("返回", role: .cancel) {}
        } message: {
            Text("確定取消 \(vm.selectedTable?.tableName ?? "") 的全部點餐？\n⚠️ 此操作無法復原，訂單將從報表中消失。")
        }
        // 訂單明細
        .sheet(isPresented: $showDetail) {
            OrderDetailSheet(vm: vm,
                             onCheckout: { showDetail = false; showCheckout = true },
                             onCancelOrder: { showDetail = false; showCancel = true })
        }
        // 結帳
        .sheet(isPresented: $showCheckout) {
            CheckoutSheet(vm: vm, isToday: isToday) {
                vm.payOrder { result in
                    lastCheckout = (result.tableName, result.total)
                    SoundEffects.playPaymentSuccess()
                    Haptics.paymentSuccess(vm.hapticEnabled)
                    showCheckout = false
                    // PDF 收據 / AirPrint 將於 M6 / M7 接上（pdfPrinterEnabled / printCheckoutEnabled）。
                }
            }
        }
        // 日期選擇
        .sheet(isPresented: $showDatePicker) {
            DatePickerSheet(selectedDate: vm.selectedDate) { millis in
                vm.updateSelectedDate(millis)
                showDatePicker = false
            } onToday: {
                vm.updateSelectedDate(Date.nowMillis)
                showDatePicker = false
            } onDismiss: {
                showDatePicker = false
            }
        }
    }

    // MARK: - 頂列
    private var topBar: some View {
        HStack {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2).fill(Theme.accent).frame(width: 4, height: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text("記帳點餐").font(.system(size: 16, weight: .bold)).foregroundColor(Theme.text)
                    Text("火鍋店 POS").font(.system(size: 10)).foregroundColor(Theme.textMuted)
                }
                if vm.openCount > 0 {
                    Text("🔔 \(vm.openCount) 桌未結帳")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Theme.error)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Theme.error.opacity(0.18))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.error.opacity(0.4), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            Spacer()
            if let lc = lastCheckout {
                Text("✓ \(lc.name) \(Formatters.money(lc.total))")
                    .font(.system(size: 12)).foregroundColor(Theme.success)
                    .lineLimit(1)
            }
            Button(action: { showDatePicker = true }) {
                Text(isToday ? "今天" : DateBoundary.mmdd(vm.selectedDate))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isToday ? Theme.textSub : Theme.error)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .background(Theme.topbar)
    }

    private var backfillBanner: some View {
        HStack {
            Text("⚠️ 補登模式：\(DateBoundary.mmdd(vm.selectedDate))　今日報表不計入")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.error)
            Spacer()
            Button("回到今天") { vm.resetToToday() }
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Theme.accent)
        }
        .padding(.horizontal, 16).padding(.vertical, 6)
        .background(Theme.error.opacity(0.13))
        .overlay(Rectangle().stroke(Theme.error.opacity(0.35), lineWidth: 1))
    }

    // MARK: - 桌號列
    private var tableSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Text("桌號").font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.textMuted)
                ForEach(vm.tables) { table in
                    let sel = table.id == vm.selectedTable?.id
                    let tableTotal = table.id.flatMap { vm.openOrderTotals[$0] } ?? 0
                    let occ = tableTotal > 0
                    VStack(spacing: 2) {
                        Text(table.tableName)
                            .font(.system(size: 13, weight: sel ? .bold : .semibold))
                            .foregroundColor(sel ? .white : (occ ? Theme.occupied : Theme.textSub))
                        if occ {
                            Text(Formatters.money(tableTotal))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(sel ? .white.opacity(0.85) : Theme.occupied)
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(sel ? Theme.accent : (occ ? Theme.occupiedBg : Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(sel ? Theme.accent : (occ ? Theme.occupied : Theme.border), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .onTapGesture { vm.selectTable(table) }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
        }
        .background(Theme.surface)
    }

    // MARK: - 分類
    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(vm.groups) { group in
                    let active = vm.selectedCategory == group.code
                    Text(group.name)
                        .font(.system(size: 13, weight: active ? .bold : .regular))
                        .foregroundColor(active ? .white : Theme.textSub)
                        .padding(.horizontal, 16).padding(.vertical, 6)
                        .background(active ? Theme.accent : Theme.card)
                        .overlay(RoundedRectangle(cornerRadius: 20)
                            .stroke(active ? Theme.accent : Theme.border, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .onTapGesture { vm.selectCategory(group.code) }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
        }
        .background(Theme.bg)
    }

    // MARK: - 菜單格
    private var menuGrid: some View {
        Group {
            if vm.menuItems.isEmpty {
                VStack {
                    Spacer()
                    Text("此分類目前沒有可用品項").foregroundColor(Theme.textMuted).font(.system(size: 14))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                        ForEach(vm.menuItems) { item in
                            MenuCard(
                                item: item,
                                qty: vm.quantityInOrder(menuItemId: item.id ?? -1),
                                intervalMs: vm.qtyRepeatIntervalMs,
                                initialDelayMs: vm.qtyRepeatInitialDelayMs,
                                hapticEnabled: vm.hapticEnabled,
                                onAdd: { vm.addItem(item) },
                                onRemove: { vm.removeItem(item) }
                            )
                        }
                    }
                    .padding(10)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 底部結帳列
    private var checkoutBar: some View {
        HStack(spacing: 12) {
            Button(action: { showDetail = true }) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(vm.selectedTable?.tableName ?? "尚未選桌")
                        .font(.system(size: 13, weight: .bold)).foregroundColor(Theme.text)
                    Text("\(vm.orderItems.count) 項 \(vm.itemCount) 件　明細 ›")
                        .font(.system(size: 11)).foregroundColor(Theme.textMuted)
                }
            }
            Spacer()
            Text(Formatters.money(vm.total))
                .font(.system(size: 22, weight: .heavy)).foregroundColor(Theme.accent)
            Button(action: { showCheckout = true }) {
                Text("結帳 →")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(vm.orderItems.isEmpty ? Theme.border : Theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(vm.orderItems.isEmpty || vm.selectedTable == nil)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Theme.surface)
    }
}

// MARK: - 菜單卡

private struct MenuCard: View {
    let item: MenuItem
    let qty: Int
    let intervalMs: Int
    let initialDelayMs: Int
    let hapticEnabled: Bool
    let onAdd: () -> Void
    let onRemove: () -> Void

    @State private var bubbleVisible = false
    @State private var bubbleIsPlus = true
    @State private var hideTask: Task<Void, Never>?

    private var active: Bool { qty > 0 }

    var body: some View {
        VStack(spacing: 6) {
            // 上半部：按下加入（可長按連續）
            RepeatableButton(intervalMs: intervalMs,
                             initialDelayMs: initialDelayMs,
                             hapticEnabled: hapticEnabled,
                             onTrigger: onAdd,
                             onPressStart: { showBubble(plus: true) },
                             onPressEnd: { scheduleHide() }) {
                VStack(spacing: 4) {
                    Text(item.name)
                        .font(.system(size: 14, weight: active ? .bold : .medium))
                        .foregroundColor(active ? Theme.accent : Theme.text)
                        .lineLimit(2).multilineTextAlignment(.center)
                    Text(Formatters.money(item.price))
                        .font(.system(size: 13, weight: .heavy)).foregroundColor(Theme.accent)
                }
                .frame(maxWidth: .infinity)
            }

            if active {
                HStack(spacing: 8) {
                    qtyButton(label: "−", plus: false, onTrigger: onRemove)
                    Text("\(qty)")
                        .font(.system(size: 16, weight: .heavy)).foregroundColor(Theme.accent)
                        .frame(minWidth: 24)
                    qtyButton(label: "+", plus: true, onTrigger: onAdd)
                }
            } else {
                Text("點選加入").font(.system(size: 11)).foregroundColor(Theme.textMuted)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(active ? Theme.accentDim : Theme.card)
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(active ? Theme.accent : Theme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .top) { if bubbleVisible { bubble } }
        .onChange(of: qty) { newQty in
            if newQty <= 0 { hideTask?.cancel(); bubbleVisible = false }
        }
    }

    private func qtyButton(label: String, plus: Bool, onTrigger: @escaping () -> Void) -> some View {
        let fg = plus ? Color(rgb: 0xFFC400) : Color(rgb: 0x00C853)
        let bg = (plus ? Color(rgb: 0xFFD600) : Color(rgb: 0x00E676)).opacity(0.18)
        return RepeatableButton(intervalMs: intervalMs,
                                initialDelayMs: initialDelayMs,
                                hapticEnabled: hapticEnabled,
                                onTrigger: onTrigger,
                                onPressStart: { showBubble(plus: plus) },
                                onPressEnd: { scheduleHide() }) {
            Text(label)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(fg)
                .frame(width: 30, height: 30)
                .background(bg)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(fg.opacity(0.55), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private var bubble: some View {
        HStack(spacing: 6) {
            Text(bubbleIsPlus ? "+" : "−").font(.system(size: 18, weight: .heavy)).foregroundColor(.white)
            Text("\(qty)").font(.system(size: 24, weight: .heavy)).foregroundColor(.white)
        }
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(bubbleIsPlus ? Color(rgb: 0xFFC400) : Color(rgb: 0x00C853))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.35), lineWidth: 2))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .offset(y: -54)
        .allowsHitTesting(false)
    }

    private func showBubble(plus: Bool) {
        hideTask?.cancel()
        bubbleIsPlus = plus
        bubbleVisible = true
    }
    private func scheduleHide() {
        hideTask?.cancel()
        hideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 600_000_000)
            if !Task.isCancelled { bubbleVisible = false }
        }
    }
}

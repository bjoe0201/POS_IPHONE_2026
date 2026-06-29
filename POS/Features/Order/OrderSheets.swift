import SwiftUI

// MARK: - 訂單明細（對應 Android OrderPanel）

struct OrderDetailSheet: View {
    @ObservedObject var vm: OrderViewModel
    let onCheckout: () -> Void
    let onCancelOrder: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 標頭
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(vm.selectedTable?.tableName ?? "尚未選桌")
                            .font(.system(size: 15, weight: .bold)).foregroundColor(Theme.text)
                        Text("共 \(vm.orderItems.count) 項目 \(vm.itemCount) 件")
                            .font(.system(size: 12)).foregroundColor(Theme.textMuted)
                    }
                    Spacer()
                    if !vm.orderItems.isEmpty {
                        Button(action: onCancelOrder) {
                            HStack(spacing: 5) {
                                Image(systemName: "trash")
                                    .font(.system(size: 14, weight: .bold))
                                Text("取消訂單")
                                    .font(.system(size: 15, weight: .bold))
                            }
                            .foregroundColor(Theme.error)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Theme.error.opacity(0.12))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.error.opacity(0.55), lineWidth: 1.5))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                Divider().background(Theme.border)

                // 品項
                if vm.orderItems.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Text("🛒").font(.system(size: 32))
                        Text("尚未點餐").foregroundColor(Theme.textMuted).font(.system(size: 13))
                        Spacer()
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(vm.orderItems) { oi in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(oi.name).font(.system(size: 14, weight: .medium)).foregroundColor(Theme.text)
                                    Text("\(Formatters.money(oi.price)) × \(oi.quantity) = \(Formatters.money(oi.lineTotal))")
                                        .font(.system(size: 12, weight: .bold)).foregroundColor(Theme.accent)
                                }
                                Spacer()
                                Button {
                                    vm.deleteOrderItem(oi)
                                } label: {
                                    Image(systemName: "trash").foregroundColor(Theme.error)
                                }
                                .buttonStyle(.plain)
                            }
                            .listRowBackground(Theme.bg)
                        }
                    }
                    .listStyle(.plain)
                }

                // 底部：備註 + 合計 + 結帳
                VStack(spacing: 10) {
                    TextField("備註（選填）", text: $vm.remark)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Text("合計").font(.system(size: 14, weight: .semibold)).foregroundColor(Theme.textSub)
                        Spacer()
                        Text(Formatters.money(vm.total))
                            .font(.system(size: 26, weight: .heavy)).foregroundColor(Theme.accent)
                    }
                    Button(action: onCheckout) {
                        Text("送出結帳 →")
                            .font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(vm.orderItems.isEmpty ? Theme.border : Theme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(vm.orderItems.isEmpty || vm.selectedTable == nil)
                }
                .padding(12)
                .background(Theme.surface)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("訂單明細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("關閉") { dismiss() } } }
        }
    }
}

// MARK: - 結帳（對應 Android CheckoutDialog）

struct CheckoutSheet: View {
    @ObservedObject var vm: OrderViewModel
    let isToday: Bool
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var dateLabel: String { isToday ? "今天" : DateBoundary.mmdd(vm.selectedDate) }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                // 桌號 + 件數
                HStack(spacing: 10) {
                    Text(vm.selectedTable?.tableName ?? "")
                        .font(.system(size: 15, weight: .bold)).foregroundColor(Theme.accent)
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(Theme.accentDim)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.accent, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    Text("共 \(vm.orderItems.count) 個品項 \(vm.itemCount) 件")
                        .font(.system(size: 13)).foregroundColor(Theme.textMuted)
                    Spacer()
                }

                // 品項清單
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(vm.orderItems) { oi in
                            HStack {
                                Text("\(oi.name) × \(oi.quantity)").font(.system(size: 14)).foregroundColor(Theme.text)
                                Spacer()
                                Text(Formatters.money(oi.lineTotal))
                                    .font(.system(size: 14, weight: .bold)).foregroundColor(Theme.accent)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                }
                .frame(maxHeight: 200)
                .background(Theme.bg)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // 應收
                HStack {
                    Text("應收金額").font(.system(size: 18, weight: .bold)).foregroundColor(Theme.text)
                    Spacer()
                    Text(Formatters.money(vm.total))
                        .font(.system(size: 34, weight: .heavy)).foregroundColor(Theme.accent)
                }

                TextField("備註（選填）", text: $vm.remark).textFieldStyle(.roundedBorder)

                if let err = vm.errorMessage, !err.isEmpty {
                    Text("⚠️ \(err)")
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.error)
                        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.error.opacity(0.12))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.error.opacity(0.4), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Spacer()

                Button(action: onConfirm) {
                    Text("✓ 確認收款")
                        .font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(16)
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("確認結帳")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(dateLabel)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(isToday ? Theme.accent : Theme.error)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("返回修改") { vm.clearError(); dismiss() }
                }
            }
        }
        .interactiveDismissDisabled(true)  // 對應 Android dismissOnClickOutside=false
    }
}

// MARK: - 日期選擇（補登）

struct DatePickerSheet: View {
    let selectedDate: Int64
    let onConfirm: (Int64) -> Void
    let onToday: () -> Void
    let onDismiss: () -> Void

    @State private var date: Date

    init(selectedDate: Int64, onConfirm: @escaping (Int64) -> Void,
         onToday: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        self.selectedDate = selectedDate
        self.onConfirm = onConfirm
        self.onToday = onToday
        self.onDismiss = onDismiss
        _date = State(initialValue: DateBoundary.date(fromMillis: selectedDate))
    }

    var body: some View {
        NavigationView {
            VStack {
                DatePicker("選擇日期", selection: $date, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
                Spacer()
            }
            .navigationTitle("選擇日期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消", action: onDismiss) }
                ToolbarItem(placement: .principal) { Button("今天", action: onToday) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("確定") { onConfirm(DateBoundary.millis(from: date)) }
                }
            }
        }
    }
}

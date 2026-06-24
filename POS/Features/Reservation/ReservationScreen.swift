import SwiftUI

/// 訂位入口。對應 Android ReservationScreen：未選日顯示月曆，選日顯示當日時段格線。
struct ReservationScreen: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject private var vm: ReservationViewModel

    init(container: AppContainer) {
        _vm = StateObject(wrappedValue: ReservationViewModel(container: container))
    }

    var body: some View {
        Group {
            if vm.selectedDate == nil {
                ReservationCalendarView(vm: vm)
            } else {
                ReservationDayView(vm: vm)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
    }
}

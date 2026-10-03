import AgendouStore
import SwiftUI

enum AppTab: Hashable {
    case home, calendar, categories, settings
}

struct RootTabView: View {
    @State private var tab = AppTab.home
    @Environment(AgendaStore.self) private var store
    @Environment(ShiftNotifier.self) private var notifier
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $tab) {
            Tab("Início", systemImage: "house", value: .home) {
                HomeScreen(onSetup: { tab = .categories }, onOpenCalendar: { tab = .calendar })
            }
            Tab("Calendário", systemImage: "calendar", value: .calendar) {
                CalendarScreen()
            }
            Tab("Categorias", systemImage: "square.stack", value: .categories) {
                CategoriesScreen()
            }
            Tab("Ajustes", systemImage: "gearshape", value: .settings) {
                SettingsScreen()
            }
        }
        // The reminders only cover the next days: refresh them when the app opens and after any change.
        .task(id: Refresh(revision: store.revision, active: scenePhase == .active)) {
            if scenePhase == .active { await notifier.resync() }
        }
    }

    private struct Refresh: Equatable {
        let revision: Int
        let active: Bool
    }
}

#Preview {
    RootTabView()
        .environment(AgendaStore.preview)
        .environment(ShiftNotifier.preview)
        .agendouEnvironment()
}

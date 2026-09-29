import AgendouStore
import SwiftUI

enum AppTab: Hashable {
    case home, calendar, categories, settings
}

struct RootTabView: View {
    @State private var tab = AppTab.home

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
    }
}

#Preview {
    RootTabView()
        .environment(AgendaStore.preview)
        .agendouEnvironment()
}

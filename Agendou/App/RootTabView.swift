import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            Tab("Início", systemImage: "house") {
                HomeScreen()
            }
            Tab("Calendário", systemImage: "calendar") {
                CalendarScreen()
            }
            Tab("Categorias", systemImage: "square.stack") {
                CategoriesScreen()
            }
            Tab("Ajustes", systemImage: "gearshape") {
                SettingsScreen()
            }
        }
    }
}

#Preview {
    RootTabView()
}

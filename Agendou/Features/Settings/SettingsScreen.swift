import SwiftUI

struct SettingsScreen: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("Em construção", systemImage: "gearshape")
                .navigationTitle("Ajustes")
        }
    }
}

#Preview {
    SettingsScreen()
}

import SwiftUI

struct HomeScreen: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("Em construção", systemImage: "clock")
                .navigationTitle("Início")
        }
    }
}

#Preview {
    HomeScreen()
}

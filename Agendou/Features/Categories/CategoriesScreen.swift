import SwiftUI

struct CategoriesScreen: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("Em construção", systemImage: "square.stack")
                .navigationTitle("Categorias")
        }
    }
}

#Preview {
    CategoriesScreen()
}

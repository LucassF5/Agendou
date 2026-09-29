import AgendouStore
import SwiftUI

struct CategoriesScreen: View {
    @Environment(AgendaStore.self) private var store
    @State private var creating = false

    var body: some View {
        NavigationStack {
            let active = store.activeCategories()
            let archived = store.archivedCategories()
            List {
                if !active.contains(where: { store.openSchedule(of: $0) != nil }) {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Configure sua escala")
                                .font(.headline)
                            Text(
                                "Diga onde você trabalha e qual é a escala (12x36, 24x48…). O calendário se preenche sozinho."
                            )
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                        Button("Configurar minha escala") { creating = true }
                            .accessibilityIdentifier("onboarding.start")
                    }
                }
                if !active.isEmpty {
                    Section("Ativas") {
                        ForEach(active) { row($0) }
                    }
                }
                if !archived.isEmpty {
                    Section("Arquivadas") {
                        ForEach(archived) { row($0) }
                    }
                }
            }
            .navigationTitle("Categorias")
            .toolbar {
                Button("Nova categoria", systemImage: "plus") { creating = true }
            }
            .navigationDestination(for: UUID.self) { CategoryDetailScreen(categoryID: $0) }
            .sheet(isPresented: $creating) { CategoryForm(mode: .create) }
        }
    }

    private func row(_ category: ShiftCategory) -> some View {
        NavigationLink(value: category.id) {
            HStack(spacing: 12) {
                Circle()
                    .fill(category.color)
                    .frame(width: 14, height: 14)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.name)
                    Text(subtitle(category))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityIdentifier("category.row.\(category.name)")
    }

    private func subtitle(_ category: ShiftCategory) -> String {
        if category.archivedAt != nil { return String(localized: "Arquivada") }
        return store.openSchedule(of: category).map(Formatting.scheduleLabel) ?? String(localized: "Sem escala")
    }
}

#Preview {
    CategoriesScreen()
        .environment(AgendaStore.preview)
        .agendouEnvironment()
}

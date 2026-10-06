import AgendouStore
import SwiftUI

/// The "Escalas" tab: each place where the user works, with its schedule or without one.
struct SchedulesScreen: View {
    @Environment(AgendaStore.self) private var store
    @State private var creating = false
    /// The category just created with a fixed schedule: "Definir escala" opens once its form is gone, so the
    /// two sheets never overlap.
    @State private var created: ShiftCategory?
    @State private var defining: ShiftCategory?

    var body: some View {
        NavigationStack {
            let active = store.activeCategories()
            let archived = store.archivedCategories()
            List {
                let ending = store.schedulesNeedingRenewal()
                if !ending.isEmpty {
                    Section("Escalas terminando") {
                        ForEach(ending) { RenewalBanner(schedule: $0) }
                    }
                }
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
                        ForEach(active) { category in
                            row(category)
                                .tourAnchor(.category, when: category.id == active.first?.id)
                        }
                    }
                }
                if !archived.isEmpty {
                    Section("Arquivadas") {
                        ForEach(archived) { row($0) }
                    }
                }
            }
            .navigationTitle("Escalas")
            .toolbar {
                Button("Nova categoria", systemImage: "plus") { creating = true }
                    .accessibilityIdentifier(TourStep.addCategory.barItemIdentifier ?? "")
            }
            .navigationDestination(for: UUID.self) { ScheduleDetailScreen(categoryID: $0) }
            .sheet(isPresented: $creating, onDismiss: defineCreatedSchedule) {
                CategoryForm(mode: .create) { created = $0 }
            }
            .sheet(item: $defining) { ScheduleForm(mode: .first($0), store: store) }
        }
    }

    private func defineCreatedSchedule() {
        defining = created
        created = nil
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
        guard let open = store.openSchedule(of: category) else { return String(localized: "Sem escala") }
        return Formatting.scheduleSummary(open)
    }
}

#Preview {
    SchedulesScreen()
        .environment(AgendaStore.preview)
        .agendouEnvironment()
}

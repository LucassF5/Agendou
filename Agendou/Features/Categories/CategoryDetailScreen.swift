import AgendouCore
import AgendouStore
import SwiftUI

struct CategoryDetailScreen: View {
    let categoryID: UUID
    @Environment(AgendaStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private enum Sheet: Identifiable {
        case edit, first, change, correct, renew, pickDays

        var id: Self { self }
    }

    @State private var sheet: Sheet?
    @State private var confirmingArchive = false
    @State private var confirmingDelete = false
    @State private var confirmingScheduleDelete = false
    @State private var errorMessage: String?

    var body: some View {
        if let category = store.category(id: categoryID) {
            content(category)
        } else {
            ContentUnavailableView("Categoria excluída", systemImage: "trash")
        }
    }

    private func content(_ category: ShiftCategory) -> some View {
        let open = store.openSchedule(of: category)
        let isArchived = category.archivedAt != nil
        return List {
            Section {
                HStack {
                    Text("Escala atual")
                    Spacer()
                    Text(open.map(Formatting.scheduleLabel) ?? String(localized: "Sem escala"))
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("schedule.current")
                }
                if let open {
                    HStack {
                        Text("Vale até")
                        Spacer()
                        Text(until(open))
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("schedule.until")
                    }
                    LabeledContent("Em vigor desde", value: Formatting.dateTime(open.startsAt))
                    if let next = nextShift(of: open) {
                        LabeledContent("Próximo plantão", value: Formatting.dateTime(next))
                    }
                }
                if let archivedAt = category.archivedAt {
                    LabeledContent("Arquivada em", value: Formatting.date(archivedAt))
                }
            }

            if !isArchived {
                Section {
                    if let open {
                        Button("Renovar escala") { sheet = .renew }
                            .accessibilityIdentifier("schedule.renew")
                        Button("Mudei de escala") { sheet = .change }
                            .accessibilityIdentifier("schedule.change")
                        if store.isEditable(open) {
                            Button("Corrigir escala") { sheet = .correct }
                                .accessibilityIdentifier("schedule.correct")
                            Button("Excluir escala", role: .destructive) { confirmingScheduleDelete = true }
                        }
                    } else {
                        Button("Marcar dias") { sheet = .pickDays }
                            .accessibilityIdentifier("category.pickDays")
                        Button("Definir escala") { sheet = .first }
                            .accessibilityIdentifier("schedule.first")
                    }
                } footer: {
                    if let open, store.isEditable(open) {
                        Text(
                            "Dá para corrigir ou excluir a escala enquanto ela tem menos de 24 horas ou nenhum plantão dela começou."
                        )
                    }
                }
            }

            let history = store.schedules(of: category)
            if !history.isEmpty {
                Section("Histórico de escalas") {
                    ForEach(history.reversed()) { schedule in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Formatting.scheduleLabel(schedule))
                                .accessibilityIdentifier("schedule.history")
                            Text(period(of: schedule))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                if !isArchived {
                    Button("Arquivar categoria", role: .destructive) { confirmingArchive = true }
                }
                if store.canDeletePermanently(category) {
                    Button("Excluir categoria", role: .destructive) { confirmingDelete = true }
                }
            } footer: {
                if !isArchived {
                    Text("Arquivar encerra a escala agora e apaga os extras futuros. O passado continua no calendário.")
                }
            }
        }
        .navigationTitle(category.name)
        .toolbar {
            if !isArchived {
                Button("Editar") { sheet = .edit }
            }
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .edit: CategoryForm(mode: .edit(category))
            case .first: ScheduleForm(mode: .first(category), store: store)
            case .change: ScheduleForm(mode: .change(category), store: store)
            case .correct:
                if let open { ScheduleForm(mode: .correct(open), store: store) }
            case .renew:
                if let open { RenewForm(schedule: open) }
            case .pickDays:
                PickDaysForm(
                    category: category, month: CivilMonth(CivilCalendar.date(containing: Date.now.epochSeconds)),
                    store: store)
            }
        }
        .confirmationDialog("Arquivar \(category.name)?", isPresented: $confirmingArchive, titleVisibility: .visible) {
            Button("Arquivar", role: .destructive) { perform { try store.archive(category) } }
        } message: {
            Text("A escala termina agora e os extras futuros são apagados. Não dá para desarquivar.")
        }
        .confirmationDialog("Excluir \(category.name)?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Excluir", role: .destructive) {
                perform { try store.deletePermanently(category) }
                dismiss()
            }
        }
        .confirmationDialog(
            "Excluir a escala atual?", isPresented: $confirmingScheduleDelete, titleVisibility: .visible
        ) {
            Button("Excluir escala", role: .destructive) {
                if let open { perform { try store.deleteSchedule(open) } }
            }
        } message: {
            Text("A escala anterior, se houver, volta a valer.")
        }
        .errorAlert($errorMessage)
    }

    private func nextShift(of schedule: CategorySchedule) -> Date? {
        store.version(of: schedule)?.firstOccurrenceStart(atOrAfter: Date.now.epochSeconds)
            .map(Date.init(epochSeconds:))
    }

    private func until(_ schedule: CategorySchedule) -> String {
        guard let end = schedule.repeatsUntil else { return String(localized: "Sem prazo") }
        return Formatting.longDay(Formatting.lastDay(ofPeriodEndingAt: end))
    }

    private func period(of schedule: CategorySchedule) -> String {
        let start = Formatting.dateTime(schedule.startsAt)
        guard let end = schedule.endsAt else { return String(localized: "\(start) – atual") }
        return "\(start) – \(Formatting.dateTime(end))"
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            errorMessage = userMessage(for: error)
        }
    }
}

#Preview {
    NavigationStack {
        CategoryDetailScreen(categoryID: AgendaStore.preview.activeCategories()[0].id)
    }
    .environment(AgendaStore.preview)
    .agendouEnvironment()
}

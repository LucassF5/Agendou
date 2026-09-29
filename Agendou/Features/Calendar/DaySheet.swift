import AgendouCore
import AgendouStore
import SwiftUI

/// Shifts that start on a day, the cancelled ones, and the day's note.
struct DaySheet: View {
    let day: CivilDate
    @Environment(AgendaStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var selected: Occurrence?
    @State private var form: ExtraForm.Mode?
    @State private var note = ""
    @State private var savedNote = ""
    @State private var errorMessage: String?

    var body: some View {
        let expansion = store.expand(in: CivilCalendar.interval(of: day))
        NavigationStack {
            List {
                Section("Plantões") {
                    if expansion.occurrences.isEmpty {
                        Text("Nenhum plantão")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(expansion.occurrences, id: \.self) { occurrence in
                        shiftRow(occurrence)
                    }
                    Button("Adicionar extra", systemImage: "plus") { form = .add(day) }
                        .accessibilityIdentifier("day.addExtra")
                }
                if !expansion.cancelled.isEmpty {
                    Section {
                        ForEach(expansion.cancelled, id: \.self) { occurrence in
                            cancelledRow(occurrence)
                        }
                    } header: {
                        Text("Cancelados")
                    } footer: {
                        Text("Plantões da escala que foram desmarcados.")
                    }
                }
                Section("Anotação") {
                    TextEditor(text: $note)
                        .frame(minHeight: 88)
                        .overlay(alignment: .topLeading) {
                            if note.isEmpty {
                                Text("O que aconteceu nesse dia?")
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                        }
                        .accessibilityIdentifier("day.note")
                }
            }
            .navigationTitle(Formatting.dayTitle(day))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") {
                        saveNote()
                        dismiss()
                    }
                    .accessibilityIdentifier("day.done")
                }
            }
            .confirmationDialog(
                dialogTitle, isPresented: Binding(get: { selected != nil }, set: { if !$0 { selected = nil } }),
                titleVisibility: .visible, presenting: selected, actions: actions
            )
            .sheet(item: $form) { ExtraForm(mode: $0, store: store) }
            .errorAlert($errorMessage)
            .onAppear {
                savedNote = store.note(for: day)?.body ?? ""
                note = savedNote
            }
            .onDisappear(perform: saveNote)
        }
    }

    @ViewBuilder
    private func shiftRow(_ occurrence: Occurrence) -> some View {
        let category = store.category(id: occurrence.categoryID)
        let row = ShiftRow(occurrence: occurrence, category: category)
        if category?.archivedAt == nil {
            Button {
                selected = occurrence
            } label: {
                row
            }
            .tint(.primary)
            .accessibilityIdentifier("shift.\(category?.name ?? "")")
        } else {
            row
        }
    }

    private func cancelledRow(_ occurrence: Occurrence) -> some View {
        let category = store.category(id: occurrence.categoryID)
        return HStack {
            ShiftRow(occurrence: occurrence, category: category)
                .strikethrough()
                .foregroundStyle(.secondary)
            Spacer()
            if category?.archivedAt == nil {
                Button("Restaurar") { perform { try store.restore(occurrence) } }
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("restore.\(category?.name ?? "")")
            }
        }
    }

    private var dialogTitle: String {
        guard let selected, let category = store.category(id: selected.categoryID) else { return "" }
        return "\(category.name) · \(Formatting.timeRange(selected))"
    }

    @ViewBuilder
    private func actions(_ occurrence: Occurrence) -> some View {
        Button("Editar horário") { form = .edit(occurrence) }
        switch occurrence.origin {
        case .scheduled:
            Button("Cancelar plantão", role: .destructive) { perform { try store.cancel(occurrence) } }
        case .extra(let overrideID):
            Button("Excluir plantão", role: .destructive) {
                perform {
                    guard let extra = store.override(id: overrideID) else { throw AgendaError.notFound }
                    try store.deleteExtra(extra)
                }
            }
        case .adjusted:
            Button("Desfazer ajuste", role: .destructive) { perform { try store.undoAdjustment(occurrence) } }
        }
    }

    private func saveNote() {
        guard note != savedNote else { return }
        perform { try store.setNote(note, for: day) }
        savedNote = note
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            errorMessage = userMessage(for: error)
        }
    }
}

/// Color bar, category, time range and origin of a shift.
struct ShiftRow: View {
    let occurrence: Occurrence
    let category: ShiftCategory?

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(category?.color ?? .gray)
                .frame(width: 4, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(category?.name ?? String(localized: "Categoria excluída"))
                Text(Formatting.timeRange(occurrence))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let tag = tag {
                Text(tag)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.fill.tertiary, in: Capsule())
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var tag: String? {
        switch occurrence.origin {
        case .scheduled: nil
        case .extra: String(localized: "Extra")
        case .adjusted: String(localized: "Ajustado")
        }
    }
}

#Preview {
    DaySheet(day: CivilCalendar.date(containing: DefaultTimes.nextShiftStart(after: .now).epochSeconds))
        .environment(AgendaStore.preview)
        .agendouEnvironment()
}

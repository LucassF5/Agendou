import AgendouCore
import AgendouStore
import SwiftUI

/// Adds an extra shift on a day, or changes the times of a shift ("Editar horário").
struct ExtraForm: View {
    enum Mode: Identifiable {
        case add(CivilDate)
        case edit(Occurrence)

        var id: String {
            switch self {
            case .add(let day): "add-\(day.string)"
            case .edit(let occurrence): "edit-\(occurrence.categoryID)-\(occurrence.startsAt)"
            }
        }
    }

    let mode: Mode
    @Environment(AgendaStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var categoryID: UUID?
    @State private var startsAt: Date
    @State private var durationMinutes: Int
    @State private var errorMessage: String?

    init(mode: Mode, store: AgendaStore) {
        self.mode = mode
        switch mode {
        case .add(let day):
            let categories = store.activeCategories()
            let category = categories.first { store.openSchedule(of: $0) != nil } ?? categories.first
            let times = Self.defaultTimes(for: category, on: day, store: store)
            _categoryID = State(initialValue: category?.id)
            _startsAt = State(initialValue: times.start)
            _durationMinutes = State(initialValue: Int(times.duration) / 60)
        case .edit(let occurrence):
            _categoryID = State(initialValue: occurrence.categoryID)
            _startsAt = State(initialValue: Date(epochSeconds: occurrence.startsAt))
            _durationMinutes = State(initialValue: Int(occurrence.durationSeconds / 60))
        }
    }

    private var endsAt: Date {
        startsAt.addingTimeInterval(TimeInterval(durationMinutes * 60))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    switch mode {
                    case .add:
                        Picker("Local", selection: $categoryID) {
                            ForEach(store.activeCategories()) { category in
                                Text(category.name).tag(Optional(category.id))
                            }
                        }
                    case .edit(let occurrence):
                        LabeledContent("Local", value: store.category(id: occurrence.categoryID)?.name ?? "")
                    }
                }
                Section {
                    DatePicker("Início", selection: $startsAt)
                    Stepper(value: $durationMinutes, in: 30...(7 * 24 * 60), step: 30) {
                        LabeledContent("Duração", value: Formatting.duration(durationMinutes * 60))
                    }
                    .accessibilityIdentifier("extra.duration")
                    LabeledContent("Fim", value: Formatting.dateTime(endsAt))
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar", action: save)
                        .disabled(categoryID == nil)
                        .accessibilityIdentifier("extra.save")
                }
            }
            .onChange(of: categoryID) {
                guard case .add(let day) = mode else { return }
                let times = Self.defaultTimes(
                    for: categoryID.flatMap(store.category(id:)), on: day, store: store)
                startsAt = times.start
                durationMinutes = Int(times.duration) / 60
            }
            .errorAlert($errorMessage)
        }
    }

    private var title: LocalizedStringKey {
        switch mode {
        case .add: "Plantão extra"
        case .edit: "Editar horário"
        }
    }

    private func save() {
        do {
            switch mode {
            case .add:
                guard let category = categoryID.flatMap(store.category(id:)) else { return }
                try store.addExtra(to: category, startsAt: startsAt, endsAt: endsAt)
            case .edit(let occurrence):
                try store.edit(occurrence, startsAt: startsAt, endsAt: endsAt)
            }
            dismiss()
        } catch {
            errorMessage = userMessage(for: error)
        }
    }

    /// The category's usual shift on that day, or 07:00 for 12 hours.
    static func defaultTimes(for category: ShiftCategory?, on day: CivilDate, store: AgendaStore)
        -> DateInterval
    {
        if let category, let interval = store.extraDefaults(for: category, on: day) { return interval }
        return DateInterval(
            start: Date(epochSeconds: CivilCalendar.instant(of: day, hour: 7, minute: 0)), duration: 12 * 3_600)
    }
}

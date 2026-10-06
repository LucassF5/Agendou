import AgendouCore
import AgendouStore
import SwiftUI

/// "Marcar dias": one shift on each day picked in the grid, all at the same time. Made for categories
/// without a schedule, where every shift is marked by hand.
struct PickDaysForm: View {
    @Environment(AgendaStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var categoryID: UUID?
    @State private var startsAt: Date
    @State private var durationMinutes: Int
    @State private var visibleMonth: CivilMonth
    @State private var days: Set<CivilDate> = []
    @State private var errorMessage: String?

    /// Without a `category`, starts on the first one without a schedule.
    init(category: ShiftCategory? = nil, month: CivilMonth, store: AgendaStore) {
        let categories = store.activeCategories()
        let category = category ?? categories.first { store.openSchedule(of: $0) == nil } ?? categories.first
        let times = Self.defaultTimes(for: category, store: store)
        _categoryID = State(initialValue: category?.id)
        _startsAt = State(initialValue: times.start)
        _durationMinutes = State(initialValue: Int(times.duration) / 60)
        _visibleMonth = State(initialValue: month)
    }

    /// Time of day of `startsAt`, in seconds.
    private var startOfDay: Int {
        let time = CivilCalendar.calendar.dateComponents([.hour, .minute], from: startsAt)
        return time.hour! * 3_600 + time.minute! * 60
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Categoria", selection: $categoryID) {
                        ForEach(store.activeCategories()) { category in
                            Text(category.name).tag(Optional(category.id))
                        }
                    }
                }
                Section("Horário") {
                    DatePicker("Início", selection: $startsAt, displayedComponents: .hourAndMinute)
                    Stepper(value: $durationMinutes, in: 30...(7 * 24 * 60), step: 30) {
                        LabeledContent("Duração", value: Formatting.duration(durationMinutes * 60))
                    }
                    LabeledContent(
                        "Plantão",
                        value: Formatting.clockRange(
                            startOfDay: Int64(startOfDay), duration: Int64(durationMinutes * 60)))
                }
                Section {
                    MonthCalendarView(
                        visibleMonth: $visibleMonth, dots: store.dayDots(in: visibleMonth), selectedDays: $days
                    )
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("pickDays.calendar")
                } header: {
                    Text("Dias")
                } footer: {
                    Text("Toque nos dias do plantão. Os pontos mostram os plantões já marcados.")
                }
            }
            .navigationTitle("Marcar dias")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button(action: save) {
                        Text(saveTitle)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(categoryID == nil || days.isEmpty)
                    .accessibilityIdentifier("pickDays.save")
                }
            }
            .onChange(of: categoryID) {
                let times = Self.defaultTimes(for: categoryID.flatMap(store.category(id:)), store: store)
                startsAt = times.start
                durationMinutes = Int(times.duration) / 60
            }
            .errorAlert($errorMessage)
        }
    }

    private var saveTitle: String {
        days.isEmpty
            ? String(localized: "Escolha os dias")
            : String(localized: "Adicionar \(Formatting.shiftCount(days.count))")
    }

    private func save() {
        guard let category = categoryID.flatMap(store.category(id:)) else { return }
        do {
            try store.addExtras(
                to: category, on: days, hour: startOfDay / 3_600, minute: startOfDay % 3_600 / 60,
                durationSeconds: durationMinutes * 60)
            dismiss()
        } catch {
            errorMessage = userMessage(for: error)
        }
    }

    /// The category's usual shift time, or 07:00 for 12 hours, as the extra form offers.
    private static func defaultTimes(for category: ShiftCategory?, store: AgendaStore) -> DateInterval {
        ExtraForm.defaultTimes(
            for: category, on: CivilCalendar.date(containing: Date.now.epochSeconds), store: store)
    }
}

#Preview {
    PickDaysForm(month: CivilMonth(CivilCalendar.date(containing: Date.now.epochSeconds)), store: .preview)
        .environment(AgendaStore.preview)
        .agendouEnvironment()
}

import AgendouCore
import AgendouStore
import SwiftUI

/// The calendar's "+". For a category without a schedule, "Marcar dias": one shift on each day picked in the
/// grid, all at the same time. For a category with one, "Mudei de escala": the schedule makes the shifts, so
/// no days are picked.
struct AddShiftsForm: View {
    @Environment(AgendaStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var categoryID: UUID?
    @State private var errorMessage: String?

    // Marcar dias
    @State private var startsAt: Date
    @State private var durationMinutes: Int
    @State private var visibleMonth: CivilMonth
    @State private var days: Set<CivilDate> = []

    // Mudei de escala
    @State private var draft: ScheduleDraft
    @State private var anchor: Date
    @State private var repeatDraft = RepeatDraft()

    /// Without a `category`, starts on the first one without a schedule.
    init(category: ShiftCategory? = nil, month: CivilMonth, store: AgendaStore) {
        let categories = store.activeCategories()
        let category = category ?? categories.first { store.openSchedule(of: $0) == nil } ?? categories.first
        let defaults = Self.defaults(for: category, store: store)
        _categoryID = State(initialValue: category?.id)
        _startsAt = State(initialValue: defaults.times.start)
        _durationMinutes = State(initialValue: Int(defaults.times.duration) / 60)
        _visibleMonth = State(initialValue: month)
        _draft = State(initialValue: defaults.schedule.draft)
        _anchor = State(initialValue: defaults.schedule.anchor)
    }

    private var category: ShiftCategory? {
        categoryID.flatMap(store.category(id:))
    }

    private var openSchedule: CategorySchedule? {
        category.flatMap(store.openSchedule(of:))
    }

    /// Time of day of `startsAt`, in seconds.
    private var startOfDay: Int {
        let time = CivilCalendar.calendar.dateComponents([.hour, .minute], from: startsAt)
        return time.hour! * 3_600 + time.minute! * 60
    }

    /// The months of the period count from the anchor's day.
    private var anchorDay: CivilDate {
        CivilCalendar.date(containing: anchor.epochSeconds)
    }

    var body: some View {
        let open = openSchedule
        NavigationStack {
            Form {
                Section {
                    Picker("Categoria", selection: $categoryID) {
                        ForEach(store.activeCategories()) { category in
                            Text(category.name).tag(Optional(category.id))
                        }
                    }
                    .accessibilityIdentifier("addShifts.category")
                    if let open {
                        LabeledContent("Escala atual", value: Formatting.scheduleSummary(open))
                    }
                }
                if open == nil {
                    daysSections
                } else {
                    ScheduleFields(draft: $draft)
                    NewScheduleStart(anchor: $anchor)
                    RepeatFields(draft: $repeatDraft, startDay: anchorDay)
                }
            }
            .navigationTitle(open == nil ? "Marcar dias" : "Mudei de escala")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button(action: save) {
                        Text(saveTitle(open))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(categoryID == nil || (open == nil && days.isEmpty))
                    .accessibilityIdentifier("addShifts.save")
                }
            }
            .onChange(of: categoryID) {
                let defaults = Self.defaults(for: category, store: store)
                startsAt = defaults.times.start
                durationMinutes = Int(defaults.times.duration) / 60
                draft = defaults.schedule.draft
                anchor = defaults.schedule.anchor
                repeatDraft = RepeatDraft()
            }
            .errorAlert($errorMessage)
        }
    }

    @ViewBuilder
    private var daysSections: some View {
        Section("Horário") {
            DatePicker("Início", selection: $startsAt, displayedComponents: .hourAndMinute)
            Stepper(value: $durationMinutes, in: 30...(7 * 24 * 60), step: 30) {
                LabeledContent("Duração", value: Formatting.duration(durationMinutes * 60))
            }
            LabeledContent(
                "Plantão",
                value: Formatting.clockRange(startOfDay: Int64(startOfDay), duration: Int64(durationMinutes * 60)))
        }
        Section {
            MonthCalendarView(visibleMonth: $visibleMonth, dots: store.dayDots(in: visibleMonth), selectedDays: $days)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("addShifts.calendar")
        } header: {
            Text("Dias")
        } footer: {
            Text("Toque nos dias do plantão. Os pontos mostram os plantões já marcados.")
        }
    }

    private func saveTitle(_ open: CategorySchedule?) -> String {
        if open != nil { return String(localized: "Salvar escala") }
        return days.isEmpty
            ? String(localized: "Escolha os dias")
            : String(localized: "Adicionar \(Formatting.shiftCount(days.count))")
    }

    private func save() {
        guard let category else { return }
        do {
            if store.openSchedule(of: category) != nil {
                try store.changeSchedule(
                    for: category, workSeconds: draft.workSeconds, restSeconds: draft.restSeconds, anchorAt: anchor,
                    period: repeatDraft.period(startingOn: anchorDay))
            } else {
                try store.addExtras(
                    to: category, on: days, hour: startOfDay / 3_600, minute: startOfDay % 3_600 / 60,
                    durationSeconds: durationMinutes * 60)
            }
            dismiss()
        } catch {
            errorMessage = userMessage(for: error)
        }
    }

    /// Times for the days, as the extra form offers (the category's usual shift, or 07:00 for 12 hours),
    /// and the starting point of a schedule change.
    private static func defaults(for category: ShiftCategory?, store: AgendaStore)
        -> (times: DateInterval, schedule: (draft: ScheduleDraft, anchor: Date))
    {
        let times = ExtraForm.defaultTimes(
            for: category, on: CivilCalendar.date(containing: Date.now.epochSeconds), store: store)
        let schedule =
            category.map { ScheduleForm.changeDefaults(for: $0, store: store) }
            ?? (ScheduleDraft(), DefaultTimes.nextShiftStart(after: .now))
        return (times, schedule)
    }
}

#Preview {
    AddShiftsForm(month: CivilMonth(CivilCalendar.date(containing: Date.now.epochSeconds)), store: .preview)
        .environment(AgendaStore.preview)
        .agendouEnvironment()
}

import AgendouCore
import AgendouStore
import SwiftUI

/// Sets the first schedule, changes it ("Mudei de escala") or corrects the open one.
struct ScheduleForm: View {
    enum Mode {
        case first(ShiftCategory)
        case change(ShiftCategory)
        case correct(CategorySchedule)
    }

    let mode: Mode
    @Environment(AgendaStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var draft: ScheduleDraft
    @State private var anchor: Date
    @State private var startsAt: Date
    @State private var repeatDraft: RepeatDraft
    @State private var errorMessage: String?

    init(mode: Mode, store: AgendaStore) {
        self.mode = mode
        let now = Date.now
        switch mode {
        case .first:
            let anchor = DefaultTimes.nextShiftStart(after: now)
            _draft = State(initialValue: ScheduleDraft())
            _anchor = State(initialValue: anchor)
            _startsAt = State(initialValue: anchor)
            _repeatDraft = State(initialValue: RepeatDraft())
        case .change(let category):
            // Next shift of the current rotation that is still ahead, so the change lands on a real shift.
            // The rotation is followed past its period: a one-month schedule changed right away would
            // otherwise have no shift left and fall back to its own anchor.
            let open = store.openSchedule(of: category)
            var rotation = open.flatMap(store.version(of:))
            rotation?.endsAt = nil
            let after = max(now.epochSeconds, rotation?.startsAt ?? 0) + 1
            let next = rotation?.firstOccurrenceStart(atOrAfter: after).map(Date.init(epochSeconds:))
            _draft = State(
                initialValue: open.map { ScheduleDraft(workSeconds: $0.workSeconds, restSeconds: $0.restSeconds) }
                    ?? ScheduleDraft())
            _anchor = State(initialValue: next ?? DefaultTimes.nextShiftStart(after: now))
            _startsAt = State(initialValue: next ?? DefaultTimes.nextShiftStart(after: now))
            _repeatDraft = State(initialValue: RepeatDraft())
        case .correct(let schedule):
            _draft = State(
                initialValue: ScheduleDraft(workSeconds: schedule.workSeconds, restSeconds: schedule.restSeconds))
            _anchor = State(initialValue: schedule.anchorAt)
            _startsAt = State(initialValue: schedule.startsAt)
            _repeatDraft = State(initialValue: RepeatDraft(repeatsUntil: schedule.repeatsUntil))
        }
    }

    private var title: LocalizedStringKey {
        switch mode {
        case .first: "Definir escala"
        case .change: "Mudei de escala"
        case .correct: "Corrigir escala"
        }
    }

    /// "Desde quando" exists for a first version only; after a change the version starts at its anchor.
    private var asksStartDate: Bool {
        switch mode {
        case .first: true
        case .change: false
        case .correct(let schedule): store.previousSchedule(of: schedule) == nil
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                ScheduleFields(draft: $draft)
                if asksStartDate {
                    FirstScheduleDates(anchor: $anchor, startsAt: $startsAt)
                } else {
                    Section {
                        DatePicker("Primeiro plantão na escala nova", selection: $anchor, in: Date.now...)
                            .accessibilityIdentifier("schedule.anchor")
                    } footer: {
                        Text("A escala nova começa nesse plantão. O que já passou não muda.")
                    }
                }
                RepeatFields(draft: $repeatDraft, startDay: anchorDay)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar", action: save)
                        .accessibilityIdentifier("schedule.save")
                }
            }
            .errorAlert($errorMessage)
        }
    }

    /// The months of the period count from the anchor's day.
    private var anchorDay: CivilDate {
        CivilCalendar.date(containing: anchor.epochSeconds)
    }

    private var period: RepeatPeriod {
        repeatDraft.period(startingOn: anchorDay)
    }

    private func save() {
        do {
            switch mode {
            case .first(let category):
                try store.startFirstSchedule(
                    for: category, workSeconds: draft.workSeconds, restSeconds: draft.restSeconds, anchorAt: anchor,
                    startsAt: startsAt, period: period)
            case .change(let category):
                try store.changeSchedule(
                    for: category, workSeconds: draft.workSeconds, restSeconds: draft.restSeconds, anchorAt: anchor,
                    period: period)
            case .correct(let schedule):
                try store.correctSchedule(
                    schedule, workSeconds: draft.workSeconds, restSeconds: draft.restSeconds, anchorAt: anchor,
                    startsAt: asksStartDate ? startsAt : nil, period: period)
            }
            dismiss()
        } catch {
            errorMessage = userMessage(for: error)
        }
    }
}

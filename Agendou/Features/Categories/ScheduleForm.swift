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
        case .change(let category):
            // Next shift of the current rotation that is still ahead, so the change lands on a real shift.
            let open = store.openSchedule(of: category)
            let version = open.flatMap(store.version(of:))
            let after = max(now.epochSeconds, version?.startsAt ?? 0) + 1
            let next = version?.firstOccurrenceStart(atOrAfter: after).map(Date.init(epochSeconds:))
            _draft = State(
                initialValue: open.map { ScheduleDraft(workSeconds: $0.workSeconds, restSeconds: $0.restSeconds) }
                    ?? ScheduleDraft())
            _anchor = State(initialValue: next ?? DefaultTimes.nextShiftStart(after: now))
            _startsAt = State(initialValue: next ?? DefaultTimes.nextShiftStart(after: now))
        case .correct(let schedule):
            _draft = State(
                initialValue: ScheduleDraft(workSeconds: schedule.workSeconds, restSeconds: schedule.restSeconds))
            _anchor = State(initialValue: schedule.anchorAt)
            _startsAt = State(initialValue: schedule.startsAt)
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

    private func save() {
        do {
            switch mode {
            case .first(let category):
                try store.startFirstSchedule(
                    for: category, workSeconds: draft.workSeconds, restSeconds: draft.restSeconds, anchorAt: anchor,
                    startsAt: startsAt, period: .months(1))
            case .change(let category):
                try store.changeSchedule(
                    for: category, workSeconds: draft.workSeconds, restSeconds: draft.restSeconds, anchorAt: anchor,
                    period: .months(1))
            case .correct(let schedule):
                try store.correctSchedule(
                    schedule, workSeconds: draft.workSeconds, restSeconds: draft.restSeconds, anchorAt: anchor,
                    startsAt: asksStartDate ? startsAt : nil, period: .months(1))
            }
            dismiss()
        } catch {
            errorMessage = userMessage(for: error)
        }
    }
}

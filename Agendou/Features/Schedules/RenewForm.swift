import AgendouCore
import AgendouStore
import SwiftUI

/// "Renovar escala": extends the open version, counting from the day after its current end.
struct RenewForm: View {
    let schedule: CategorySchedule
    @Environment(AgendaStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft = RepeatDraft()
    @State private var errorMessage: String?

    var body: some View {
        let start = store.renewalStart(of: schedule)
        NavigationStack {
            Form {
                if let end = schedule.repeatsUntil {
                    Section {
                        LabeledContent(
                            "Prazo atual",
                            value: Formatting.longDay(CivilCalendar.date(containing: end.epochSeconds - 1)))
                    }
                }
                RepeatFields(draft: $draft, startDay: start)
            }
            .navigationTitle("Renovar escala")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        do {
                            try store.renewSchedule(schedule, period: draft.period(startingOn: start))
                            dismiss()
                        } catch {
                            errorMessage = userMessage(for: error)
                        }
                    }
                    .accessibilityIdentifier("renew.save")
                }
            }
            .errorAlert($errorMessage)
        }
    }
}

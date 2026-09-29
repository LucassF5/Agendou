import AgendouCore
import SwiftUI

/// The period the user picks: 1, 3 or 6 months, or through a last day.
struct RepeatDraft: Equatable {
    enum Choice: Hashable {
        case months(Int)
        case custom
    }

    var choice = Choice.months(1)
    /// Last day for `.custom`; only its civil day matters.
    var lastDay = Date.now

    func period(startingOn day: CivilDate) -> RepeatPeriod {
        switch choice {
        case .months(let count): .months(count)
        case .custom: .through(CivilCalendar.date(containing: lastDay.epochSeconds))
        }
    }

    /// A draft showing an existing end as a custom last day, or the default for versions without one.
    init(repeatsUntil: Date? = nil) {
        guard let repeatsUntil else { return }
        choice = .custom
        lastDay = repeatsUntil.addingTimeInterval(-43_200)
    }
}

/// "Repetir": 1, 3 or 6 calendar months counted from `startDay`'s month, or a last day, with the
/// resulting date shown live.
struct RepeatFields: View {
    @Binding var draft: RepeatDraft
    /// The day the months count from: the anchor's day, or the day after the current end when renewing.
    let startDay: CivilDate

    var body: some View {
        Section {
            ForEach([1, 3, 6], id: \.self) { count in
                option(
                    count == 1 ? String(localized: "1 mês") : String(localized: "\(count) meses"),
                    selected: draft.choice == .months(count)
                ) { draft.choice = .months(count) }
                .accessibilityIdentifier("repeat.\(count)")
            }
            option(String(localized: "Personalizado"), selected: draft.choice == .custom) {
                if draft.choice != .custom {
                    draft.lastDay = noon(of: RepeatPeriod.months(1).lastDay(startingOn: startDay))
                }
                draft.choice = .custom
            }
            .accessibilityIdentifier("repeat.custom")
            if draft.choice == .custom {
                DatePicker(
                    "Último dia", selection: $draft.lastDay, in: noon(of: startDay)..., displayedComponents: .date
                )
                .accessibilityIdentifier("repeat.lastDay")
            }
        } header: {
            Text("Repetir")
        } footer: {
            Text("Vale até \(Formatting.longDay(draft.period(startingOn: startDay).lastDay(startingOn: startDay)))")
                .accessibilityIdentifier("repeat.until")
        }
    }

    private func noon(of day: CivilDate) -> Date {
        Date(epochSeconds: CivilCalendar.instant(of: day, hour: 12, minute: 0))
    }

    private func option(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                // Color.primary, not .primary: inside a button .primary resolves to the tint.
                Text(title)
                    .foregroundStyle(Color.primary)
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

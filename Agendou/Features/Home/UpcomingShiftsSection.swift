import AgendouCore
import AgendouStore
import SwiftUI

/// The shifts after the one on the card, to plan the next days without opening the calendar.
struct UpcomingShiftsSection: View {
    let shifts: [Occurrence]
    let onSelect: (CivilDate) -> Void
    @Environment(AgendaStore.self) private var store

    var body: some View {
        if !shifts.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Próximos plantões")
                    .font(.headline)
                VStack(spacing: 0) {
                    ForEach(Array(shifts.enumerated()), id: \.offset) { index, shift in
                        if index > 0 {
                            Divider()
                                .padding(.leading, 16)
                        }
                        row(shift)
                    }
                }
                .padding(.horizontal)
                .background(.fill.quinary, in: RoundedRectangle(cornerRadius: 20))
            }
        }
    }

    private func row(_ shift: Occurrence) -> some View {
        let category = store.category(id: shift.categoryID)
        let day = CivilCalendar.date(containing: shift.startsAt)
        return Button {
            onSelect(day)
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(category?.color ?? .gray)
                    .frame(width: 4, height: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: "\(Formatting.shortWeekday(day)), \(Formatting.shortDay(day))")
                        .font(.subheadline.weight(.semibold))
                    Text(category?.name ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(Formatting.timeRange(shift))
                    .font(.subheadline)
                    .monospacedDigit()
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("upcoming.row")
    }
}

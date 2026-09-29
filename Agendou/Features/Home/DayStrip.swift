import AgendouCore
import AgendouStore
import SwiftUI

/// Today and the two days on each side. A day shows a dot per category with a shift starting on it and
/// the time the first of those shifts starts.
struct DayStrip: View {
    let today: CivilDate
    let onSelect: (CivilDate) -> Void
    @Environment(AgendaStore.self) private var store

    var body: some View {
        let first = today.adding(days: -2)
        let last = today.adding(days: 2)
        let range = CivilCalendar.interval(of: first).lowerBound..<CivilCalendar.interval(of: last).upperBound
        let occurrences = store.expand(in: range).occurrences
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Últimos e próximos dias")
                    .font(.headline)
                    .accessibilityIdentifier("home.days.title")
                Text(
                    "\(Formatting.shortDay(first)) a \(Formatting.shortDay(last)) · toque num dia para ver os plantões"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("home.days.caption")
            }
            HStack(spacing: 8) {
                ForEach(0..<5, id: \.self) { offset in
                    let day = first.adding(days: offset)
                    cell(day, shifts: shifts(on: day, occurrences))
                }
            }
        }
    }

    private func cell(_ day: CivilDate, shifts: [Occurrence]) -> some View {
        let isToday = day == today
        return Button {
            onSelect(day)
        } label: {
            VStack(spacing: 4) {
                Text(isToday ? String(localized: "hoje") : Formatting.shortWeekday(day))
                    .font(.caption.weight(isToday ? .semibold : .regular))
                    .foregroundStyle(isToday ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                Text(verbatim: "\(day.day)")
                    .font(.title3.weight(isToday ? .bold : .regular))
                    .monospacedDigit()
                HStack(spacing: 3) {
                    ForEach(Array(colors(of: shifts).prefix(3).enumerated()), id: \.offset) { _, color in
                        Circle().fill(color).frame(width: 6, height: 6)
                    }
                }
                .frame(height: 6)
                // Reserve the line even without a shift, so every day keeps the same height.
                Text(verbatim: startLabel(shifts) ?? "00:00")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .opacity(shifts.isEmpty ? 0 : 1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(isToday ? AnyShapeStyle(.tint.opacity(0.15)) : AnyShapeStyle(.fill.quinary))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(day, shifts: shifts))
        .accessibilityIdentifier("home.day.\(day.string)")
    }

    private func shifts(on day: CivilDate, _ occurrences: [Occurrence]) -> [Occurrence] {
        let interval = CivilCalendar.interval(of: day)
        return occurrences.filter { interval.contains($0.startsAt) }
    }

    /// One color per category, in the order its first shift starts.
    private func colors(of shifts: [Occurrence]) -> [Color] {
        var seen: Set<UUID> = []
        return shifts.filter { seen.insert($0.categoryID).inserted }
            .map { store.category(id: $0.categoryID)?.color ?? .gray }
    }

    /// "07:00", or "07:00 +1" when more shifts start that day.
    private func startLabel(_ shifts: [Occurrence]) -> String? {
        guard let first = shifts.first else { return nil }
        let time = Formatting.time(Date(epochSeconds: first.startsAt))
        return shifts.count == 1 ? time : "\(time) +\(shifts.count - 1)"
    }

    private func accessibilityLabel(_ day: CivilDate, shifts: [Occurrence]) -> String {
        let title = Formatting.dayTitle(day)
        let base = day == today ? String(localized: "Hoje, \(title)") : title
        guard let first = shifts.first else { return String(localized: "\(base), sem plantão") }
        let time = Formatting.time(Date(epochSeconds: first.startsAt))
        return shifts.count == 1
            ? String(localized: "\(base), plantão às \(time)")
            : String(localized: "\(base), \(shifts.count) plantões, o primeiro às \(time)")
    }
}

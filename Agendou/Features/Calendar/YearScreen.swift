import AgendouCore
import AgendouStore
import SwiftUI

/// Twelve mini months with the days that have a shift starting on them.
struct YearScreen: View {
    @State var year: Int
    /// Called with the month the user taps.
    let onSelect: (CivilMonth) -> Void
    @Environment(AgendaStore.self) private var store

    var body: some View {
        let occurrences = store.expand(in: CivilCalendar.interval(ofYear: year)).occurrences
        let colors = firstColorByDay(occurrences)
        let summary = PeriodSummary(occurrences: occurrences)
        let current = CivilMonth(CivilCalendar.date(containing: Date.now.epochSeconds))
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(
                    "\(Formatting.duration(Int(summary.totalSeconds))) · \(Formatting.shiftCount(summary.count)) no ano"
                )
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("year.total")
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 16, alignment: .top), count: 3),
                    spacing: 20
                ) {
                    ForEach(1...12, id: \.self) { number in
                        let month = CivilMonth(year: year, month: number)
                        Button {
                            onSelect(month)
                        } label: {
                            MiniMonthView(month: month, colors: colors, isCurrent: month == current)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(accessibilityLabel(month, occurrences))
                        .accessibilityIdentifier("year.month.\(number)")
                    }
                }
            }
            .padding()
        }
        .navigationTitle(String(year))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Ano anterior", systemImage: "chevron.left") { year -= 1 }
                Button("Próximo ano", systemImage: "chevron.right") { year += 1 }
            }
        }
    }

    private func firstColorByDay(_ occurrences: [Occurrence]) -> [CivilDate: Color] {
        var colors: [CivilDate: Color] = [:]
        for occurrence in occurrences {
            let day = CivilCalendar.date(containing: occurrence.startsAt)
            if colors[day] == nil {
                colors[day] = store.category(id: occurrence.categoryID)?.color ?? .gray
            }
        }
        return colors
    }

    private func accessibilityLabel(_ month: CivilMonth, _ occurrences: [Occurrence]) -> String {
        let interval = CivilCalendar.interval(of: month)
        let count = occurrences.filter { interval.contains($0.startsAt) }.count
        return "\(Formatting.monthName(month)), \(Formatting.shiftCount(count))"
    }
}

private struct MiniMonthView: View {
    let month: CivilMonth
    let colors: [CivilDate: Color]
    let isCurrent: Bool

    var body: some View {
        let leading = CivilCalendar.weekday(of: month.firstDay) - 1
        VStack(alignment: .leading, spacing: 6) {
            Text(Formatting.monthName(month).capitalized)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isCurrent ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 7), spacing: 2) {
                ForEach(0..<leading, id: \.self) { _ in
                    Color.clear.frame(height: 14)
                }
                ForEach(month.days, id: \.self) { day in
                    Text("\(day.day)")
                        .font(.system(size: 8, weight: colors[day] == nil ? .regular : .bold))
                        .monospacedDigit()
                        .foregroundStyle(colors[day] == nil ? Color.secondary : Color.white)
                        .frame(width: 14, height: 14)
                        .background {
                            if let color = colors[day] {
                                Circle().fill(color)
                            }
                        }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        YearScreen(year: 2026) { _ in }
    }
    .environment(AgendaStore.preview)
    .agendouEnvironment()
}

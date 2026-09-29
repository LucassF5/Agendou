import AgendouCore
import AgendouStore
import SwiftUI

/// Hours and shifts of a month, overall and per category, counted by the day each shift starts.
struct MonthSummaryView: View {
    let month: CivilMonth
    @Environment(AgendaStore.self) private var store

    var body: some View {
        let summary = PeriodSummary(occurrences: store.expand(in: CivilCalendar.interval(of: month)).occurrences)
        VStack(alignment: .leading, spacing: 16) {
            Text("Resumo de \(Formatting.monthName(month))")
                .font(.headline)
            HStack(spacing: 32) {
                stat(Formatting.duration(Int(summary.totalSeconds)), caption: "horas", id: "summary.hours")
                stat(Formatting.shiftCount(summary.count), caption: "no mês", id: "summary.count")
            }
            if summary.byCategory.isEmpty {
                Text("Nenhum plantão neste mês")
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(rows(summary), id: \.category.id) { row in
                        HStack {
                            Circle()
                                .fill(row.category.color)
                                .frame(width: 10, height: 10)
                            Text(row.category.name)
                            Spacer()
                            Text(
                                "\(Formatting.duration(Int(row.total.seconds))) · \(Formatting.shiftCount(row.total.count))"
                            )
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("summary.category.\(row.category.name)")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.fill.quinary, in: RoundedRectangle(cornerRadius: 20))
    }

    private func stat(_ value: String, caption: LocalizedStringKey, id: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title.weight(.semibold))
                .monospacedDigit()
                .accessibilityIdentifier(id)
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Categories with the most hours first.
    private func rows(_ summary: PeriodSummary) -> [(category: ShiftCategory, total: PeriodSummary.Total)] {
        summary.byCategory.compactMap { id, total in store.category(id: id).map { ($0, total) } }
            .sorted { ($0.total.seconds, $1.category.name) > ($1.total.seconds, $0.category.name) }
    }
}

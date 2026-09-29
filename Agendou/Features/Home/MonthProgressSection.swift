import AgendouCore
import AgendouStore
import SwiftUI

/// This month's hours and shifts: those that have already started and the whole month, planned shifts
/// included, overall and per category.
struct MonthProgressSection: View {
    let now: Date
    let onOpenCalendar: () -> Void
    @Environment(AgendaStore.self) private var store

    var body: some View {
        let month = CivilMonth(CivilCalendar.date(containing: now.epochSeconds))
        let progress = PeriodProgress(
            occurrences: store.expand(in: CivilCalendar.interval(of: month)).occurrences, now: now.epochSeconds)
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Resumo de \(Formatting.monthName(month))")
                    .font(.headline)
                Spacer()
                Button("Ver no calendário", action: onOpenCalendar)
                    .font(.subheadline)
                    .accessibilityIdentifier("home.month.openCalendar")
            }
            HStack(alignment: .top, spacing: 32) {
                stat("Até hoje", progress.soFar)
                    .accessibilityIdentifier("home.month.soFar")
                stat("No mês", progress.total)
                    .accessibilityIdentifier("home.month.total")
            }
            if progress.total.count == 0 {
                Text("Nenhum plantão neste mês")
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(rows(progress), id: \.category.id) { row in
                        HStack {
                            Circle()
                                .fill(row.category.color)
                                .frame(width: 10, height: 10)
                            Text(row.category.name)
                            Spacer()
                            Text("\(Formatting.duration(row.soFar)) de \(Formatting.duration(row.total))")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("home.month.category.\(row.category.name)")
                    }
                }
            }
            Text("“Até hoje” conta os plantões que já começaram; “no mês” soma também os que ainda vão acontecer.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.fill.quinary, in: RoundedRectangle(cornerRadius: 20))
    }

    private func stat(_ title: LocalizedStringKey, _ summary: PeriodSummary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(Formatting.duration(Int(summary.totalSeconds)))
                .font(.title2.weight(.semibold))
                .monospacedDigit()
            Text(Formatting.shiftCount(summary.count))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    /// Categories with the most hours in the month first; hours so far next to the month's total.
    private func rows(_ progress: PeriodProgress) -> [(category: ShiftCategory, soFar: Int, total: Int)] {
        progress.total.byCategory.compactMap { id, total in
            store.category(id: id).map {
                ($0, Int(progress.soFar.byCategory[id]?.seconds ?? 0), Int(total.seconds))
            }
        }
        .sorted { ($0.total, $1.category.name) > ($1.total, $0.category.name) }
    }
}

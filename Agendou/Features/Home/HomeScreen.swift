import AgendouCore
import AgendouStore
import SwiftUI

/// The shift in progress or the next one, and the days around today.
struct HomeScreen: View {
    /// Switches to the Categories tab.
    var onSetup: () -> Void
    @Environment(AgendaStore.self) private var store
    @State private var selectedDay: CivilDate?

    var body: some View {
        NavigationStack {
            TimelineView(.everyMinute) { context in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if let shift = store.currentOrNextShift() {
                            ShiftCard(shift: shift, now: context.date) {
                                selectedDay = CivilCalendar.date(containing: shift.startsAt)
                            }
                        } else {
                            emptyState
                        }
                        FiveDayStrip(today: CivilCalendar.date(containing: context.date.epochSeconds)) {
                            selectedDay = $0
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Início")
            .sheet(item: $selectedDay) { day in
                DaySheet(day: day)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nenhum plantão pela frente")
                .font(.headline)
            Text("Cadastre onde você trabalha e a sua escala para ver aqui o próximo plantão.")
                .foregroundStyle(.secondary)
            Button("Configurar escala", action: onSetup)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("home.setup")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.fill.quinary, in: RoundedRectangle(cornerRadius: 20))
    }
}

/// The shift in progress or the next one.
private struct ShiftCard: View {
    let shift: Occurrence
    let now: Date
    let action: () -> Void
    @Environment(AgendaStore.self) private var store

    var body: some View {
        let category = store.category(id: shift.categoryID)
        let start = Date(epochSeconds: shift.startsAt)
        let end = Date(epochSeconds: shift.endsAt)
        let inProgress = shift.startsAt <= now.epochSeconds
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Text(inProgress ? "Em andamento" : "Próximo plantão")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(category?.color ?? .accentColor)
                Text(category?.name ?? "")
                    .font(.title2.weight(.bold))
                VStack(alignment: .leading, spacing: 2) {
                    Text(Formatting.dayTitle(CivilCalendar.date(containing: shift.startsAt)))
                    Text(Formatting.timeRange(shift))
                        .monospacedDigit()
                }
                .foregroundStyle(.secondary)
                Text(
                    inProgress
                        ? String(localized: "Termina \(Formatting.relative(end, from: now))")
                        : String(localized: "Começa \(Formatting.relative(start, from: now))")
                )
                .font(.subheadline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .fill((category?.color ?? .accentColor).opacity(0.12))
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.card")
    }
}

/// Today and the two days on each side, with a dot per category that has a shift starting that day.
private struct FiveDayStrip: View {
    let today: CivilDate
    let onSelect: (CivilDate) -> Void
    @Environment(AgendaStore.self) private var store

    var body: some View {
        let first = today.adding(days: -2)
        let range =
            CivilCalendar.interval(of: first).lowerBound..<CivilCalendar.interval(of: today.adding(days: 2)).upperBound
        let occurrences = store.expand(in: range).occurrences
        HStack(spacing: 8) {
            ForEach(0..<5, id: \.self) { offset in
                let day = first.adding(days: offset)
                let colors = colors(on: day, occurrences)
                Button {
                    onSelect(day)
                } label: {
                    VStack(spacing: 6) {
                        Text(Formatting.shortWeekday(day))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(day.day)")
                            .font(.title3.weight(day == today ? .bold : .regular))
                            .monospacedDigit()
                        HStack(spacing: 3) {
                            ForEach(Array(colors.prefix(3).enumerated()), id: \.offset) { _, color in
                                Circle().fill(color).frame(width: 6, height: 6)
                            }
                        }
                        .frame(height: 6)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(day == today ? AnyShapeStyle(.tint.opacity(0.15)) : AnyShapeStyle(.fill.quinary))
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibilityLabel(day, count: colors.count))
                .accessibilityIdentifier("home.day.\(day.string)")
            }
        }
    }

    private func colors(on day: CivilDate, _ occurrences: [Occurrence]) -> [Color] {
        let interval = CivilCalendar.interval(of: day)
        var seen: Set<UUID> = []
        return occurrences.filter { interval.contains($0.startsAt) && seen.insert($0.categoryID).inserted }
            .map { store.category(id: $0.categoryID)?.color ?? .gray }
    }

    private func accessibilityLabel(_ day: CivilDate, count: Int) -> String {
        let title = Formatting.dayTitle(day)
        return count == 0 ? title : String(localized: "\(title), com plantão")
    }
}

#Preview {
    HomeScreen {}
        .environment(AgendaStore.preview)
        .agendouEnvironment()
}

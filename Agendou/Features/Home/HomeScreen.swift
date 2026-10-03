import AgendouCore
import AgendouStore
import SwiftUI

/// The shift in progress or the next one, the days around today, the next shifts and the month so far.
struct HomeScreen: View {
    /// Switches to the Categories tab.
    var onSetup: () -> Void
    /// Switches to the Calendar tab.
    var onOpenCalendar: () -> Void
    @Environment(AgendaStore.self) private var store
    @State private var selectedDay: CivilDate?

    var body: some View {
        NavigationStack {
            TimelineView(.everyMinute) { context in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        ForEach(store.schedulesNeedingRenewal()) { schedule in
                            RenewalBanner(schedule: schedule)
                                .padding()
                                .background(.fill.quinary, in: RoundedRectangle(cornerRadius: 16))
                        }
                        let shift = store.currentOrNextShift()
                        if let shift {
                            ShiftCard(shift: shift, now: context.date) {
                                selectedDay = CivilCalendar.date(containing: shift.startsAt)
                            }
                            .tourAnchor(.nextShift)
                        } else {
                            emptyState
                        }
                        DayStrip(today: CivilCalendar.date(containing: context.date.epochSeconds)) {
                            selectedDay = $0
                        }
                        .tourAnchor(.dayStrip)
                        if let shift {
                            UpcomingShiftsSection(shifts: store.upcomingShifts(after: shift, limit: 4)) {
                                selectedDay = $0
                            }
                        }
                        MonthProgressSection(now: context.date, onOpenCalendar: onOpenCalendar)
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

#Preview {
    HomeScreen(onSetup: {}, onOpenCalendar: {})
        .environment(AgendaStore.preview)
        .agendouEnvironment()
}

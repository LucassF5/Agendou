import AgendouCore
import AgendouStore
import SwiftUI

struct CalendarScreen: View {
    @Environment(AgendaStore.self) private var store
    @State private var visibleMonth = CivilMonth(CivilCalendar.date(containing: Date.now.epochSeconds))
    @State private var selectedDay: CivilDate?
    @State private var showingYear = false
    @State private var sharing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    MonthCalendarView(visibleMonth: $visibleMonth, dots: dots()) { selectedDay = $0 }
                    MonthSummaryView(month: visibleMonth)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Calendário")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Enviar", systemImage: "square.and.arrow.up") { sharing = true }
                        .accessibilityIdentifier("calendar.share")
                    Button("Ano") { showingYear = true }
                        .accessibilityIdentifier("calendar.year")
                    Button("Hoje") {
                        visibleMonth = CivilMonth(CivilCalendar.date(containing: Date.now.epochSeconds))
                    }
                }
            }
            .navigationDestination(isPresented: $showingYear) {
                YearScreen(year: visibleMonth.year) { month in
                    visibleMonth = month
                    showingYear = false
                }
            }
            .sheet(item: $selectedDay) { day in
                DaySheet(day: day)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $sharing) {
                ShareMonthScreen(month: visibleMonth)
            }
        }
    }

    /// One dot per category with a shift starting on the day, in the order the shifts start.
    private func dots() -> [CivilDate: [Color]] {
        let expansion = store.expand(in: CivilCalendar.interval(of: visibleMonth))
        var dots: [CivilDate: [Color]] = [:]
        var seen: [CivilDate: Set<UUID>] = [:]
        for occurrence in expansion.occurrences {
            let day = CivilCalendar.date(containing: occurrence.startsAt)
            guard seen[day, default: []].insert(occurrence.categoryID).inserted else { continue }
            dots[day, default: []].append(store.category(id: occurrence.categoryID)?.color ?? .gray)
        }
        return dots
    }
}

#Preview {
    CalendarScreen()
        .environment(AgendaStore.preview)
        .agendouEnvironment()
}

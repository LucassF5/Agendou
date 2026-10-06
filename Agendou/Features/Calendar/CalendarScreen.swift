import AgendouCore
import AgendouStore
import SwiftUI

struct CalendarScreen: View {
    @Environment(AgendaStore.self) private var store
    @State private var visibleMonth = CivilMonth(CivilCalendar.date(containing: Date.now.epochSeconds))
    @State private var selectedDay: CivilDate?
    @State private var showingYear = false
    @State private var sharing = false
    @State private var pickingDays = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    MonthCalendarView(visibleMonth: $visibleMonth, dots: store.dayDots(in: visibleMonth)) {
                        selectedDay = $0
                    }
                    .tourAnchor(.calendar)
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Marcar dias", systemImage: "plus") { pickingDays = true }
                        .accessibilityIdentifier("calendar.pickDays")
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
            .sheet(isPresented: $pickingDays) {
                PickDaysForm(month: visibleMonth, store: store)
            }
        }
    }
}

#Preview {
    CalendarScreen()
        .environment(AgendaStore.preview)
        .agendouEnvironment()
}

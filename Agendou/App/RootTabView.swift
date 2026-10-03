import AgendouCore
import AgendouStore
import SwiftUI

enum AppTab: Hashable {
    case home, calendar, categories, settings
}

struct RootTabView: View {
    /// `nil` keeps the tour from opening by itself (UI tests, previews).
    let tutorialGate: TutorialGate?
    @State private var tab = AppTab.home
    @State private var creatingCategory = false
    @State private var tour = TourController()
    @State private var tourWindow = TourWindow()
    /// The sample agenda shown while the tour runs; `nil` the rest of the time.
    @State private var demoStore: AgendaStore?
    /// The day sheet the tour opens on steps 6 and 7.
    @State private var tourDay: CivilDate?
    @Environment(AgendaStore.self) private var store
    @Environment(ShiftNotifier.self) private var notifier
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $tab) {
            Tab("Início", systemImage: "house", value: .home) {
                HomeScreen(onSetup: { tab = .categories }, onOpenCalendar: { tab = .calendar })
            }
            Tab("Calendário", systemImage: "calendar", value: .calendar) {
                CalendarScreen()
            }
            Tab("Categorias", systemImage: "square.stack", value: .categories) {
                CategoriesScreen()
            }
            Tab("Ajustes", systemImage: "gearshape", value: .settings) {
                SettingsScreen()
            }
        }
        .sheet(item: $tourDay) { day in
            DaySheet(day: day)
                .presentationDetents([.medium, .large])
        }
        .environment(demoStore ?? store)
        .environment(tour)
        // The reminders only cover the next days: refresh them when the app opens and after any change.
        // `store` here is always the real one: the tour never schedules or clears reminders.
        .task(id: Refresh(revision: store.revision, active: scenePhase == .active)) {
            if scenePhase == .active { await notifier.resync() }
        }
        .environment(\.showTutorial, startTour)
        .task {
            if tutorialGate?.shouldPresentOnLaunch == true { startTour() }
        }
        .onChange(of: tour.step) { _, step in
            guard let step else { return }
            tab = step.tab
            tourDay = step.needsDaySheet ? sampleDay : nil
        }
        .sheet(isPresented: $creatingCategory) { CategoryForm(mode: .create) }
    }

    /// The day of the sample agenda's next shift, where the day sheet steps happen.
    private var sampleDay: CivilDate? {
        (demoStore?.currentOrNextShift()).map { CivilCalendar.date(containing: $0.startsAt) }
    }

    private func startTour() {
        guard !tour.isActive, let demo = try? AgendaStore.demo() else { return }
        demoStore = demo
        tour.onExit = endTour
        tour.start(hasSchedule: store.hasAnySchedule)
        tourWindow.show(tour)
    }

    /// Counts as seen however it was left; "Configurar minha escala" goes on to the category form.
    private func endTour(_ reason: TourController.Exit) {
        tourWindow.hide()
        tourDay = nil
        demoStore = nil
        tutorialGate?.markSeen()
        if reason == .setUp {
            tab = .categories
            creatingCategory = true
        }
    }

    private struct Refresh: Equatable {
        let revision: Int
        let active: Bool
    }
}

extension EnvironmentValues {
    /// Starts the tour over the tabs, so its last button can switch to the Categories tab.
    @Entry var showTutorial: () -> Void = {}
}

#Preview {
    RootTabView(tutorialGate: nil)
        .environment(AgendaStore.preview)
        .environment(ShiftNotifier.preview)
        .agendouEnvironment()
}

import AgendouCore
import AgendouStore
import SwiftUI
import WidgetKit

enum AppTab: Hashable {
    case home, calendar, schedules, settings
}

struct RootTabView: View {
    /// `nil` keeps the tour from opening by itself (UI tests, previews).
    let tutorialGate: TutorialGate?
    @State private var tab = AppTab.home
    @State private var creatingCategory = false
    /// The category just created with a fixed schedule: "Definir escala" opens once its form is gone.
    @State private var createdCategory: ShiftCategory?
    @State private var definingCategory: ShiftCategory?
    @State private var tour = TourController()
    @State private var tourWindow = TourWindow()
    /// The sample agenda shown while the tour runs; `nil` the rest of the time.
    @State private var demoStore: AgendaStore?
    /// The day sheet the tour opens on steps 6 and 7.
    @State private var tourDay: CivilDate?
    /// The intro shown before anything else on a first launch.
    @State private var showingIntro = false
    /// What the intro's choice asked for, acted on once its cover is gone.
    @State private var introChoice: IntroChoice?
    @Environment(AgendaStore.self) private var store
    @Environment(ShiftNotifier.self) private var notifier
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $tab) {
            Tab("Início", systemImage: "house", value: .home) {
                HomeScreen(onSetup: { tab = .schedules }, onOpenCalendar: { tab = .calendar })
            }
            Tab("Calendário", systemImage: "calendar", value: .calendar) {
                CalendarScreen()
            }
            Tab("Escalas", systemImage: "square.stack", value: .schedules) {
                SchedulesScreen()
            }
            Tab("Ajustes", systemImage: "gearshape", value: .settings) {
                SettingsScreen()
            }
        }
        // Rebuilt when the tour swaps the agenda in or out: pushed screens, scroll positions and the visible
        // month go back to the start, so the tour never shows a screen left halfway, and the user does not
        // come back to sample screens afterwards.
        .id(demoStore == nil)
        .sheet(item: $tourDay) { day in
            DaySheet(day: day)
                .presentationDetents([.medium, .large])
        }
        .environment(demoStore ?? store)
        .environment(tour)
        // The reminders only cover the next days: refresh them when the app opens and after any change.
        // The widget reads the same data: it reloads on the same triggers.
        // `store` here is always the real one: the tour never schedules or clears reminders.
        .task(id: Refresh(revision: store.revision, active: scenePhase == .active)) {
            guard scenePhase == .active else { return }
            WidgetCenter.shared.reloadAllTimelines()
            await notifier.resync()
        }
        .environment(\.showTutorial, startTour)
        .task {
            if tutorialGate?.shouldPresentOnLaunch == true { showingIntro = true }
        }
        .fullScreenCover(isPresented: $showingIntro, onDismiss: afterIntro) {
            IntroScreen(
                onTour: {
                    introChoice = .tour
                    showingIntro = false
                },
                onStart: {
                    introChoice = .start
                    showingIntro = false
                })
        }
        .onChange(of: tour.step) { _, step in
            guard let step else { return }
            tab = step.tab
            tourDay = step.needsDaySheet ? sampleDay : nil
            tourWindow.stepChanged()
        }
        .sheet(isPresented: $creatingCategory, onDismiss: defineCreatedSchedule) {
            CategoryForm(mode: .create) { createdCategory = $0 }
        }
        .sheet(item: $definingCategory) { ScheduleForm(mode: .first($0), store: store) }
    }

    private func defineCreatedSchedule() {
        definingCategory = createdCategory
        createdCategory = nil
    }

    /// The day of the sample agenda's next shift, where the day sheet steps happen.
    private var sampleDay: CivilDate? {
        (demoStore?.currentOrNextShift()).map { CivilCalendar.date(containing: $0.startsAt) }
    }

    private enum IntroChoice {
        case tour, start
    }

    /// "Fazer o tour" starts it; "Pular e começar a usar" counts as seen and goes to the category form.
    private func afterIntro() {
        defer { introChoice = nil }
        switch introChoice {
        case .tour:
            startTour()
        case .start, nil:
            tutorialGate?.markSeen()
            if !store.hasAnySchedule {
                tab = .schedules
                creatingCategory = true
            }
        }
    }

    /// Runs the tour itself; "Ver tutorial" in Settings comes straight here, without the intro.
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
            tab = .schedules
            creatingCategory = true
        }
    }

    private struct Refresh: Equatable {
        let revision: Int
        let active: Bool
    }
}

extension EnvironmentValues {
    /// Starts the tour over the tabs, so its last button can switch to the Escalas tab.
    @Entry var showTutorial: () -> Void = {}
}

#Preview {
    RootTabView(tutorialGate: nil)
        .environment(AgendaStore.preview)
        .environment(ShiftNotifier.preview)
        .agendouEnvironment()
}

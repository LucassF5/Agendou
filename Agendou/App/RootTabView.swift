import AgendouStore
import SwiftUI

enum AppTab: Hashable {
    case home, calendar, categories, settings
}

struct RootTabView: View {
    /// `nil` keeps the tutorial from opening by itself (UI tests, previews).
    let tutorialGate: TutorialGate?
    @State private var tab = AppTab.home
    @State private var showingTutorial: Bool
    @State private var setUpAfterTutorial = false
    @State private var creatingCategory = false
    @Environment(AgendaStore.self) private var store
    @Environment(ShiftNotifier.self) private var notifier
    @Environment(\.scenePhase) private var scenePhase

    init(tutorialGate: TutorialGate?) {
        self.tutorialGate = tutorialGate
        _showingTutorial = State(initialValue: tutorialGate?.shouldPresentOnLaunch ?? false)
    }

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
        // The reminders only cover the next days: refresh them when the app opens and after any change.
        .task(id: Refresh(revision: store.revision, active: scenePhase == .active)) {
            if scenePhase == .active { await notifier.resync() }
        }
        .environment(\.showTutorial) { showingTutorial = true }
        .fullScreenCover(isPresented: $showingTutorial, onDismiss: afterTutorial) {
            TutorialScreen(hasSchedule: store.hasAnySchedule) { setUp in
                setUpAfterTutorial = setUp
                showingTutorial = false
            }
        }
        .sheet(isPresented: $creatingCategory) { CategoryForm(mode: .create) }
    }

    /// Counts as seen however it was closed; "Configurar minha escala" goes on to the category form.
    private func afterTutorial() {
        tutorialGate?.markSeen()
        guard setUpAfterTutorial else { return }
        setUpAfterTutorial = false
        tab = .categories
        creatingCategory = true
    }

    private struct Refresh: Equatable {
        let revision: Int
        let active: Bool
    }
}

extension EnvironmentValues {
    /// Opens the tutorial over the tabs, so its last button can switch to the Categories tab.
    @Entry var showTutorial: () -> Void = {}
}

#Preview {
    RootTabView(tutorialGate: nil)
        .environment(AgendaStore.preview)
        .environment(ShiftNotifier.preview)
        .agendouEnvironment()
}

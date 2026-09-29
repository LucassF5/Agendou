import AgendouCore
import AgendouStore
import SwiftData
import SwiftUI

@main
struct AgendouApp: App {
    private let container: ModelContainer
    @State private var store: AgendaStore

    init() {
        // UI tests start from an empty in-memory store and a fresh first launch.
        let isUITesting = ProcessInfo.processInfo.arguments.contains("-ui-testing")
        let defaults: UserDefaults
        do {
            container = try AgendouContainer.make(inMemory: isUITesting)
        } catch {
            fatalError("Could not open the local database: \(error)")
        }
        if isUITesting {
            defaults = UserDefaults(suiteName: "ui-testing")!
            defaults.removePersistentDomain(forName: "ui-testing")
        } else {
            defaults = .standard
        }
        let store = AgendaStore(context: container.mainContext)
        store.seedIfFirstLaunch(defaults: defaults)
        _store = State(initialValue: store)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .agendouEnvironment()
        }
        .modelContainer(container)
        .environment(store)
    }
}

extension View {
    /// Dates are shown and picked in the workplace time zone and in pt-BR, whatever the device says.
    func agendouEnvironment() -> some View {
        environment(\.timeZone, CivilCalendar.timeZone)
            .environment(\.calendar, CivilCalendar.calendar)
            .environment(\.locale, Locale(identifier: "pt_BR"))
    }
}

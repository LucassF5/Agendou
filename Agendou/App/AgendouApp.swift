import AgendouStore
import SwiftData
import SwiftUI

@main
struct AgendouApp: App {
    private let container: ModelContainer
    @State private var store: AgendaStore

    init() {
        do {
            container = try AgendouContainer.make()
        } catch {
            fatalError("Could not open the local database: \(error)")
        }
        let store = AgendaStore(context: container.mainContext)
        store.seedIfFirstLaunch(defaults: .standard)
        _store = State(initialValue: store)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(container)
        .environment(store)
    }
}

import AgendouCore
import Foundation
import Testing

@testable import AgendouStore

struct TutorialGateTests {
    private let agenda = TestAgenda()
    private let defaults = UserDefaults(suiteName: "tutorial-gate-\(UUID().uuidString)")!

    private func makeGate() -> TutorialGate {
        TutorialGate(store: agenda.store, defaults: defaults)
    }

    @Test func showsOnTheFirstLaunchWithNoSchedule() {
        #expect(makeGate().shouldPresentOnLaunch)
    }

    @Test func showsWhenOnlyTheSeededCategoryWithoutScheduleExists() {
        agenda.store.seedIfFirstLaunch(defaults: defaults)

        #expect(makeGate().shouldPresentOnLaunch)
    }

    @Test func hidesOnceSeen() {
        makeGate().markSeen()

        #expect(!makeGate().shouldPresentOnLaunch)
    }

    @Test func hidesWhenThereIsASchedule() throws {
        _ = try agenda.category12x36(anchor: at(2026, 10, 1, 7))

        #expect(!makeGate().shouldPresentOnLaunch)
    }

    @Test func hidesWhenTheOnlyScheduleWasClosed() throws {
        let category = try agenda.category12x36(anchor: at(2026, 9, 1, 7))
        try agenda.store.archive(category)

        #expect(!makeGate().shouldPresentOnLaunch)
    }
}

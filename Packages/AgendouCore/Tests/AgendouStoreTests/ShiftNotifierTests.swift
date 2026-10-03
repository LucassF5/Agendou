import AgendouCore
import Foundation
import Testing

@testable import AgendouStore

/// Records what the notifier asks the system to schedule.
final class FakeScheduler: ReminderScheduling {
    var grantsAuthorization = true
    private(set) var authorizationRequests = 0
    /// Every call to `replaceAll`, oldest first.
    private(set) var calls: [[PlannedReminder]] = []

    var scheduled: [PlannedReminder] { calls.last ?? [] }

    func requestAuthorization() async -> Bool {
        authorizationRequests += 1
        return grantsAuthorization
    }

    func replaceAll(with reminders: [PlannedReminder]) async {
        calls.append(reminders)
    }
}

struct ShiftNotifierTests {
    private let agenda = TestAgenda(now: at(2026, 9, 29, 12))
    private let scheduler = FakeScheduler()
    private let defaults = UserDefaults(suiteName: "shift-notifier-\(UUID().uuidString)")!

    private func makeNotifier() -> ShiftNotifier {
        ShiftNotifier(store: agenda.store, scheduler: scheduler, defaults: defaults)
    }

    /// A 12x36 rotation starting Oct 1 at 07:00: a shift every other day.
    private func addRotation(name: String = "UTI") throws {
        _ = try agenda.category12x36(name: name, anchor: at(2026, 10, 1, 7))
    }

    @Test func startsDisabledAtSevenAndSchedulesNothing() async throws {
        try addRotation()
        let notifier = makeNotifier()

        await notifier.resync()

        #expect(!notifier.isEnabled)
        #expect(notifier.hour == 7 && notifier.minute == 0)
        #expect(scheduler.scheduled.isEmpty)
        #expect(scheduler.authorizationRequests == 0)
    }

    @Test func turningOnAsksPermissionAndSchedulesOneReminderPerShiftDay() async throws {
        try addRotation()
        let notifier = makeNotifier()

        let granted = await notifier.setEnabled(true)

        #expect(granted && notifier.isEnabled)
        #expect(scheduler.authorizationRequests == 1)
        // Window is Sep 29 … Oct 28; shifts start Oct 1, 3, … 27: fourteen days.
        #expect(scheduler.scheduled.count == 14)
        #expect(scheduler.scheduled.first?.fireAt == at(2026, 10, 1, 7).epochSeconds)
        #expect(scheduler.scheduled.first?.shifts.map(\.categoryName) == ["UTI"])
    }

    @Test func staysOffWhenPermissionIsDenied() async throws {
        try addRotation()
        scheduler.grantsAuthorization = false
        let notifier = makeNotifier()

        let granted = await notifier.setEnabled(true)

        #expect(!granted && !notifier.isEnabled)
        #expect(scheduler.scheduled.isEmpty)
    }

    @Test func turningOffClearsWhatWasScheduled() async throws {
        try addRotation()
        let notifier = makeNotifier()
        _ = await notifier.setEnabled(true)

        _ = await notifier.setEnabled(false)

        #expect(!notifier.isEnabled)
        #expect(scheduler.scheduled.isEmpty)
    }

    @Test func changingTheTimeReschedulesAtTheNewTime() async throws {
        try addRotation()
        let notifier = makeNotifier()
        _ = await notifier.setEnabled(true)

        await notifier.setTime(hour: 6, minute: 30)

        #expect(scheduler.scheduled.first?.fireAt == at(2026, 10, 1, 6, 30).epochSeconds)
    }

    @Test func resyncPicksUpChangesToTheAgenda() async throws {
        let notifier = makeNotifier()
        _ = await notifier.setEnabled(true)
        #expect(scheduler.scheduled.isEmpty)

        try addRotation()
        await notifier.resync()

        #expect(scheduler.scheduled.count == 14)
    }

    @Test func rememberedAcrossLaunches() async throws {
        let notifier = makeNotifier()
        _ = await notifier.setEnabled(true)
        await notifier.setTime(hour: 5, minute: 45)

        let next = makeNotifier()

        #expect(next.isEnabled)
        #expect(next.hour == 5 && next.minute == 45)
    }
}

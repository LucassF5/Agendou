import AgendouCore
import Foundation
import Observation

/// A reminder ready to hand to the system: when it fires and what the day holds.
public struct PlannedReminder: Equatable, Sendable {
    public struct Shift: Equatable, Sendable {
        public var categoryName: String
        public var startsAt: Int64
        public var endsAt: Int64
    }

    public var day: CivilDate
    public var fireAt: Int64
    /// The shifts that start on `day`, in the order they start.
    public var shifts: [Shift]
}

/// The system side of the reminders (local notifications), kept behind a protocol so it can be faked.
public protocol ReminderScheduling {
    /// Asks the user for permission to notify; `true` when it is granted.
    func requestAuthorization() async -> Bool
    /// Removes every reminder scheduled before and schedules `reminders` in their place.
    func replaceAll(with reminders: [PlannedReminder]) async
}

/// The daily "you have a shift today" reminder: one per day with shifts, at a time the user picks.
///
/// Reminders are local and only cover the next `ShiftReminders.windowDays` days, so `resync()` runs
/// whenever the app opens or the agenda changes.
@Observable
public final class ShiftNotifier {
    @ObservationIgnored private let store: AgendaStore
    @ObservationIgnored private let scheduler: any ReminderScheduling
    @ObservationIgnored private let defaults: UserDefaults

    public private(set) var isEnabled: Bool
    public private(set) var hour: Int
    public private(set) var minute: Int

    private enum Key {
        static let enabled = "reminder.enabled"
        static let hour = "reminder.hour"
        static let minute = "reminder.minute"
    }

    public init(store: AgendaStore, scheduler: any ReminderScheduling, defaults: UserDefaults = .standard) {
        self.store = store
        self.scheduler = scheduler
        self.defaults = defaults
        isEnabled = defaults.bool(forKey: Key.enabled)
        hour = defaults.object(forKey: Key.hour) as? Int ?? 7
        minute = defaults.object(forKey: Key.minute) as? Int ?? 0
    }

    /// Turns the reminder on or off. Turning it on asks for permission first; when it is denied the
    /// reminder stays off and this returns `false`.
    @discardableResult
    public func setEnabled(_ enabled: Bool) async -> Bool {
        if enabled, !(await scheduler.requestAuthorization()) {
            await resync()
            return false
        }
        isEnabled = enabled
        defaults.set(enabled, forKey: Key.enabled)
        await resync()
        return true
    }

    public func setTime(hour: Int, minute: Int) async {
        self.hour = hour
        self.minute = minute
        defaults.set(hour, forKey: Key.hour)
        defaults.set(minute, forKey: Key.minute)
        await resync()
    }

    /// Rebuilds the scheduled reminders from the current agenda.
    public func resync() async {
        await scheduler.replaceAll(with: isEnabled ? plannedReminders() : [])
    }

    private func plannedReminders() -> [PlannedReminder] {
        let now = store.now
        let today = CivilCalendar.date(containing: now)
        let end = CivilCalendar.interval(of: today.adding(days: ShiftReminders.windowDays)).lowerBound
        let occurrences = store.expand(in: CivilCalendar.interval(of: today).lowerBound..<end).occurrences
        return ShiftReminders.plan(occurrences: occurrences, hour: hour, minute: minute, now: now)
            .map { reminder in
                PlannedReminder(
                    day: reminder.day, fireAt: reminder.fireAt,
                    shifts: reminder.shifts.map { shift in
                        PlannedReminder.Shift(
                            categoryName: store.category(id: shift.categoryID)?.name ?? "",
                            startsAt: shift.startsAt, endsAt: shift.endsAt)
                    })
            }
    }
}

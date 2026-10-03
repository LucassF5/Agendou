import Foundation

/// One reminder for a day with shifts: when to fire and the shifts that start that day.
public struct ShiftReminder: Equatable, Sendable {
    public var day: CivilDate
    public var fireAt: Int64
    /// The shifts that start on `day`, in the order they start.
    public var shifts: [Occurrence]
}

public enum ShiftReminders {
    /// How many days ahead reminders are scheduled; the app refreshes them every time it opens.
    public static let windowDays = 30

    /// One reminder per day that has a shift starting in it, fired at `hour:minute` workplace time.
    ///
    /// A shift belongs to the day it starts, so one that crosses midnight does not add a second day.
    /// The window is `windowDays` civil days from today; a reminder whose time has already passed is dropped.
    public static func plan(
        occurrences: [Occurrence], hour: Int, minute: Int, now: Int64, windowDays: Int = windowDays
    ) -> [ShiftReminder] {
        let today = CivilCalendar.date(containing: now)
        let last = today.adding(days: windowDays - 1)
        let byDay = Dictionary(grouping: occurrences, by: { CivilCalendar.date(containing: $0.startsAt) })
        return byDay.keys
            .filter { $0 >= today && $0 <= last }
            .sorted()
            .compactMap { day in
                let fireAt = CivilCalendar.instant(of: day, hour: hour, minute: minute)
                guard fireAt > now, let shifts = byDay[day] else { return nil }
                return ShiftReminder(
                    day: day, fireAt: fireAt,
                    shifts: shifts.sorted { ($0.startsAt, $0.categoryID.uuidString) < ($1.startsAt, $1.categoryID.uuidString) })
            }
    }
}

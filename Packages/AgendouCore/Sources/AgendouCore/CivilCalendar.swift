import Foundation

/// Calendar used to turn instants into civil days and months.
///
/// Shifts are bucketed in the workplace time zone, never the device's: travelling to another
/// time zone must not move a night shift to a different day.
public enum CivilCalendar {
    public static let timeZone = TimeZone(identifier: "America/Sao_Paulo")!

    public static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }()

    /// The civil day an instant falls on.
    public static func date(containing instant: Int64) -> CivilDate {
        let components = calendar.dateComponents([.year, .month, .day], from: Date(epochSeconds: instant))
        return CivilDate(year: components.year!, month: components.month!, day: components.day!)
    }

    /// The instant of a wall-clock time on a civil day.
    public static func instant(of date: CivilDate, hour: Int, minute: Int, second: Int = 0) -> Int64 {
        let components = DateComponents(
            year: date.year, month: date.month, day: date.day, hour: hour, minute: minute, second: second)
        return calendar.date(from: components)!.epochSeconds
    }

    /// 1 = Sunday … 7 = Saturday, as `Calendar` numbers weekdays.
    public static func weekday(of date: CivilDate) -> Int {
        calendar.component(.weekday, from: Date(epochSeconds: instant(of: date, hour: 12, minute: 0)))
    }

    /// `[start of the day, start of the next day)`.
    public static func interval(of date: CivilDate) -> Range<Int64> {
        let start = instant(of: date, hour: 0, minute: 0)
        let next = calendar.date(byAdding: .day, value: 1, to: Date(epochSeconds: start))!
        return start..<next.epochSeconds
    }

    /// `[first instant of the month, first instant of the next month)`.
    public static func interval(of month: CivilMonth) -> Range<Int64> {
        instant(of: month.firstDay, hour: 0, minute: 0)..<instant(of: month.next.firstDay, hour: 0, minute: 0)
    }

    /// `[first instant of the year, first instant of the next year)`.
    public static func interval(ofYear year: Int) -> Range<Int64> {
        let start = CivilDate(year: year, month: 1, day: 1)
        let end = CivilDate(year: year + 1, month: 1, day: 1)
        return instant(of: start, hour: 0, minute: 0)..<instant(of: end, hour: 0, minute: 0)
    }
}

extension CivilDate {
    /// The civil day `days` after this one (before it when negative).
    public func adding(days: Int) -> CivilDate {
        let noon = Date(epochSeconds: CivilCalendar.instant(of: self, hour: 12, minute: 0))
        let moved = CivilCalendar.calendar.date(byAdding: .day, value: days, to: noon)!
        return CivilCalendar.date(containing: moved.epochSeconds)
    }
}

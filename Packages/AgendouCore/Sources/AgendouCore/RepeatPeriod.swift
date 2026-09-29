/// How long a schedule version repeats: whole calendar months counted from the month of the day it
/// starts (that month is the first), or through a chosen last day.
public enum RepeatPeriod: Hashable, Sendable {
    case months(Int)
    /// Inclusive last day.
    case through(CivilDate)

    /// Exclusive end instant: midnight of the day after the last day.
    public func end(startingOn day: CivilDate) -> Int64 {
        switch self {
        case .months(let count):
            CivilCalendar.interval(of: CivilMonth(day).adding(months: count)).lowerBound
        case .through(let lastDay):
            CivilCalendar.interval(of: lastDay).upperBound
        }
    }

    public func lastDay(startingOn day: CivilDate) -> CivilDate {
        CivilCalendar.date(containing: end(startingOn: day) - 1)
    }
}

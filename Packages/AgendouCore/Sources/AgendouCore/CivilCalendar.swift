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
}

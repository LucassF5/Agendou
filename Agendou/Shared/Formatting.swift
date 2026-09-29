import AgendouCore
import AgendouStore
import Foundation

enum Formatting {
    static let locale = Locale(identifier: "pt_BR")

    /// "12x36", or "12h30x35h30" when a side is not a whole number of hours.
    static func scheduleLabel(workSeconds: Int, restSeconds: Int) -> String {
        "\(hours(workSeconds))x\(hours(restSeconds))"
    }

    static func scheduleLabel(_ schedule: CategorySchedule) -> String {
        scheduleLabel(workSeconds: schedule.workSeconds, restSeconds: schedule.restSeconds)
    }

    /// "12h", "12h30".
    static func duration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        return minutes % 60 == 0 ? "\(minutes / 60)h" : "\(minutes / 60)h\(String(format: "%02d", minutes % 60))"
    }

    /// Always in the workplace time zone and pt-BR, e.g. "29/09/2026 07:00".
    static func dateTime(_ date: Date) -> String {
        date.formatted(style(date: .numeric, time: .shortened))
    }

    /// "29/09/2026".
    static func date(_ date: Date) -> String {
        date.formatted(style(date: .numeric, time: .omitted))
    }

    /// "07:00".
    static func time(_ date: Date) -> String {
        date.formatted(style(date: .omitted, time: .shortened))
    }

    static func style(date: Date.FormatStyle.DateStyle, time: Date.FormatStyle.TimeStyle) -> Date.FormatStyle {
        Date.FormatStyle(
            date: date, time: time, locale: locale, calendar: CivilCalendar.calendar, timeZone: CivilCalendar.timeZone)
    }

    private static func hours(_ seconds: Int) -> String {
        seconds % 3_600 == 0 ? "\(seconds / 3_600)" : duration(seconds)
    }
}

enum DefaultTimes {
    /// The next 07:00 in the workplace time zone: the usual start of a day shift.
    static func nextShiftStart(after now: Date) -> Date {
        let today = CivilCalendar.date(containing: now.epochSeconds)
        let sevenToday = CivilCalendar.instant(of: today, hour: 7, minute: 0)
        if sevenToday > now.epochSeconds { return Date(epochSeconds: sevenToday) }
        return Date(epochSeconds: sevenToday + 86_400)
    }
}

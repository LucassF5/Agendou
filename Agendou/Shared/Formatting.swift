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
        "\(Self.date(date)) \(time(date))"
    }

    /// "29/09/2026".
    static func date(_ date: Date) -> String {
        date.formatted(style(date: .numeric, time: .omitted))
    }

    /// "07:00", with the leading zero as it is written in Brazil.
    static func time(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle(locale: locale, calendar: CivilCalendar.calendar, timeZone: CivilCalendar.timeZone)
                .hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    }

    /// "19:00 – 07:00 (+1)": the "+n" counts the days the shift runs past its start day.
    static func timeRange(_ occurrence: Occurrence) -> String {
        let start = Date(epochSeconds: occurrence.startsAt)
        let end = Date(epochSeconds: occurrence.endsAt)
        let startDay = CivilCalendar.date(containing: occurrence.startsAt)
        let endDay = CivilCalendar.date(containing: occurrence.endsAt)
        let days =
            CivilCalendar.calendar.dateComponents(
                [.day], from: Date(epochSeconds: CivilCalendar.interval(of: startDay).lowerBound),
                to: Date(epochSeconds: CivilCalendar.interval(of: endDay).lowerBound)
            ).day ?? 0
        let range = "\(time(start)) – \(time(end))"
        return days > 0 ? "\(range) (+\(days))" : range
    }

    /// "terça-feira, 29 de setembro".
    static func dayTitle(_ day: CivilDate) -> String {
        let noon = Date(epochSeconds: CivilCalendar.instant(of: day, hour: 12, minute: 0))
        return noon.formatted(
            Date.FormatStyle(locale: locale, calendar: CivilCalendar.calendar, timeZone: CivilCalendar.timeZone)
                .weekday(.wide).day().month(.wide))
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

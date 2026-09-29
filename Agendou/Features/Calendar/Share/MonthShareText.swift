import AgendouCore
import Foundation

/// The month as plain text, one line per shift, for people who prefer to read or copy it.
enum MonthShareText {
    static func make(_ share: MonthShare) -> String {
        let names = Dictionary(uniqueKeysWithValues: share.categories.map { ($0.id, $0.name) })
        var lines = [String(localized: "Plantões de \(Formatting.monthYear(share.month))"), ""]
        for shift in share.shifts {
            let day = CivilCalendar.date(containing: shift.startsAt)
            let weekday = Formatting.shortWeekday(day).replacingOccurrences(of: ".", with: "")
            let range = Formatting.timeRange(startsAt: shift.startsAt, endsAt: shift.endsAt)
            lines.append("\(weekday) \(String(format: "%02d", day.day)) · \(names[shift.categoryID] ?? "") · \(range)")
        }
        lines.append("")
        lines.append(String(localized: "Total: \(Formatting.shiftCount(share.totalCount))"))
        lines.append(share.categories.map { "\($0.name): \($0.count)" }.joined(separator: " · "))
        return lines.joined(separator: "\n")
    }
}

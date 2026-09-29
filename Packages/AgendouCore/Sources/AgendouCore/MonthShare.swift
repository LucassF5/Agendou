import Foundation

/// A month of shifts to show someone else: the shifts of the chosen categories that start in the month,
/// and a legend with a short label, the count and the usual time of each category.
public struct MonthShare: Equatable, Sendable {
    public struct Category: Equatable, Sendable, Identifiable {
        public var id: UUID
        public var name: String
        /// The name's first word, or a letter for every category when two share their first word.
        public var shortLabel: String
        public var count: Int
        /// Most common start, in seconds after midnight (workplace time).
        public var usualStart: Int64
        /// Length of the most common shift.
        public var usualDuration: Int64
    }

    public struct Shift: Equatable, Sendable {
        public var categoryID: UUID
        public var startsAt: Int64
        public var endsAt: Int64
    }

    public var month: CivilMonth
    /// Most shifts first, then by name.
    public var categories: [Category]
    /// In the order they start.
    public var shifts: [Shift]

    public var totalCount: Int {
        shifts.count
    }

    /// - Parameters:
    ///   - occurrences: shifts to consider; only those starting in `month` are kept.
    ///   - names: category names; shifts of categories without a name are left out.
    ///   - including: the categories to keep; `nil` keeps them all.
    public init(month: CivilMonth, occurrences: [Occurrence], names: [UUID: String], including: Set<UUID>? = nil) {
        self.month = month
        let interval = CivilCalendar.interval(of: month)
        shifts =
            occurrences
            .filter { occurrence in
                interval.contains(occurrence.startsAt) && names[occurrence.categoryID] != nil
                    && (including?.contains(occurrence.categoryID) ?? true)
            }
            .sorted { ($0.startsAt, $0.categoryID.uuidString) < ($1.startsAt, $1.categoryID.uuidString) }
            .map { Shift(categoryID: $0.categoryID, startsAt: $0.startsAt, endsAt: $0.endsAt) }

        var legend: [Category] = []
        for (id, categoryShifts) in Dictionary(grouping: shifts, by: { $0.categoryID }) {
            let usual = Self.usualTime(of: categoryShifts)
            let name = (names[id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            legend.append(
                Category(
                    id: id, name: name, shortLabel: "", count: categoryShifts.count, usualStart: usual.start,
                    usualDuration: usual.duration))
        }
        legend.sort { $0.count != $1.count ? $0.count > $1.count : $0.name < $1.name }
        let labels = Self.shortLabels(for: legend.map { $0.name })
        for index in legend.indices {
            legend[index].shortLabel = labels[index]
        }
        categories = legend
    }

    /// The shifts that start on `day`, in order.
    public func shifts(on day: CivilDate) -> [Shift] {
        let interval = CivilCalendar.interval(of: day)
        return shifts.filter { interval.contains($0.startsAt) }
    }

    /// First words, unless two of them repeat: then a letter for every category, in legend order.
    static func shortLabels(for names: [String]) -> [String] {
        let firstWords = names.map { name in
            name.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? name
        }
        guard Set(firstWords.map { $0.lowercased() }).count < firstWords.count else { return firstWords }
        return names.indices.map { String(UnicodeScalar(UInt8(65 + $0 % 26))) }
    }

    /// The most common (start time of day, length); a tie goes to the earlier start, then the shorter one.
    private static func usualTime(of shifts: [Shift]) -> (start: Int64, duration: Int64) {
        var counts: [TimeOfDay: Int] = [:]
        for shift in shifts {
            let midnight = CivilCalendar.interval(of: CivilCalendar.date(containing: shift.startsAt)).lowerBound
            counts[TimeOfDay(start: shift.startsAt - midnight, duration: shift.endsAt - shift.startsAt), default: 0] +=
                1
        }
        let usual = counts.max { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value < rhs.value }
            if lhs.key.start != rhs.key.start { return lhs.key.start > rhs.key.start }
            return lhs.key.duration > rhs.key.duration
        }
        return (usual?.key.start ?? 0, usual?.key.duration ?? 0)
    }

    private struct TimeOfDay: Hashable {
        let start: Int64
        let duration: Int64
    }
}

import Foundation

/// One state of the next-shift widget: it holds from `date` until the next entry.
public struct ShiftTimelineEntry: Equatable, Sendable {
    /// When this state starts to hold, in epoch seconds.
    public var date: Int64
    /// The shift in progress at `date`, or else the next one. `nil` when there is none.
    public var shift: Occurrence?
    /// The shifts after `shift`, soonest first, at most `ShiftTimeline.followingLimit`.
    public var following: [Occurrence]

    public init(date: Int64, shift: Occurrence?, following: [Occurrence]) {
        self.date = date
        self.shift = shift
        self.following = following
    }

    public var isInProgress: Bool {
        shift.map { $0.startsAt <= date } ?? false
    }
}

/// Plans what the widget shows over time, so the system can switch states on its own without the app
/// running: one entry now and one each time a shift starts or ends.
public enum ShiftTimeline {
    public static let followingLimit = 2
    public static let maxEntries = 40
    /// When to ask for a new timeline if nothing is going to change before then.
    public static let emptyRefresh: Int64 = 12 * 3_600

    /// `occurrences` are the shifts not over at `now`, soonest first (`ScheduleEngine.occurrencesNotOver`).
    /// Entries cover `window` seconds from `now`, but the headline of each one looks at the whole list, so
    /// a next shift beyond the window is still found.
    public static func entries(occurrences: [Occurrence], now: Int64, window: Int64) -> [ShiftTimelineEntry] {
        var instants: Set<Int64> = [now]
        for occurrence in occurrences {
            for instant in [occurrence.startsAt, occurrence.endsAt] where instant > now && instant < now + window {
                instants.insert(instant)
            }
        }
        return instants.sorted().prefix(maxEntries).map { entry(at: $0, occurrences: occurrences) }
    }

    /// When the widget should ask for a new timeline: when the last entry starts to hold (the window ends
    /// there), or `emptyRefresh` after `now` when nothing is going to change.
    public static func refreshDate(for entries: [ShiftTimelineEntry], now: Int64) -> Int64 {
        guard let last = entries.last, last.date > now else { return now + emptyRefresh }
        return last.date
    }

    private static func entry(at date: Int64, occurrences: [Occurrence]) -> ShiftTimelineEntry {
        let notOver = occurrences.filter { date < $0.endsAt }
        // Sorted by start: the first one that has started is in progress; else the first one is the next.
        guard let headline = notOver.first else {
            return ShiftTimelineEntry(date: date, shift: nil, following: [])
        }
        let following = notOver.dropFirst().prefix(followingLimit)
        return ShiftTimelineEntry(date: date, shift: headline, following: Array(following))
    }
}

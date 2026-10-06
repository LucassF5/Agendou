import AgendouCore
import AgendouStore
import WidgetKit

/// A shift with its category resolved: the widget draws values, never the database.
nonisolated struct WidgetShift: Equatable, Sendable {
    let categoryName: String
    let color: CategoryColor
    let startsAt: Int64
    let endsAt: Int64

    var start: Date { Date(epochSeconds: startsAt) }
    var end: Date { Date(epochSeconds: endsAt) }
}

nonisolated struct NextShiftEntry: TimelineEntry, Sendable {
    let date: Date
    /// In progress at `date`, or else the next one. `nil` when there is none.
    let shift: WidgetShift?
    /// `shift` has started at `date` (`ShiftTimelineEntry.isInProgress`).
    let isInProgress: Bool
    /// The shifts after `shift`, at most two.
    let following: [WidgetShift]
    /// The database could not be opened, as before the first unlock after a reboot: the shifts are unknown,
    /// which is not the same as having none.
    let isUnavailable: Bool

    static func empty(at date: Date) -> NextShiftEntry {
        NextShiftEntry(date: date, shift: nil, isInProgress: false, following: [], isUnavailable: false)
    }

    static func unavailable(at date: Date) -> NextShiftEntry {
        NextShiftEntry(date: date, shift: nil, isInProgress: false, following: [], isUnavailable: true)
    }

    /// For the gallery and previews: a shift starting in three hours, then two more.
    static var sample: NextShiftEntry {
        let now = Date.now
        let first = now.epochSeconds + 3 * 3_600
        func shift(_ name: String, _ color: CategoryColor, from start: Int64) -> WidgetShift {
            WidgetShift(categoryName: name, color: color, startsAt: start, endsAt: start + 12 * 3_600)
        }
        return NextShiftEntry(
            date: now,
            shift: shift("UTI Hospital X", .teal, from: first),
            isInProgress: false,
            following: [
                shift("UTI Hospital X", .teal, from: first + 48 * 3_600),
                shift("Extra", .orange, from: first + 96 * 3_600),
            ],
            isUnavailable: false)
    }

    /// For previews: the same shift, already running for four hours.
    static var sampleInProgress: NextShiftEntry {
        let now = Date.now
        let start = now.epochSeconds - 4 * 3_600
        return NextShiftEntry(
            date: now,
            shift: WidgetShift(
                categoryName: "UTI Hospital X", color: .teal, startsAt: start, endsAt: start + 12 * 3_600),
            isInProgress: true,
            following: sample.following,
            isUnavailable: false)
    }
}

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
    /// The shifts after `shift`, at most two.
    let following: [WidgetShift]

    var isInProgress: Bool {
        shift.map { $0.startsAt <= date.epochSeconds } ?? false
    }

    static func empty(at date: Date) -> NextShiftEntry {
        NextShiftEntry(date: date, shift: nil, following: [])
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
            following: [
                shift("UTI Hospital X", .teal, from: first + 48 * 3_600),
                shift("Extra", .orange, from: first + 96 * 3_600),
            ])
    }

    /// For previews: the same shift, already running for four hours.
    static var sampleInProgress: NextShiftEntry {
        let now = Date.now
        let start = now.epochSeconds - 4 * 3_600
        return NextShiftEntry(
            date: now,
            shift: WidgetShift(
                categoryName: "UTI Hospital X", color: .teal, startsAt: start, endsAt: start + 12 * 3_600),
            following: sample.following)
    }
}

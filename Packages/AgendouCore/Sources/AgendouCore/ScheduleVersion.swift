import Foundation

/// One version (vigência) of a category's rotation: `work` seconds on, `rest` seconds off, forever,
/// in phase with `anchorAt`, valid for occurrences that start in `[startsAt, endsAt)`.
///
/// A version that has started is never edited: changing the rotation closes it and opens another,
/// which is what keeps the past frozen.
public struct ScheduleVersion: Hashable, Sendable, Identifiable {
    public var id: UUID
    public var categoryID: UUID
    public var workSeconds: Int64
    public var restSeconds: Int64
    /// Start of a real shift; fixes the phase of the cycle.
    public var anchorAt: Int64
    /// Inclusive.
    public var startsAt: Int64
    /// Exclusive; `nil` while the version is open.
    public var endsAt: Int64?

    public init(
        id: UUID, categoryID: UUID, workSeconds: Int64, restSeconds: Int64, anchorAt: Int64, startsAt: Int64,
        endsAt: Int64?
    ) {
        self.id = id
        self.categoryID = categoryID
        self.workSeconds = workSeconds
        self.restSeconds = restSeconds
        self.anchorAt = anchorAt
        self.startsAt = startsAt
        self.endsAt = endsAt
    }

    public var cycleSeconds: Int64 {
        workSeconds + restSeconds
    }

    /// Start of the first occurrence that belongs to this version, or `nil` if it ends before any.
    public var firstOccurrenceStart: Int64? {
        firstOccurrenceStart(atOrAfter: startsAt)
    }

    /// Start of the first occurrence of this version at or after `instant`, or `nil` if the version ends
    /// before it.
    public func firstOccurrenceStart(atOrAfter instant: Int64) -> Int64? {
        guard workSeconds > 0, restSeconds > 0 else { return nil }
        let lower = max(startsAt, instant)
        let start = anchorAt + ceilDiv(lower - anchorAt, cycleSeconds) * cycleSeconds
        if let endsAt, start >= endsAt { return nil }
        return start
    }

    /// Starts `anchorAt + k·cycle` that fall in `range` and inside the version.
    func occurrenceStarts(in range: Range<Int64>) -> [Int64] {
        let cycle = cycleSeconds
        guard workSeconds > 0, restSeconds > 0 else { return [] }
        let lower = max(startsAt, range.lowerBound)
        let upper = min(endsAt ?? .max, range.upperBound)
        guard lower < upper else { return [] }

        var starts: [Int64] = []
        var start = anchorAt + ceilDiv(lower - anchorAt, cycle) * cycle
        while start < upper {
            starts.append(start)
            let (next, overflow) = start.addingReportingOverflow(cycle)
            if overflow { break }
            start = next
        }
        return starts
    }
}

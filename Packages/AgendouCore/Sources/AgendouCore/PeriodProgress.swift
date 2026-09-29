/// A period's totals split at `now`: what has already happened and the whole period, planned shifts
/// included. A shift counts whole as soon as it starts, like everywhere else.
public struct PeriodProgress: Equatable, Sendable {
    /// Shifts that have started (`start <= now`).
    public var soFar: PeriodSummary
    /// Every shift in the period.
    public var total: PeriodSummary

    /// Pass the occurrences that start in the period.
    public init(occurrences: some Sequence<Occurrence>, now: Int64) {
        let occurrences = Array(occurrences)
        soFar = PeriodSummary(occurrences: occurrences.filter { $0.startsAt <= now })
        total = PeriodSummary(occurrences: occurrences)
    }
}

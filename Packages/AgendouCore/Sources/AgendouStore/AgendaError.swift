/// Rule violations reported by `AgendaStore`. The app turns them into pt-BR messages.
public enum AgendaError: Error, Equatable, Sendable {
    case emptyName
    case categoryArchived
    /// Work, rest or a shift length that is not positive.
    case invalidDuration
    /// The first version cannot start after its anchor ("desde quando" is at most the next shift).
    case startsAfterAnchor
    case categoryAlreadyHasSchedule
    case noOpenSchedule
    /// A new version never starts in the past.
    case anchorInPast
    case anchorNotAfterCurrentStart
    /// Only the open version is editable, and only if created less than 24h ago or before any of its
    /// shifts started.
    case scheduleLocked
    /// Permanent deletion needs a category with no started shift and nothing marked by hand.
    case categoryHasHistory
    /// Overrides are unique per (category, start, kind).
    case duplicateOverride
    case notScheduled
    case notAdjusted
    case notFound
    /// The period does not cover the first shift, or a renewal does not go past the current end.
    case invalidRepeatEnd
}

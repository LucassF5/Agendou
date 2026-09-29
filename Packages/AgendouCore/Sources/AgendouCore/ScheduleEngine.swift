import Foundation

/// Occurrences in a window, and the generated ones that were cancelled.
public struct Expansion: Equatable, Sendable {
    public var occurrences: [Occurrence]
    /// Generated occurrences suppressed by a cancellation that has no extra at the same start.
    public var cancelled: [Occurrence]
}

public enum ScheduleEngine {
    /// Everything that starts in `range`: generated occurrences, minus cancelled ones, plus extras.
    ///
    /// An occurrence belongs to the window, day and month in which it **starts**, and to the schedule
    /// version in which it starts. Nothing is counted twice at a border.
    public static func expand(schedules: [ScheduleVersion], overrides: [Override], in range: Range<Int64>)
        -> Expansion
    {
        var cancellations: Set<Key> = []
        var extrasByKey: [Key: Override] = [:]
        for override in overrides {
            let key = Key(categoryID: override.categoryID, startsAt: override.startsAt)
            switch override.kind {
            case .cancellation: cancellations.insert(key)
            case .extra: extrasByKey[key] = override
            }
        }

        var occurrences: [Occurrence] = []
        var cancelled: [Occurrence] = []
        var adjustingExtras: Set<UUID> = []
        for schedule in schedules {
            for start in schedule.occurrenceStarts(in: range) {
                let key = Key(categoryID: schedule.categoryID, startsAt: start)
                let generated = Occurrence(
                    categoryID: schedule.categoryID, startsAt: start, endsAt: start + schedule.workSeconds,
                    origin: .scheduled(scheduleID: schedule.id))
                guard cancellations.contains(key) else {
                    occurrences.append(generated)
                    continue
                }
                if let extra = extrasByKey[key] {
                    adjustingExtras.insert(extra.id)
                    occurrences.append(
                        Occurrence(
                            categoryID: extra.categoryID, startsAt: extra.startsAt, endsAt: extra.endsAt,
                            origin: .adjusted(overrideID: extra.id, scheduleID: schedule.id)))
                } else {
                    cancelled.append(generated)
                }
            }
        }

        for extra in extrasByKey.values where range.contains(extra.startsAt) && !adjustingExtras.contains(extra.id) {
            occurrences.append(
                Occurrence(
                    categoryID: extra.categoryID, startsAt: extra.startsAt, endsAt: extra.endsAt,
                    origin: .extra(overrideID: extra.id)))
        }

        return Expansion(
            occurrences: occurrences.sorted(by: chronological), cancelled: cancelled.sorted(by: chronological))
    }

    private struct Key: Hashable {
        let categoryID: UUID
        let startsAt: Int64
    }

    private static func chronological(_ lhs: Occurrence, _ rhs: Occurrence) -> Bool {
        if lhs.startsAt != rhs.startsAt { return lhs.startsAt < rhs.startsAt }
        if lhs.categoryID != rhs.categoryID { return lhs.categoryID.uuidString < rhs.categoryID.uuidString }
        return rank(lhs.origin) < rank(rhs.origin)
    }

    private static func rank(_ origin: Occurrence.Origin) -> Int {
        switch origin {
        case .scheduled: 0
        case .adjusted: 1
        case .extra: 2
        }
    }
}

extension ScheduleEngine {
    /// How far ahead `currentOrNext` looks for the next shift.
    public static let nextShiftHorizon: Int64 = 400 * 86_400

    /// The shift in progress at `now` (`start <= now < end`), or else the next one to start. This is the
    /// one place where a shift counts as "now" by its whole length rather than by its start.
    public static func currentOrNext(
        schedules: [ScheduleVersion], overrides: [Override], now: Int64, horizon: Int64 = nextShiftHorizon
    ) -> Occurrence? {
        // Look back by the longest shift so one that started long ago but is still running is found.
        let longestWork = schedules.map(\.workSeconds).max() ?? 0
        let longestExtra = overrides.filter { $0.kind == .extra }.map { $0.endsAt - $0.startsAt }.max() ?? 0
        let lookback = max(longestWork, longestExtra, 0)
        let occurrences = expand(schedules: schedules, overrides: overrides, in: (now - lookback)..<(now + horizon))
            .occurrences
        if let current = occurrences.first(where: { $0.startsAt <= now && now < $0.endsAt }) {
            return current
        }
        return occurrences.first { $0.startsAt > now }
    }
}

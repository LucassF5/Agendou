import AgendouCore
import Foundation

extension AgendaStore {
    /// The day a renewal counts from: the day after the current end, or today for versions without one.
    public func renewalStart(of schedule: CategorySchedule) -> CivilDate {
        _ = revision
        guard let end = schedule.repeatsUntil else { return CivilCalendar.date(containing: now) }
        return CivilCalendar.date(containing: end.epochSeconds)
    }

    /// Extends the open version, keeping its rhythm. Only the future changes, so it works on versions
    /// that are no longer editable. After the end it continues from the old end: the gap is filled.
    public func renewSchedule(_ schedule: CategorySchedule, period: RepeatPeriod) throws {
        guard schedule.endsAt == nil else { throw AgendaError.noOpenSchedule }
        if let category = schedule.category { try requireActive(category) }
        let end = period.end(startingOn: renewalStart(of: schedule))
        let floor = schedule.repeatsUntil?.epochSeconds ?? now
        guard end > floor else { throw AgendaError.invalidRepeatEnd }
        schedule.repeatsUntil = Date(epochSeconds: end)
        try save()
    }

    /// Open versions of active categories whose period ends within 7 days or has already ended, soonest
    /// first.
    public func schedulesNeedingRenewal() -> [CategorySchedule] {
        let now = self.now
        return activeCategories().compactMap(openSchedule(of:))
            .filter { schedule in
                guard let end = schedule.repeatsUntil?.epochSeconds else { return false }
                return end - now <= 7 * 86_400
            }
            .sorted { ($0.repeatsUntil ?? .distantFuture) < ($1.repeatsUntil ?? .distantFuture) }
    }
}

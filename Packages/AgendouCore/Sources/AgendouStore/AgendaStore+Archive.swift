import AgendouCore
import Foundation
import SwiftData

extension AgendaStore {
    /// Stops a job. The open version closes now, versions that have not started are dropped, and future
    /// extras are deleted. The past stays on the calendar and in the summaries. There is no un-archive:
    /// going back to the job means a new category.
    public func archive(_ category: ShiftCategory) throws {
        try requireActive(category)
        let now = self.now
        for schedule in Array(category.schedules) {
            if schedule.startsAt.epochSeconds >= now {
                context.delete(schedule)
            } else if schedule.endsAt.map({ $0.epochSeconds > now }) ?? true {
                schedule.endsAt = Date(epochSeconds: now)
            }
        }
        for override in Array(category.overrides)
        where override.kindRaw == Override.Kind.extra.rawValue && override.startsAt.epochSeconds > now {
            context.delete(override)
        }
        category.archivedAt = Date(epochSeconds: now)
        try save()
    }

    /// Only a category without history: no shift of it has started and nothing was marked by hand.
    public func canDeletePermanently(_ category: ShiftCategory) -> Bool {
        _ = revision
        let now = self.now
        return category.overrides.isEmpty
            && category.schedules.allSatisfy { schedule in
                guard let first = version(of: schedule)?.firstOccurrenceStart else { return true }
                return first > now
            }
    }

    public func deletePermanently(_ category: ShiftCategory) throws {
        guard canDeletePermanently(category) else { throw AgendaError.categoryHasHistory }
        context.delete(category)
        try save()
    }
}

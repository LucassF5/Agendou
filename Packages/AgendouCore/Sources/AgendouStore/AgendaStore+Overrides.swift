import AgendouCore
import Foundation
import SwiftData

extension AgendaStore {
    public func override(id: UUID) -> ShiftOverride? {
        _ = revision
        return try? context.fetch(FetchDescriptor<ShiftOverride>(predicate: #Predicate { $0.id == id })).first
    }

    /// A shift outside the rotation. Past extras are allowed: marking what happened is not a schedule
    /// change.
    @discardableResult
    public func addExtra(to category: ShiftCategory, startsAt: Date, endsAt: Date) throws -> ShiftOverride {
        try requireActive(category)
        let interval = try validInterval(startsAt, endsAt)
        try requireUnique(in: category, startsAt: interval.lowerBound, kind: .extra)
        let extra = insertOverride(.extra, in: category, interval)
        try save()
        return extra
    }

    /// "Marcar dias": one extra per day, all at the same time, saved together. A day where the category
    /// already has a shift starting at that time is skipped.
    @discardableResult
    public func addExtras(
        to category: ShiftCategory, on days: some Sequence<CivilDate>, hour: Int, minute: Int, durationSeconds: Int
    ) throws -> [ShiftOverride] {
        try requireActive(category)
        guard durationSeconds > 0 else { throw AgendaError.invalidDuration }
        var added: [ShiftOverride] = []
        for day in Set(days).sorted() {
            let start = CivilCalendar.instant(of: day, hour: hour, minute: minute)
            let taken = expand(in: CivilCalendar.interval(of: day)).occurrences.contains {
                $0.categoryID == category.id && $0.startsAt == start
            }
            if taken { continue }
            added.append(insertOverride(.extra, in: category, start..<(start + Int64(durationSeconds))))
        }
        try save()
        return added
    }

    public func updateExtra(_ extra: ShiftOverride, startsAt: Date, endsAt: Date) throws {
        guard extra.kindRaw == Override.Kind.extra.rawValue, let category = extra.category else {
            throw AgendaError.notFound
        }
        try requireActive(category)
        let interval = try validInterval(startsAt, endsAt)
        try requireUnique(in: category, startsAt: interval.lowerBound, kind: .extra, excluding: extra.id)
        extra.startsAt = Date(epochSeconds: interval.lowerBound)
        extra.endsAt = Date(epochSeconds: interval.upperBound)
        try save()
    }

    public func deleteExtra(_ extra: ShiftOverride) throws {
        if let category = extra.category { try requireActive(category) }
        context.delete(extra)
        try save()
    }

    /// Unmarks a generated shift. It moves to `Expansion.cancelled`, from where `restore` brings it back.
    public func cancel(_ occurrence: Occurrence) throws {
        guard case .scheduled = occurrence.origin else { throw AgendaError.notScheduled }
        let category = try activeCategory(occurrence.categoryID)
        try requireUnique(in: category, startsAt: occurrence.startsAt, kind: .cancellation)
        insertOverride(.cancellation, in: category, occurrence.startsAt..<occurrence.endsAt)
        try save()
    }

    public func restore(_ occurrence: Occurrence) throws {
        let category = try activeCategory(occurrence.categoryID)
        guard let cancellation = existingOverride(in: category, startsAt: occurrence.startsAt, kind: .cancellation)
        else { throw AgendaError.notFound }
        context.delete(cancellation)
        try save()
    }

    /// "Editar plantão". A generated shift becomes cancellation + extra; with the same start the calendar
    /// shows it as one adjusted shift. Extras and adjustments just move their extra.
    public func edit(_ occurrence: Occurrence, startsAt: Date, endsAt: Date) throws {
        switch occurrence.origin {
        case .scheduled:
            let category = try activeCategory(occurrence.categoryID)
            let interval = try validInterval(startsAt, endsAt)
            try requireUnique(in: category, startsAt: occurrence.startsAt, kind: .cancellation)
            try requireUnique(in: category, startsAt: interval.lowerBound, kind: .extra)
            insertOverride(.cancellation, in: category, occurrence.startsAt..<occurrence.endsAt)
            insertOverride(.extra, in: category, interval)
            try save()
        case .extra(let overrideID), .adjusted(let overrideID, _):
            guard let extra = override(id: overrideID) else { throw AgendaError.notFound }
            try updateExtra(extra, startsAt: startsAt, endsAt: endsAt)
        }
    }

    /// Deletes both halves of an adjustment, bringing the generated shift back.
    public func undoAdjustment(_ occurrence: Occurrence) throws {
        guard case .adjusted(let overrideID, _) = occurrence.origin else { throw AgendaError.notAdjusted }
        let category = try activeCategory(occurrence.categoryID)
        guard let extra = override(id: overrideID) else { throw AgendaError.notFound }
        context.delete(extra)
        if let cancellation = existingOverride(in: category, startsAt: occurrence.startsAt, kind: .cancellation) {
            context.delete(cancellation)
        }
        try save()
    }

    /// Prefill for the extra form: the open version's shift time on `day`, lasting one `work`.
    public func extraDefaults(for category: ShiftCategory, on day: CivilDate) -> DateInterval? {
        guard let open = openSchedule(of: category) else { return nil }
        let time = CivilCalendar.calendar.dateComponents([.hour, .minute, .second], from: open.anchorAt)
        let start = CivilCalendar.instant(of: day, hour: time.hour!, minute: time.minute!, second: time.second!)
        return DateInterval(
            start: Date(epochSeconds: start), end: Date(epochSeconds: start + Int64(open.workSeconds)))
    }

    // MARK: - Helpers

    private func activeCategory(_ id: UUID) throws -> ShiftCategory {
        guard let category = category(id: id) else { throw AgendaError.notFound }
        try requireActive(category)
        return category
    }

    private func validInterval(_ startsAt: Date, _ endsAt: Date) throws -> Range<Int64> {
        let start = startsAt.epochSeconds
        let end = endsAt.epochSeconds
        guard end > start else { throw AgendaError.invalidDuration }
        return start..<end
    }

    private func existingOverride(in category: ShiftCategory, startsAt: Int64, kind: Override.Kind) -> ShiftOverride? {
        category.overrides.first { $0.kindRaw == kind.rawValue && $0.startsAt.epochSeconds == startsAt }
    }

    private func requireUnique(
        in category: ShiftCategory, startsAt: Int64, kind: Override.Kind, excluding id: UUID? = nil
    ) throws {
        if let existing = existingOverride(in: category, startsAt: startsAt, kind: kind), existing.id != id {
            throw AgendaError.duplicateOverride
        }
    }

    @discardableResult
    private func insertOverride(_ kind: Override.Kind, in category: ShiftCategory, _ interval: Range<Int64>)
        -> ShiftOverride
    {
        let override = ShiftOverride(
            category: category, kindRaw: kind.rawValue, startsAt: Date(epochSeconds: interval.lowerBound),
            endsAt: Date(epochSeconds: interval.upperBound), createdAt: Date(epochSeconds: now))
        context.insert(override)
        return override
    }
}

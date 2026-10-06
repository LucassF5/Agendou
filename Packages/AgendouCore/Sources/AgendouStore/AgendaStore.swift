import AgendouCore
import Foundation
import Observation
import SwiftData

/// The only way the app writes data. Rules SwiftData cannot express live here and are tested.
///
/// Every instant is normalized to whole seconds before it is saved. Views read `revision` (through the
/// query methods) so they refresh after any write.
@Observable
public final class AgendaStore {
    @ObservationIgnored public let context: ModelContext
    @ObservationIgnored private let clock: () -> Date
    /// Holds a container nobody else owns (the sample agenda's): a context does not keep its container alive.
    @ObservationIgnored var ownedContainer: ModelContainer?
    /// Bumped on every successful write.
    public private(set) var revision = 0

    public init(context: ModelContext, clock: @escaping () -> Date = Date.init) {
        self.context = context
        self.clock = clock
    }

    var now: Int64 {
        clock().epochSeconds
    }

    // MARK: - Categories

    public func activeCategories() -> [ShiftCategory] {
        categories().filter { $0.archivedAt == nil }
    }

    public func archivedCategories() -> [ShiftCategory] {
        categories().filter { $0.archivedAt != nil }
    }

    public func category(id: UUID) -> ShiftCategory? {
        _ = revision
        return try? context.fetch(FetchDescriptor<ShiftCategory>(predicate: #Predicate { $0.id == id })).first
    }

    @discardableResult
    public func createCategory(name: String, color: CategoryColor) throws -> ShiftCategory {
        let name = try validName(name)
        let category = ShiftCategory(name: name, colorKey: color.rawValue, createdAt: Date(epochSeconds: now))
        context.insert(category)
        try save()
        return category
    }

    public func updateCategory(_ category: ShiftCategory, name: String, color: CategoryColor) throws {
        category.name = try validName(name)
        category.colorKey = color.rawValue
        try save()
    }

    /// First use of the app creates the "Extra" category for one-off shifts. It is an ordinary category:
    /// it can be renamed or deleted, and it never comes back on its own.
    public func seedIfFirstLaunch(defaults: UserDefaults) {
        let key = "didSeedExtraCategory"
        guard !defaults.bool(forKey: key) else { return }
        defaults.set(true, forKey: key)
        guard categories().isEmpty else { return }
        _ = try? createCategory(name: "Extra", color: .orange)
    }

    // MARK: - Schedules

    /// Whether any schedule was ever set up, open or closed: someone who had one is not a new user.
    public var hasAnySchedule: Bool {
        _ = revision
        return ((try? context.fetchCount(FetchDescriptor<CategorySchedule>())) ?? 0) > 0
    }

    /// Versions of a category, oldest first.
    public func schedules(of category: ShiftCategory) -> [CategorySchedule] {
        _ = revision
        return category.schedules.sorted { $0.startsAt < $1.startsAt }
    }

    public func openSchedule(of category: ShiftCategory) -> CategorySchedule? {
        _ = revision
        return category.schedules.first { $0.endsAt == nil }
    }

    /// First version of a category. `startsAt` ("desde quando") may go back and fill the past, but never
    /// past the anchor. The period counts from the anchor's month, so going back does not use it up.
    @discardableResult
    public func startFirstSchedule(
        for category: ShiftCategory, workSeconds: Int, restSeconds: Int, anchorAt: Date, startsAt: Date,
        period: RepeatPeriod
    ) throws -> CategorySchedule {
        try requireActive(category)
        guard category.schedules.isEmpty else { throw AgendaError.categoryAlreadyHasSchedule }
        try validateDurations(workSeconds, restSeconds)
        let anchor = anchorAt.epochSeconds
        let start = startsAt.epochSeconds
        guard start <= anchor else { throw AgendaError.startsAfterAnchor }
        let end = try periodEnd(period, anchor: anchor)

        let schedule = CategorySchedule(
            category: category, workSeconds: workSeconds, restSeconds: restSeconds,
            anchorAt: Date(epochSeconds: anchor), startsAt: Date(epochSeconds: start),
            repeatsUntil: Date(epochSeconds: end), createdAt: Date(epochSeconds: now))
        context.insert(schedule)
        try save()
        return schedule
    }

    /// "Mudei de escala": the new version starts at the new anchor, never in the past, and closes the
    /// open one at that instant.
    @discardableResult
    public func changeSchedule(
        for category: ShiftCategory, workSeconds: Int, restSeconds: Int, anchorAt: Date, period: RepeatPeriod
    ) throws -> CategorySchedule {
        try requireActive(category)
        guard let open = openSchedule(of: category) else { throw AgendaError.noOpenSchedule }
        try validateDurations(workSeconds, restSeconds)
        let anchor = anchorAt.epochSeconds
        guard anchor >= now else { throw AgendaError.anchorInPast }
        guard anchor > open.startsAt.epochSeconds else { throw AgendaError.anchorNotAfterCurrentStart }
        let end = try periodEnd(period, anchor: anchor)

        open.endsAt = Date(epochSeconds: anchor)
        let schedule = CategorySchedule(
            category: category, workSeconds: workSeconds, restSeconds: restSeconds,
            anchorAt: Date(epochSeconds: anchor), startsAt: Date(epochSeconds: anchor),
            repeatsUntil: Date(epochSeconds: end), createdAt: Date(epochSeconds: now))
        context.insert(schedule)
        try save()
        return schedule
    }

    /// Open version created less than 24h ago, or none of whose shifts has started.
    public func isEditable(_ schedule: CategorySchedule) -> Bool {
        _ = revision
        guard schedule.endsAt == nil else { return false }
        if now - schedule.createdAt.epochSeconds < 86_400 { return true }
        guard let first = version(of: schedule)?.firstOccurrenceStart else { return true }
        return first > now
    }

    /// Fixes a mistake in the open version. For the first version `startsAt` is the "desde quando";
    /// after a change the version starts at its anchor, and the previous one follows it. The previous
    /// version's history up to the earlier of now and the original anchor never changes.
    public func correctSchedule(
        _ schedule: CategorySchedule, workSeconds: Int, restSeconds: Int, anchorAt: Date, startsAt: Date?,
        period: RepeatPeriod
    ) throws {
        guard isEditable(schedule) else { throw AgendaError.scheduleLocked }
        if let category = schedule.category { try requireActive(category) }
        try validateDurations(workSeconds, restSeconds)
        let anchor = anchorAt.epochSeconds
        let end = try periodEnd(period, anchor: anchor)

        if let previous = previousSchedule(of: schedule) {
            guard anchor >= min(now, schedule.anchorAt.epochSeconds) else { throw AgendaError.anchorInPast }
            guard anchor > previous.startsAt.epochSeconds else { throw AgendaError.anchorNotAfterCurrentStart }
            previous.endsAt = Date(epochSeconds: anchor)
            schedule.startsAt = Date(epochSeconds: anchor)
        } else {
            let start = (startsAt ?? anchorAt).epochSeconds
            guard start <= anchor else { throw AgendaError.startsAfterAnchor }
            schedule.startsAt = Date(epochSeconds: start)
        }
        schedule.workSeconds = workSeconds
        schedule.restSeconds = restSeconds
        schedule.anchorAt = Date(epochSeconds: anchor)
        schedule.repeatsUntil = Date(epochSeconds: end)
        try save()
    }

    /// Deletes an editable version and reopens the previous one, if any.
    public func deleteSchedule(_ schedule: CategorySchedule) throws {
        guard isEditable(schedule) else { throw AgendaError.scheduleLocked }
        previousSchedule(of: schedule)?.endsAt = nil
        context.delete(schedule)
        try save()
    }

    // MARK: - Queries

    /// Occurrences starting in `range`, archived categories included: their past stays on the calendar.
    public func expand(in range: Range<Int64>) -> Expansion {
        let (schedules, overrides) = engineInput()
        return ScheduleEngine.expand(schedules: schedules, overrides: overrides, in: range)
    }

    /// The shift in progress now, or else the next one.
    public func currentOrNextShift() -> Occurrence? {
        let (schedules, overrides) = engineInput()
        return ScheduleEngine.currentOrNext(schedules: schedules, overrides: overrides, now: now)
    }

    /// The shift in progress and every one starting within `horizon`, soonest first: what the widget plans
    /// its timeline from. Read-only.
    public func shiftsFromNow(horizon: Int64 = ScheduleEngine.nextShiftHorizon) -> [Occurrence] {
        let (schedules, overrides) = engineInput()
        return ScheduleEngine.occurrencesNotOver(schedules: schedules, overrides: overrides, now: now, horizon: horizon)
    }

    /// How far ahead `upcomingShifts` looks.
    public static let upcomingHorizonDays = 60

    /// The shifts after `shift` (the one on the Home card), starting within the next 60 days, soonest
    /// first. Another category's shift starting at the same instant as `shift` is included.
    public func upcomingShifts(after shift: Occurrence, limit: Int) -> [Occurrence] {
        let horizon = now + Int64(Self.upcomingHorizonDays) * 86_400
        guard shift.startsAt < horizon else { return [] }
        return Array(expand(in: shift.startsAt..<horizon).occurrences.filter { $0 != shift }.prefix(limit))
    }

    private func engineInput() -> ([ScheduleVersion], [Override]) {
        _ = revision
        let schedules = (try? context.fetch(FetchDescriptor<CategorySchedule>())) ?? []
        let overrides = (try? context.fetch(FetchDescriptor<ShiftOverride>())) ?? []
        return (schedules.compactMap(version(of:)), overrides.compactMap(snapshot(of:)))
    }

    // MARK: - Helpers

    func save() throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        revision += 1
    }

    private func categories() -> [ShiftCategory] {
        _ = revision
        let descriptor = FetchDescriptor<ShiftCategory>(sortBy: [SortDescriptor(\.createdAt)])
        return (try? context.fetch(descriptor)) ?? []
    }

    private func validName(_ name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AgendaError.emptyName }
        return trimmed
    }

    func requireActive(_ category: ShiftCategory) throws {
        guard category.archivedAt == nil else { throw AgendaError.categoryArchived }
    }

    func validateDurations(_ workSeconds: Int, _ restSeconds: Int) throws {
        guard workSeconds > 0, restSeconds > 0 else { throw AgendaError.invalidDuration }
    }

    /// The version closed exactly where this one starts.
    public func previousSchedule(of schedule: CategorySchedule) -> CategorySchedule? {
        schedule.category?.schedules.first { $0.id != schedule.id && $0.endsAt == schedule.startsAt }
    }

    /// The version as the schedule engine sees it: it ends at the earlier of `endsAt` (replaced or
    /// archived) and `repeatsUntil` (the period the user chose).
    public func version(of schedule: CategorySchedule) -> ScheduleVersion? {
        guard let categoryID = schedule.category?.id else { return nil }
        let end = [schedule.endsAt, schedule.repeatsUntil].compactMap { $0?.epochSeconds }.min()
        return ScheduleVersion(
            id: schedule.id, categoryID: categoryID, workSeconds: Int64(schedule.workSeconds),
            restSeconds: Int64(schedule.restSeconds), anchorAt: schedule.anchorAt.epochSeconds,
            startsAt: schedule.startsAt.epochSeconds, endsAt: end)
    }

    /// End of `period` counted from the anchor's month; it must leave room for the first shift.
    func periodEnd(_ period: RepeatPeriod, anchor: Int64) throws -> Int64 {
        let end = period.end(startingOn: CivilCalendar.date(containing: anchor))
        guard end > anchor else { throw AgendaError.invalidRepeatEnd }
        return end
    }

    func snapshot(of override: ShiftOverride) -> Override? {
        guard let categoryID = override.category?.id, let kind = Override.Kind(rawValue: override.kindRaw) else {
            return nil
        }
        return Override(
            id: override.id, categoryID: categoryID, kind: kind, startsAt: override.startsAt.epochSeconds,
            endsAt: override.endsAt.epochSeconds)
    }
}

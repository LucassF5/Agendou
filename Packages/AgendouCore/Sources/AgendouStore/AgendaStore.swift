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
    /// past the anchor.
    @discardableResult
    public func startFirstSchedule(
        for category: ShiftCategory, workSeconds: Int, restSeconds: Int, anchorAt: Date, startsAt: Date
    ) throws -> CategorySchedule {
        try requireActive(category)
        guard category.schedules.isEmpty else { throw AgendaError.categoryAlreadyHasSchedule }
        try validateDurations(workSeconds, restSeconds)
        let anchor = anchorAt.epochSeconds
        let start = startsAt.epochSeconds
        guard start <= anchor else { throw AgendaError.startsAfterAnchor }

        let schedule = CategorySchedule(
            category: category, workSeconds: workSeconds, restSeconds: restSeconds,
            anchorAt: Date(epochSeconds: anchor), startsAt: Date(epochSeconds: start),
            createdAt: Date(epochSeconds: now))
        context.insert(schedule)
        try save()
        return schedule
    }

    /// "Mudei de escala": the new version starts at the new anchor, never in the past, and closes the
    /// open one at that instant.
    @discardableResult
    public func changeSchedule(for category: ShiftCategory, workSeconds: Int, restSeconds: Int, anchorAt: Date)
        throws -> CategorySchedule
    {
        try requireActive(category)
        guard let open = openSchedule(of: category) else { throw AgendaError.noOpenSchedule }
        try validateDurations(workSeconds, restSeconds)
        let anchor = anchorAt.epochSeconds
        guard anchor >= now else { throw AgendaError.anchorInPast }
        guard anchor > open.startsAt.epochSeconds else { throw AgendaError.anchorNotAfterCurrentStart }

        open.endsAt = Date(epochSeconds: anchor)
        let schedule = CategorySchedule(
            category: category, workSeconds: workSeconds, restSeconds: restSeconds,
            anchorAt: Date(epochSeconds: anchor), startsAt: Date(epochSeconds: anchor),
            createdAt: Date(epochSeconds: now))
        context.insert(schedule)
        try save()
        return schedule
    }

    /// Open version created less than 24h ago, or none of whose shifts has started.
    public func isEditable(_ schedule: CategorySchedule) -> Bool {
        _ = revision
        guard schedule.endsAt == nil else { return false }
        if now - schedule.createdAt.epochSeconds < 86_400 { return true }
        guard let first = snapshot(of: schedule)?.firstOccurrenceStart else { return true }
        return first > now
    }

    /// Fixes a mistake in the open version. For the first version `startsAt` is the "desde quando";
    /// after a change the version starts at its anchor, and the previous one follows it. The previous
    /// version's history up to the earlier of now and the original anchor never changes.
    public func correctSchedule(
        _ schedule: CategorySchedule, workSeconds: Int, restSeconds: Int, anchorAt: Date, startsAt: Date?
    ) throws {
        guard isEditable(schedule) else { throw AgendaError.scheduleLocked }
        if let category = schedule.category { try requireActive(category) }
        try validateDurations(workSeconds, restSeconds)
        let anchor = anchorAt.epochSeconds

        if let previous = predecessor(of: schedule) {
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
        try save()
    }

    /// Deletes an editable version and reopens the previous one, if any.
    public func deleteSchedule(_ schedule: CategorySchedule) throws {
        guard isEditable(schedule) else { throw AgendaError.scheduleLocked }
        predecessor(of: schedule)?.endsAt = nil
        context.delete(schedule)
        try save()
    }

    // MARK: - Queries

    /// Occurrences starting in `range`, archived categories included: their past stays on the calendar.
    public func expand(in range: Range<Int64>) -> Expansion {
        _ = revision
        let schedules = (try? context.fetch(FetchDescriptor<CategorySchedule>())) ?? []
        let overrides = (try? context.fetch(FetchDescriptor<ShiftOverride>())) ?? []
        return ScheduleEngine.expand(
            schedules: schedules.compactMap(snapshot(of:)), overrides: overrides.compactMap(snapshot(of:)), in: range)
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
    private func predecessor(of schedule: CategorySchedule) -> CategorySchedule? {
        schedule.category?.schedules.first { $0.id != schedule.id && $0.endsAt == schedule.startsAt }
    }

    func snapshot(of schedule: CategorySchedule) -> ScheduleVersion? {
        guard let categoryID = schedule.category?.id else { return nil }
        return ScheduleVersion(
            id: schedule.id, categoryID: categoryID, workSeconds: Int64(schedule.workSeconds),
            restSeconds: Int64(schedule.restSeconds), anchorAt: schedule.anchorAt.epochSeconds,
            startsAt: schedule.startsAt.epochSeconds, endsAt: schedule.endsAt?.epochSeconds)
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

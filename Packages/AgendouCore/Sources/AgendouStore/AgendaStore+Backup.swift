import AgendouCore
import Foundation
import SwiftData

extension AgendaStore {
    /// Everything stored, in a stable order.
    public func makeExport() -> AgendaExport {
        _ = revision
        let categories = ((try? context.fetch(FetchDescriptor<ShiftCategory>())) ?? [])
            .sorted { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }
        let schedules = ((try? context.fetch(FetchDescriptor<CategorySchedule>())) ?? [])
            .sorted { ($0.startsAt, $0.id.uuidString) < ($1.startsAt, $1.id.uuidString) }
        let overrides = ((try? context.fetch(FetchDescriptor<ShiftOverride>())) ?? [])
            .sorted { ($0.startsAt, $0.kindRaw, $0.id.uuidString) < ($1.startsAt, $1.kindRaw, $1.id.uuidString) }
        let notes = ((try? context.fetch(FetchDescriptor<DayNote>())) ?? []).sorted { $0.day < $1.day }

        return AgendaExport(
            schemaVersion: AgendaExport.currentSchemaVersion,
            exportedAt: Date(epochSeconds: now),
            categories: categories.map {
                .init(
                    id: $0.id, name: $0.name, colorKey: $0.colorKey, archivedAt: $0.archivedAt, createdAt: $0.createdAt)
            },
            schedules: schedules.compactMap { schedule in
                schedule.category.map {
                    .init(
                        id: schedule.id, categoryId: $0.id, workSeconds: schedule.workSeconds,
                        restSeconds: schedule.restSeconds, anchorAt: schedule.anchorAt, startsAt: schedule.startsAt,
                        endsAt: schedule.endsAt, repeatsUntil: schedule.repeatsUntil, createdAt: schedule.createdAt)
                }
            },
            overrides: overrides.compactMap { override in
                guard let category = override.category, let kind = Override.Kind(rawValue: override.kindRaw) else {
                    return nil
                }
                return .init(
                    id: override.id, categoryId: category.id, kind: kind == .extra ? "extra" : "cancellation",
                    startsAt: override.startsAt, endsAt: override.endsAt, createdAt: override.createdAt)
            },
            dayNotes: notes.map { .init(id: $0.id, day: $0.day, body: $0.body, updatedAt: $0.updatedAt) })
    }

    public func exportData() throws -> Data {
        try makeExport().encoded()
    }

    /// Replaces all data with a validated export, in a single save: either everything is replaced or
    /// nothing changes.
    public func replaceAll(with export: AgendaExport) throws {
        try export.validate()
        for category in (try? context.fetch(FetchDescriptor<ShiftCategory>())) ?? [] { context.delete(category) }
        for schedule in (try? context.fetch(FetchDescriptor<CategorySchedule>())) ?? [] { context.delete(schedule) }
        for override in (try? context.fetch(FetchDescriptor<ShiftOverride>())) ?? [] { context.delete(override) }
        for note in (try? context.fetch(FetchDescriptor<DayNote>())) ?? [] { context.delete(note) }

        var categories: [UUID: ShiftCategory] = [:]
        for record in export.categories {
            let category = ShiftCategory(
                id: record.id, name: record.name, colorKey: record.colorKey,
                archivedAt: record.archivedAt.map(normalized), createdAt: normalized(record.createdAt))
            context.insert(category)
            categories[record.id] = category
        }
        for record in export.schedules {
            context.insert(
                CategorySchedule(
                    id: record.id, category: categories[record.categoryId], workSeconds: record.workSeconds,
                    restSeconds: record.restSeconds, anchorAt: normalized(record.anchorAt),
                    startsAt: normalized(record.startsAt), endsAt: record.endsAt.map(normalized),
                    repeatsUntil: record.repeatsUntil.map(normalized), createdAt: normalized(record.createdAt)))
        }
        for record in export.overrides {
            let kind: Override.Kind = record.kind == "extra" ? .extra : .cancellation
            context.insert(
                ShiftOverride(
                    id: record.id, category: categories[record.categoryId], kindRaw: kind.rawValue,
                    startsAt: normalized(record.startsAt), endsAt: normalized(record.endsAt),
                    createdAt: normalized(record.createdAt)))
        }
        for record in export.dayNotes {
            context.insert(
                DayNote(id: record.id, day: record.day, body: record.body, updatedAt: normalized(record.updatedAt)))
        }
        try save()
    }

    private func normalized(_ date: Date) -> Date {
        Date(epochSeconds: date.epochSeconds)
    }
}

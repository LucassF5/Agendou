import AgendouCore
import Foundation
import SwiftData
import Testing

@testable import AgendouStore

struct ExportImportTests {
    /// A store with every kind of data: active and archived categories, a schedule change, extras,
    /// a cancellation, an adjustment and notes.
    private func populated() throws -> TestAgenda {
        let agenda = TestAgenda(now: at(2026, 9, 29, 12))
        let uti = try agenda.category12x36(name: "UTI", anchor: at(2026, 9, 1, 7), startsAt: at(2026, 8, 1, 0))
        _ = try agenda.store.changeSchedule(
            for: uti, workSeconds: 24 * hour, restSeconds: 48 * hour, anchorAt: at(2026, 10, 3, 7))
        let ps = try agenda.category12x36(name: "PS", anchor: at(2026, 9, 2, 19))
        _ = try agenda.store.addExtra(to: ps, startsAt: at(2026, 9, 10, 7), endsAt: at(2026, 9, 10, 13))
        let september = agenda.month(2026, 9).occurrences
        let scheduled = try #require(september.first { $0.categoryID == uti.id })
        try agenda.store.cancel(scheduled)
        let other = try #require(september.last { $0.categoryID == uti.id && $0.startsAt != scheduled.startsAt })
        try agenda.store.edit(
            other, startsAt: Date(epochSeconds: other.startsAt), endsAt: Date(epochSeconds: other.startsAt + 6 * 3_600))
        try agenda.store.archive(ps)
        try agenda.store.setNote("Troquei com a Ana", for: CivilDate(year: 2026, month: 9, day: 5))
        return agenda
    }

    private func year(_ agenda: TestAgenda) -> Expansion {
        agenda.store.expand(in: CivilCalendar.interval(ofYear: 2026))
    }

    @Test func roundTripsIntoAFreshStore() throws {
        let source = try populated()
        let data = try source.store.exportData()

        let target = TestAgenda(now: source.now)
        try target.store.replaceAll(with: try AgendaExport.decode(data))

        #expect(target.store.makeExport() == source.store.makeExport())
        #expect(year(target) == year(source))
        #expect(target.store.note(for: CivilDate(year: 2026, month: 9, day: 5))?.body == "Troquei com a Ana")
        #expect(target.store.archivedCategories().map(\.name) == ["PS"])
    }

    @Test func reimportingIntoTheSameStoreChangesNothing() throws {
        let agenda = try populated()
        let before = agenda.store.makeExport()
        let expansion = year(agenda)

        try agenda.store.replaceAll(with: try AgendaExport.decode(agenda.store.exportData()))

        #expect(agenda.store.makeExport() == before)
        #expect(year(agenda) == expansion)
    }

    @Test func importReplacesEverythingThatWasThere() throws {
        let source = try populated()
        let target = TestAgenda()
        _ = try target.category12x36(name: "Antiga", anchor: at(2026, 10, 1, 7))
        try target.store.setNote("apagar", for: CivilDate(year: 2026, month: 1, day: 1))

        try target.store.replaceAll(with: try AgendaExport.decode(source.store.exportData()))

        #expect(Set(target.store.activeCategories().map(\.name)) == ["UTI"])
        #expect(target.store.note(for: CivilDate(year: 2026, month: 1, day: 1)) == nil)
    }

    @Test func writesTheDocumentedFormat() throws {
        let agenda = try populated()
        let json = try #require(String(data: try agenda.store.exportData(), encoding: .utf8))
        let object = try #require(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])

        #expect(object["schemaVersion"] as? Int == 1)
        #expect(object["exportedAt"] as? String == "2026-09-29T15:00:00Z")
        #expect(
            Set(object.keys) == ["schemaVersion", "exportedAt", "categories", "schedules", "overrides", "dayNotes"])
        let overrides = try #require(object["overrides"] as? [[String: Any]])
        #expect(Set(overrides.compactMap { $0["kind"] as? String }) == ["extra", "cancellation"])
        let notes = try #require(object["dayNotes"] as? [[String: Any]])
        #expect(notes.first?["day"] as? String == "2026-09-05")
        #expect(!json.contains("."), "instants have no fractional seconds and nothing else has a dot")
    }

    @Test func replacingWithAnInvalidExportLeavesTheStoreUntouched() throws {
        let agenda = try populated()
        let before = agenda.store.makeExport()
        var invalid = before
        invalid.schedules[0].workSeconds = 0

        #expect(throws: AgendaImportError.invalidSchedule) { try agenda.store.replaceAll(with: invalid) }
        #expect(agenda.store.makeExport() == before)
    }
}

struct ImportValidationTests {
    private let category = UUID()

    private func document(
        schemaVersion: Int = 1, categories: String? = nil, schedules: String = "[]", overrides: String = "[]",
        dayNotes: String = "[]"
    ) -> Data {
        let categories =
            categories
                ?? """
                [{"id": "\(category)", "name": "UTI", "colorKey": "teal", "createdAt": "2026-09-01T10:00:00Z"}]
                """
        return Data(
            """
            {"schemaVersion": \(schemaVersion), "exportedAt": "2026-09-29T15:00:00Z", "categories": \(categories),
             "schedules": \(schedules), "overrides": \(overrides), "dayNotes": \(dayNotes)}
            """.utf8)
    }

    private func schedule(
        id: UUID = UUID(), category: UUID? = nil, work: Int = 43_200, rest: Int = 129_600,
        anchor: String = "2026-09-01T10:00:00Z", starts: String = "2026-09-01T10:00:00Z", ends: String? = nil
    ) -> String {
        let ends = ends.map { #", "endsAt": "\#($0)""# } ?? ""
        return """
            {"id": "\(id)", "categoryId": "\(category ?? self.category)", "workSeconds": \(work), "restSeconds": \(rest),
             "anchorAt": "\(anchor)", "startsAt": "\(starts)"\(ends), "createdAt": "2026-09-01T10:00:00Z"}
            """
    }

    private func override(
        kind: String = "extra", starts: String = "2026-09-10T10:00:00Z", ends: String = "2026-09-10T22:00:00Z"
    )
        -> String
    {
        """
        {"id": "\(UUID())", "categoryId": "\(category)", "kind": "\(kind)", "startsAt": "\(starts)",
         "endsAt": "\(ends)", "createdAt": "2026-09-01T10:00:00Z"}
        """
    }

    @Test func acceptsAValidDocument() throws {
        let export = try AgendaExport.decode(
            document(
                schedules: "[\(schedule())]", overrides: "[\(override())]",
                dayNotes:
                    #"[{"id": "\#(UUID())", "day": "2026-09-05", "body": "x", "updatedAt": "2026-09-05T10:00:00Z"}]"#))
        #expect(export.schedules.count == 1)
        #expect(export.overrides.count == 1)
        #expect(export.dayNotes.count == 1)
    }

    @Test func rejectsGarbage() {
        #expect(throws: AgendaImportError.unreadable) { try AgendaExport.decode(Data("not json".utf8)) }
    }

    @Test func rejectsFractionalSeconds() {
        #expect(throws: AgendaImportError.unreadable) {
            try AgendaExport.decode(document(schedules: "[\(schedule(anchor: "2026-09-01T10:00:00.500Z"))]"))
        }
    }

    @Test func rejectsANewerSchemaVersion() {
        #expect(throws: AgendaImportError.unsupportedVersion(2)) { try AgendaExport.decode(document(schemaVersion: 2)) }
    }

    @Test func rejectsReferencesToMissingCategories() {
        #expect(throws: AgendaImportError.unknownCategory) {
            try AgendaExport.decode(document(schedules: "[\(schedule(category: UUID()))]"))
        }
    }

    @Test func rejectsDuplicateIDs() {
        let id = UUID()
        #expect(throws: AgendaImportError.duplicateID) {
            try AgendaExport.decode(
                document(
                    schedules:
                        "[\(schedule(id: id, ends: "2026-09-10T10:00:00Z")), \(schedule(id: id, anchor: "2026-09-10T10:00:00Z", starts: "2026-09-10T10:00:00Z"))]"
                ))
        }
    }

    @Test(
        arguments: [
            (0, 129_600, "2026-09-01T10:00:00Z", nil),
            (43_200, 0, "2026-09-01T10:00:00Z", nil),
            (43_200, 129_600, "2026-09-02T10:00:00Z", nil),
            (43_200, 129_600, "2026-09-01T10:00:00Z", "2026-09-01T10:00:00Z"),
        ] as [(Int, Int, String, String?)])
    func rejectsInvalidSchedules(work: Int, rest: Int, starts: String, ends: String?) {
        #expect(throws: AgendaImportError.invalidSchedule) {
            try AgendaExport.decode(
                document(schedules: "[\(schedule(work: work, rest: rest, starts: starts, ends: ends))]"))
        }
    }

    @Test func rejectsTwoOpenSchedulesInACategory() {
        #expect(throws: AgendaImportError.overlappingSchedules) {
            try AgendaExport.decode(
                document(
                    schedules:
                        "[\(schedule()), \(schedule(anchor: "2026-09-10T10:00:00Z", starts: "2026-09-10T10:00:00Z"))]"))
        }
    }

    @Test func rejectsOverlappingSchedules() {
        #expect(throws: AgendaImportError.overlappingSchedules) {
            try AgendaExport.decode(
                document(
                    schedules:
                        "[\(schedule(ends: "2026-09-20T10:00:00Z")), \(schedule(anchor: "2026-09-10T10:00:00Z", starts: "2026-09-10T10:00:00Z"))]"
                ))
        }
    }

    @Test func rejectsInvalidOverrides() {
        #expect(throws: AgendaImportError.invalidOverride) {
            try AgendaExport.decode(document(overrides: "[\(override(kind: "swap"))]"))
        }
        #expect(throws: AgendaImportError.invalidOverride) {
            try AgendaExport.decode(document(overrides: "[\(override(ends: "2026-09-10T10:00:00Z"))]"))
        }
    }

    @Test func rejectsDuplicateOverrides() {
        #expect(throws: AgendaImportError.duplicateOverride) {
            try AgendaExport.decode(document(overrides: "[\(override()), \(override(ends: "2026-09-10T20:00:00Z"))]"))
        }
    }

    @Test(arguments: ["2026-02-30", "05/09/2026"])
    func rejectsInvalidDays(day: String) {
        #expect(throws: AgendaImportError.invalidDayNote) {
            try AgendaExport.decode(
                document(
                    dayNotes:
                        #"[{"id": "\#(UUID())", "day": "\#(day)", "body": "x", "updatedAt": "2026-09-05T10:00:00Z"}]"#))
        }
    }

    @Test func rejectsTwoNotesForOneDay() {
        let note = #"{"id": "\#(UUID())", "day": "2026-09-05", "body": "x", "updatedAt": "2026-09-05T10:00:00Z"}"#
        let other = #"{"id": "\#(UUID())", "day": "2026-09-05", "body": "y", "updatedAt": "2026-09-05T10:00:00Z"}"#
        #expect(throws: AgendaImportError.invalidDayNote) {
            try AgendaExport.decode(document(dayNotes: "[\(note), \(other)]"))
        }
    }
}

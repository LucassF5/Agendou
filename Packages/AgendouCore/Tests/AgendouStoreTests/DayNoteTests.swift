import AgendouCore
import Foundation
import SwiftData
import Testing

@testable import AgendouStore

struct DayNoteTests {
    private let day = CivilDate(year: 2026, month: 10, day: 1)

    @Test func savesOneNotePerDay() throws {
        let agenda = TestAgenda()
        try agenda.store.setNote("Troquei com a Ana", for: day)

        let note = try #require(agenda.store.note(for: day))
        #expect(note.body == "Troquei com a Ana")
        #expect(note.day == "2026-10-01")
        #expect(note.updatedAt == agenda.now)
        #expect(agenda.store.note(for: CivilDate(year: 2026, month: 10, day: 2)) == nil)
    }

    @Test func replacesTheExistingNote() throws {
        let agenda = TestAgenda()
        try agenda.store.setNote("Primeira", for: day)
        agenda.now += 60
        try agenda.store.setNote("Segunda", for: day)

        #expect(agenda.store.note(for: day)?.body == "Segunda")
        #expect(agenda.store.note(for: day)?.updatedAt == agenda.now)
        #expect(try agenda.container.mainContext.fetchCount(FetchDescriptor<DayNote>()) == 1)
    }

    @Test func savingABlankNoteDeletesIt() throws {
        let agenda = TestAgenda()
        try agenda.store.setNote("Algo", for: day)
        try agenda.store.setNote("  \n ", for: day)

        #expect(agenda.store.note(for: day) == nil)
        #expect(try agenda.container.mainContext.fetchCount(FetchDescriptor<DayNote>()) == 0)
    }
}

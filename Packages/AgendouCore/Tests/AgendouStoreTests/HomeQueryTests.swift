import AgendouCore
import Foundation
import Testing

@testable import AgendouStore

struct HomeQueryTests {
    @Test func findsTheNextShiftFromStoredData() throws {
        let agenda = TestAgenda(now: at(2026, 9, 29, 12))
        let category = try agenda.category12x36(anchor: at(2026, 10, 1, 7))

        let shift = agenda.store.currentOrNextShift()

        #expect(shift?.categoryID == category.id)
        #expect(shift?.startsAt == at(2026, 10, 1, 7).epochSeconds)
    }

    @Test func archivedCategoriesHaveNoNextShift() throws {
        // 20:00, after the Sep 29 07:00–19:00 shift: nothing in progress.
        let agenda = TestAgenda(now: at(2026, 9, 29, 20))
        let category = try agenda.category12x36(anchor: at(2026, 9, 1, 7))
        try agenda.store.archive(category)

        #expect(agenda.store.currentOrNextShift() == nil)
    }

    @Test func aShiftInProgressWhenArchivingStillShows() throws {
        let agenda = TestAgenda(now: at(2026, 9, 29, 12))
        let category = try agenda.category12x36(anchor: at(2026, 9, 1, 7))
        try agenda.store.archive(category)

        #expect(agenda.store.currentOrNextShift()?.startsAt == at(2026, 9, 29, 7).epochSeconds)
    }
}

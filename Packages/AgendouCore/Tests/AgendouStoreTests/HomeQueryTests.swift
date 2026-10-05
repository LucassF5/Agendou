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

struct UpcomingShiftsTests {
    @Test func listsTheShiftsAfterTheCard() throws {
        let agenda = TestAgenda(now: at(2026, 9, 29, 12))
        _ = try agenda.category12x36(anchor: at(2026, 10, 1, 7))
        let card = try #require(agenda.store.currentOrNextShift())

        let upcoming = agenda.store.upcomingShifts(after: card, limit: 4)

        #expect(card.startsAt == at(2026, 10, 1, 7).epochSeconds)
        #expect(upcoming.map(\.startsAt) == [3, 5, 7, 9].map { at(2026, 10, $0, 7).epochSeconds })
    }

    @Test func followsAShiftInProgress() throws {
        let agenda = TestAgenda(now: at(2026, 10, 1, 10))
        _ = try agenda.category12x36(anchor: at(2026, 10, 1, 7))
        let card = try #require(agenda.store.currentOrNextShift())

        #expect(agenda.store.upcomingShifts(after: card, limit: 1).map(\.startsAt) == [at(2026, 10, 3, 7).epochSeconds])
    }

    @Test func includesAnotherCategoryStartingWithTheCard() throws {
        let agenda = TestAgenda(now: at(2026, 9, 29, 12))
        let uti = try agenda.category12x36(name: "UTI", anchor: at(2026, 10, 1, 7))
        let ps = try agenda.category12x36(name: "PS", anchor: at(2026, 10, 1, 7))
        let card = try #require(agenda.store.currentOrNextShift())

        let first = try #require(agenda.store.upcomingShifts(after: card, limit: 1).first)

        #expect(first.startsAt == card.startsAt)
        #expect(Set([first.categoryID, card.categoryID]) == [uti.id, ps.id])
    }

    @Test func looksSixtyDaysAhead() throws {
        let agenda = TestAgenda(now: at(2026, 9, 29, 12))
        let category = try agenda.store.createCategory(name: "Extra", color: .orange)
        for day in [1, 59, 61] {
            let start = agenda.now.addingTimeInterval(TimeInterval(day * 86_400))
            _ = try agenda.store.addExtra(to: category, startsAt: start, endsAt: start.addingTimeInterval(3_600))
        }
        let card = try #require(agenda.store.currentOrNextShift())

        let upcoming = agenda.store.upcomingShifts(after: card, limit: 4)

        #expect(upcoming.map(\.startsAt) == [agenda.now.addingTimeInterval(59 * 86_400).epochSeconds])
    }
}

struct ShiftsFromNowTests {
    @Test func startsWithTheShiftInProgress() throws {
        let agenda = TestAgenda(now: at(2026, 10, 1, 10))
        _ = try agenda.category12x36(anchor: at(2026, 10, 1, 7))

        let starts = agenda.store.shiftsFromNow(horizon: 5 * 86_400).map(\.startsAt)

        #expect(starts == [1, 3, 5].map { at(2026, 10, $0, 7).epochSeconds })
    }

    @Test func isEmptyWithoutSchedules() {
        let agenda = TestAgenda(now: at(2026, 10, 1, 10))

        #expect(agenda.store.shiftsFromNow().isEmpty)
    }

    @Test func anArchivedCategoryKeepsOnlyTheShiftInProgress() throws {
        let agenda = TestAgenda(now: at(2026, 10, 1, 10))
        let category = try agenda.category12x36(anchor: at(2026, 9, 1, 7))
        try agenda.store.archive(category)

        let starts = agenda.store.shiftsFromNow(horizon: 10 * 86_400).map(\.startsAt)

        #expect(starts == [at(2026, 10, 1, 7).epochSeconds])
    }
}

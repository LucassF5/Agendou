import AgendouCore
import Foundation
import Testing

@testable import AgendouStore

struct ArchiveTests {
    @Test func closesTheOpenVersionNowAndKeepsThePast() throws {
        let agenda = TestAgenda(now: at(2026, 9, 29, 12))
        let category = try agenda.category12x36(anchor: at(2026, 9, 1, 7))
        let schedule = try #require(agenda.store.openSchedule(of: category))
        let september = agenda.month(2026, 9)

        try agenda.store.archive(category)

        #expect(category.archivedAt == agenda.now)
        #expect(schedule.endsAt == agenda.now)
        #expect(agenda.month(2026, 9) == september)
        #expect(agenda.month(2026, 10).occurrences.isEmpty)
        #expect(agenda.store.activeCategories().isEmpty)
        #expect(agenda.store.archivedCategories().map(\.id) == [category.id])
    }

    @Test func dropsVersionsThatHaveNotStartedAndClosesThePreviousOneNow() throws {
        let agenda = TestAgenda(now: at(2026, 9, 29, 12))
        let category = try agenda.category12x36(anchor: at(2026, 9, 1, 7))
        let old = try #require(agenda.store.openSchedule(of: category))
        _ = try agenda.store.changeSchedule(
            for: category, workSeconds: 24 * hour, restSeconds: 48 * hour, anchorAt: at(2026, 10, 3, 7))

        try agenda.store.archive(category)

        #expect(agenda.store.schedules(of: category).map(\.id) == [old.id])
        #expect(old.endsAt == agenda.now)
    }

    @Test func deletesFutureExtrasOnly() throws {
        let agenda = TestAgenda(now: at(2026, 9, 29, 12))
        let category = try agenda.store.createCategory(name: "Plantão avulso", color: .teal)
        let past = try agenda.store.addExtra(to: category, startsAt: at(2026, 9, 10, 7), endsAt: at(2026, 9, 10, 19))
        _ = try agenda.store.addExtra(to: category, startsAt: at(2026, 10, 10, 7), endsAt: at(2026, 10, 10, 19))

        try agenda.store.archive(category)

        #expect(category.overrides.map(\.id) == [past.id])
    }

    @Test func archivedCategoryAcceptsNoNewShifts() throws {
        let agenda = TestAgenda()
        let category = try agenda.store.createCategory(name: "UTI", color: .teal)
        try agenda.store.archive(category)
        #expect(throws: AgendaError.categoryArchived) {
            try agenda.store.addExtra(to: category, startsAt: at(2026, 10, 1, 7), endsAt: at(2026, 10, 1, 19))
        }
        #expect(throws: AgendaError.categoryArchived) {
            try agenda.store.startFirstSchedule(
                for: category, workSeconds: 12 * hour, restSeconds: 36 * hour, anchorAt: at(2026, 10, 1, 7),
                startsAt: at(2026, 10, 1, 7))
        }
        #expect(throws: AgendaError.categoryArchived) { try agenda.store.archive(category) }
    }
}

struct DeletePermanentlyTests {
    @Test func allowedWhenNothingHasStarted() throws {
        let agenda = TestAgenda()
        let category = try agenda.category12x36(anchor: at(2026, 10, 1, 7))
        #expect(agenda.store.canDeletePermanently(category))

        try agenda.store.deletePermanently(category)

        #expect(agenda.store.activeCategories().isEmpty)
        #expect(agenda.month(2026, 10).occurrences.isEmpty)
    }

    @Test func rejectedOnceAShiftHasStarted() throws {
        let agenda = TestAgenda(now: at(2026, 9, 29, 12))
        let category = try agenda.category12x36(anchor: at(2026, 9, 29, 7))
        #expect(!agenda.store.canDeletePermanently(category))
        #expect(throws: AgendaError.categoryHasHistory) { try agenda.store.deletePermanently(category) }
    }

    @Test func rejectedWithAnythingMarkedByHand() throws {
        let agenda = TestAgenda()
        let category = try agenda.store.createCategory(name: "UTI", color: .teal)
        _ = try agenda.store.addExtra(to: category, startsAt: at(2026, 12, 1, 7), endsAt: at(2026, 12, 1, 19))
        #expect(throws: AgendaError.categoryHasHistory) { try agenda.store.deletePermanently(category) }
    }

    @Test func allowedForArchivedCategoryWithoutHistory() throws {
        let agenda = TestAgenda()
        let category = try agenda.store.createCategory(name: "UTI", color: .teal)
        try agenda.store.archive(category)
        try agenda.store.deletePermanently(category)
        #expect(agenda.store.archivedCategories().isEmpty)
    }
}

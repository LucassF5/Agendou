import AgendouCore
import Foundation
import Testing

@testable import AgendouStore

struct PeriodTests {
    private func agendaWith12x36(anchor: Date, period: RepeatPeriod, now: Date = at(2026, 9, 29, 12))
        throws -> (TestAgenda, ShiftCategory)
    {
        let agenda = TestAgenda(now: now)
        let category = try agenda.store.createCategory(name: "UTI", color: .teal)
        try agenda.store.startFirstSchedule(
            for: category, workSeconds: 12 * hour, restSeconds: 36 * hour, anchorAt: anchor, startsAt: anchor,
            period: period)
        return (agenda, category)
    }

    @Test func storesTheEndCountedFromTheAnchorMonth() throws {
        let (agenda, category) = try agendaWith12x36(anchor: at(2026, 10, 5, 7), period: .months(1))
        #expect(agenda.store.openSchedule(of: category)?.repeatsUntil == at(2026, 11, 1, 0))
    }

    @Test func shiftsStopAtTheEnd() throws {
        let (agenda, _) = try agendaWith12x36(anchor: at(2026, 10, 5, 7), period: .months(1))
        #expect(agenda.month(2026, 10).occurrences.count == 14)  // Oct 5, 7, ..., 31
        #expect(agenda.month(2026, 11).occurrences.isEmpty)
    }

    @Test func aShiftStartingOnTheLastDayCountsWhole() throws {
        let (agenda, _) = try agendaWith12x36(anchor: at(2026, 10, 1, 19), period: .months(1))
        let last = try #require(agenda.month(2026, 10).occurrences.last)
        #expect(last.startsAt == at(2026, 10, 31, 19).epochSeconds)
        #expect(last.endsAt == at(2026, 11, 1, 7).epochSeconds)
    }

    @Test func shortPeriodEndsTheSameMonth() throws {
        let (agenda, category) = try agendaWith12x36(anchor: at(2026, 9, 30, 7), period: .months(1))
        #expect(agenda.store.openSchedule(of: category)?.repeatsUntil == at(2026, 10, 1, 0))
        #expect(agenda.month(2026, 10).occurrences.isEmpty)
    }

    @Test func rejectsAnEndBeforeTheAnchor() throws {
        let agenda = TestAgenda()
        let category = try agenda.store.createCategory(name: "UTI", color: .teal)
        #expect(throws: AgendaError.invalidRepeatEnd) {
            try agenda.store.startFirstSchedule(
                for: category, workSeconds: 12 * hour, restSeconds: 36 * hour, anchorAt: at(2026, 10, 5, 7),
                startsAt: at(2026, 10, 5, 7), period: .through(CivilDate(year: 2026, month: 10, day: 4)))
        }
    }

    @Test func renewingExtendsFromTheDayAfterTheEndKeepingThePhase() throws {
        let (agenda, category) = try agendaWith12x36(anchor: at(2026, 10, 5, 7), period: .months(1))
        let october = agenda.month(2026, 10)
        let schedule = try #require(agenda.store.openSchedule(of: category))

        #expect(agenda.store.renewalStart(of: schedule) == CivilDate(year: 2026, month: 11, day: 1))
        try agenda.store.renewSchedule(schedule, period: .months(1))

        #expect(schedule.repeatsUntil == at(2026, 12, 1, 0))
        #expect(agenda.month(2026, 10) == october)
        #expect(agenda.month(2026, 11).occurrences.first?.startsAt == at(2026, 11, 2, 7).epochSeconds)
    }

    @Test func renewingAfterItEndedFillsTheGap() throws {
        let (agenda, category) = try agendaWith12x36(anchor: at(2026, 10, 5, 7), period: .months(1))
        agenda.now = at(2027, 1, 10, 12)
        let schedule = try #require(agenda.store.openSchedule(of: category))
        #expect(agenda.month(2026, 12).occurrences.isEmpty)

        try agenda.store.renewSchedule(schedule, period: .months(3))

        #expect(schedule.repeatsUntil == at(2027, 2, 1, 0))
        #expect(!agenda.month(2026, 12).occurrences.isEmpty)
    }

    @Test func renewingMustGoPastTheCurrentEnd() throws {
        let (agenda, category) = try agendaWith12x36(anchor: at(2026, 10, 5, 7), period: .months(3))
        let schedule = try #require(agenda.store.openSchedule(of: category))
        #expect(throws: AgendaError.invalidRepeatEnd) {
            try agenda.store.renewSchedule(schedule, period: .through(CivilDate(year: 2026, month: 12, day: 31)))
        }
    }

    @Test func renewingIsAllowedOnceTheVersionIsLocked() throws {
        let (agenda, category) = try agendaWith12x36(
            anchor: at(2026, 9, 1, 7), period: .months(2), now: at(2026, 9, 1, 6))
        agenda.now = at(2026, 10, 25, 12)
        let schedule = try #require(agenda.store.openSchedule(of: category))
        #expect(!agenda.store.isEditable(schedule))
        try agenda.store.renewSchedule(schedule, period: .months(1))
        #expect(schedule.repeatsUntil == at(2026, 12, 1, 0))
    }

    @Test func changingKeepsThePreviousPeriodAndDeletingTheChangeRestoresIt() throws {
        let (agenda, category) = try agendaWith12x36(anchor: at(2026, 10, 1, 7), period: .months(3))
        let old = try #require(agenda.store.openSchedule(of: category))
        let new = try agenda.store.changeSchedule(
            for: category, workSeconds: 24 * hour, restSeconds: 48 * hour, anchorAt: at(2026, 10, 20, 7),
            period: .months(1))

        #expect(old.repeatsUntil == at(2027, 1, 1, 0))
        #expect(new.repeatsUntil == at(2026, 11, 1, 0))

        try agenda.store.deleteSchedule(new)
        #expect(old.endsAt == nil)
        #expect(agenda.month(2026, 12).occurrences.count > 0)
    }

    @Test func archivingStillCutsAtNow() throws {
        let (agenda, category) = try agendaWith12x36(anchor: at(2026, 9, 1, 7), period: .months(6))
        try agenda.store.archive(category)
        #expect(agenda.month(2026, 10).occurrences.isEmpty)
    }

    @Test func listsSchedulesEndingWithinAWeekOrAlreadyEnded() throws {
        let agenda = TestAgenda(now: at(2026, 10, 25, 6))
        let soon = try agenda.store.createCategory(name: "Soon", color: .teal)
        try agenda.store.startFirstSchedule(
            for: soon, workSeconds: 12 * hour, restSeconds: 36 * hour, anchorAt: at(2026, 10, 25, 7),
            startsAt: at(2026, 10, 25, 7), period: .months(1))  // ends Oct 31: within 7 days
        let later = try agenda.store.createCategory(name: "Later", color: .teal)
        try agenda.store.startFirstSchedule(
            for: later, workSeconds: 12 * hour, restSeconds: 36 * hour, anchorAt: at(2026, 10, 25, 7),
            startsAt: at(2026, 10, 25, 7), period: .months(2))
        let archived = try agenda.store.createCategory(name: "Archived", color: .teal)
        try agenda.store.startFirstSchedule(
            for: archived, workSeconds: 12 * hour, restSeconds: 36 * hour, anchorAt: at(2026, 10, 25, 7),
            startsAt: at(2026, 10, 25, 7), period: .months(1))
        try agenda.store.archive(archived)

        #expect(agenda.store.schedulesNeedingRenewal().compactMap(\.category?.name) == ["Soon"])
        agenda.now = at(2026, 12, 20, 12)
        #expect(agenda.store.schedulesNeedingRenewal().compactMap(\.category?.name) == ["Soon", "Later"])
    }

    @Test func correctingRecountsThePeriodFromTheCorrectedAnchor() throws {
        let (agenda, category) = try agendaWith12x36(anchor: at(2026, 10, 5, 7), period: .months(1))
        let schedule = try #require(agenda.store.openSchedule(of: category))
        try agenda.store.correctSchedule(
            schedule, workSeconds: 12 * hour, restSeconds: 36 * hour, anchorAt: at(2026, 11, 2, 7),
            startsAt: at(2026, 11, 2, 7), period: .months(1))
        #expect(schedule.repeatsUntil == at(2026, 12, 1, 0))
    }

    @Test func versionsWithoutPeriodRepeatWithoutEnd() throws {
        let (agenda, category) = try agendaWith12x36(anchor: at(2026, 10, 5, 7), period: .months(1))
        let schedule = try #require(agenda.store.openSchedule(of: category))
        schedule.repeatsUntil = nil  // as migrated from V1
        #expect(!agenda.month(2027, 6).occurrences.isEmpty)
        #expect(agenda.store.renewalStart(of: schedule) == CivilDate(year: 2026, month: 9, day: 29))
        #expect(agenda.store.schedulesNeedingRenewal().isEmpty)
    }
}

import AgendouCore
import Foundation
import Testing

@testable import AgendouStore

struct FirstScheduleTests {
    @Test func storesWholeSecondInstants() throws {
        let agenda = TestAgenda()
        let category = try agenda.store.createCategory(name: "UTI", color: .teal)
        let anchor = at(2026, 10, 1, 7).addingTimeInterval(0.75)
        let schedule = try agenda.store.startFirstSchedule(
            for: category, workSeconds: 12 * hour, restSeconds: 36 * hour, anchorAt: anchor, startsAt: anchor)
        #expect(schedule.anchorAt == at(2026, 10, 1, 7))
        #expect(schedule.startsAt == at(2026, 10, 1, 7))
        #expect(schedule.endsAt == nil)
        #expect(schedule.createdAt == agenda.now)
    }

    @Test(arguments: [(0, 36), (12, 0), (-1, 36)])
    func rejectsNonPositiveDurations(workHours: Int, restHours: Int) throws {
        let agenda = TestAgenda()
        let category = try agenda.store.createCategory(name: "UTI", color: .teal)
        #expect(throws: AgendaError.invalidDuration) {
            try agenda.store.startFirstSchedule(
                for: category, workSeconds: workHours * hour, restSeconds: restHours * hour,
                anchorAt: at(2026, 10, 1, 7), startsAt: at(2026, 10, 1, 7))
        }
    }

    @Test func rejectsStartAfterAnchor() throws {
        let agenda = TestAgenda()
        let category = try agenda.store.createCategory(name: "UTI", color: .teal)
        #expect(throws: AgendaError.startsAfterAnchor) {
            try agenda.store.startFirstSchedule(
                for: category, workSeconds: 12 * hour, restSeconds: 36 * hour,
                anchorAt: at(2026, 10, 1, 7), startsAt: at(2026, 10, 1, 8))
        }
    }

    @Test func goingBackFillsThePast() throws {
        let agenda = TestAgenda()
        _ = try agenda.category12x36(anchor: at(2026, 10, 1, 7), startsAt: at(2026, 9, 1, 0))
        // Sep 1, 3, ..., 29 at 07:00
        #expect(agenda.month(2026, 9).occurrences.count == 15)
    }

    @Test func withoutGoingBackThePastStaysEmpty() throws {
        let agenda = TestAgenda()
        _ = try agenda.category12x36(anchor: at(2026, 10, 1, 7))
        #expect(agenda.month(2026, 9).occurrences.isEmpty)
    }

    @Test func onlyOnceLaterChangesCloseTheOpenVersion() throws {
        let agenda = TestAgenda()
        let category = try agenda.category12x36(anchor: at(2026, 10, 1, 7))
        #expect(throws: AgendaError.categoryAlreadyHasSchedule) {
            try agenda.store.startFirstSchedule(
                for: category, workSeconds: 12 * hour, restSeconds: 36 * hour,
                anchorAt: at(2026, 10, 2, 7), startsAt: at(2026, 10, 2, 7))
        }
    }
}

struct ChangeScheduleTests {
    @Test func closesOpenVersionAtTheNewAnchor() throws {
        let agenda = TestAgenda()
        let category = try agenda.category12x36(anchor: at(2026, 9, 1, 7))
        let old = try #require(agenda.store.openSchedule(of: category))

        let new = try agenda.store.changeSchedule(
            for: category, workSeconds: 24 * hour, restSeconds: 48 * hour, anchorAt: at(2026, 10, 2, 7))

        #expect(old.endsAt == at(2026, 10, 2, 7))
        #expect(new.startsAt == at(2026, 10, 2, 7))
        #expect(new.anchorAt == at(2026, 10, 2, 7))
        #expect(new.endsAt == nil)
        #expect(agenda.store.openSchedule(of: category)?.id == new.id)
        #expect(agenda.store.schedules(of: category).filter { $0.endsAt == nil }.count == 1)
    }

    @Test func rejectsAnchorInThePast() throws {
        let agenda = TestAgenda()
        let category = try agenda.category12x36(anchor: at(2026, 9, 1, 7))
        #expect(throws: AgendaError.anchorInPast) {
            try agenda.store.changeSchedule(
                for: category, workSeconds: 24 * hour, restSeconds: 48 * hour, anchorAt: agenda.now - 1)
        }
    }

    @Test func rejectsAnchorNotAfterCurrentVersionStart() throws {
        let agenda = TestAgenda()
        let category = try agenda.category12x36(anchor: at(2026, 10, 10, 7))
        #expect(throws: AgendaError.anchorNotAfterCurrentStart) {
            try agenda.store.changeSchedule(
                for: category, workSeconds: 24 * hour, restSeconds: 48 * hour, anchorAt: at(2026, 10, 10, 7))
        }
    }

    @Test func requiresAnOpenVersion() throws {
        let agenda = TestAgenda()
        let category = try agenda.store.createCategory(name: "UTI", color: .teal)
        #expect(throws: AgendaError.noOpenSchedule) {
            try agenda.store.changeSchedule(
                for: category, workSeconds: 24 * hour, restSeconds: 48 * hour, anchorAt: at(2026, 10, 2, 7))
        }
    }

    @Test func rejectsNonPositiveDurations() throws {
        let agenda = TestAgenda()
        let category = try agenda.category12x36(anchor: at(2026, 9, 1, 7))
        #expect(throws: AgendaError.invalidDuration) {
            try agenda.store.changeSchedule(
                for: category, workSeconds: 0, restSeconds: 48 * hour, anchorAt: at(2026, 10, 2, 7))
        }
    }

    /// The check from the plan: 12x36 since last month, switch to 24x48 from today, last month unchanged.
    @Test func keepsThePastFrozen() throws {
        let agenda = TestAgenda(now: at(2026, 9, 29, 12))
        let category = try agenda.category12x36(anchor: at(2026, 9, 1, 7), startsAt: at(2026, 8, 1, 0))
        let august = agenda.month(2026, 8)
        let septemberSoFar = agenda.store.expand(in: at(2026, 9, 1, 0).epochSeconds..<agenda.now.epochSeconds)
        #expect(august.occurrences.count == 15)  // Aug 2, 4, ..., 30

        _ = try agenda.store.changeSchedule(
            for: category, workSeconds: 24 * hour, restSeconds: 48 * hour, anchorAt: at(2026, 9, 29, 19))

        #expect(agenda.month(2026, 8) == august)
        #expect(agenda.store.expand(in: at(2026, 9, 1, 0).epochSeconds..<agenda.now.epochSeconds) == septemberSoFar)
    }
}

struct CorrectScheduleTests {
    @Test func allowedWithin24HoursEvenAfterAShiftStarted() throws {
        let agenda = TestAgenda(now: at(2026, 9, 29, 6))
        let category = try agenda.category12x36(anchor: at(2026, 9, 29, 7))
        agenda.now = at(2026, 9, 29, 20)
        let schedule = try #require(agenda.store.openSchedule(of: category))
        #expect(agenda.store.isEditable(schedule))

        try agenda.store.correctSchedule(
            schedule, workSeconds: 12 * hour, restSeconds: 60 * hour, anchorAt: at(2026, 9, 29, 7),
            startsAt: at(2026, 9, 29, 7))
        #expect(schedule.restSeconds == 60 * hour)
    }

    @Test func allowedAfter24HoursWhileNoShiftStarted() throws {
        let agenda = TestAgenda(now: at(2026, 9, 1, 12))
        let category = try agenda.category12x36(anchor: at(2026, 10, 1, 7))
        agenda.now = at(2026, 9, 20, 12)
        let schedule = try #require(agenda.store.openSchedule(of: category))
        #expect(agenda.store.isEditable(schedule))

        try agenda.store.correctSchedule(
            schedule, workSeconds: 24 * hour, restSeconds: 72 * hour, anchorAt: at(2026, 10, 2, 7),
            startsAt: at(2026, 10, 2, 7))
        #expect(schedule.anchorAt == at(2026, 10, 2, 7))
        #expect(schedule.workSeconds == 24 * hour)
    }

    @Test func lockedAfter24HoursOnceAShiftStarted() throws {
        let agenda = TestAgenda(now: at(2026, 9, 1, 6))
        let category = try agenda.category12x36(anchor: at(2026, 9, 1, 7))
        agenda.now = at(2026, 9, 2, 6)
        let schedule = try #require(agenda.store.openSchedule(of: category))
        #expect(!agenda.store.isEditable(schedule))
        #expect(throws: AgendaError.scheduleLocked) {
            try agenda.store.correctSchedule(
                schedule, workSeconds: 12 * hour, restSeconds: 60 * hour, anchorAt: at(2026, 9, 1, 7),
                startsAt: at(2026, 9, 1, 7))
        }
    }

    @Test func closedVersionsAreNeverEditable() throws {
        let agenda = TestAgenda(now: at(2026, 9, 29, 6))
        let category = try agenda.category12x36(anchor: at(2026, 10, 1, 7))
        let first = try #require(agenda.store.openSchedule(of: category))
        _ = try agenda.store.changeSchedule(
            for: category, workSeconds: 24 * hour, restSeconds: 48 * hour, anchorAt: at(2026, 10, 5, 7))
        #expect(!agenda.store.isEditable(first))
    }

    @Test func firstVersionStillCannotStartAfterItsAnchor() throws {
        let agenda = TestAgenda()
        let category = try agenda.category12x36(anchor: at(2026, 10, 1, 7))
        let schedule = try #require(agenda.store.openSchedule(of: category))
        #expect(throws: AgendaError.startsAfterAnchor) {
            try agenda.store.correctSchedule(
                schedule, workSeconds: 12 * hour, restSeconds: 36 * hour, anchorAt: at(2026, 10, 1, 7),
                startsAt: at(2026, 10, 2, 7))
        }
    }

    @Test func correctingAChangeMovesTheBoundaryWithIt() throws {
        let agenda = TestAgenda(now: at(2026, 9, 29, 12))
        let category = try agenda.category12x36(anchor: at(2026, 9, 1, 7))
        let old = try #require(agenda.store.openSchedule(of: category))
        let new = try agenda.store.changeSchedule(
            for: category, workSeconds: 24 * hour, restSeconds: 48 * hour, anchorAt: at(2026, 10, 3, 7))

        try agenda.store.correctSchedule(
            new, workSeconds: 24 * hour, restSeconds: 48 * hour, anchorAt: at(2026, 10, 1, 7), startsAt: nil)

        #expect(new.startsAt == at(2026, 10, 1, 7))
        #expect(old.endsAt == at(2026, 10, 1, 7))
    }

    @Test func correctingAChangeCannotRewriteThePreviousVersionsPast() throws {
        let agenda = TestAgenda(now: at(2026, 9, 29, 12))
        let category = try agenda.category12x36(anchor: at(2026, 9, 1, 7))
        let new = try agenda.store.changeSchedule(
            for: category, workSeconds: 24 * hour, restSeconds: 48 * hour, anchorAt: at(2026, 10, 3, 7))
        #expect(throws: AgendaError.anchorInPast) {
            try agenda.store.correctSchedule(
                new, workSeconds: 24 * hour, restSeconds: 48 * hour, anchorAt: at(2026, 9, 28, 7), startsAt: nil)
        }
    }

    @Test func exposesThePreviousVersion() throws {
        let agenda = TestAgenda(now: at(2026, 9, 29, 12))
        let category = try agenda.category12x36(anchor: at(2026, 9, 1, 7))
        let old = try #require(agenda.store.openSchedule(of: category))
        let new = try agenda.store.changeSchedule(
            for: category, workSeconds: 24 * hour, restSeconds: 48 * hour, anchorAt: at(2026, 10, 3, 7))

        #expect(agenda.store.previousSchedule(of: new)?.id == old.id)
        #expect(agenda.store.previousSchedule(of: old) == nil)
        #expect(agenda.store.version(of: new)?.firstOccurrenceStart == at(2026, 10, 3, 7).epochSeconds)
    }

    @Test func deletingAnEditableChangeReopensThePreviousVersion() throws {
        let agenda = TestAgenda(now: at(2026, 9, 29, 12))
        let category = try agenda.category12x36(anchor: at(2026, 9, 1, 7))
        let old = try #require(agenda.store.openSchedule(of: category))
        let new = try agenda.store.changeSchedule(
            for: category, workSeconds: 24 * hour, restSeconds: 48 * hour, anchorAt: at(2026, 10, 3, 7))

        try agenda.store.deleteSchedule(new)

        #expect(old.endsAt == nil)
        #expect(agenda.store.schedules(of: category).map(\.id) == [old.id])
    }

    @Test func deletingTheOnlyEditableVersionLeavesTheCategoryWithoutSchedule() throws {
        let agenda = TestAgenda()
        let category = try agenda.category12x36(anchor: at(2026, 10, 1, 7))
        try agenda.store.deleteSchedule(try #require(agenda.store.openSchedule(of: category)))
        #expect(agenda.store.schedules(of: category).isEmpty)
    }

    @Test func deletingALockedVersionIsRejected() throws {
        let agenda = TestAgenda(now: at(2026, 9, 1, 6))
        let category = try agenda.category12x36(anchor: at(2026, 9, 1, 7))
        agenda.now = at(2026, 9, 5, 6)
        #expect(throws: AgendaError.scheduleLocked) {
            try agenda.store.deleteSchedule(try #require(agenda.store.openSchedule(of: category)))
        }
    }
}

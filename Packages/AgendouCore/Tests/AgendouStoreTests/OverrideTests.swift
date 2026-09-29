import AgendouCore
import Foundation
import Testing

@testable import AgendouStore

struct ExtraTests {
    @Test func appearsOnlyOnTheDayItStarts() throws {
        let agenda = TestAgenda()
        let category = try agenda.store.createCategory(name: "Extra", color: .orange)
        let extra = try agenda.store.addExtra(to: category, startsAt: at(2026, 10, 1, 19), endsAt: at(2026, 10, 2, 7))

        #expect(
            agenda.day(2026, 10, 1).occurrences == [
                Occurrence(
                    categoryID: category.id, startsAt: at(2026, 10, 1, 19).epochSeconds,
                    endsAt: at(2026, 10, 2, 7).epochSeconds, origin: .extra(overrideID: extra.id))
            ])
        #expect(agenda.day(2026, 10, 2).occurrences.isEmpty)
    }

    @Test func storesWholeSecondInstants() throws {
        let agenda = TestAgenda()
        let category = try agenda.store.createCategory(name: "Extra", color: .orange)
        let extra = try agenda.store.addExtra(
            to: category, startsAt: at(2026, 10, 1, 19).addingTimeInterval(0.4),
            endsAt: at(2026, 10, 2, 7).addingTimeInterval(0.9))
        #expect(extra.startsAt == at(2026, 10, 1, 19))
        #expect(extra.endsAt == at(2026, 10, 2, 7))
    }

    @Test func rejectsNonPositiveLength() throws {
        let agenda = TestAgenda()
        let category = try agenda.store.createCategory(name: "Extra", color: .orange)
        #expect(throws: AgendaError.invalidDuration) {
            try agenda.store.addExtra(to: category, startsAt: at(2026, 10, 1, 19), endsAt: at(2026, 10, 1, 19))
        }
    }

    @Test func rejectsASecondExtraAtTheSameStartInTheSameCategory() throws {
        let agenda = TestAgenda()
        let first = try agenda.store.createCategory(name: "UTI", color: .teal)
        let second = try agenda.store.createCategory(name: "PS", color: .red)
        _ = try agenda.store.addExtra(to: first, startsAt: at(2026, 10, 1, 7), endsAt: at(2026, 10, 1, 19))

        #expect(throws: AgendaError.duplicateOverride) {
            try agenda.store.addExtra(to: first, startsAt: at(2026, 10, 1, 7), endsAt: at(2026, 10, 1, 13))
        }
        _ = try agenda.store.addExtra(to: second, startsAt: at(2026, 10, 1, 7), endsAt: at(2026, 10, 1, 19))
    }

    @Test func movesAndDeletes() throws {
        let agenda = TestAgenda()
        let category = try agenda.store.createCategory(name: "Extra", color: .orange)
        let extra = try agenda.store.addExtra(to: category, startsAt: at(2026, 10, 1, 7), endsAt: at(2026, 10, 1, 19))

        try agenda.store.updateExtra(extra, startsAt: at(2026, 10, 3, 7), endsAt: at(2026, 10, 3, 13))
        #expect(agenda.day(2026, 10, 1).occurrences.isEmpty)
        #expect(agenda.day(2026, 10, 3).occurrences.map(\.endsAt) == [at(2026, 10, 3, 13).epochSeconds])

        try agenda.store.deleteExtra(extra)
        #expect(agenda.month(2026, 10).occurrences.isEmpty)
    }

    @Test func defaultsFollowTheOpenScheduleOnTheChosenDay() throws {
        let agenda = TestAgenda()
        let category = try agenda.category12x36(anchor: at(2026, 9, 1, 19, 30))
        #expect(
            agenda.store.extraDefaults(for: category, on: CivilDate(year: 2026, month: 10, day: 10))
                == DateInterval(start: at(2026, 10, 10, 19, 30), end: at(2026, 10, 11, 7, 30)))
    }

    @Test func noDefaultsWithoutASchedule() throws {
        let agenda = TestAgenda()
        let category = try agenda.store.createCategory(name: "Extra", color: .orange)
        #expect(agenda.store.extraDefaults(for: category, on: CivilDate(year: 2026, month: 10, day: 10)) == nil)
    }
}

struct CancellationTests {
    @Test func movesTheShiftToCancelledAndBack() throws {
        let agenda = TestAgenda()
        _ = try agenda.category12x36(anchor: at(2026, 10, 1, 7))
        let shift = try #require(agenda.day(2026, 10, 1).occurrences.first)

        try agenda.store.cancel(shift)
        #expect(agenda.day(2026, 10, 1).occurrences.isEmpty)
        #expect(agenda.day(2026, 10, 1).cancelled == [shift])

        try agenda.store.restore(shift)
        #expect(agenda.day(2026, 10, 1).occurrences == [shift])
        #expect(agenda.day(2026, 10, 1).cancelled.isEmpty)
    }

    @Test func cancellingTwiceIsRejected() throws {
        let agenda = TestAgenda()
        _ = try agenda.category12x36(anchor: at(2026, 10, 1, 7))
        let shift = try #require(agenda.day(2026, 10, 1).occurrences.first)
        try agenda.store.cancel(shift)
        #expect(throws: AgendaError.duplicateOverride) { try agenda.store.cancel(shift) }
    }

    @Test func onlyGeneratedShiftsCanBeCancelled() throws {
        let agenda = TestAgenda()
        let category = try agenda.store.createCategory(name: "Extra", color: .orange)
        _ = try agenda.store.addExtra(to: category, startsAt: at(2026, 10, 1, 7), endsAt: at(2026, 10, 1, 19))
        let extra = try #require(agenda.day(2026, 10, 1).occurrences.first)
        #expect(throws: AgendaError.notScheduled) { try agenda.store.cancel(extra) }
    }
}

struct AdjustmentTests {
    @Test func keepsTheStartAndReplacesTheEnd() throws {
        let agenda = TestAgenda()
        let category = try agenda.category12x36(anchor: at(2026, 10, 1, 7))
        let schedule = try #require(agenda.store.openSchedule(of: category))
        let shift = try #require(agenda.day(2026, 10, 1).occurrences.first)

        try agenda.store.edit(shift, startsAt: at(2026, 10, 1, 7), endsAt: at(2026, 10, 1, 13))

        let day = agenda.day(2026, 10, 1)
        let extra = try #require(category.overrides.first { $0.kindRaw == Override.Kind.extra.rawValue })
        #expect(
            day.occurrences == [
                Occurrence(
                    categoryID: category.id, startsAt: shift.startsAt, endsAt: at(2026, 10, 1, 13).epochSeconds,
                    origin: .adjusted(overrideID: extra.id, scheduleID: schedule.id))
            ])
        #expect(day.cancelled.isEmpty)
        #expect(category.overrides.count == 2)
    }

    @Test func editingAnAdjustmentUpdatesItsExtra() throws {
        let agenda = TestAgenda()
        let category = try agenda.category12x36(anchor: at(2026, 10, 1, 7))
        let shift = try #require(agenda.day(2026, 10, 1).occurrences.first)
        try agenda.store.edit(shift, startsAt: at(2026, 10, 1, 7), endsAt: at(2026, 10, 1, 13))
        let adjusted = try #require(agenda.day(2026, 10, 1).occurrences.first)

        try agenda.store.edit(adjusted, startsAt: at(2026, 10, 1, 7), endsAt: at(2026, 10, 1, 15))

        #expect(agenda.day(2026, 10, 1).occurrences.map(\.endsAt) == [at(2026, 10, 1, 15).epochSeconds])
        #expect(category.overrides.count == 2)
    }

    @Test func undoingDeletesBothOverrides() throws {
        let agenda = TestAgenda()
        let category = try agenda.category12x36(anchor: at(2026, 10, 1, 7))
        let shift = try #require(agenda.day(2026, 10, 1).occurrences.first)
        try agenda.store.edit(shift, startsAt: at(2026, 10, 1, 7), endsAt: at(2026, 10, 1, 13))
        let adjusted = try #require(agenda.day(2026, 10, 1).occurrences.first)

        try agenda.store.undoAdjustment(adjusted)

        #expect(agenda.day(2026, 10, 1).occurrences == [shift])
        #expect(category.overrides.isEmpty)
        #expect(throws: AgendaError.notAdjusted) { try agenda.store.undoAdjustment(shift) }
    }

    @Test func movingTheStartLeavesTheGeneratedShiftCancelled() throws {
        let agenda = TestAgenda()
        _ = try agenda.category12x36(anchor: at(2026, 10, 1, 7))
        let shift = try #require(agenda.day(2026, 10, 1).occurrences.first)

        try agenda.store.edit(shift, startsAt: at(2026, 10, 1, 8), endsAt: at(2026, 10, 1, 20))

        let day = agenda.day(2026, 10, 1)
        #expect(day.occurrences.map(\.startsAt) == [at(2026, 10, 1, 8).epochSeconds])
        #expect(day.cancelled == [shift])
    }

    @Test func rejectsNonPositiveLength() throws {
        let agenda = TestAgenda()
        _ = try agenda.category12x36(anchor: at(2026, 10, 1, 7))
        let shift = try #require(agenda.day(2026, 10, 1).occurrences.first)
        #expect(throws: AgendaError.invalidDuration) {
            try agenda.store.edit(shift, startsAt: at(2026, 10, 1, 7), endsAt: at(2026, 10, 1, 6))
        }
        #expect(agenda.day(2026, 10, 1).occurrences == [shift])
    }
}

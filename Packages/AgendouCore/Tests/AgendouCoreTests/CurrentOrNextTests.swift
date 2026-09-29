import Foundation
import Testing

@testable import AgendouCore

struct CurrentOrNextTests {
    private let category = UUID()
    private let other = UUID()

    private func at(_ day: Int, _ hour: Int) -> Int64 {
        CivilCalendar.instant(of: CivilDate(year: 2026, month: 10, day: day), hour: hour, minute: 0)
    }

    /// 12x36 from Oct 1 07:00: Oct 1, 3, 5, ... 07:00–19:00.
    private var schedule: ScheduleVersion {
        ScheduleVersion(
            id: UUID(), categoryID: category, workSeconds: 43_200, restSeconds: 129_600, anchorAt: at(1, 7),
            startsAt: at(1, 7), endsAt: nil)
    }

    @Test func returnsTheShiftInProgress() {
        let shift = ScheduleEngine.currentOrNext(schedules: [schedule], overrides: [], now: at(1, 10))
        #expect(shift?.startsAt == at(1, 7))
    }

    @Test func returnsTheNextShiftBetweenShifts() {
        let shift = ScheduleEngine.currentOrNext(schedules: [schedule], overrides: [], now: at(1, 20))
        #expect(shift?.startsAt == at(3, 7))
    }

    @Test func aShiftIsOverAtItsEnd() {
        let shift = ScheduleEngine.currentOrNext(schedules: [schedule], overrides: [], now: at(1, 19))
        #expect(shift?.startsAt == at(3, 7))
    }

    @Test func aShiftIsInProgressFromItsStart() {
        let shift = ScheduleEngine.currentOrNext(schedules: [schedule], overrides: [], now: at(3, 7))
        #expect(shift?.startsAt == at(3, 7))
    }

    @Test func nothingWithoutSchedules() {
        #expect(ScheduleEngine.currentOrNext(schedules: [], overrides: [], now: at(1, 10)) == nil)
    }

    @Test func nothingAfterTheLastVersionEnded() {
        var closed = schedule
        closed.endsAt = at(2, 0)
        #expect(ScheduleEngine.currentOrNext(schedules: [closed], overrides: [], now: at(2, 12)) == nil)
    }

    @Test func anEarlierExtraComesFirst() {
        let extra = Override(id: UUID(), categoryID: other, kind: .extra, startsAt: at(2, 8), endsAt: at(2, 14))
        let shift = ScheduleEngine.currentOrNext(schedules: [schedule], overrides: [extra], now: at(1, 20))
        #expect(shift?.origin == .extra(overrideID: extra.id))
    }

    @Test func skipsACancelledShift() {
        let cancellation = Override(
            id: UUID(), categoryID: category, kind: .cancellation, startsAt: at(3, 7), endsAt: at(3, 19))
        let shift = ScheduleEngine.currentOrNext(schedules: [schedule], overrides: [cancellation], now: at(1, 20))
        #expect(shift?.startsAt == at(5, 7))
    }

    @Test func looksBackFarEnoughForALongShiftInProgress() {
        let extra = Override(id: UUID(), categoryID: other, kind: .extra, startsAt: at(1, 20), endsAt: at(3, 20))
        let shift = ScheduleEngine.currentOrNext(schedules: [], overrides: [extra], now: at(3, 12))
        #expect(shift?.origin == .extra(overrideID: extra.id))
    }

    @Test func anAdjustedShiftEndsWhenTheAdjustmentSays() {
        let cancellation = Override(
            id: UUID(), categoryID: category, kind: .cancellation, startsAt: at(1, 7), endsAt: at(1, 19))
        let extra = Override(id: UUID(), categoryID: category, kind: .extra, startsAt: at(1, 7), endsAt: at(1, 9))
        let shift = ScheduleEngine.currentOrNext(
            schedules: [schedule], overrides: [cancellation, extra], now: at(1, 10))
        #expect(shift?.startsAt == at(3, 7))
    }

    @Test func findsANextShiftMonthsAhead() {
        let later = ScheduleVersion(
            id: UUID(), categoryID: category, workSeconds: 43_200, restSeconds: 129_600,
            anchorAt: at(1, 7) + 200 * 86_400,
            startsAt: at(1, 7) + 200 * 86_400, endsAt: nil)
        #expect(
            ScheduleEngine.currentOrNext(schedules: [later], overrides: [], now: at(1, 7))?.startsAt == later.anchorAt)
    }
}

struct CivilDateArithmeticTests {
    @Test func addsDaysAcrossMonthAndYear() {
        #expect(CivilDate(year: 2026, month: 9, day: 29).adding(days: 2) == CivilDate(year: 2026, month: 10, day: 1))
        #expect(CivilDate(year: 2026, month: 12, day: 31).adding(days: 1) == CivilDate(year: 2027, month: 1, day: 1))
        #expect(CivilDate(year: 2026, month: 3, day: 1).adding(days: -1) == CivilDate(year: 2026, month: 2, day: 28))
        #expect(CivilDate(year: 2026, month: 3, day: 1).adding(days: 0) == CivilDate(year: 2026, month: 3, day: 1))
    }
}

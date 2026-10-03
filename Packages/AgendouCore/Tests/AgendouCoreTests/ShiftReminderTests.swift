import Foundation
import Testing

@testable import AgendouCore

struct ShiftReminderTests {
    private let uti = UUID()
    private let ps = UUID()

    private func at(_ day: Int, _ hour: Int, _ minute: Int = 0, month: Int = 10) -> Int64 {
        CivilCalendar.instant(of: CivilDate(year: 2026, month: month, day: day), hour: hour, minute: minute)
    }

    private func shift(_ category: UUID, _ day: Int, _ hour: Int, hours: Int64 = 12, month: Int = 10) -> Occurrence {
        let start = at(day, hour, month: month)
        return Occurrence(
            categoryID: category, startsAt: start, endsAt: start + hours * 3_600,
            origin: .scheduled(scheduleID: UUID()))
    }

    private func plan(_ occurrences: [Occurrence], now: Int64, hour: Int = 7, minute: Int = 0, days: Int = 30)
        -> [ShiftReminder]
    {
        ShiftReminders.plan(occurrences: occurrences, hour: hour, minute: minute, now: now, windowDays: days)
    }

    @Test func remindsOncePerShiftDayAtTheChosenTime() {
        let reminders = plan([shift(uti, 5, 19), shift(uti, 7, 7)], now: at(1, 12), hour: 6, minute: 30)

        #expect(reminders.map(\.fireAt) == [at(5, 6, 30), at(7, 6, 30)])
        #expect(reminders.map(\.day) == [CivilDate(year: 2026, month: 10, day: 5), CivilDate(year: 2026, month: 10, day: 7)])
    }

    @Test func daysWithoutShiftsGetNoReminder() {
        let reminders = plan([shift(uti, 5, 19)], now: at(1, 12))

        #expect(reminders.count == 1)
    }

    @Test func twoShiftsOnTheSameDayShareOneReminder() {
        let reminders = plan([shift(ps, 5, 19), shift(uti, 5, 7)], now: at(1, 12))

        #expect(reminders.count == 1)
        #expect(reminders[0].shifts.map(\.startsAt) == [at(5, 7), at(5, 19)])
    }

    @Test func aShiftCrossingMidnightCountsOnlyOnTheDayItStarts() {
        let reminders = plan([shift(uti, 5, 19)], now: at(1, 12))

        #expect(reminders.map(\.day) == [CivilDate(year: 2026, month: 10, day: 5)])
    }

    @Test func todayIsSkippedOnceTheReminderTimeHasPassed() {
        let occurrences = [shift(uti, 5, 19), shift(uti, 6, 19)]

        #expect(plan(occurrences, now: at(5, 8)).map(\.fireAt) == [at(6, 7)])
        #expect(plan(occurrences, now: at(5, 6)).map(\.fireAt) == [at(5, 7), at(6, 7)])
    }

    @Test func onlyTheNextWindowDaysAreKept() {
        let reminders = plan(
            [shift(uti, 5, 19), shift(uti, 31, 19), shift(uti, 1, 19, month: 11)], now: at(1, 12), days: 30)

        // Windows starts today (Oct 1): Oct 1 … Oct 30. Oct 31 and Nov 1 fall outside.
        #expect(reminders.map(\.day) == [CivilDate(year: 2026, month: 10, day: 5)])
    }

    @Test func remindersComeInChronologicalOrderWhateverTheInputOrder() {
        let reminders = plan([shift(uti, 9, 7), shift(uti, 5, 7), shift(uti, 7, 7)], now: at(1, 12))

        #expect(reminders.map(\.fireAt) == [at(5, 7), at(7, 7), at(9, 7)])
    }

    @Test func noShiftsMeansNoReminders() {
        #expect(plan([], now: at(1, 12)).isEmpty)
    }
}

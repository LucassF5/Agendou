import Testing

@testable import AgendouCore

struct RepeatPeriodTests {
    private func day(_ string: String) -> CivilDate { CivilDate(string: string)! }
    private func midnight(_ string: String) -> Int64 { CivilCalendar.interval(of: day(string)).lowerBound }

    @Test func addsMonthsAcrossYears() {
        #expect(CivilMonth(year: 2026, month: 10).adding(months: 3) == CivilMonth(year: 2027, month: 1))
        #expect(CivilMonth(year: 2026, month: 1).adding(months: -1) == CivilMonth(year: 2025, month: 12))
        #expect(CivilMonth(year: 2026, month: 5).adding(months: 0) == CivilMonth(year: 2026, month: 5))
    }

    @Test(arguments: [
        ("2026-10-05", 1, "2026-11-01"),
        ("2026-10-05", 3, "2027-01-01"),
        ("2026-10-05", 6, "2027-04-01"),
        ("2026-09-30", 1, "2026-10-01"),
        ("2026-12-01", 1, "2027-01-01"),
    ])
    func monthsEndAtTheStartOfTheMonthAfter(start: String, months: Int, end: String) {
        #expect(RepeatPeriod.months(months).end(startingOn: day(start)) == midnight(end))
    }

    @Test func throughEndsAtTheStartOfTheNextDay() {
        #expect(RepeatPeriod.through(day("2026-10-15")).end(startingOn: day("2026-10-05")) == midnight("2026-10-16"))
    }

    @Test func lastDayIsTheDayBeforeTheEnd() {
        #expect(RepeatPeriod.months(1).lastDay(startingOn: day("2026-10-05")) == day("2026-10-31"))
        #expect(RepeatPeriod.through(day("2026-10-15")).lastDay(startingOn: day("2026-10-05")) == day("2026-10-15"))
    }
}

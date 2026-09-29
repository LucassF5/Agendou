import Testing

@testable import AgendouCore

struct CivilDateTests {
    @Test func parsesAndFormatsISODay() {
        let date = CivilDate(string: "2026-01-31")
        #expect(date == CivilDate(year: 2026, month: 1, day: 31))
        #expect(date?.string == "2026-01-31")
        #expect(CivilDate(year: 2026, month: 3, day: 5).string == "2026-03-05")
    }

    @Test(arguments: [
        "2026-02-29", "2026-13-01", "2026-00-10", "2026-01-32", "2026-1-5", "26-01-05", "", "2026-01-05T00",
    ])
    func rejectsInvalidDays(string: String) {
        #expect(CivilDate(string: string) == nil)
    }

    @Test func acceptsLeapDay() {
        #expect(CivilDate(string: "2028-02-29") == CivilDate(year: 2028, month: 2, day: 29))
    }

    @Test func ordersChronologically() {
        #expect(CivilDate(year: 2025, month: 12, day: 31) < CivilDate(year: 2026, month: 1, day: 1))
        #expect(CivilDate(year: 2026, month: 1, day: 31) < CivilDate(year: 2026, month: 2, day: 1))
        #expect(CivilDate(year: 2026, month: 2, day: 1) < CivilDate(year: 2026, month: 2, day: 2))
    }
}

struct CivilMonthTests {
    @Test func navigatesAcrossYears() {
        #expect(CivilMonth(year: 2026, month: 12).next == CivilMonth(year: 2027, month: 1))
        #expect(CivilMonth(year: 2026, month: 1).previous == CivilMonth(year: 2025, month: 12))
        #expect(CivilMonth(year: 2026, month: 5).next == CivilMonth(year: 2026, month: 6))
    }

    @Test func listsEveryDay() {
        let february = CivilMonth(year: 2028, month: 2)
        #expect(february.days.count == 29)
        #expect(february.days.first == CivilDate(year: 2028, month: 2, day: 1))
        #expect(february.days.last == CivilDate(year: 2028, month: 2, day: 29))
        #expect(CivilMonth(year: 2026, month: 2).days.count == 28)
        #expect(CivilMonth(year: 2026, month: 1).days.count == 31)
    }

    @Test func containsItsDays() {
        #expect(CivilMonth(CivilDate(year: 2026, month: 7, day: 14)) == CivilMonth(year: 2026, month: 7))
    }

    @Test func parsesAndFormats() {
        #expect(CivilMonth(string: "2026-02") == CivilMonth(year: 2026, month: 2))
        #expect(CivilMonth(year: 2026, month: 2).string == "2026-02")
        #expect(CivilMonth(string: "2026-13") == nil)
    }
}

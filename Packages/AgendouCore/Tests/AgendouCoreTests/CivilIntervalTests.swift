import Testing

@testable import AgendouCore

struct CivilIntervalTests {
    // 2026-01-31T00:00-03:00 == 2026-01-31T03:00:00Z
    private let january31 = Int64(1_769_828_400)
    private let day = Int64(86_400)

    @Test func dayIntervalStartsAtLocalMidnight() {
        let interval = CivilCalendar.interval(of: CivilDate(year: 2026, month: 1, day: 31))
        #expect(interval == january31..<(january31 + day))
    }

    @Test func dateContainingUsesSaoPauloNotUTC() {
        // 2026-02-01T02:59:59Z is still 23:59:59 on Jan 31 in São Paulo.
        #expect(CivilCalendar.date(containing: january31 + day - 1) == CivilDate(year: 2026, month: 1, day: 31))
        #expect(CivilCalendar.date(containing: january31 + day) == CivilDate(year: 2026, month: 2, day: 1))
        #expect(CivilCalendar.date(containing: january31) == CivilDate(year: 2026, month: 1, day: 31))
        #expect(CivilCalendar.date(containing: january31 - 1) == CivilDate(year: 2026, month: 1, day: 30))
    }

    @Test func monthIntervalCoversEveryDay() {
        let interval = CivilCalendar.interval(of: CivilMonth(year: 2026, month: 1))
        #expect(interval.lowerBound == january31 - 30 * day)
        #expect(interval.upperBound == january31 + day)
    }

    @Test func yearIntervalCoversEveryMonth() {
        let interval = CivilCalendar.interval(ofYear: 2026)
        #expect(interval.lowerBound == CivilCalendar.interval(of: CivilMonth(year: 2026, month: 1)).lowerBound)
        #expect(interval.upperBound == CivilCalendar.interval(of: CivilMonth(year: 2027, month: 1)).lowerBound)
        #expect(interval.count == Int(365 * day))
    }

    @Test func instantAtLocalTime() {
        let evening = CivilCalendar.instant(of: CivilDate(year: 2026, month: 1, day: 31), hour: 19, minute: 0)
        #expect(evening == january31 + 19 * 3_600)
        let withSeconds = CivilCalendar.instant(
            of: CivilDate(year: 2026, month: 1, day: 31), hour: 7, minute: 30, second: 15)
        #expect(withSeconds == january31 + 7 * 3_600 + 30 * 60 + 15)
    }
}

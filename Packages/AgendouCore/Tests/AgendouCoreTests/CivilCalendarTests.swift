import Foundation
import Testing

@testable import AgendouCore

struct CivilCalendarTests {
    @Test func usesSaoPauloTimeZone() {
        #expect(CivilCalendar.timeZone.identifier == "America/Sao_Paulo")
        #expect(CivilCalendar.calendar.timeZone == CivilCalendar.timeZone)
    }

    // Schedule math runs on absolute time and assumes a fixed UTC−3 offset (no DST since 2019).
    // If Brazil brings DST back, this fails and the cycle arithmetic must move to wall-clock time.
    @Test func hasFixedUTCMinusThreeOffset() {
        let january = Date(timeIntervalSince1970: 1_767_225_600)  // 2026-01-01T00:00:00Z
        let july = Date(timeIntervalSince1970: 1_782_864_000)  // 2026-07-01T00:00:00Z

        #expect(CivilCalendar.timeZone.secondsFromGMT(for: january) == -10_800)
        #expect(CivilCalendar.timeZone.secondsFromGMT(for: july) == -10_800)
    }
}

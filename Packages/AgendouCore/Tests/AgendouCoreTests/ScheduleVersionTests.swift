import Foundation
import Testing

@testable import AgendouCore

struct ScheduleVersionTests {
    private func at(_ day: Int, _ hour: Int) -> Int64 {
        CivilCalendar.instant(of: CivilDate(year: 2026, month: 1, day: day), hour: hour, minute: 0)
    }

    private func version(anchor: Int64, startsAt: Int64, endsAt: Int64? = nil) -> ScheduleVersion {
        ScheduleVersion(
            id: UUID(), categoryID: UUID(), workSeconds: 43_200, restSeconds: 129_600,
            anchorAt: anchor, startsAt: startsAt, endsAt: endsAt)
    }

    @Test func firstOccurrenceIsTheAnchorWhenTheVersionStartsThere() {
        #expect(version(anchor: at(5, 7), startsAt: at(5, 7)).firstOccurrenceStart == at(5, 7))
    }

    @Test func firstOccurrenceGoesBackToTheVersionStart() {
        #expect(version(anchor: at(20, 7), startsAt: at(10, 0)).firstOccurrenceStart == at(10, 7))
    }

    @Test func firstOccurrenceSkipsCyclesBeforeTheVersionStart() {
        #expect(version(anchor: at(5, 7), startsAt: at(6, 0)).firstOccurrenceStart == at(7, 7))
    }

    @Test func versionEndingBeforeItsFirstOccurrenceHasNone() {
        #expect(version(anchor: at(20, 7), startsAt: at(10, 0), endsAt: at(10, 5)).firstOccurrenceStart == nil)
    }

    @Test func nextOccurrenceAtOrAfterAnInstant() {
        let schedule = version(anchor: at(5, 7), startsAt: at(5, 7))
        #expect(schedule.firstOccurrenceStart(atOrAfter: at(5, 7)) == at(5, 7))
        #expect(schedule.firstOccurrenceStart(atOrAfter: at(5, 7) + 1) == at(7, 7))
        #expect(schedule.firstOccurrenceStart(atOrAfter: at(1, 0)) == at(5, 7))
    }

    @Test func noOccurrenceAfterTheVersionEnds() {
        let schedule = version(anchor: at(5, 7), startsAt: at(5, 7), endsAt: at(7, 7))
        #expect(schedule.firstOccurrenceStart(atOrAfter: at(6, 0)) == nil)
    }

    @Test func cycleIsWorkPlusRest() {
        #expect(version(anchor: 0, startsAt: 0).cycleSeconds == 172_800)
    }
}

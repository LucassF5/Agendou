import Foundation
import Testing

@testable import AgendouCore

struct PeriodProgressTests {
    private let uti = UUID()
    private let ps = UUID()

    private func shift(_ category: UUID, startsAt: Int64, hours: Int64) -> Occurrence {
        Occurrence(
            categoryID: category, startsAt: startsAt, endsAt: startsAt + hours * 3_600,
            origin: .scheduled(scheduleID: UUID()))
    }

    @Test func splitsByWhetherTheShiftHasStarted() {
        let now: Int64 = 1_000_000
        let progress = PeriodProgress(
            occurrences: [
                shift(uti, startsAt: now - 100_000, hours: 12),
                shift(ps, startsAt: now - 50_000, hours: 24),
                shift(uti, startsAt: now + 100_000, hours: 12),
            ], now: now)

        #expect(progress.soFar.count == 2)
        #expect(progress.soFar.totalSeconds == 36 * 3_600)
        #expect(progress.total.count == 3)
        #expect(progress.total.totalSeconds == 48 * 3_600)
        #expect(progress.soFar.byCategory[uti] == PeriodSummary.Total(seconds: 12 * 3_600, count: 1))
        #expect(progress.total.byCategory[uti] == PeriodSummary.Total(seconds: 24 * 3_600, count: 2))
    }

    /// Counted by start like everywhere else: a shift in progress counts whole, one starting now has
    /// started.
    @Test func aShiftInProgressOrStartingNowCountsWhole() {
        let now: Int64 = 1_000_000
        let progress = PeriodProgress(
            occurrences: [shift(uti, startsAt: now - 3_600, hours: 12), shift(ps, startsAt: now, hours: 6)], now: now)

        #expect(progress.soFar.count == 2)
        #expect(progress.soFar.totalSeconds == 18 * 3_600)
    }

    @Test func emptyPeriod() {
        let progress = PeriodProgress(occurrences: [], now: 0)
        #expect(progress.soFar == PeriodSummary(occurrences: []))
        #expect(progress.total == PeriodSummary(occurrences: []))
    }
}

import Foundation
import Testing

@testable import AgendouCore

struct MonthShareTests {
    private let uti = UUID()
    private let ps = UUID()
    private let october = CivilMonth(year: 2026, month: 10)

    private func at(_ day: Int, _ hour: Int, month: Int = 10) -> Int64 {
        CivilCalendar.instant(of: CivilDate(year: 2026, month: month, day: day), hour: hour, minute: 0)
    }

    private func shift(_ category: UUID, _ day: Int, _ hour: Int, hours: Int64, month: Int = 10) -> Occurrence {
        let start = at(day, hour, month: month)
        return Occurrence(
            categoryID: category, startsAt: start, endsAt: start + hours * 3_600,
            origin: .scheduled(scheduleID: UUID()))
    }

    private var names: [UUID: String] { [uti: "UTI Hospital X", ps: " PS Santa Casa"] }

    @Test func keepsTheMonthsShiftsInChronologicalOrder() {
        let share = MonthShare(
            month: october,
            occurrences: [
                shift(uti, 3, 7, hours: 12), shift(ps, 2, 19, hours: 12), shift(uti, 1, 7, hours: 12),
                shift(uti, 30, 7, hours: 12, month: 9), shift(uti, 1, 7, hours: 12, month: 11),
            ], names: names)

        #expect(share.shifts.map(\.startsAt) == [at(1, 7), at(2, 19), at(3, 7)])
        #expect(share.shifts(on: CivilDate(year: 2026, month: 10, day: 2)).map(\.categoryID) == [ps])
    }

    @Test func legendHasMostShiftsFirstWithCounts() {
        let share = MonthShare(
            month: october,
            occurrences: [shift(ps, 2, 19, hours: 12), shift(uti, 1, 7, hours: 12), shift(uti, 3, 7, hours: 12)],
            names: names)

        #expect(share.categories.map(\.name) == ["UTI Hospital X", "PS Santa Casa"])
        #expect(share.categories.map(\.count) == [2, 1])
        #expect(share.totalCount == 3)
    }

    @Test func leavesOutCategoriesThatWereNotChosen() {
        let share = MonthShare(
            month: october, occurrences: [shift(ps, 2, 19, hours: 12), shift(uti, 1, 7, hours: 12)], names: names,
            including: [uti])

        #expect(share.categories.map(\.id) == [uti])
        #expect(share.shifts.map(\.categoryID) == [uti])
    }

    @Test func shortLabelIsTheFirstWord() {
        let share = MonthShare(
            month: october, occurrences: [shift(ps, 2, 19, hours: 12), shift(uti, 1, 7, hours: 12)], names: names)
        let labels = Dictionary(uniqueKeysWithValues: share.categories.map { ($0.id, $0.shortLabel) })
        #expect(labels == [uti: "UTI", ps: "PS"])
    }

    @Test func repeatedFirstWordsSwitchEveryLabelToLetters() {
        let first = UUID()
        let second = UUID()
        let share = MonthShare(
            month: october,
            occurrences: [
                shift(first, 1, 7, hours: 12), shift(first, 3, 7, hours: 12), shift(second, 2, 7, hours: 12),
                shift(uti, 4, 7, hours: 12),
            ],
            names: [first: "Hospital A", second: "Hospital B", uti: "UTI Hospital X"])

        #expect(share.categories.map(\.shortLabel) == ["A", "B", "C"])
    }

    @Test func usualTimeIsTheMostCommonStartAndLength() {
        let share = MonthShare(
            month: october,
            occurrences: [
                shift(uti, 1, 7, hours: 12), shift(uti, 3, 7, hours: 12), shift(uti, 5, 19, hours: 12),
                shift(ps, 2, 19, hours: 12), shift(ps, 4, 7, hours: 6),
            ], names: names)

        let utiLegend = share.categories.first { $0.id == uti }
        #expect(utiLegend?.usualStart == Int64(7 * 3_600))
        #expect(utiLegend?.usualDuration == Int64(12 * 3_600))
        // A tie goes to the earlier start.
        let psLegend = share.categories.first { $0.id == ps }
        #expect(psLegend?.usualStart == Int64(7 * 3_600))
        #expect(psLegend?.usualDuration == Int64(6 * 3_600))
    }

    @Test func emptyMonth() {
        let share = MonthShare(month: october, occurrences: [], names: names)
        #expect(share.shifts.isEmpty)
        #expect(share.categories.isEmpty)
        #expect(share.totalCount == 0)
    }
}

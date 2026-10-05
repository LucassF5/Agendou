import Foundation
import Testing

@testable import AgendouCore

struct ShiftTimelineTests {
    private let uti = UUID()
    private let ps = UUID()
    private let h: Int64 = 3_600

    private func shift(_ category: UUID, _ start: Int64, _ end: Int64) -> Occurrence {
        Occurrence(categoryID: category, startsAt: start, endsAt: end, origin: .extra(overrideID: UUID()))
    }

    private func at(_ day: Int, _ hour: Int) -> Int64 {
        CivilCalendar.instant(of: CivilDate(year: 2026, month: 10, day: day), hour: hour, minute: 0)
    }

    @Test func noShiftsMakesOneEmptyEntry() {
        let entries = ShiftTimeline.entries(occurrences: [], now: 1_000, window: 100 * h)
        #expect(entries == [ShiftTimelineEntry(date: 1_000, shift: nil, following: [])])
    }

    @Test func aFutureShiftStartsThenEnds() {
        let a = shift(uti, 10 * h, 20 * h)
        let entries = ShiftTimeline.entries(occurrences: [a], now: 0, window: 100 * h)
        #expect(entries.map(\.date) == [0, 10 * h, 20 * h])
        #expect(entries.map(\.shift) == [a, a, nil])
        #expect(entries.map(\.isInProgress) == [false, true, false])
    }

    @Test func aShiftInProgressNowIsTheHeadline() {
        let a = shift(uti, 0, 10 * h)
        let entries = ShiftTimeline.entries(occurrences: [a], now: 4 * h, window: 100 * h)
        #expect(entries.map(\.date) == [4 * h, 10 * h])
        #expect(entries.first?.shift == a)
        #expect(entries.first?.isInProgress == true)
    }

    @Test func aShiftEndingExactlyAtTheEntryDateIsOver() {
        let a = shift(uti, 0, 10 * h)
        let entries = ShiftTimeline.entries(occurrences: [a], now: 10 * h, window: 100 * h)
        #expect(entries == [ShiftTimelineEntry(date: 10 * h, shift: nil, following: [])])
    }

    @Test func followingHoldsTheTwoShiftsAfterTheHeadline() {
        let a = shift(uti, h, 2 * h)
        let b = shift(uti, 3 * h, 4 * h)
        let c = shift(uti, 5 * h, 6 * h)
        let d = shift(uti, 7 * h, 8 * h)
        let entries = ShiftTimeline.entries(occurrences: [a, b, c, d], now: 0, window: 100 * h)
        #expect(entries.first?.shift == a)
        #expect(entries.first?.following == [b, c])
        let atTwo = entries.first { $0.date == 2 * h }
        #expect(atTwo?.shift == b)
        #expect(atTwo?.following == [c, d])
    }

    @Test func twoShiftsStartingTogetherShareTheStart() {
        let a = shift(uti, 10 * h, 22 * h)
        let b = shift(ps, 10 * h, 22 * h)
        let entries = ShiftTimeline.entries(occurrences: [a, b], now: 0, window: 100 * h)
        #expect(entries.map(\.date) == [0, 10 * h, 22 * h])
        #expect(entries[1].shift == a)
        #expect(entries[1].following == [b])
        #expect(entries[2].shift == nil)
    }

    @Test func overlappingShiftsHandOverWhenTheFirstEnds() {
        let a = shift(uti, 0, 12 * h)
        let b = shift(ps, 6 * h, 18 * h)
        let entries = ShiftTimeline.entries(occurrences: [a, b], now: 0, window: 100 * h)
        #expect(entries.map(\.date) == [0, 6 * h, 12 * h, 18 * h])
        #expect(entries.map(\.shift) == [a, a, b, nil])
        #expect(entries[2].following == [])
    }

    @Test func aShiftBeyondTheWindowStillHeadlinesTheLastEntry() {
        let near = shift(uti, h, 2 * h)
        let far = shift(uti, 200 * h, 201 * h)
        let entries = ShiftTimeline.entries(occurrences: [near, far], now: 0, window: 100 * h)
        #expect(entries.map(\.date) == [0, h, 2 * h])
        #expect(entries.last?.shift == far)
        #expect(entries.last?.following == [])
    }

    @Test func aShiftCrossingMidnightIsInProgressUntilMorning() {
        let night = shift(uti, at(1, 19), at(2, 7))
        let entries = ShiftTimeline.entries(occurrences: [night], now: at(1, 23), window: 7 * 24 * h)
        #expect(entries.map(\.date) == [at(1, 23), at(2, 7)])
        #expect(entries.map(\.isInProgress) == [true, false])
        #expect(entries.first?.shift == night)
    }

    @Test func entriesAreCapped() {
        let many = (0..<60).map { shift(uti, Int64($0) * 2 * h + h, Int64($0) * 2 * h + 2 * h) }
        let entries = ShiftTimeline.entries(occurrences: many, now: 0, window: 1_000 * h)
        #expect(entries.count == ShiftTimeline.maxEntries)
        #expect(entries.map(\.date) == entries.map(\.date).sorted())
    }

    @Test func refreshesWhenTheLastEntryStarts() {
        let a = shift(uti, 10 * h, 20 * h)
        let entries = ShiftTimeline.entries(occurrences: [a], now: 0, window: 100 * h)
        #expect(ShiftTimeline.refreshDate(for: entries, now: 0) == 20 * h)
    }

    @Test func refreshesTwelveHoursLaterWithASingleEntry() {
        let entries = ShiftTimeline.entries(occurrences: [], now: 500, window: 100 * h)
        #expect(ShiftTimeline.refreshDate(for: entries, now: 500) == 500 + 12 * h)
    }
}

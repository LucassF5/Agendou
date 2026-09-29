import Foundation

/// Hours and shift count for a period, overall and per category.
///
/// Pass the occurrences that **start** in the period; a night shift crossing into the next month is
/// counted whole in the month it starts.
public struct PeriodSummary: Equatable, Sendable {
    public struct Total: Equatable, Sendable {
        public var seconds: Int64
        public var count: Int

        public init(seconds: Int64, count: Int) {
            self.seconds = seconds
            self.count = count
        }
    }

    public var totalSeconds: Int64
    public var count: Int
    public var byCategory: [UUID: Total]

    public init(totalSeconds: Int64, count: Int, byCategory: [UUID: Total]) {
        self.totalSeconds = totalSeconds
        self.count = count
        self.byCategory = byCategory
    }

    public init(occurrences: some Sequence<Occurrence>) {
        self.init(totalSeconds: 0, count: 0, byCategory: [:])
        for occurrence in occurrences {
            totalSeconds += occurrence.durationSeconds
            count += 1
            byCategory[occurrence.categoryID, default: Total(seconds: 0, count: 0)].seconds +=
                occurrence.durationSeconds
            byCategory[occurrence.categoryID, default: Total(seconds: 0, count: 0)].count += 1
        }
    }
}

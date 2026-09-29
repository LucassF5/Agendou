import Foundation

extension Date {
    /// Whole seconds since 1970-01-01T00:00:00Z, rounded toward the past.
    ///
    /// Every instant the app stores goes through this: `Date` is a `Double`, and two dates that print the
    /// same can still differ by a fraction of a second and break equality on (category, start).
    public var epochSeconds: Int64 {
        Int64(timeIntervalSince1970.rounded(.down))
    }

    public init(epochSeconds: Int64) {
        self.init(timeIntervalSince1970: TimeInterval(epochSeconds))
    }
}

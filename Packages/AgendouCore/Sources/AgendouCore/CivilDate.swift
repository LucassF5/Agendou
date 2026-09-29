/// A day on the wall calendar (no time, no time zone), such as the day a note belongs to.
public struct CivilDate: Hashable, Comparable, Sendable, Identifiable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// Parses `AAAA-MM-DD`; `nil` for anything else, including days that do not exist.
    public init?(string: String) {
        let parts = string.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
            let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
            (1...12).contains(month),
            (1...CivilMonth(year: year, month: month).numberOfDays).contains(day)
        else { return nil }
        self.init(year: year, month: month, day: day)
    }

    /// `AAAA-MM-DD`.
    public var string: String {
        "\(pad(year, 4))-\(pad(month, 2))-\(pad(day, 2))"
    }

    public var id: String {
        string
    }

    public static func < (lhs: CivilDate, rhs: CivilDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

/// A month on the wall calendar.
public struct CivilMonth: Hashable, Comparable, Sendable {
    public let year: Int
    /// 1...12
    public let month: Int

    public init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    public init(_ date: CivilDate) {
        self.init(year: date.year, month: date.month)
    }

    /// Parses `AAAA-MM`.
    public init?(string: String) {
        let parts = string.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 2, parts[0].count == 4, parts[1].count == 2,
            let year = Int(parts[0]), let month = Int(parts[1]), (1...12).contains(month)
        else { return nil }
        self.init(year: year, month: month)
    }

    /// `AAAA-MM`.
    public var string: String {
        "\(pad(year, 4))-\(pad(month, 2))"
    }

    public var next: CivilMonth {
        month == 12 ? CivilMonth(year: year + 1, month: 1) : CivilMonth(year: year, month: month + 1)
    }

    public var previous: CivilMonth {
        month == 1 ? CivilMonth(year: year - 1, month: 12) : CivilMonth(year: year, month: month - 1)
    }

    public var numberOfDays: Int {
        switch month {
        case 2: isLeapYear ? 29 : 28
        case 4, 6, 9, 11: 30
        default: 31
        }
    }

    public var firstDay: CivilDate {
        CivilDate(year: year, month: month, day: 1)
    }

    public var days: [CivilDate] {
        (1...numberOfDays).map { CivilDate(year: year, month: month, day: $0) }
    }

    private var isLeapYear: Bool {
        (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }

    public static func < (lhs: CivilMonth, rhs: CivilMonth) -> Bool {
        (lhs.year, lhs.month) < (rhs.year, rhs.month)
    }
}

private func pad(_ value: Int, _ width: Int) -> String {
    let digits = String(value)
    return String(repeating: "0", count: max(0, width - digits.count)) + digits
}

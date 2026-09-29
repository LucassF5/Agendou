import Testing

@testable import AgendouCore

struct IntegerDivisionTests {
    // Swift's `/` truncates toward zero (`-1 / 7 == 0`), which would put an occurrence before the anchor
    // in the wrong cycle. Both helpers must round toward −∞ / +∞ regardless of the sign.
    @Test(arguments: [
        (Int64(0), Int64(7), Int64(0)),
        (14, 7, 2),
        (15, 7, 2),
        (-1, 7, -1),
        (-7, 7, -1),
        (-8, 7, -2),
    ])
    func floorDivRoundsTowardNegativeInfinity(numerator: Int64, divisor: Int64, expected: Int64) {
        #expect(floorDiv(numerator, divisor) == expected)
    }

    @Test(arguments: [
        (Int64(0), Int64(7), Int64(0)),
        (14, 7, 2),
        (15, 7, 3),
        (-1, 7, 0),
        (-7, 7, -1),
        (-8, 7, -1),
    ])
    func ceilDivRoundsTowardPositiveInfinity(numerator: Int64, divisor: Int64, expected: Int64) {
        #expect(ceilDiv(numerator, divisor) == expected)
    }
}

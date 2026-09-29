/// Integer division rounded toward −∞. `divisor` must be positive.
///
/// Swift's `/` truncates toward zero, so `-1 / 7 == 0`: the cycle index of an instant before the anchor
/// would come out one too high and an occurrence would vanish.
public func floorDiv(_ numerator: Int64, _ divisor: Int64) -> Int64 {
    precondition(divisor > 0, "divisor must be positive")
    let quotient = numerator / divisor
    return numerator % divisor < 0 ? quotient - 1 : quotient
}

/// Integer division rounded toward +∞. `divisor` must be positive.
public func ceilDiv(_ numerator: Int64, _ divisor: Int64) -> Int64 {
    precondition(divisor > 0, "divisor must be positive")
    let quotient = numerator / divisor
    return numerator % divisor > 0 ? quotient + 1 : quotient
}

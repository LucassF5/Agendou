import Foundation
import Testing

@testable import AgendouCore

struct EpochSecondsTests {
    @Test func dropsFractionalSeconds() {
        #expect(Date(timeIntervalSince1970: 1_767_225_600.999).epochSeconds == 1_767_225_600)
    }

    @Test func roundsTowardPastBeforeEpoch() {
        #expect(Date(timeIntervalSince1970: -0.5).epochSeconds == -1)
    }

    @Test func roundTrips() {
        #expect(Date(epochSeconds: 1_767_225_600).epochSeconds == 1_767_225_600)
        #expect(Date(epochSeconds: 1_767_225_600).timeIntervalSince1970 == 1_767_225_600)
    }
}

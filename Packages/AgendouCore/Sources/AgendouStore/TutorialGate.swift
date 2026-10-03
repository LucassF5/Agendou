import Foundation

/// Decides whether the first-launch tutorial opens by itself and remembers that it was seen.
public struct TutorialGate {
    private let store: AgendaStore
    private let defaults: UserDefaults
    private static let seenKey = "tutorial.seen"

    public init(store: AgendaStore, defaults: UserDefaults = .standard) {
        self.store = store
        self.defaults = defaults
    }

    /// Never seen and no schedule yet. The seeded "Extra" category has no schedule, so it does not count.
    public var shouldPresentOnLaunch: Bool {
        !defaults.bool(forKey: Self.seenKey) && !store.hasAnySchedule
    }

    public func markSeen() {
        defaults.set(true, forKey: Self.seenKey)
    }
}

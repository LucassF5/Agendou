import AgendouCore
import Foundation
import SwiftData

@testable import AgendouStore

/// A store over an in-memory container with a clock the test moves by hand.
final class TestAgenda {
    let container: ModelContainer
    let store: AgendaStore
    var now: Date

    init(now: Date = at(2026, 9, 29, 12)) {
        self.now = now
        container = try! AgendouContainer.make(inMemory: true)
        var clockNow: () -> Date = { Date() }
        store = AgendaStore(context: container.mainContext, clock: { clockNow() })
        clockNow = { [unowned self] in self.now }
    }

    /// A category with an open 12x36 schedule anchored at `anchor`.
    func category12x36(name: String = "UTI", anchor: Date, startsAt: Date? = nil) throws -> ShiftCategory {
        let category = try store.createCategory(name: name, color: .teal)
        try store.startFirstSchedule(
            for: category, workSeconds: 43_200, restSeconds: 129_600, anchorAt: anchor, startsAt: startsAt ?? anchor)
        return category
    }

    func month(_ year: Int, _ month: Int) -> Expansion {
        store.expand(in: CivilCalendar.interval(of: CivilMonth(year: year, month: month)))
    }

    func day(_ year: Int, _ month: Int, _ day: Int) -> Expansion {
        store.expand(in: CivilCalendar.interval(of: CivilDate(year: year, month: month, day: day)))
    }
}

/// Wall-clock time in America/Sao_Paulo.
func at(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
    Date(
        epochSeconds: CivilCalendar.instant(
            of: CivilDate(year: year, month: month, day: day), hour: hour, minute: minute))
}

let hour = 3_600

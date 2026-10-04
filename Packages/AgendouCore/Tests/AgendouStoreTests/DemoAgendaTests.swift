import AgendouCore
import Foundation
import Testing

@testable import AgendouStore

struct DemoAgendaTests {
    private let now = at(2026, 10, 3, 12)

    private func demo() throws -> AgendaStore {
        try AgendaStore.demo(clock: { [now] in now })
    }

    @Test func hasTheTwoSampleCategories() throws {
        let store = try demo()

        #expect(store.activeCategories().map(\.name).sorted() == ["PS Exemplo", "UTI Exemplo"])
    }

    @Test func theUTIRunsA12x36FromWeeksAgo() throws {
        let store = try demo()
        let uti = try #require(store.activeCategories().first { $0.name == "UTI Exemplo" })
        let schedule = try #require(store.openSchedule(of: uti))

        #expect(schedule.workSeconds == 43_200 && schedule.restSeconds == 129_600)
        let september = store.expand(in: CivilCalendar.interval(of: CivilMonth(year: 2026, month: 9)))
        #expect(september.occurrences.contains { $0.categoryID == uti.id })
        #expect(store.currentOrNextShift()?.categoryID == uti.id)
    }

    @Test func thePSHasOneExtraTwoDaysFromTodayAt19h() throws {
        let store = try demo()
        let ps = try #require(store.activeCategories().first { $0.name == "PS Exemplo" })
        let day = store.expand(in: CivilCalendar.interval(of: CivilDate(year: 2026, month: 10, day: 5)))

        #expect(store.openSchedule(of: ps) == nil)
        #expect(day.occurrences.filter { $0.categoryID == ps.id }.map(\.startsAt) == [at(2026, 10, 5, 19).epochSeconds])
    }

    @Test func eachCallStartsFromAFreshStore() throws {
        let first = try demo()
        _ = try first.createCategory(name: "Outra", color: .blue)

        #expect(try demo().activeCategories().count == 2)
    }
}

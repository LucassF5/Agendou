import AgendouCore
import Foundation

extension AgendaStore {
    /// The sample agenda the tour runs on: kept in memory only, so nothing in it is ever saved.
    ///
    /// "UTI Exemplo" works a 12x36 at 07:00 that started four weeks ago, so the calendar, the month summary
    /// and the next shift have something to show; "PS Exemplo" has no schedule and one extra two days from
    /// today at 19:00, so the calendar shows a second color.
    public static func demo(clock: @escaping () -> Date = Date.init) throws -> AgendaStore {
        let container = try AgendouContainer.make(inMemory: true)
        let store = AgendaStore(context: container.mainContext, clock: clock)
        store.ownedContainer = container
        let now = clock()
        let today = CivilCalendar.date(containing: now.epochSeconds)
        let sevenToday = Date(epochSeconds: CivilCalendar.instant(of: today, hour: 7, minute: 0))
        let anchor = sevenToday > now ? sevenToday : sevenToday.addingTimeInterval(86_400)

        let uti = try store.createCategory(name: "UTI Exemplo", color: .teal)
        try store.startFirstSchedule(
            for: uti, workSeconds: 43_200, restSeconds: 129_600, anchorAt: anchor,
            startsAt: anchor.addingTimeInterval(-28 * 86_400), period: .months(3))

        let ps = try store.createCategory(name: "PS Exemplo", color: .orange)
        let extraStart = Date(epochSeconds: CivilCalendar.instant(of: today.adding(days: 2), hour: 19, minute: 0))
        _ = try store.addExtra(to: ps, startsAt: extraStart, endsAt: extraStart.addingTimeInterval(43_200))
        return store
    }
}

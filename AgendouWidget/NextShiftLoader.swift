import AgendouCore
import AgendouStore
import Foundation
import SwiftData
import WidgetKit

/// Reads the app's database (read-only) from the App Group and plans the widget's timeline.
@MainActor
enum NextShiftLoader {
    /// How far ahead entries are planned; the headline of each one looks further.
    static let window: Int64 = 14 * 86_400

    static func timeline(now: Date) -> Timeline<NextShiftEntry> {
        guard let loaded = load(now: now) else {
            return Timeline(
                entries: [.empty(at: now)], policy: .after(now.addingTimeInterval(Double(ShiftTimeline.emptyRefresh))))
        }
        return Timeline(entries: loaded.entries, policy: .after(loaded.refresh))
    }

    private static func load(now: Date) -> (entries: [NextShiftEntry], refresh: Date)? {
        guard let container = try? AgendouContainer.make() else { return nil }
        // A context does not keep its container alive: hold it until every value has been copied out.
        return withExtendedLifetime(container) {
            let store = AgendaStore(context: container.mainContext, clock: { now })
            let categories = Dictionary(
                (store.activeCategories() + store.archivedCategories()).map { ($0.id, $0) },
                uniquingKeysWith: { first, _ in first })

            // A local function in a closure is not inferred to be on the main actor; `CategoryColor(key:)` needs it.
            @MainActor func resolve(_ occurrence: Occurrence) -> WidgetShift {
                let category = categories[occurrence.categoryID]
                return WidgetShift(
                    categoryName: category?.name ?? "Plantão",
                    color: category.map { CategoryColor(key: $0.colorKey) } ?? .teal,
                    startsAt: occurrence.startsAt, endsAt: occurrence.endsAt)
            }

            let planned = ShiftTimeline.entries(
                occurrences: store.shiftsFromNow(), now: now.epochSeconds, window: window)
            let entries = planned.map {
                NextShiftEntry(
                    date: Date(epochSeconds: $0.date), shift: $0.shift.map(resolve),
                    following: $0.following.map(resolve))
            }
            let refresh = Date(epochSeconds: ShiftTimeline.refreshDate(for: planned, now: now.epochSeconds))
            return (entries, refresh)
        }
    }
}

import AgendouCore
import AgendouStore
import Foundation
import SwiftData
import WidgetKit
import os

/// Reads the app's database (read-only) from the App Group and plans the widget's timeline.
@MainActor
enum NextShiftLoader {
    /// How far ahead entries are planned; the headline of each one looks further.
    static let window: Int64 = 14 * 86_400
    /// When to try again if the database cannot be opened, as before the first unlock after a reboot.
    static let openRetry: TimeInterval = 15 * 60

    private static let logger = Logger(subsystem: "com.lucasfranco.agendou.widget", category: "timeline")

    static func timeline(now: Date) -> Timeline<NextShiftEntry> {
        let container: ModelContainer
        do {
            container = try AgendouContainer.makeReadOnly()
        } catch AgendouContainer.OpenError.storeNotCreated {
            // The app has not saved anything yet: no shifts, as in an empty agenda.
            return plan(shifts: [], categories: [:], now: now)
        } catch {
            logger.error("Could not open the database: \(error.localizedDescription, privacy: .public)")
            return Timeline(entries: [.unavailable(at: now)], policy: .after(now.addingTimeInterval(openRetry)))
        }
        // A context does not keep its container alive: hold it until every value has been copied out.
        return withExtendedLifetime(container) {
            let store = AgendaStore(context: container.mainContext, clock: { now })
            let categories = Dictionary(
                (store.activeCategories() + store.archivedCategories()).map { ($0.id, $0) },
                uniquingKeysWith: { first, _ in first })
            return plan(shifts: store.shiftsFromNow(), categories: categories, now: now)
        }
    }

    /// The entries for `shifts` (not over at `now`, soonest first), with each category resolved to the
    /// values the views draw.
    private static func plan(shifts: [Occurrence], categories: [UUID: ShiftCategory], now: Date)
        -> Timeline<NextShiftEntry>
    {
        func resolve(_ occurrence: Occurrence) -> WidgetShift {
            let category = categories[occurrence.categoryID]
            return WidgetShift(
                categoryName: category?.name ?? "Plantão",
                color: category.map { CategoryColor(key: $0.colorKey) } ?? .teal,
                startsAt: occurrence.startsAt, endsAt: occurrence.endsAt)
        }

        let planned = ShiftTimeline.entries(occurrences: shifts, now: now.epochSeconds, window: window)
        let entries = planned.map {
            NextShiftEntry(
                date: Date(epochSeconds: $0.date), shift: $0.shift.map(resolve), isInProgress: $0.isInProgress,
                following: $0.following.map(resolve), isUnavailable: false)
        }
        let refresh = Date(epochSeconds: ShiftTimeline.refreshDate(for: planned, now: now.epochSeconds))
        return Timeline(entries: entries, policy: .after(refresh))
    }
}

import AgendouCore
import AgendouStore
import Foundation
import SwiftData

extension AgendaStore {
    /// In-memory store with two categories, for previews.
    static let preview: AgendaStore = {
        let container = try! AgendouContainer.make(inMemory: true)
        let store = AgendaStore(context: container.mainContext)
        let uti = try! store.createCategory(name: "UTI Hospital X", color: .teal)
        let anchor = DefaultTimes.nextShiftStart(after: .now)
        try! store.startFirstSchedule(
            for: uti, workSeconds: 12 * 3_600, restSeconds: 36 * 3_600, anchorAt: anchor,
            startsAt: anchor.addingTimeInterval(-60 * 86_400), period: .months(3))
        _ = try! store.createCategory(name: "Extra", color: .orange)
        return store
    }()
}

extension ShiftNotifier {
    /// A notifier that schedules nothing, for previews.
    static let preview = ShiftNotifier(
        store: .preview, scheduler: UITestReminderScheduler(), defaults: UserDefaults(suiteName: "preview")!)
}

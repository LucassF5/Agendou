import AgendouCore
import Foundation
import SwiftData

extension AgendaStore {
    public func note(for day: CivilDate) -> DayNote? {
        _ = revision
        let key = day.string
        return try? context.fetch(FetchDescriptor<DayNote>(predicate: #Predicate { $0.day == key })).first
    }

    /// One note per day; saving a blank note deletes it.
    public func setNote(_ body: String, for day: CivilDate) throws {
        let existing = note(for: day)
        if body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let existing else { return }
            context.delete(existing)
        } else if let existing {
            existing.body = body
            existing.updatedAt = Date(epochSeconds: now)
        } else {
            context.insert(DayNote(day: day.string, body: body, updatedAt: Date(epochSeconds: now)))
        }
        try save()
    }
}

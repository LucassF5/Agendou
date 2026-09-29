import AgendouCore
import Foundation

/// The backup file: the stored state only, never computed occurrences. Instants are ISO 8601 UTC
/// without fractional seconds.
public struct AgendaExport: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public struct CategoryRecord: Codable, Equatable, Sendable {
        public var id: UUID
        public var name: String
        public var colorKey: String
        public var archivedAt: Date?
        public var createdAt: Date
    }

    public struct ScheduleRecord: Codable, Equatable, Sendable {
        public var id: UUID
        public var categoryId: UUID
        public var workSeconds: Int
        public var restSeconds: Int
        public var anchorAt: Date
        public var startsAt: Date
        public var endsAt: Date?
        public var createdAt: Date
    }

    public struct OverrideRecord: Codable, Equatable, Sendable {
        public var id: UUID
        public var categoryId: UUID
        /// "extra" or "cancellation".
        public var kind: String
        public var startsAt: Date
        public var endsAt: Date
        public var createdAt: Date
    }

    public struct DayNoteRecord: Codable, Equatable, Sendable {
        public var id: UUID
        /// `AAAA-MM-DD`.
        public var day: String
        public var body: String
        public var updatedAt: Date
    }

    public var schemaVersion: Int
    public var exportedAt: Date
    public var categories: [CategoryRecord]
    public var schedules: [ScheduleRecord]
    public var overrides: [OverrideRecord]
    public var dayNotes: [DayNoteRecord]

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    /// Reads and validates a whole file. Nothing is written anywhere.
    public static func decode(_ data: Data) throws -> AgendaExport {
        let decoder = JSONDecoder()
        // Stricter than `.iso8601`, which also takes fractional seconds.
        decoder.dateDecodingStrategy = .custom { decoder in
            let string = try decoder.singleValueContainer().decode(String.self)
            guard !string.contains("."), let date = try? Date(string, strategy: .iso8601) else {
                throw DecodingError.dataCorrupted(
                    .init(codingPath: decoder.codingPath, debugDescription: "Not ISO 8601 in whole seconds: \(string)"))
            }
            return date
        }
        // The version first, so a file from a newer app says so instead of looking corrupt.
        guard let version = try? decoder.decode(VersionProbe.self, from: data).schemaVersion else {
            throw AgendaImportError.unreadable
        }
        guard version == currentSchemaVersion else { throw AgendaImportError.unsupportedVersion(version) }
        guard let export = try? decoder.decode(AgendaExport.self, from: data) else {
            throw AgendaImportError.unreadable
        }
        try export.validate()
        return export
    }

    private struct VersionProbe: Decodable {
        let schemaVersion: Int
    }

    /// The invariants `AgendaStore` keeps, checked before anything is replaced.
    func validate() throws {
        func unique(_ ids: [UUID]) -> Bool { Set(ids).count == ids.count }
        guard unique(categories.map(\.id)), unique(schedules.map(\.id)), unique(overrides.map(\.id)),
            unique(dayNotes.map(\.id))
        else { throw AgendaImportError.duplicateID }

        let categoryIDs = Set(categories.map(\.id))
        guard schedules.allSatisfy({ categoryIDs.contains($0.categoryId) }),
            overrides.allSatisfy({ categoryIDs.contains($0.categoryId) })
        else { throw AgendaImportError.unknownCategory }

        for schedule in schedules {
            guard schedule.workSeconds > 0, schedule.restSeconds > 0, schedule.startsAt <= schedule.anchorAt,
                schedule.endsAt.map({ $0 > schedule.startsAt }) ?? true
            else { throw AgendaImportError.invalidSchedule }
        }
        // Versions of a category follow one another: each ends at or before the next starts.
        for versions in Dictionary(grouping: schedules, by: \.categoryId).values {
            let sorted = versions.sorted { $0.startsAt < $1.startsAt }
            for (current, next) in zip(sorted, sorted.dropFirst()) {
                guard let end = current.endsAt, end <= next.startsAt else {
                    throw AgendaImportError.overlappingSchedules
                }
            }
        }

        var overrideKeys: Set<String> = []
        for override in overrides {
            guard ["extra", "cancellation"].contains(override.kind), override.endsAt > override.startsAt else {
                throw AgendaImportError.invalidOverride
            }
            let key = "\(override.categoryId)|\(override.startsAt.epochSeconds)|\(override.kind)"
            guard overrideKeys.insert(key).inserted else { throw AgendaImportError.duplicateOverride }
        }

        var days: Set<String> = []
        for note in dayNotes {
            guard CivilDate(string: note.day) != nil, days.insert(note.day).inserted else {
                throw AgendaImportError.invalidDayNote
            }
        }
    }
}

/// Why a backup file was refused. The app turns these into pt-BR messages.
public enum AgendaImportError: Error, Equatable, Sendable {
    /// Not JSON, missing fields, or instants that are not ISO 8601 without fractions.
    case unreadable
    case unsupportedVersion(Int)
    case duplicateID
    case unknownCategory
    case invalidSchedule
    case overlappingSchedules
    case invalidOverride
    case duplicateOverride
    case invalidDayNote
}

import Foundation
import SwiftData

/// First version of the on-device schema. Later versions go next to it and get a stage in
/// `AgendouMigrationPlan`; models are always referenced through the typealiases below.
public enum AgendouSchemaV1: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [ShiftCategory.self, CategorySchedule.self, ShiftOverride.self, DayNote.self]
    }

    /// A job (place + kind of work), e.g. "UTI Hospital X".
    @Model public final class ShiftCategory {
        @Attribute(.unique) public internal(set) var id: UUID
        public internal(set) var name: String
        /// Key of the fixed palette (`CategoryColor`), never a hex value.
        public internal(set) var colorKey: String
        public internal(set) var archivedAt: Date?
        public internal(set) var createdAt: Date
        @Relationship(deleteRule: .cascade, inverse: \CategorySchedule.category)
        public internal(set) var schedules: [CategorySchedule] = []
        @Relationship(deleteRule: .cascade, inverse: \ShiftOverride.category)
        public internal(set) var overrides: [ShiftOverride] = []

        init(id: UUID = UUID(), name: String, colorKey: String, archivedAt: Date? = nil, createdAt: Date) {
            self.id = id
            self.name = name
            self.colorKey = colorKey
            self.archivedAt = archivedAt
            self.createdAt = createdAt
        }
    }

    /// A version of a category's rotation. Once it has started it is never edited: it is closed and
    /// another one is opened.
    @Model public final class CategorySchedule {
        @Attribute(.unique) public internal(set) var id: UUID
        public internal(set) var category: ShiftCategory?
        public internal(set) var workSeconds: Int
        public internal(set) var restSeconds: Int
        /// Start of a real shift; fixes the phase of the cycle.
        public internal(set) var anchorAt: Date
        /// Inclusive.
        public internal(set) var startsAt: Date
        /// Exclusive; `nil` while open.
        public internal(set) var endsAt: Date?
        public internal(set) var createdAt: Date

        init(
            id: UUID = UUID(), category: ShiftCategory?, workSeconds: Int, restSeconds: Int, anchorAt: Date,
            startsAt: Date, endsAt: Date? = nil, createdAt: Date
        ) {
            self.id = id
            self.category = category
            self.workSeconds = workSeconds
            self.restSeconds = restSeconds
            self.anchorAt = anchorAt
            self.startsAt = startsAt
            self.endsAt = endsAt
            self.createdAt = createdAt
        }
    }

    /// Everything marked by hand: extra shifts and cancellations of generated ones.
    @Model public final class ShiftOverride {
        @Attribute(.unique) public internal(set) var id: UUID
        /// Required by the rules; optional only because SwiftData relationships must be.
        public internal(set) var category: ShiftCategory?
        /// `Override.Kind` raw value. Stored as `Int` because `#Predicate` does not filter enums reliably.
        public internal(set) var kindRaw: Int
        public internal(set) var startsAt: Date
        public internal(set) var endsAt: Date
        public internal(set) var createdAt: Date

        init(
            id: UUID = UUID(), category: ShiftCategory?, kindRaw: Int, startsAt: Date, endsAt: Date,
            createdAt: Date
        ) {
            self.id = id
            self.category = category
            self.kindRaw = kindRaw
            self.startsAt = startsAt
            self.endsAt = endsAt
            self.createdAt = createdAt
        }
    }

    /// What happened on a day, independent of shifts.
    @Model public final class DayNote {
        @Attribute(.unique) public internal(set) var id: UUID
        /// `AAAA-MM-DD` civil day in America/Sao_Paulo. Text, not a `Date` at midnight: a note has no time.
        @Attribute(.unique) public internal(set) var day: String
        public internal(set) var body: String
        public internal(set) var updatedAt: Date

        init(id: UUID = UUID(), day: String, body: String, updatedAt: Date) {
            self.id = id
            self.day = day
            self.body = body
            self.updatedAt = updatedAt
        }
    }
}

public typealias ShiftCategory = AgendouSchemaV1.ShiftCategory
public typealias CategorySchedule = AgendouSchemaV1.CategorySchedule
public typealias ShiftOverride = AgendouSchemaV1.ShiftOverride
public typealias DayNote = AgendouSchemaV1.DayNote

public enum AgendouMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [AgendouSchemaV1.self] }
    public static var stages: [MigrationStage] { [] }
}

public enum AgendouContainer {
    public static let appGroupIdentifier = "group.com.lucasfranco.agendou"

    /// The app's container, in the App Group so a future widget can read it. `inMemory` is for tests
    /// and previews.
    public static func make(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: AgendouSchemaV1.self)
        let configuration =
            inMemory
            ? ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            : ModelConfiguration(schema: schema, groupContainer: .identifier(appGroupIdentifier))
        return try ModelContainer(for: schema, migrationPlan: AgendouMigrationPlan.self, configurations: configuration)
    }
}

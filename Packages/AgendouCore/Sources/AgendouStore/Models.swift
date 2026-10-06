import Foundation
import SwiftData

/// First version of the on-device schema, kept so older stores can be migrated. Models are always
/// referenced through the typealiases below, which point to the latest version.
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
/// Adds `CategorySchedule.repeatsUntil`, the period a version repeats for.
public enum AgendouSchemaV2: VersionedSchema {
    public static let versionIdentifier = Schema.Version(2, 0, 0)

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
        /// Exclusive; `nil` while open. Set when the version is replaced ("Mudei de escala") or archived.
        public internal(set) var endsAt: Date?
        /// Exclusive end of the period the user chose (midnight after the last day); `nil` only for
        /// versions created before periods existed. The version generates shifts up to the earlier of
        /// this and `endsAt`.
        public internal(set) var repeatsUntil: Date?
        public internal(set) var createdAt: Date

        init(
            id: UUID = UUID(), category: ShiftCategory?, workSeconds: Int, restSeconds: Int, anchorAt: Date,
            startsAt: Date, endsAt: Date? = nil, repeatsUntil: Date? = nil, createdAt: Date
        ) {
            self.id = id
            self.category = category
            self.workSeconds = workSeconds
            self.restSeconds = restSeconds
            self.anchorAt = anchorAt
            self.startsAt = startsAt
            self.endsAt = endsAt
            self.repeatsUntil = repeatsUntil
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

public typealias ShiftCategory = AgendouSchemaV2.ShiftCategory
public typealias CategorySchedule = AgendouSchemaV2.CategorySchedule
public typealias ShiftOverride = AgendouSchemaV2.ShiftOverride
public typealias DayNote = AgendouSchemaV2.DayNote

public enum AgendouMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [AgendouSchemaV1.self, AgendouSchemaV2.self] }
    public static var stages: [MigrationStage] {
        // V2 only adds an optional attribute: nothing to convert.
        [.lightweight(fromVersion: AgendouSchemaV1.self, toVersion: AgendouSchemaV2.self)]
    }
}

public enum AgendouContainer {
    public static let appGroupIdentifier = "group.com.lucasfranco.agendou"

    /// The app's container, in the App Group so a future widget can read it. `inMemory` is for tests
    /// and previews.
    static var schema: Schema {
        Schema(versionedSchema: AgendouSchemaV2.self)
    }

    public static func make(inMemory: Bool = false) throws -> ModelContainer {
        let configuration =
            inMemory
            ? ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            : ModelConfiguration(schema: schema, groupContainer: .identifier(appGroupIdentifier))
        return try ModelContainer(for: schema, migrationPlan: AgendouMigrationPlan.self, configurations: configuration)
    }

    /// A store at a file URL, for migration tests.
    static func make(at url: URL) throws -> ModelContainer {
        try ModelContainer(
            for: schema, migrationPlan: AgendouMigrationPlan.self,
            configurations: ModelConfiguration(schema: schema, url: url))
    }

    public enum OpenError: Error, Equatable, Sendable {
        /// The app has not created the store yet: there is nothing to read.
        case storeNotCreated
    }

    /// The app's store, opened read-only for an extension: it never saves, never creates the file and
    /// never migrates it. Throws `OpenError.storeNotCreated` when the app has not created it yet.
    public static func makeReadOnly() throws -> ModelContainer {
        try makeReadOnly(
            ModelConfiguration(schema: schema, allowsSave: false, groupContainer: .identifier(appGroupIdentifier)))
    }

    /// `makeReadOnly()` for a store at a file URL, for tests.
    static func makeReadOnly(at url: URL) throws -> ModelContainer {
        try makeReadOnly(ModelConfiguration(schema: schema, url: url, allowsSave: false))
    }

    private static func makeReadOnly(_ configuration: ModelConfiguration) throws -> ModelContainer {
        // Opening a missing store would create an empty one.
        guard FileManager.default.fileExists(atPath: configuration.url.path(percentEncoded: false)) else {
            throw OpenError.storeNotCreated
        }
        return try ModelContainer(
            for: schema, migrationPlan: AgendouMigrationPlan.self, configurations: configuration)
    }
}

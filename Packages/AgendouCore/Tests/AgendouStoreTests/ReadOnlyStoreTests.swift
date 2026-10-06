import Foundation
import SwiftData
import Testing

@testable import AgendouStore

/// What the widget can and cannot do to the store it opens read-only.
struct ReadOnlyStoreTests {
    @Test func readsAStoreTheAppWrote() throws {
        let url = try storeWithOneCategory()

        let container = try AgendouContainer.makeReadOnly(at: url)

        #expect(try container.mainContext.fetch(FetchDescriptor<ShiftCategory>()).map(\.name) == ["UTI"])
    }

    @Test func savingThrowsAndLeavesTheFileAsItWas() throws {
        let url = try storeWithOneCategory()
        let before = try StoreFiles(closedAt: url)

        do {
            let container = try AgendouContainer.makeReadOnly(at: url)
            container.mainContext.insert(ShiftCategory(name: "PS", colorKey: "red", createdAt: .now))
            // Core Data refuses: "Unable to write to file opened Read Only." (Cocoa error 513).
            #expect(throws: (any Error).self) { try container.mainContext.save() }
        }

        #expect(try StoreFiles(closedAt: url) == before)
        let reopened = try AgendouContainer.make(at: url)
        #expect(try reopened.mainContext.fetch(FetchDescriptor<ShiftCategory>()).map(\.name) == ["UTI"])
    }

    @Test func aMissingStoreIsReportedAndNotCreated() throws {
        let url = URL.temporaryDirectory.appending(path: "agendou-missing-\(UUID()).store")

        #expect(throws: AgendouContainer.OpenError.storeNotCreated) { try AgendouContainer.makeReadOnly(at: url) }
        #expect(!FileManager.default.fileExists(atPath: url.path(percentEncoded: false)))
    }

    @Test func aVersionOneStoreIsLeftForTheAppToMigrate() throws {
        let url = URL.temporaryDirectory.appending(path: "agendou-v1-\(UUID()).store")
        do {
            let schema = Schema(versionedSchema: AgendouSchemaV1.self)
            let v1 = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url))
            v1.mainContext.insert(AgendouSchemaV1.ShiftCategory(name: "UTI", colorKey: "teal", createdAt: .now))
            try v1.mainContext.save()
        }
        let before = try StoreFiles(closedAt: url)

        // A read-only store cannot be migrated in place: the open fails (SQLite "attempt to write a readonly
        // database") and the app migrates the file the next time it opens it.
        #expect(throws: (any Error).self) { try AgendouContainer.makeReadOnly(at: url) }

        #expect(try StoreFiles(closedAt: url) == before)
        let migrated = try AgendouContainer.make(at: url)
        #expect(try migrated.mainContext.fetch(FetchDescriptor<ShiftCategory>()).map(\.name) == ["UTI"])
    }

    /// A current-schema store with one category, written through the app's read-write container.
    private func storeWithOneCategory() throws -> URL {
        let url = URL.temporaryDirectory.appending(path: "agendou-\(UUID()).store")
        let container = try AgendouContainer.make(at: url)
        container.mainContext.insert(ShiftCategory(name: "UTI", colorKey: "teal", createdAt: .now))
        try container.mainContext.save()
        return url
    }
}

/// The bytes of a closed SQLite store: the database and its write-ahead log (`-wal`). A writer copies the
/// log into the database and empties it when it closes, which can happen a little after its container is
/// released, so this first waits for the log to be empty. The shared-memory index (`-shm`) is left out:
/// even a read-only open rewrites it.
private struct StoreFiles: Equatable {
    struct StillOpen: Error {}

    let database: Data
    let log: Data?

    init(closedAt url: URL) throws {
        let logPath = url.path(percentEncoded: false) + "-wal"
        func logSize() -> Int { (try? FileManager.default.attributesOfItem(atPath: logPath)[.size] as? Int) ?? 0 }
        let deadline = Date.now.addingTimeInterval(5)
        while logSize() > 0 {
            guard Date.now < deadline else { throw StillOpen() }
            Thread.sleep(forTimeInterval: 0.01)
        }
        database = try Data(contentsOf: url)
        log = FileManager.default.contents(atPath: logPath)
    }
}

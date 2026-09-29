import Foundation
import SwiftData
import Testing

@testable import AgendouStore

struct MigrationTests {
    @Test func opensAVersionOneStoreAndKeepsItsSchedulesWithoutPeriod() throws {
        let url = URL.temporaryDirectory.appending(path: "agendou-v1-\(UUID()).store")
        do {
            let schema = Schema(versionedSchema: AgendouSchemaV1.self)
            let v1 = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url))
            let category = AgendouSchemaV1.ShiftCategory(name: "UTI", colorKey: "teal", createdAt: .now)
            v1.mainContext.insert(category)
            v1.mainContext.insert(
                AgendouSchemaV1.CategorySchedule(
                    category: category, workSeconds: 43_200, restSeconds: 129_600, anchorAt: .now, startsAt: .now,
                    createdAt: .now))
            try v1.mainContext.save()
        }

        let v2 = try AgendouContainer.make(at: url)
        let schedules = try v2.mainContext.fetch(FetchDescriptor<CategorySchedule>())
        #expect(schedules.count == 1)
        #expect(schedules.first?.repeatsUntil == nil)
        #expect(schedules.first?.category?.name == "UTI")
    }
}

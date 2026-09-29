import AgendouCore
import Foundation
import Testing

@testable import AgendouStore

struct CategoryTests {
    @Test func createsCategoryWithTrimmedName() throws {
        let agenda = TestAgenda()
        let category = try agenda.store.createCategory(name: "  UTI Hospital X \n", color: .indigo)
        #expect(category.name == "UTI Hospital X")
        #expect(category.colorKey == "indigo")
        #expect(category.createdAt == agenda.now)
        #expect(agenda.store.activeCategories().map(\.id) == [category.id])
    }

    @Test func rejectsBlankName() {
        let agenda = TestAgenda()
        #expect(throws: AgendaError.emptyName) { try agenda.store.createCategory(name: "   ", color: .teal) }
    }

    @Test func updatesNameAndColor() throws {
        let agenda = TestAgenda()
        let category = try agenda.store.createCategory(name: "UTI", color: .teal)
        try agenda.store.updateCategory(category, name: " Pronto-socorro ", color: .red)
        #expect(category.name == "Pronto-socorro")
        #expect(category.colorKey == "red")
        #expect(throws: AgendaError.emptyName) { try agenda.store.updateCategory(category, name: "", color: .red) }
    }

    @Test func seedsExtraCategoryOnlyOnFirstLaunch() throws {
        let agenda = TestAgenda()
        let defaults = UserDefaults(suiteName: UUID().uuidString)!

        agenda.store.seedIfFirstLaunch(defaults: defaults)
        #expect(agenda.store.activeCategories().map(\.name) == ["Extra"])

        try agenda.store.deletePermanently(agenda.store.activeCategories()[0])
        agenda.store.seedIfFirstLaunch(defaults: defaults)
        #expect(agenda.store.activeCategories().isEmpty)
    }

    @Test func doesNotSeedWhenCategoriesAlreadyExist() throws {
        let agenda = TestAgenda()
        _ = try agenda.store.createCategory(name: "UTI", color: .teal)
        agenda.store.seedIfFirstLaunch(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        #expect(agenda.store.activeCategories().map(\.name) == ["UTI"])
    }

    @Test func listsCategoriesInCreationOrder() throws {
        let agenda = TestAgenda()
        _ = try agenda.store.createCategory(name: "B", color: .teal)
        agenda.now += 1
        _ = try agenda.store.createCategory(name: "A", color: .teal)
        #expect(agenda.store.activeCategories().map(\.name) == ["B", "A"])
    }
}

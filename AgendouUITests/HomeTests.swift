import XCTest

final class HomeTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testEmptyStateLeadsToCategories() {
        let app = XCUIApplication.agendou()
        app.launch()

        let setup = app.buttons["home.setup"]
        XCTAssertTrue(setup.waitForExistence(timeout: 5))
        setup.tap()
        XCTAssertTrue(app.buttons["onboarding.start"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testShowsTheNextShiftAndTheFiveDayStrip() {
        let app = XCUIApplication.agendou()
        app.launch()
        app.createCategory("UTI")
        app.tabBars.buttons["Início"].tap()

        let card = app.buttons["home.card"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertTrue(card.label.contains("UTI"), card.label)
        XCTAssertTrue(card.label.contains("07:00 – 19:00"), card.label)
        snapshot(app, "home")

        let today = WorkplaceCalendar.calendar.dateComponents([.year, .month, .day], from: .now)
        let todayID = String(format: "home.day.%04d-%02d-%02d", today.year!, today.month!, today.day!)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'home.day.'")).count, 5)
        app.buttons[todayID].tap()
        XCTAssertTrue(app.buttons["day.done"].waitForExistence(timeout: 5))
    }
}

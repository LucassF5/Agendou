import XCTest

final class CategoriesTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testFirstLaunchHasTheExtraCategoryAndOffersOnboarding() {
        let app = XCUIApplication.agendou()
        app.launch()
        app.tabBars.buttons["Categorias"].tap()

        XCTAssertTrue(app.buttons["category.row.Extra"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["onboarding.start"].exists)
        snapshot(app, "categories-onboarding")
    }

    @MainActor
    func testCreatesACategoryWithA12x36Schedule() {
        let app = XCUIApplication.agendou()
        app.launch()
        app.tabBars.buttons["Categorias"].tap()
        app.buttons["onboarding.start"].tap()

        let name = app.textFields["category.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("UTI Hospital X")
        app.buttons["preset.12x36"].tap()
        snapshot(app, "category-form")
        app.buttons["category.save"].tap()

        let row = app.buttons["category.row.UTI Hospital X"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("12x36"), row.label)
        XCTAssertFalse(app.buttons["onboarding.start"].exists)

        row.tap()
        XCTAssertTrue(app.staticTexts["schedule.current"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["schedule.current"].label, "12x36")
    }

    @MainActor
    func testChangingTheScheduleKeepsTheOldOneInHistory() {
        let app = XCUIApplication.agendou()
        app.launch()
        app.tabBars.buttons["Categorias"].tap()
        app.buttons["onboarding.start"].tap()
        let name = app.textFields["category.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("UTI")
        app.buttons["preset.12x36"].tap()
        app.buttons["category.save"].tap()
        app.buttons["category.row.UTI"].tap()

        app.buttons["schedule.change"].tap()
        app.buttons["preset.24x48"].tap()
        app.buttons["schedule.save"].tap()

        XCTAssertTrue(app.staticTexts["schedule.current"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["schedule.current"].label, "24x48")
        XCTAssertEqual(app.staticTexts.matching(identifier: "schedule.history").count, 2)
        snapshot(app, "category-detail")
    }

    @MainActor
    func testMarksDaysOfACategoryWithoutSchedule() {
        let app = XCUIApplication.agendou()
        app.launch()
        app.tabBars.buttons["Categorias"].tap()
        app.buttons["category.row.Extra"].tap()
        app.buttons["category.pickDays"].tap()

        app.pickDaysOfNextMonth([15])
        let save = app.buttons["addShifts.save"]
        XCTAssertEqual(save.label, "Adicionar 1 plantão")
        save.tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: 5))

        app.openDay(WorkplaceCalendar.nextMonth(day: 15))
        XCTAssertTrue(app.buttons["shift.menu.Extra"].waitForExistence(timeout: 5))
    }
}

import XCTest

final class TutorialTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testOpensOnTheFirstLaunchAndSkips() {
        let app = XCUIApplication.agendou(tutorial: true)
        app.launch()

        let skip = app.buttons["tutorial.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Seus plantões, organizados"].exists)
        snapshot(app, "tutorial-first")
        skip.tap()

        XCTAssertTrue(skip.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Início"].isSelected)
    }

    @MainActor
    func testWalksThroughAndOpensTheCategoryForm() {
        let app = XCUIApplication.agendou(tutorial: true)
        app.launch()

        let next = app.buttons["tutorial.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        for _ in 0..<5 { next.tap() }
        XCTAssertTrue(app.staticTexts["Lembrete no dia"].waitForExistence(timeout: 5))
        XCTAssertFalse(next.exists)
        snapshot(app, "tutorial-last")
        app.buttons["tutorial.setup"].tap()

        XCTAssertTrue(app.textFields["category.name"].waitForExistence(timeout: 5))
        app.buttons["Cancelar"].tap()
        XCTAssertTrue(app.tabBars.buttons["Categorias"].isSelected)
    }

    @MainActor
    func testReopensFromSettingsAndEndsWithDoneWhenThereIsASchedule() {
        let app = XCUIApplication.agendou()
        app.launch()
        XCTAssertFalse(app.buttons["tutorial.skip"].waitForExistence(timeout: 2))
        app.createCategory("UTI")
        app.tabBars.buttons["Ajustes"].tap()
        app.buttons["settings.tutorial"].revealed(in: app).tap()

        let next = app.buttons["tutorial.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        for _ in 0..<5 { next.tap() }
        let done = app.buttons["tutorial.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["tutorial.skip"].exists)
        XCTAssertFalse(app.buttons["tutorial.setup"].exists)
        done.tap()

        XCTAssertTrue(done.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Ajustes"].isSelected)
    }
}

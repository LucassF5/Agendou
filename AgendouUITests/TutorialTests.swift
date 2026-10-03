import XCTest

final class TutorialTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testFirstLaunchHighlightsTheNextShiftOnTheSampleAgenda() {
        let app = XCUIApplication.agendou(tutorial: true)
        app.launch()

        let text = app.staticTexts["tour.text"]
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        XCTAssertEqual(text.label, "Ao abrir o app, você vê o próximo plantão e quanto falta.")
        assertHighlights(app, app.descendants(matching: .any)["home.card"])
        snapshot(app, "tour-1")

        app.buttons["tour.next"].tap()
        XCTAssertTrue(
            app.staticTexts["tour.text"].label.hasPrefix("Os próximos dias e as horas do mês"),
            app.staticTexts["tour.text"].label)
        assertHighlights(app, app.staticTexts["home.days.title"])
    }

    @MainActor
    func testTapsOutsideTheBalloonDoNothing() {
        let app = XCUIApplication.agendou(tutorial: true)
        app.launch()
        XCTAssertTrue(app.staticTexts["tour.text"].waitForExistence(timeout: 5))

        // Where the Calendar tab is, under the dimmed layer.
        let calendarTab = app.tabBars.buttons["Calendário"]
        calendarTab.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        XCTAssertTrue(app.tabBars.buttons["Início"].isSelected)
        XCTAssertEqual(app.staticTexts["tour.text"].label, "Ao abrir o app, você vê o próximo plantão e quanto falta.")
    }

    @MainActor
    func testSkipLeavesTheSampleAgendaBehind() {
        let app = XCUIApplication.agendou(tutorial: true)
        app.launch()
        let skip = app.buttons["tour.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 5))
        skip.tap()

        XCTAssertTrue(skip.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home.setup"].waitForExistence(timeout: 5), "real, empty Home")
        app.tabBars.buttons["Categorias"].tap()
        XCTAssertFalse(app.buttons["category.row.UTI Exemplo"].waitForExistence(timeout: 2))
    }
}

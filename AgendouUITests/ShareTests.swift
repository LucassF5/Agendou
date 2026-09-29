import XCTest

final class ShareTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Opens "Enviar plantões" for the month of the first shift (the next 07:00).
    @MainActor
    private func openShare(_ app: XCUIApplication) {
        app.tabBars.buttons["Calendário"].tap()
        let first = WorkplaceCalendar.nextShiftDay()
        let today = WorkplaceCalendar.calendar.dateComponents([.year, .month], from: .now)
        if first.month != today.month {
            app.buttons["DatePicker.NextMonth"].tap()
        }
        app.buttons["calendar.share"].tap()
    }

    @MainActor
    func testSharesTheMonthWithEachPlaceAndCanLeaveOneOut() {
        let app = XCUIApplication.agendou()
        app.launch()
        app.createCategory("UTI Hospital X")
        app.addCategory("PS Santa Casa", preset: "24x72")
        openShare(app)

        XCTAssertTrue(app.switches["share.category.UTI Hospital X"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.switches["share.category.PS Santa Casa"].exists)
        XCTAssertFalse(app.switches["share.category.Extra"].exists, "categories without shifts stay out")
        app.swipeUp()
        snapshot(app, "share-image")

        let text = app.staticTexts["share.textPreview"].revealed(in: app)
        XCTAssertTrue(text.label.contains("UTI Hospital X · 07:00 – 19:00"), text.label)
        XCTAssertTrue(text.label.contains("PS Santa Casa · 07:00 – 07:00 (+1)"), text.label)
        XCTAssertTrue(app.images["share.imagePreview"].exists)
        snapshot(app, "share-screen")

        app.swipeDown(velocity: .slow)
        let ps = app.switches["share.category.PS Santa Casa"].revealed(in: app)
        ps.switches.firstMatch.tap()
        let updated = app.staticTexts["share.textPreview"].revealed(in: app)
        XCTAssertFalse(updated.label.contains("PS Santa Casa"), updated.label)
        XCTAssertTrue(updated.label.contains("UTI Hospital X"), updated.label)

        XCTAssertTrue(app.buttons["share.sendImage"].isEnabled)
        app.buttons["share.sendText"].tap()
        let sheetTitle = app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH 'Plantões de '")
        ).firstMatch
        XCTAssertTrue(sheetTitle.waitForExistence(timeout: 10), "share sheet for the text")
    }

    @MainActor
    func testNothingToSendWithoutShifts() {
        let app = XCUIApplication.agendou()
        app.launch()
        app.tabBars.buttons["Calendário"].tap()
        app.buttons["calendar.share"].tap()

        XCTAssertTrue(app.staticTexts["share.empty"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["share.sendImage"].isEnabled)
        XCTAssertFalse(app.buttons["share.sendText"].isEnabled)
    }
}

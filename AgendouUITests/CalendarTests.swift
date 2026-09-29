import XCTest

final class CalendarTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testCancelsAndRestoresAScheduledShift() {
        let app = XCUIApplication.agendou()
        app.launch()
        app.createCategory("UTI")
        app.tabBars.buttons["Calendário"].tap()
        snapshot(app, "calendar-grid")
        app.openDay(WorkplaceCalendar.nextShiftDay())

        let shift = app.buttons["shift.UTI"]
        XCTAssertTrue(shift.waitForExistence(timeout: 5))
        snapshot(app, "day-sheet")
        shift.tap()
        app.buttons["Cancelar plantão"].tap()

        let restore = app.buttons["restore.UTI"]
        XCTAssertTrue(restore.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["shift.UTI"].exists)
        restore.tap()
        XCTAssertTrue(app.buttons["shift.UTI"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["restore.UTI"].exists)
    }

    @MainActor
    func testAddsAndDeletesAnExtraOnARestDay() {
        let app = XCUIApplication.agendou()
        app.launch()
        app.createCategory("UTI")
        app.openDay(WorkplaceCalendar.nextShiftDay(plusDays: 1))

        XCTAssertTrue(app.buttons["day.addExtra"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["shift.UTI"].exists)
        app.buttons["day.addExtra"].tap()
        XCTAssertTrue(app.buttons["extra.save"].waitForExistence(timeout: 5))
        snapshot(app, "extra-form")
        app.buttons["extra.save"].tap()

        let extra = app.buttons["shift.UTI"]
        XCTAssertTrue(extra.waitForExistence(timeout: 5))
        XCTAssertTrue(extra.label.contains("Extra"), extra.label)
        extra.tap()
        app.buttons["Excluir plantão"].tap()
        XCTAssertTrue(extra.waitForNonExistence(timeout: 5))
    }

    @MainActor
    func testAdjustsAScheduledShiftAndUndoesIt() {
        let app = XCUIApplication.agendou()
        app.launch()
        app.createCategory("UTI")
        app.openDay(WorkplaceCalendar.nextShiftDay())

        let shift = app.buttons["shift.UTI"]
        XCTAssertTrue(shift.waitForExistence(timeout: 5))
        shift.tap()
        app.buttons["Editar horário"].tap()
        let duration = app.steppers["extra.duration"]
        XCTAssertTrue(duration.waitForExistence(timeout: 5))
        duration.buttons.element(boundBy: 0).tap()
        app.buttons["extra.save"].tap()

        XCTAssertTrue(app.buttons["shift.UTI"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["shift.UTI"].label.contains("Ajustado"), app.buttons["shift.UTI"].label)
        app.buttons["shift.UTI"].tap()
        app.buttons["Desfazer ajuste"].tap()
        let restored = app.buttons["shift.UTI"]
        XCTAssertTrue(restored.waitForExistence(timeout: 5))
        XCTAssertFalse(restored.label.contains("Ajustado"), restored.label)
    }

    @MainActor
    func testKeepsTheDayNote() {
        let app = XCUIApplication.agendou()
        app.launch()
        let today = WorkplaceCalendar.calendar.dateComponents([.year, .month, .day], from: .now)
        app.openDay(today)

        let note = app.textViews["day.note"]
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        note.tap()
        note.typeText("Troquei com a Ana")
        app.buttons["day.done"].tap()

        app.openDay(today)
        XCTAssertTrue(app.textViews["day.note"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textViews["day.note"].value as? String, "Troquei com a Ana")
    }
}

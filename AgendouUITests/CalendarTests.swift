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

        let menu = app.buttons["shift.menu.UTI"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        snapshot(app, "day-sheet")
        menu.tap()
        app.buttons["Cancelar plantão"].tap()

        let restore = app.buttons["restore.UTI"]
        XCTAssertTrue(restore.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["shift.menu.UTI"].exists)
        restore.tap()
        XCTAssertTrue(app.buttons["shift.menu.UTI"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["restore.UTI"].exists)
    }

    @MainActor
    func testAddsAndDeletesAnExtraOnARestDay() {
        let app = XCUIApplication.agendou()
        app.launch()
        app.createCategory("UTI")
        app.openDay(WorkplaceCalendar.nextShiftDay(plusDays: 1))

        XCTAssertTrue(app.buttons["day.addExtra"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["shift.menu.UTI"].exists)
        app.buttons["day.addExtra"].tap()
        XCTAssertTrue(app.buttons["extra.save"].waitForExistence(timeout: 5))
        snapshot(app, "extra-form")
        app.buttons["extra.save"].tap()

        let menu = app.buttons["shift.menu.UTI"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        menu.tap()
        app.buttons["Excluir plantão"].tap()
        XCTAssertTrue(menu.waitForNonExistence(timeout: 5))
    }

    @MainActor
    func testAdjustsAScheduledShiftAndUndoesIt() {
        let app = XCUIApplication.agendou()
        app.launch()
        app.createCategory("UTI")
        app.openDay(WorkplaceCalendar.nextShiftDay())

        let row = app.descendants(matching: .any)["shift.UTI"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        let before = row.label
        app.buttons["shift.menu.UTI"].tap()
        app.buttons["Editar horário"].tap()
        let duration = app.steppers["extra.duration"]
        XCTAssertTrue(duration.waitForExistence(timeout: 5))
        duration.buttons.element(boundBy: 0).tap()
        app.buttons["extra.save"].tap()

        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertNotEqual(row.label, before, "the shift now has another length")
        app.buttons["shift.menu.UTI"].tap()
        app.buttons["Desfazer ajuste"].tap()
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertEqual(row.label, before)
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

    /// Regression: a day with shifts of two categories lost its dots.
    @MainActor
    func testShowsDotsOnDaysWithTwoCategories() {
        let app = XCUIApplication.agendou()
        app.launch()
        app.createCategory("UTI")
        app.addCategory("PS", preset: "24x72")

        // 12x36 and 24x72 from the same 07:00: both on the first day, only UTI two days later.
        let both = app.calendarCell(WorkplaceCalendar.nextShiftDay())
        snapshot(app, "two-categories")
        XCTAssertTrue(app.cellShowsDots(both), "day with UTI and PS")

        app.terminate()
        app.launch()
        app.createCategory("UTI")
        let one = app.calendarCell(WorkplaceCalendar.nextShiftDay(plusDays: 2))
        XCTAssertTrue(app.cellShowsDots(one), "day with UTI only")
    }
}

import XCTest

final class SummaryYearTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testMonthSummaryCountsTheShiftsStartingInTheVisibleMonth() {
        let app = XCUIApplication.agendou()
        app.launch()
        app.createCategory("UTI")
        app.tabBars.buttons["Calendário"].tap()

        // 12x36 from the next 07:00: every other day until the end of that month.
        let first = WorkplaceCalendar.nextShiftDay()
        let today = WorkplaceCalendar.calendar.dateComponents([.year, .month], from: .now)
        if first.month != today.month {
            app.buttons["DatePicker.NextMonth"].tap()
        }
        let firstDate = WorkplaceCalendar.calendar.date(from: first)!
        let lastDay = WorkplaceCalendar.calendar.range(of: .day, in: .month, for: firstDate)!.count
        let count = (lastDay - first.day!) / 2 + 1

        let hours = app.staticTexts["summary.hours"]
        XCTAssertTrue(hours.waitForExistence(timeout: 5))
        XCTAssertEqual(hours.label, "\(count * 12)h")
        XCTAssertEqual(app.staticTexts["summary.count"].label, count == 1 ? "1 plantão" : "\(count) plantões")
        let row = app.descendants(matching: .any)["summary.category.UTI"]
        XCTAssertTrue(row.label.contains("\(count * 12)h"), row.label)
        app.swipeUp()
        snapshot(app, "month-summary")
    }

    @MainActor
    func testYearViewShowsTwelveMonthsAndJumpsToOne() {
        let app = XCUIApplication.agendou()
        app.launch()
        app.createCategory("UTI")
        app.tabBars.buttons["Calendário"].tap()
        app.buttons["calendar.year"].tap()

        XCTAssertTrue(app.buttons["year.month.1"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'year.month.'")).count, 12)
        snapshot(app, "year")

        let year = WorkplaceCalendar.calendar.component(.year, from: .now)
        app.buttons["year.month.1"].tap()
        let month = app.buttons["Mês"]
        XCTAssertTrue(month.waitForExistence(timeout: 5))
        XCTAssertEqual(month.value as? String, "janeiro de \(year)")
    }
}

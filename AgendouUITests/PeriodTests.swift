import XCTest

final class PeriodTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testOneMonthStopsAtTheEndOfTheMonthAndRenewingContinues() {
        let app = XCUIApplication.agendou()
        app.launch()
        app.createCategory("UTI", repeat: "1")

        // Month after the first shift's month: empty until the schedule is renewed.
        let first = WorkplaceCalendar.nextShiftDay()
        app.tabBars.buttons["Calendário"].tap()
        let today = WorkplaceCalendar.calendar.dateComponents([.year, .month], from: .now)
        if first.month != today.month {
            app.buttons["DatePicker.NextMonth"].tap()
        }
        app.buttons["DatePicker.NextMonth"].tap()
        XCTAssertTrue(app.staticTexts["summary.count"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["summary.count"].label, "0 plantões")

        app.tabBars.buttons["Escalas"].tap()
        app.buttons["category.row.UTI"].tap()
        XCTAssertTrue(app.staticTexts["schedule.until"].waitForExistence(timeout: 5))
        app.buttons["schedule.renew"].tap()
        app.buttons["repeat.1"].revealed(in: app).tap()
        snapshot(app, "renew-form")
        app.buttons["renew.save"].tap()

        app.tabBars.buttons["Calendário"].tap()
        XCTAssertNotEqual(app.staticTexts["summary.count"].label, "0 plantões")
    }

    @MainActor
    func testFormShowsTheEndDate() {
        let app = XCUIApplication.agendou()
        app.launch()
        app.tabBars.buttons["Escalas"].tap()
        app.buttons["category.row.Extra"].tap()
        app.buttons["schedule.first"].tap()
        let three = app.buttons["repeat.3"].revealed(in: app)
        XCTAssertTrue(three.exists)
        three.tap()
        let until = app.staticTexts["repeat.until"].revealed(in: app)
        XCTAssertTrue(until.exists)
        XCTAssertTrue(until.label.hasPrefix("Vale até"), until.label)
        snapshot(app, "period-form")
    }

    @MainActor
    func testHomeWarnsWhenTheScheduleEndsWithinAWeek() {
        let app = XCUIApplication.agendou()
        app.launch()
        app.createCategory("UTI", repeat: "1")
        app.tabBars.buttons["Início"].tap()

        // "1 mês" ends when the first shift's month ends; the warning shows in its last 7 days.
        let first = WorkplaceCalendar.calendar.date(from: WorkplaceCalendar.nextShiftDay())!
        let monthEnd = WorkplaceCalendar.calendar.dateInterval(of: .month, for: first)!.end
        let warns = monthEnd.timeIntervalSinceNow <= 7 * 86_400
        let banner = app.buttons["renewal.UTI"]
        if warns {
            XCTAssertTrue(banner.waitForExistence(timeout: 5))
            snapshot(app, "home-renewal")
            banner.tap()
            XCTAssertTrue(app.buttons["renew.save"].waitForExistence(timeout: 5))
            app.buttons["repeat.3"].revealed(in: app).tap()
            app.buttons["renew.save"].tap()
            XCTAssertTrue(banner.waitForNonExistence(timeout: 5))
        } else {
            XCTAssertFalse(banner.waitForExistence(timeout: 2))
        }
    }

    @MainActor
    func testCategoriesListsSchedulesEndingSoon() {
        let app = XCUIApplication.agendou()
        app.launch()
        app.createCategory("UTI", repeat: "1")

        let first = WorkplaceCalendar.calendar.date(from: WorkplaceCalendar.nextShiftDay())!
        let monthEnd = WorkplaceCalendar.calendar.dateInterval(of: .month, for: first)!.end
        let warns = monthEnd.timeIntervalSinceNow <= 7 * 86_400
        XCTAssertEqual(app.buttons["renewal.UTI"].waitForExistence(timeout: warns ? 5 : 2), warns)
    }
}

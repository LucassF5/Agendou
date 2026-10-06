import XCTest

final class HomeTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testEmptyStateLeadsToSchedules() {
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

    /// Times are always in America/Sao_Paulo, never the device's time zone.
    @MainActor
    func testShowsWorkplaceTimesWhateverTheDeviceTimeZone() {
        let app = XCUIApplication.agendou()
        app.launchEnvironment["TZ"] = "Asia/Tokyo"
        app.launch()
        app.createCategory("UTI")
        app.buttons["category.row.UTI"].tap()
        let since = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Em vigor desde,'"))
            .firstMatch
        XCTAssertTrue(since.waitForExistence(timeout: 5))
        XCTAssertTrue(since.label.hasSuffix("07:00"), since.label)

        app.tabBars.buttons["Início"].tap()
        let card = app.buttons["home.card"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertTrue(card.label.contains("07:00 – 19:00"), card.label)
    }

    @MainActor
    func testDayStripSaysWhatItShows() {
        let app = XCUIApplication.agendou()
        app.launch()

        let title = app.staticTexts["home.days.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(title.label, "Últimos e próximos dias")
        XCTAssertEqual(
            app.staticTexts["home.days.caption"].label,
            "\(WorkplaceCalendar.dayMonth(daysFromToday: -2)) a \(WorkplaceCalendar.dayMonth(daysFromToday: 2))"
                + " · toque num dia para ver os plantões")
        let today = app.buttons[WorkplaceCalendar.homeDayID(daysFromToday: 0)]
        XCTAssertTrue(today.label.hasPrefix("Hoje"), today.label)
    }

    @MainActor
    func testDayStripShowsTheShiftStartTime() {
        let app = XCUIApplication.agendou()
        app.launch()
        app.createCategory("UTI")
        app.tabBars.buttons["Início"].tap()

        // The first shift is the next 07:00: today or tomorrow, both in the strip.
        let first = WorkplaceCalendar.nextShiftDay()
        let id = String(format: "home.day.%04d-%02d-%02d", first.year!, first.month!, first.day!)
        let cell = app.buttons[id]
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        XCTAssertTrue(cell.label.hasSuffix("plantão às 07:00"), cell.label)
        snapshot(app, "home-details")
    }

    @MainActor
    func testListsTheNextShiftsAfterTheCard() {
        let app = XCUIApplication.agendou()
        app.launch()
        app.createCategory("UTI")
        app.tabBars.buttons["Início"].tap()

        let rows = app.buttons.matching(identifier: "upcoming.row")
        XCTAssertTrue(rows.firstMatch.revealed(in: app).exists)
        XCTAssertEqual(rows.count, 4)
        // 12x36: the card holds the first shift, the list starts two days later.
        let second = WorkplaceCalendar.nextShiftDay(plusDays: 2)
        let secondLabel = String(format: "%02d/%02d", second.day!, second.month!)
        XCTAssertTrue(rows.element(boundBy: 0).label.contains(secondLabel), rows.element(boundBy: 0).label)
        snapshot(app, "home-upcoming")

        rows.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["day.done"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testMonthSummarySplitsSoFarAndTheWholeMonth() {
        let app = XCUIApplication.agendou()
        app.launch()
        app.createCategory("UTI")
        app.tabBars.buttons["Início"].tap()

        // 12x36 from the next 07:00: nothing has started yet, and the month holds every other day from
        // the first shift to its end (nothing when the first shift is already next month).
        let calendar = WorkplaceCalendar.calendar
        let first = WorkplaceCalendar.nextShiftDay()
        let thisMonth = calendar.component(.month, from: .now)
        let lastDay = calendar.range(of: .day, in: .month, for: .now)!.count
        let count = first.month == thisMonth ? (lastDay - first.day!) / 2 + 1 : 0
        let shifts = count == 1 ? "1 plantão" : "\(count) plantões"

        let soFar = app.descendants(matching: .any)["home.month.soFar"].revealed(in: app)
        XCTAssertEqual(soFar.label, "Até hoje, 0h, 0 plantões")
        XCTAssertEqual(app.descendants(matching: .any)["home.month.total"].label, "No mês, \(count * 12)h, \(shifts)")
        if count > 0 {
            XCTAssertEqual(
                app.descendants(matching: .any)["home.month.category.UTI"].label, "UTI, 0h de \(count * 12)h")
        }
        app.swipeUp()
        snapshot(app, "home-month")

        app.buttons["home.month.openCalendar"].tap()
        XCTAssertTrue(app.tabBars.buttons["Calendário"].isSelected)
    }
}

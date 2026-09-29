import XCTest

extension XCUIApplication {
    /// The app with an in-memory store and fresh first-launch state.
    static func agendou() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        return app
    }
}

extension XCTestCase {
    /// Keeps a screenshot in the test results, for reviewing the UI.
    @MainActor
    func snapshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

extension XCUIApplication {
    /// Creates a category with a preset schedule through the onboarding. The first shift is the next 07:00.
    func createCategory(_ name: String, preset: String = "12x36") {
        tabBars.buttons["Categorias"].tap()
        buttons["onboarding.start"].tap()
        let field = textFields["category.name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(name)
        buttons["preset.\(preset)"].tap()
        buttons["category.save"].tap()
        XCTAssertTrue(buttons["category.row.\(name)"].waitForExistence(timeout: 5))
    }

    /// Opens the day sheet of `date` (at most one month ahead of today) from the Calendar tab.
    func openDay(_ date: DateComponents) {
        tabBars.buttons["Calendário"].tap()
        let today = WorkplaceCalendar.calendar.dateComponents([.year, .month], from: .now)
        if (date.year!, date.month!) != (today.year!, today.month!) {
            buttons["DatePicker.NextMonth"].tap()
        }
        let month = WorkplaceCalendar.monthNames[date.month! - 1]
        let cell = buttons.matching(NSPredicate(format: "label ENDSWITH %@", ", \(date.day!) de \(month)")).firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 5), "day \(date)")
        cell.tap()
    }
}

/// The app's fixed time zone, so tests agree with it whatever the simulator's settings.
enum WorkplaceCalendar {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        return calendar
    }()

    static let monthNames = [
        "janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto", "setembro", "outubro",
        "novembro", "dezembro",
    ]

    /// Day of the next 07:00, where a category created with the default dates has its first shift.
    static func nextShiftDay(plusDays days: Int = 0) -> DateComponents {
        let now = Date.now
        let hour = calendar.component(.hour, from: now)
        let offset = (hour < 7 ? 0 : 1) + days
        let day = calendar.date(byAdding: .day, value: offset, to: now)!
        return calendar.dateComponents([.year, .month, .day], from: day)
    }
}

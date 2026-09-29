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
    /// Creates a category with a preset schedule through the onboarding. The first shift is the next 07:00;
    /// `months` is the repeat period ("1", "3", "6"), long by default so tests near a month's end hold.
    func createCategory(_ name: String, preset: String = "12x36", repeat months: String = "6") {
        tabBars.buttons["Categorias"].tap()
        buttons["onboarding.start"].tap()
        let field = textFields["category.name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(name)
        buttons["preset.\(preset)"].tap()
        buttons["repeat.\(months)"].revealed(in: self).tap()
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

extension XCUIApplication {
    /// Adds another category through the "+" button, with a preset schedule starting at the next 07:00.
    func addCategory(_ name: String, preset: String) {
        tabBars.buttons["Categorias"].tap()
        buttons["Nova categoria"].tap()
        let field = textFields["category.name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(name)
        buttons["preset.\(preset)"].tap()
        buttons["repeat.6"].revealed(in: self).tap()
        buttons["category.save"].tap()
        XCTAssertTrue(buttons["category.row.\(name)"].waitForExistence(timeout: 5))
    }

    /// The grid cell of `date` in the Calendar tab, moving to the next month if needed.
    func calendarCell(_ date: DateComponents) -> XCUIElement {
        tabBars.buttons["Calendário"].tap()
        let today = WorkplaceCalendar.calendar.dateComponents([.year, .month], from: .now)
        if (date.year!, date.month!) != (today.year!, today.month!) {
            buttons["DatePicker.NextMonth"].tap()
        }
        let month = WorkplaceCalendar.monthNames[date.month! - 1]
        let cell = buttons.matching(NSPredicate(format: "label ENDSWITH %@", ", \(date.day!) de \(month)")).firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 5), "day \(date)")
        return cell
    }

    /// Whether the area under the day number of a grid cell has colored (not gray) pixels: the dots.
    /// Decorations are not in the accessibility tree, so the screenshot is the only way to see them.
    func cellShowsDots(_ cell: XCUIElement) -> Bool {
        let image = XCUIScreen.main.screenshot().image
        guard let cgImage = image.cgImage, let data = cgImage.dataProvider?.data,
            let bytes = CFDataGetBytePtr(data)
        else { return false }
        let scale = image.scale
        let frame = cell.frame
        // Dots sit in the lower part of the cell, below the number (which is tinted on today).
        let area = CGRect(
            x: frame.minX * scale, y: (frame.minY + frame.height * 0.62) * scale,
            width: frame.width * scale, height: frame.height * 0.33 * scale)
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        for y in Int(area.minY)..<min(Int(area.maxY), cgImage.height) {
            for x in Int(area.minX)..<min(Int(area.maxX), cgImage.width) {
                let offset = y * cgImage.bytesPerRow + x * bytesPerPixel
                let channels = [bytes[offset], bytes[offset + 1], bytes[offset + 2]].map(Int.init)
                if channels.max()! - channels.min()! > 60 { return true }
            }
        }
        return false
    }
}

extension XCUIElement {
    /// Swipes up until the element exists: Form rows below the fold are only created when scrolled to.
    func revealed(in app: XCUIApplication, attempts: Int = 4) -> XCUIElement {
        var tries = 0
        while !waitForExistence(timeout: 1) && tries < attempts {
            app.swipeUp()
            tries += 1
        }
        return self
    }
}

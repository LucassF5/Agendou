import XCTest

extension XCUIApplication {
    /// The app with an in-memory store and fresh first-launch state. The tutorial that opens on a first
    /// launch is skipped unless `tutorial` is set.
    static func agendou(tutorial: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = tutorial ? ["-ui-testing"] : ["-ui-testing", "-skip-tutorial"]
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
    /// Creates a category with a preset schedule through the onboarding: the category, then "Definir escala",
    /// which opens right after it. The first shift is the next 07:00; `months` is the repeat period ("1", "3",
    /// "6"), long by default so tests near a month's end hold. Ends on the Escalas list.
    func createCategory(_ name: String, preset: String = "12x36", repeat months: String = "6") {
        tabBars.buttons["Escalas"].tap()
        buttons["onboarding.start"].tap()
        let field = textFields["category.name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(name)
        buttons["category.save"].tap()
        defineSchedule(preset: preset, repeat: months)
        XCTAssertTrue(buttons["category.row.\(name)"].waitForExistence(timeout: 5))
    }

    /// Fills and saves "Definir escala".
    func defineSchedule(preset: String = "12x36", repeat months: String = "6") {
        let presetButton = buttons["preset.\(preset)"]
        XCTAssertTrue(presetButton.waitForExistence(timeout: 5), "Definir escala")
        presetButton.tap()
        buttons["repeat.\(months)"].revealed(in: self).tap()
        let save = buttons["schedule.save"]
        save.tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: 5))
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

    /// "27/09" for the day `daysFromToday` away.
    static func dayMonth(daysFromToday days: Int) -> String {
        let components = calendar.dateComponents(
            [.day, .month], from: calendar.date(byAdding: .day, value: days, to: .now)!)
        return String(format: "%02d/%02d", components.day!, components.month!)
    }

    /// `day` of next month: always in the future, and every month has a 25th.
    static func nextMonth(day: Int) -> DateComponents {
        var components = calendar.dateComponents(
            [.year, .month], from: calendar.date(byAdding: .month, value: 1, to: .now)!)
        components.day = day
        return components
    }

    /// Identifier of a day in the Home strip, `daysFromToday` away.
    static func homeDayID(daysFromToday days: Int) -> String {
        let components = calendar.dateComponents(
            [.year, .month, .day], from: calendar.date(byAdding: .day, value: days, to: .now)!)
        return String(format: "home.day.%04d-%02d-%02d", components.year!, components.month!, components.day!)
    }

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
        tabBars.buttons["Escalas"].tap()
        buttons["Novo local"].tap()
        let field = textFields["category.name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(name)
        buttons["category.save"].tap()
        defineSchedule(preset: preset)
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

    /// In the "Marcar dias" sheet, moves to next month and taps `days` in its grid.
    func pickDaysOfNextMonth(_ days: [Int]) {
        let grid = otherElements["addShifts.calendar"]
        XCTAssertTrue(grid.waitForExistence(timeout: 5), "day picker")
        grid.buttons["DatePicker.NextMonth"].tap()
        let month = WorkplaceCalendar.monthNames[WorkplaceCalendar.nextMonth(day: 1).month! - 1]
        for day in days {
            let cell = grid.buttons.matching(NSPredicate(format: "label ENDSWITH %@", ", \(day) de \(month)"))
                .firstMatch
            XCTAssertTrue(cell.waitForExistence(timeout: 5), "day \(day)")
            // The last weeks of the grid start out under the bottom bar.
            if cell.frame.maxY > buttons["addShifts.save"].frame.minY { swipeUp() }
            cell.tap()
        }
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

extension XCTestCase {
    /// The tour's cut-out sits over `element`, and not over the whole screen.
    @MainActor
    func assertHighlights(
        _ app: XCUIApplication, _ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line
    ) {
        let cutout = app.descendants(matching: .any)["tour.cutout"]
        XCTAssertTrue(cutout.waitForExistence(timeout: 5), "cut-out", file: file, line: line)
        XCTAssertTrue(element.waitForExistence(timeout: 5), "highlighted element", file: file, line: line)
        // List cells and their content differ by a few points either way, so compare overlap, not containment:
        // most of the smaller of the two rectangles lies inside the other.
        let target = element.frame
        let covered = cutout.frame.intersection(target)
        let smaller = min(cutout.frame.width * cutout.frame.height, target.width * target.height)
        XCTAssertTrue(
            !covered.isNull && covered.width * covered.height >= 0.7 * smaller,
            "\(cutout.frame) does not cover \(target)", file: file, line: line)
        XCTAssertLessThan(
            cutout.frame.height, app.frame.height * 0.8, "cut-out covers the screen: \(cutout.frame)", file: file,
            line: line)
    }
}

extension XCUIElement {
    /// Taps once the element stops moving: the tour's balloon slides between the top and the bottom of the
    /// screen, and a tap during the slide lands where the button no longer is.
    func tapWhenSettled() {
        var last = frame
        for _ in 0..<20 {
            usleep(100_000)
            if frame == last { break }
            last = frame
        }
        tap()
    }
}

extension XCUIApplication {
    /// On a first launch, goes past the intro by its "Pular" to the choice and picks the tour.
    func startTourFromIntro() {
        let skip = buttons["intro.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 5), "intro")
        skip.tap()
        let tour = buttons["intro.tour"]
        XCTAssertTrue(tour.waitForExistence(timeout: 5), "intro choice")
        tour.tap()
    }
}

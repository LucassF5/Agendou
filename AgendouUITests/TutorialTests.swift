import XCTest

final class TutorialTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testFirstLaunchHighlightsTheNextShiftOnTheSampleAgenda() {
        let app = XCUIApplication.agendou(tutorial: true)
        app.launch()
        app.startTourFromIntro()

        let text = app.staticTexts["tour.text"]
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        XCTAssertEqual(text.label, "Ao abrir o app, você vê o próximo plantão e quanto falta.")
        assertHighlights(app, app.descendants(matching: .any)["home.card"])
        snapshot(app, "tour-1")

        app.buttons["tour.next"].tapWhenSettled()
        XCTAssertTrue(
            app.staticTexts["tour.text"].label.hasPrefix("Os próximos dias e as horas do mês"),
            app.staticTexts["tour.text"].label)
        assertHighlights(app, app.staticTexts["home.days.title"])
    }

    @MainActor
    func testTapsOutsideTheBalloonDoNothing() {
        let app = XCUIApplication.agendou(tutorial: true)
        app.launch()
        app.startTourFromIntro()
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
        app.startTourFromIntro()
        let skip = app.buttons["tour.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 5))
        skip.tap()

        XCTAssertTrue(skip.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home.setup"].waitForExistence(timeout: 5), "real, empty Home")
        app.tabBars.buttons["Escalas"].tap()
        XCTAssertFalse(app.buttons["category.row.UTI Exemplo"].waitForExistence(timeout: 2))
    }

    /// The balloon text of each step, in order (the start of it is enough).
    private let stepTexts = [
        "Ao abrir o app", "Os próximos dias", "Cada lugar onde você trabalha", "Crie uma categoria aqui",
        "O calendário se preenche", "Edite o horário", "Marque um plantão avulso", "Receba um aviso",
    ]

    @MainActor
    func testWalksThroughEveryStepOnTheRealScreens() {
        let app = XCUIApplication.agendou(tutorial: true)
        app.launch()
        app.startTourFromIntro()
        let text = app.staticTexts["tour.text"]
        XCTAssertTrue(text.waitForExistence(timeout: 5))

        let highlights: [XCUIElement] = [
            app.descendants(matching: .any)["home.card"],
            app.staticTexts["home.days.title"],
            app.buttons["category.row.UTI Exemplo"],
            app.buttons["Nova categoria"],
            app.buttons.matching(NSPredicate(format: "label CONTAINS ' de '")).firstMatch,
            app.buttons["shift.menu.UTI Exemplo"],
            app.buttons["day.addExtra"],
            app.switches["settings.reminder"],
        ]
        let tabs = [
            "Início", "Início", "Escalas", "Escalas", "Calendário", "Calendário", "Calendário", "Ajustes",
        ]
        for index in stepTexts.indices {
            XCTAssertTrue(text.label.hasPrefix(stepTexts[index]), "step \(index + 1): \(text.label)")
            XCTAssertTrue(app.tabBars.buttons[tabs[index]].isSelected, "step \(index + 1) tab")
            assertHighlights(app, highlights[index])
            snapshot(app, "tour-\(index + 1)")
            if index < stepTexts.count - 1 { app.buttons["tour.next"].tapWhenSettled() }
        }
        XCTAssertFalse(app.buttons["tour.next"].exists)
        XCTAssertTrue(app.buttons["tour.skip"].exists)

        app.buttons["tour.setup"].tap()
        XCTAssertTrue(app.textFields["category.name"].waitForExistence(timeout: 5))
        app.buttons["Cancelar"].tap()
        XCTAssertTrue(app.tabBars.buttons["Escalas"].isSelected)
        XCTAssertFalse(app.buttons["category.row.UTI Exemplo"].exists)
    }

    @MainActor
    func testSkipFromTheDaySheetClosesIt() {
        let app = XCUIApplication.agendou(tutorial: true)
        app.launch()
        app.startTourFromIntro()
        let next = app.buttons["tour.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        for _ in 0..<5 { next.tapWhenSettled() }
        XCTAssertTrue(app.buttons["shift.menu.UTI Exemplo"].waitForExistence(timeout: 5))

        // The balloon sits above the sheet here; it must stay clear of the status bar.
        let balloon = app.descendants(matching: .any)["tour.balloon"]
        XCTAssertGreaterThanOrEqual(balloon.frame.minY, 54, "\(balloon.frame)")

        app.buttons["tour.skip"].tap()

        XCTAssertTrue(app.buttons["shift.menu.UTI Exemplo"].waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.buttons["day.done"].exists)
        XCTAssertFalse(app.staticTexts["tour.text"].exists)
    }

    @MainActor
    func testReplayFromSettingsKeepsRealDataAndEndsWithDone() {
        let app = XCUIApplication.agendou()
        app.launch()
        XCTAssertFalse(app.staticTexts["tour.text"].waitForExistence(timeout: 2))
        app.createCategory("UTI")

        for round in 1...2 {
            app.tabBars.buttons["Ajustes"].tap()
            app.buttons["settings.tutorial"].revealed(in: app).tap()
            let next = app.buttons["tour.next"]
            XCTAssertTrue(next.waitForExistence(timeout: 5), "round \(round)")
            for _ in 0..<7 { next.tapWhenSettled() }
            let done = app.buttons["tour.done"]
            XCTAssertTrue(done.waitForExistence(timeout: 5), "round \(round): \(app.staticTexts["tour.text"].label)")
            XCTAssertFalse(app.buttons["tour.skip"].exists)
            XCTAssertFalse(app.buttons["tour.setup"].exists)
            done.tap()
            XCTAssertTrue(done.waitForNonExistence(timeout: 5))
        }

        app.tabBars.buttons["Escalas"].tap()
        XCTAssertTrue(app.buttons["category.row.UTI"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["category.row.UTI Exemplo"].exists)
    }

    @MainActor
    func testBalloonStaysReachableWithVeryLargeText() {
        let app = XCUIApplication.agendou(tutorial: true)
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        app.startTourFromIntro()
        let next = app.buttons["tour.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        for step in 1...7 {
            XCTAssertTrue(next.isHittable, "Próximo on step \(step)")
            XCTAssertTrue(app.buttons["tour.skip"].isHittable, "Pular on step \(step)")
            next.tapWhenSettled()
        }
        XCTAssertTrue(app.buttons["tour.setup"].isHittable)
        snapshot(app, "tour-large-text")
    }

    @MainActor
    func testReplayStartsFromCleanScreensWhateverTheTabsWereLeftIn() {
        let app = XCUIApplication.agendou()
        app.launch()
        app.createCategory("UTI")
        // Leave Categories on a pushed detail and Settings scrolled down to "Ver tutorial".
        app.buttons["category.row.UTI"].tap()
        app.tabBars.buttons["Ajustes"].tap()
        app.buttons["settings.tutorial"].revealed(in: app).tap()

        let next = app.buttons["tour.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        next.tapWhenSettled()
        next.tapWhenSettled()
        assertHighlights(app, app.buttons["category.row.UTI Exemplo"])
        next.tapWhenSettled()
        assertHighlights(app, app.buttons["Nova categoria"])
        for _ in 0..<4 { next.tapWhenSettled() }
        assertHighlights(app, app.switches["settings.reminder"])
    }

    @MainActor
    func testBalloonFollowsTheSafeAreaAfterRotating() {
        let app = XCUIApplication.agendou(tutorial: true)
        XCUIDevice.shared.orientation = .landscapeLeft
        app.launch()
        app.startTourFromIntro()
        let next = app.buttons["tour.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        XCUIDevice.shared.orientation = .portrait

        for _ in 0..<5 { next.tapWhenSettled() }
        XCTAssertTrue(app.staticTexts["tour.text"].label.hasPrefix("Edite o horário"))
        let balloon = app.descendants(matching: .any)["tour.balloon"]
        XCTAssertGreaterThanOrEqual(balloon.frame.minY, 54, "\(balloon.frame)")
    }

    // MARK: - Intro

    @MainActor
    func testFirstLaunchOpensWithTheIntroAndEndsOnTheChoice() {
        let app = XCUIApplication.agendou(tutorial: true)
        app.launch()

        XCTAssertTrue(app.staticTexts["Bem-vindo ao Agendou"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["tour.text"].exists)
        snapshot(app, "intro-1")
        app.buttons["intro.next"].tap()
        XCTAssertTrue(app.staticTexts["O que o Agendou faz"].waitForExistence(timeout: 5))
        snapshot(app, "intro-2")
        app.buttons["intro.next"].tap()

        XCTAssertTrue(app.staticTexts["Quer conhecer o app num tour rápido?"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["intro.next"].exists)
        XCTAssertFalse(app.buttons["intro.skip"].exists)
        snapshot(app, "intro-3")
        app.buttons["intro.tour"].tap()

        XCTAssertTrue(app.staticTexts["tour.text"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["tour.text"].label.hasPrefix("Ao abrir o app"))
    }

    @MainActor
    func testIntroSkipGoesToTheChoiceNotPastIt() {
        let app = XCUIApplication.agendou(tutorial: true)
        app.launch()
        let skip = app.buttons["intro.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 5))

        skip.tap()

        XCTAssertTrue(app.buttons["intro.tour"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["intro.start"].exists)
    }

    @MainActor
    func testStartUsingOpensTheCategoryFormWithoutTheTour() {
        let app = XCUIApplication.agendou(tutorial: true)
        app.launch()
        let skip = app.buttons["intro.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 5))
        skip.tap()
        app.buttons["intro.start"].tap()

        XCTAssertTrue(app.textFields["category.name"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["tour.text"].exists)
        app.buttons["Cancelar"].tap()
        XCTAssertTrue(app.tabBars.buttons["Escalas"].isSelected)
        XCTAssertFalse(app.buttons["category.row.UTI Exemplo"].exists)
    }

    @MainActor
    func testStartUsingGoesOnToDefiningTheSchedule() {
        let app = XCUIApplication.agendou(tutorial: true)
        app.launch()
        let skip = app.buttons["intro.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 5))
        skip.tap()
        app.buttons["intro.start"].tap()

        let name = app.textFields["category.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("UTI")
        app.buttons["category.save"].tap()

        XCTAssertTrue(app.buttons["preset.12x36"].waitForExistence(timeout: 5), "Definir escala")
        XCTAssertTrue(app.tabBars.buttons["Escalas"].isSelected)
        app.defineSchedule()
        XCTAssertTrue(app.buttons["category.row.UTI"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.cellShowsDots(app.calendarCell(WorkplaceCalendar.nextShiftDay())))
    }
}

import XCTest

final class TutorialTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testFirstLaunchHighlightsTheNextShiftOnTheSampleAgenda() {
        let app = XCUIApplication.agendou(tutorial: true)
        app.launch()

        let text = app.staticTexts["tour.text"]
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        XCTAssertEqual(text.label, "Ao abrir o app, você vê o próximo plantão e quanto falta.")
        assertHighlights(app, app.descendants(matching: .any)["home.card"])
        snapshot(app, "tour-1")

        app.buttons["tour.next"].tap()
        XCTAssertTrue(
            app.staticTexts["tour.text"].label.hasPrefix("Os próximos dias e as horas do mês"),
            app.staticTexts["tour.text"].label)
        assertHighlights(app, app.staticTexts["home.days.title"])
    }

    @MainActor
    func testTapsOutsideTheBalloonDoNothing() {
        let app = XCUIApplication.agendou(tutorial: true)
        app.launch()
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
        let skip = app.buttons["tour.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 5))
        skip.tap()

        XCTAssertTrue(skip.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home.setup"].waitForExistence(timeout: 5), "real, empty Home")
        app.tabBars.buttons["Categorias"].tap()
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
            "Início", "Início", "Categorias", "Categorias", "Calendário", "Calendário", "Calendário", "Ajustes",
        ]
        for index in stepTexts.indices {
            XCTAssertTrue(text.label.hasPrefix(stepTexts[index]), "step \(index + 1): \(text.label)")
            XCTAssertTrue(app.tabBars.buttons[tabs[index]].isSelected, "step \(index + 1) tab")
            assertHighlights(app, highlights[index])
            snapshot(app, "tour-\(index + 1)")
            if index < stepTexts.count - 1 { app.buttons["tour.next"].tap() }
        }
        XCTAssertFalse(app.buttons["tour.next"].exists)
        XCTAssertTrue(app.buttons["tour.skip"].exists)

        app.buttons["tour.setup"].tap()
        XCTAssertTrue(app.textFields["category.name"].waitForExistence(timeout: 5))
        app.buttons["Cancelar"].tap()
        XCTAssertTrue(app.tabBars.buttons["Categorias"].isSelected)
        XCTAssertFalse(app.buttons["category.row.UTI Exemplo"].exists)
    }

    @MainActor
    func testSkipFromTheDaySheetClosesIt() {
        let app = XCUIApplication.agendou(tutorial: true)
        app.launch()
        let next = app.buttons["tour.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        for _ in 0..<5 { next.tap() }
        XCTAssertTrue(app.buttons["shift.menu.UTI Exemplo"].waitForExistence(timeout: 5))

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
            for _ in 0..<7 { next.tap() }
            let done = app.buttons["tour.done"]
            XCTAssertTrue(done.waitForExistence(timeout: 5))
            XCTAssertFalse(app.buttons["tour.skip"].exists)
            XCTAssertFalse(app.buttons["tour.setup"].exists)
            done.tap()
            XCTAssertTrue(done.waitForNonExistence(timeout: 5))
        }

        app.tabBars.buttons["Categorias"].tap()
        XCTAssertTrue(app.buttons["category.row.UTI"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["category.row.UTI Exemplo"].exists)
    }

    @MainActor
    func testBalloonStaysReachableWithVeryLargeText() {
        let app = XCUIApplication.agendou(tutorial: true)
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"]
        app.launch()
        let next = app.buttons["tour.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        for step in 1...7 {
            XCTAssertTrue(next.isHittable, "Próximo on step \(step)")
            XCTAssertTrue(app.buttons["tour.skip"].isHittable, "Pular on step \(step)")
            next.tap()
        }
        XCTAssertTrue(app.buttons["tour.setup"].isHittable)
        snapshot(app, "tour-large-text")
    }
}

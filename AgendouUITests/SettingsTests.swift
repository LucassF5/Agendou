import XCTest

final class SettingsTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testOffersBackupAndShowsTheVersion() {
        let app = XCUIApplication.agendou()
        app.launch()
        app.tabBars.buttons["Ajustes"].tap()

        let export = app.buttons["settings.export"]
        XCTAssertTrue(export.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settings.import"].exists)
        let version = app.staticTexts["settings.version"].label
        XCTAssertTrue(version.contains("0.1.0 (1)"), version)
        snapshot(app, "settings")

        export.tap()
        let sheetTitle = app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Backup do Agendou'"))
            .firstMatch
        XCTAssertTrue(sheetTitle.waitForExistence(timeout: 10), "share sheet with the backup file")
        snapshot(app, "share-sheet")
    }

    /// The plan's backup check: export, start from nothing, import, same data.
    @MainActor
    func testExportThenImportIntoAnEmptyAppRestoresTheData() {
        let app = XCUIApplication.agendou()
        app.launch()
        app.createCategory("UTI Backup")
        app.tabBars.buttons["Ajustes"].tap()
        app.buttons["settings.export"].tap()

        let saveToFiles = app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Save to Files'"))
            .firstMatch
        XCTAssertTrue(saveToFiles.waitForExistence(timeout: 10))
        saveToFiles.tap()
        let save = app.buttons["Save"]
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        snapshot(app, "save-to-files")
        save.tap()
        let replace = app.buttons["Replace"]
        if replace.waitForExistence(timeout: 3) { replace.tap() }

        // A fresh launch starts from an empty in-memory store: the app was "deleted".
        app.terminate()
        app.launch()
        app.tabBars.buttons["Ajustes"].tap()
        app.buttons["settings.import"].tap()
        let file = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Agendou-'"))
            .firstMatch
        XCTAssertTrue(file.waitForExistence(timeout: 10))
        snapshot(app, "import-picker")
        file.tap()

        let confirm = app.buttons["Substituir"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 10))
        confirm.tap()
        XCTAssertTrue(app.alerts["Dados importados"].waitForExistence(timeout: 5))
        app.alerts.buttons["OK"].tap()

        app.tabBars.buttons["Categorias"].tap()
        let row = app.buttons["category.row.UTI Backup"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("12x36"), row.label)
    }
}

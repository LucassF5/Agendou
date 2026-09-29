import XCTest

final class LaunchTests: XCTestCase {
    @MainActor
    func testLaunchShowsTheFourTabs() {
        let app = XCUIApplication.agendou()
        app.launch()

        for tab in ["Início", "Calendário", "Categorias", "Ajustes"] {
            XCTAssertTrue(app.tabBars.buttons[tab].waitForExistence(timeout: 5), tab)
        }
    }
}

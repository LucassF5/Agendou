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

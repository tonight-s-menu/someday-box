import XCTest

final class AppLaunchTests: XCTestCase {
    @MainActor
    func testFreshLaunchShowsPrimaryProductActions() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["Draw a paper"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Put in an idea"].exists)
        XCTAssertTrue(app.tabBars.buttons["Box"].exists)
        XCTAssertTrue(app.tabBars.buttons["Memories"].exists)
    }

    @MainActor
    func testCaptureCannotSaveWithoutDuration() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Put in an idea"].tap()

        let title = app.textFields["Paper title"]
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        title.typeText("Read one chapter")

        let save = app.buttons["Put it in the Box"]
        XCTAssertTrue(save.exists)
        XCTAssertFalse(save.isEnabled)
    }

    @MainActor
    func testSettingsExposesExplicitLocalDataControls() {
        let app = XCUIApplication()
        app.launch()

        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()

        XCTAssertTrue(app.buttons["Export backup"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Restore backup"].exists)
        XCTAssertTrue(app.buttons["Erase all local data"].exists)
    }

    @MainActor
    func testHomeAndSettingsPassAutomatedAccessibilityAudit() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 5))

        try app.performAccessibilityAudit()
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
        try app.performAccessibilityAudit()
    }
}

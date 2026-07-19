import XCTest

final class AppLaunchTests: XCTestCase {
    @MainActor
    func testFreshLaunchShowsPrimaryProductActions() {
        let app = XCUIApplication()
        app.launch()
        openBoxIfNeeded(app)

        XCTAssertTrue(app.buttons["Draw a paper"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Put in an idea"].exists)
        XCTAssertTrue(app.tabBars.buttons["Box"].exists)
        XCTAssertTrue(app.tabBars.buttons["Memories"].exists)
    }

    @MainActor
    func testCaptureCannotSaveWithoutDuration() {
        let app = XCUIApplication()
        app.launch()
        openBoxIfNeeded(app)
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
        openBoxIfNeeded(app)

        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()

        XCTAssertTrue(app.buttons["Export backup"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Restore backup"].exists)
        let erase = app.buttons["Erase all local data"]
        app.swipeUp()
        XCTAssertTrue(erase.waitForExistence(timeout: 3))
    }

    @MainActor
    func testHomeAndSettingsPassAutomatedAccessibilityAudit() throws {
        let app = XCUIApplication()
        app.launch()
        openBoxIfNeeded(app)
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 5))

        try app.performAccessibilityAudit(for: auditTypes)
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
        try app.performAccessibilityAudit(for: auditTypes)
    }

    @MainActor
    func testSettingsRemainsOperableAtLargestAccessibilityTextSize() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        ]
        app.launch()
        openBoxIfNeeded(app)

        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 5))
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons["Export backup"].waitForExistence(timeout: 3))

        let erase = app.buttons["Erase all local data"]
        for _ in 0..<4 where !erase.exists { app.swipeUp() }
        XCTAssertTrue(erase.waitForExistence(timeout: 3))
    }

    private var auditTypes: XCUIAccessibilityAuditType {
        [.contrast, .elementDetection, .hitRegion, .sufficientElementDescription, .textClipped, .trait]
    }

    @MainActor
    private func openBoxIfNeeded(_ app: XCUIApplication) {
        let openButton = app.buttons["Open my Box"]
        if openButton.waitForExistence(timeout: 2) {
            XCTAssertTrue(app.staticTexts["Put it in. Draw it out."].exists)
            openButton.tap()
        }
    }
}

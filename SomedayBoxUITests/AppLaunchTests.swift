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

    /// FST-01: the scene builds asynchronously, so the controls layered over it must be
    /// usable immediately — not after the stage is ready. The elapsed ceiling here is loose
    /// because simulator timing is indicative; the 400 ms budget is a device gate (WP-13).
    @MainActor
    func testOverlayControlsRespondWhileTheSceneIsStillBuilding() {
        let app = XCUIApplication()
        app.launch()
        openBoxIfNeeded(app)

        let started = Date()
        let capture = app.buttons["Put in an idea"]
        XCTAssertTrue(capture.waitForExistence(timeout: 5))
        XCTAssertTrue(capture.isHittable)
        capture.tap()

        let title = app.textFields["Paper title"]
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        XCTAssertLessThan(Date().timeIntervalSince(started), 4)
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

    /// LID-04 / FST-02: long-pressing the visible equivalent bypasses the lid preamble
    /// and the existing sheet still owns focus and validation.
    @MainActor
    func testLongPressCaptureOpensTheFocusedSheetWithoutPreamble() {
        let app = XCUIApplication()
        app.launch()
        openBoxIfNeeded(app)

        let capture = app.buttons["Put in an idea"]
        XCTAssertTrue(capture.waitForExistence(timeout: 5))
        capture.press(forDuration: 0.55)

        let released = Date()
        let title = app.textFields["Paper title"]
        XCTAssertTrue(title.waitForExistence(timeout: 1))
        XCTAssertLessThan(Date().timeIntervalSince(released), 1.2)
        title.typeText("Fast capture draft")
        XCTAssertEqual(title.value as? String, "Fast capture draft")
    }

    /// LID-01: tapping the rendered lid itself routes through the RealityKit input target
    /// and opens the same focused capture surface as the visible equivalent.
    @MainActor
    func testTappingTheRenderedLidOpensTheFocusedCaptureSheet() {
        let app = XCUIApplication()
        app.launch()
        openBoxIfNeeded(app)
        XCTAssertTrue(app.buttons["Put in an idea"].waitForExistence(timeout: 5))

        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.42)).tap()

        let title = app.textFields["Paper title"]
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        title.typeText("Lid capture draft")
        XCTAssertEqual(title.value as? String, "Lid capture draft")
    }

    /// LID-03 / LID-06: a forced local commit failure must leave the sheet and draft
    /// intact; the scene coordinator's companion unit fixture proves the focus paper stays
    /// hovering with the lid open.
    @MainActor
    func testCaptureFailureKeepsTheDraftIntact() {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-test-force-capture-failure")
        app.launch()
        openBoxIfNeeded(app)
        app.buttons["Put in an idea"].tap()

        let title = app.textFields["Paper title"]
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        title.typeText("Keep this draft")
        app.buttons["Up to 10 minutes"].tap()
        app.buttons["Put it in the Box"].tap()

        let alert = app.alerts["Your Box was not changed"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3))
        alert.buttons["OK"].tap()
        XCTAssertTrue(title.exists)
        XCTAssertEqual(title.value as? String, "Keep this draft")
        XCTAssertTrue(app.buttons["Put it in the Box"].isEnabled)
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

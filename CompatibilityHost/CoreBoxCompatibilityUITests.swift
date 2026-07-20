import XCTest

@MainActor
final class CoreBoxCompatibilityUITests: XCTestCase {
    func testValidatedAssetCreatesOneRealityRoot() {
        for tier in ["full3D", "lite3D"] {
            let app = XCUIApplication()
            app.launchArguments = ["--core-box-proof-tier", tier]
            app.launch()

            XCTAssertTrue(app.otherElements["probe.reality"].waitForExistence(timeout: 20))
            for motion in ["idle.listen", "capture.deposit", "draw.reveal"] {
                XCTAssertTrue(
                    app.staticTexts["probe.motion.\(motion).complete"].waitForExistence(timeout: 20),
                    motion
                )
            }
            XCTAssertEqual(app.staticTexts["probe.ribbon.samples"].label, "0.0,0.72,1.0")
            app.buttons["probe.advance.stable-pose"].tap()
            let counts = app.staticTexts["probe.reality.counts"]
            let updated = NSPredicate(format: "label == %@", "make:1,update:1,roots:1")
            expectation(for: updated, evaluatedWith: counts)
            waitForExpectations(timeout: 10)
            app.terminate()
        }
    }

    func testStructuralFailureShowsTwoDFallbackWithNoRealityRoot() {
        let app = XCUIApplication()
        app.launchArguments += ["-CoreBoxProofForceInvalidAsset", "YES"]
        app.launch()

        let status = app.staticTexts["probe.status"]
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        XCTAssertTrue(status.label.hasPrefix("2D fallback:"), status.label)
        XCTAssertTrue(app.staticTexts["probe.reality.counts"].label.contains("roots:0"))
        for action in ["capture", "draw", "peek", "current", "memories", "settings", "recovery"] {
            let button = app.buttons["probe.2d.\(action)"]
            XCTAssertTrue(button.isHittable, action)
            button.tap()
            XCTAssertEqual(app.staticTexts["probe.2d.last-action"].label, action)
        }
    }
}

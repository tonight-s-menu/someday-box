import XCTest

final class AppLaunchTests: XCTestCase {
    @MainActor
    func testLaunchesToHome() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["Put it in. Draw it out."].waitForExistence(timeout: 3))
    }
}

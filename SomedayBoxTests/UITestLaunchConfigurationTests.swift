import Foundation
import Testing
@testable import SomedayBox

@Suite("UI test launch isolation")
struct UITestLaunchConfigurationTests {
    @Test func invalidOrUppercaseRunIDsDisableFixtures() {
        let base = [
            UITestEnvironmentKey.enabled: "1",
            UITestEnvironmentKey.runID: "00000000-0000-0000-0000-000000000001",
            UITestEnvironmentKey.fixture: "empty-box",
        ]
        #expect(UITestLaunchConfiguration.load(environment: base).enabled)

        var uppercase = base
        uppercase[UITestEnvironmentKey.runID] = "00000000-0000-0000-0000-00000000000A"
        #expect(UITestLaunchConfiguration.load(environment: uppercase).enabled == false)

        var invalid = base
        invalid[UITestEnvironmentKey.runID] = "not-a-uuid"
        #expect(UITestLaunchConfiguration.load(environment: invalid).enabled == false)
    }

    @Test func fixtureAndOptionsDecodeWithoutTouchingProductState() {
        let environment = [
            UITestEnvironmentKey.enabled: "1",
            UITestEnvironmentKey.runID: "00000000-0000-0000-0000-000000000002",
            UITestEnvironmentKey.fixture: "active-papers:3",
            UITestEnvironmentKey.renderer: "simplified2D",
            UITestEnvironmentKey.motionMode: "reduced",
            UITestEnvironmentKey.projectionFailures: "2",
            UITestEnvironmentKey.lowPowerCap: "1",
        ]
        let configuration = UITestLaunchConfiguration.load(environment: environment)
        #expect(configuration.fixture == .activePapers(3))
        #expect(configuration.renderer == .simplified2D)
        #expect(configuration.motionMode == .reduced)
        #expect(configuration.projectionFailures == 2)
        #expect(configuration.lowPowerCap)
    }
}

import Foundation
import RealityKit
import XCTest
@testable import SomedayBox

/// WP-03 stage fixtures: the camera state table (§15.2, PEEK-02) and the light rig that
/// consumes `box-scene-v1`'s derived values (§9.1).
@MainActor
final class BoxSceneStageTests: XCTestCase {
    func testEveryCameraStateHasItsOwnDistinctViewpoint() {
        let eyes = BoxSceneCameraState.allCases.map(\.eye)
        XCTAssertEqual(Set(eyes.map { "\($0)" }).count, BoxSceneCameraState.allCases.count)
        for state in BoxSceneCameraState.allCases {
            XCTAssertNotEqual(state.eye, state.target, "\(state) would look at its own position.")
            XCTAssertGreaterThan(state.fieldOfViewDegrees, 0)
        }
    }

    func testPeekStaysInsideItsCameraBudget() {
        XCTAssertLessThanOrEqual(BoxSceneCameraState.peek.transitionDuration, 0.8)
        XCTAssertGreaterThan(BoxSceneCameraState.peek.eye.y, BoxSceneCameraState.frontIdle.eye.y)
    }

    func testEveryCameraTransitionStaysInsideTheStandardMotionTier() {
        for state in BoxSceneCameraState.allCases {
            XCTAssertLessThanOrEqual(state.transitionDuration, 0.8, "\(state) exceeds the §11.2 tier.")
        }
    }

    func testLightRigDrivesIntensityAndWarmthFromTheDerivedValues() throws {
        let environment = try EnvironmentRig()
        let key = try XCTUnwrap(environment.root.findEntity(named: EnvironmentRig.NodeName.keyLight) as? DirectionalLight)

        environment.apply(rig(intensity: 0.2, kelvin: 2_700))
        let night = key.light.intensity
        let nightColor = key.light.color

        environment.apply(rig(intensity: 1.0, kelvin: 6_500))
        let noon = key.light.intensity

        XCTAssertGreaterThan(noon, night)
        XCTAssertNotEqual(nightColor, key.light.color)
    }

    func testStageBuildsTheEnvironmentAndCameraNodes() throws {
        let root = try BoxSceneStage().build()
        XCTAssertEqual(root.name, BoxSceneStage.NodeName.root)
        XCTAssertNotNil(root.findEntity(named: EnvironmentRig.NodeName.environment))
        XCTAssertNotNil(root.findEntity(named: EnvironmentRig.NodeName.ground))
        XCTAssertNotNil(root.findEntity(named: CameraRig.NodeName.camera))
    }

    private func rig(intensity: Float, kelvin: Float) -> LightRig {
        LightRig(
            band: .day,
            elevationRadians: 0.9,
            azimuthRadians: 0,
            colorTemperatureKelvin: kelvin,
            relativeIntensity: intensity,
            shadowSoftness: 0.4
        )
    }
}

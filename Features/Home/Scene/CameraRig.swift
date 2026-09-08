import Foundation
import RealityKit

/// The camera states of specification §15.2. Each names where the camera sits, what it
/// looks at, and how long it takes to get there; the interactions that trigger them arrive
/// with their own work packages (capture WP-06, reveal WP-07, peek WP-08, slot WP-17).
enum BoxSceneCameraState: String, Equatable, Sendable, CaseIterable {
    case frontIdle
    case captureLid
    case peek
    case revealFocus
    case slotFocus

    var eye: SIMD3<Float> {
        switch self {
        case .frontIdle: [0.18, 0.34, 1.04]
        case .captureLid: [0, 0.46, 0.74]
        case .peek: [0, 1.05, 0.10]
        case .revealFocus: [0, 0.30, 0.62]
        case .slotFocus: [0.30, 0.30, 0.72]
        }
    }

    var target: SIMD3<Float> {
        switch self {
        case .frontIdle, .revealFocus: [0, 0, 0]
        case .captureLid: [0, 0.06, 0]
        case .peek: [0, 0.02, 0]
        case .slotFocus: [0.06, 0.02, 0.09]
        }
    }

    var fieldOfViewDegrees: Float {
        switch self {
        case .frontIdle, .slotFocus: 42
        case .captureLid: 44
        case .peek: 48
        case .revealFocus: 38
        }
    }

    /// Peek is capped at 0.8 s by PEEK-02; the rest stay inside the §11.2 standard tier.
    var transitionDuration: TimeInterval {
        switch self {
        case .frontIdle: 0.55
        case .captureLid: 0.45
        case .peek: 0.70
        case .revealFocus: 0.50
        case .slotFocus: 0.45
        }
    }
}

/// Holds the scene's single camera and moves it between states.
///
/// `RealityViewCameraContent.animate` is iOS 26 only, so transitions use
/// `Entity.move(to:relativeTo:duration:timingFunction:)`, which is also what LB-D15's
/// determinism requires: no simulation participates in any camera move.
@MainActor
struct CameraRig {
    enum NodeName {
        static let cameraRig = "CameraRig"
        static let camera = "Camera"
    }

    let root: Entity
    private let camera: PerspectiveCamera

    init(initialState: BoxSceneCameraState = .frontIdle) {
        let root = Entity()
        root.name = NodeName.cameraRig

        let camera = PerspectiveCamera()
        camera.name = NodeName.camera
        root.addChild(camera)

        self.root = root
        self.camera = camera
        apply(initialState, animated: false)
    }

    /// Moves to a state. With Reduce Motion the camera cuts instead of travelling; the
    /// hosting view cross-fades a veil across the cut so the change still reads as one
    /// continuous surface (§11.3, PEEK-02).
    func apply(_ state: BoxSceneCameraState, animated: Bool) {
        camera.camera.fieldOfViewInDegrees = state.fieldOfViewDegrees

        guard animated else {
            camera.look(at: state.target, from: state.eye, relativeTo: nil)
            return
        }

        let destination = Self.transform(eye: state.eye, target: state.target)
        camera.move(
            to: destination,
            relativeTo: nil,
            duration: state.transitionDuration,
            timingFunction: .easeInOut
        )
    }

    private static func transform(eye: SIMD3<Float>, target: SIMD3<Float>) -> Transform {
        let probe = Entity()
        probe.look(at: target, from: eye, relativeTo: nil)
        return probe.transform
    }
}

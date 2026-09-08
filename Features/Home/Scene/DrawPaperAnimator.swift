import Foundation
import RealityKit

/// Presentation-only choreography. Selection and reservation are already persisted.
@MainActor
final class DrawPaperAnimator {
    static let handoffTime: TimeInterval = 2.25
    static let duration: TimeInterval = 2.65
    let root = Entity()
    private let box: BoxGeometry
    private let paper: ModelEntity

    init(box: BoxGeometry) {
        self.box = box
        root.name = "DrawFlight"
        paper = ModelEntity(
            mesh: .generateBox(width: 0.20, height: 0.27, depth: 0.0012, cornerRadius: 0.004),
            materials: [BoxMaterials.paper()]
        )
        paper.name = "DrawnPaper"
        paper.isEnabled = false
        root.addChild(paper)
    }

    func apply(time: TimeInterval) {
        let t = Float(max(time, 0))
        let shake: Float = t < 0.85 ? sin(t / 0.85 * .pi) : 0
        box.root.transform = Transform(
            rotation: simd_quatf(angle: sin(t * 49) * 0.035 * shake, axis: [0, 0, 1]),
            translation: [sin(t * 58) * 0.0025 * shake, 0, 0]
        )
        box.setLid(openness: smooth((t - 0.70) / 0.35) * (1 - smooth((t - 1.85) / 0.4)))
        paper.isEnabled = time >= 0.88 && time < Self.duration
        root.components.set(OpacityComponent(opacity: 1 - smooth((t - Float(Self.handoffTime)) / 0.22)))
        guard paper.isEnabled else { return }

        let progress = min(max((t - 0.88) / 1.37, 0), 1)
        let eased = 1 - pow(1 - progress, 3)
        let start = SIMD3<Float>(0, BoxGeometry.Metrics.interiorFloor + 0.03, 0)
        let camera = BoxSceneCameraState.frontIdle
        let forward = simd_normalize(camera.target - camera.eye)
        let right = simd_normalize(simd_cross(forward, SIMD3<Float>(0, 1, 0)))
        let up = simd_cross(right, forward)
        let end = camera.eye + forward * 0.42 + up * 0.045
        // A high arc clears both flaps before decelerating in front of the virtual camera.
        let control = SIMD3<Float>(-0.065, 0.44, 0.18)
        let position = (1 - eased) * (1 - eased) * start
            + 2 * (1 - eased) * eased * control + eased * eased * end
        let facing = simd_quatf(from: [0, 0, 1], to: -forward)
        let folded = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
        let rotation = simd_slerp(folded, facing, smooth(progress))
            * simd_quatf(angle: sin(progress * .pi * 2) * 0.30 * (1 - progress), axis: [0, 0, 1])
        let unfolding = smooth((progress - 0.2) / 0.8)
        paper.transform = Transform(
            scale: [0.52 + 0.08 * unfolding, 0.18 + 0.42 * unfolding, 1],
            rotation: rotation,
            translation: position
        )
    }

    private func smooth(_ value: Float) -> Float {
        let x = min(max(value, 0), 1)
        return x * x * (3 - 2 * x)
    }
}

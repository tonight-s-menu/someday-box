import Foundation
import RealityKit

/// A finite ten-second performance, followed by complete stillness (PRF-03).
/// Time is injected so frame rate never changes choreography or accumulated transforms.
struct BoxIdlePose {
    var stretch: Float = 1
    var lift: Float = 0
    var tilt: Float = 0
    var turn: Float = 0
    var eyeOpen: Float = 1
    var glance: Float = 0

    static func sample(at time: TimeInterval) -> Self {
        guard time > 0, time < 10 else { return Self() }
        let t = Float(time)
        var pose = Self()
        let envelope = window(t, 0, 10)
        pose.stretch += 0.012 * sin(t * .pi / 2) * envelope
        // Two quick blinks, then a curious glance with a delayed body follow-through.
        pose.eyeOpen = 1 - 0.94 * max(window(t, 1.3, 1.58), window(t, 4.1, 4.4))
        pose.glance = 0.004 * window(t, 2.1, 4.0)
        pose.tilt = -0.065 * window(t, 2.4, 4.2)
        pose.turn = 0.09 * window(t, 2.6, 4.3)
        // Anticipation, flight, landing squash, and a smaller settling rebound.
        pose.stretch -= 0.07 * window(t, 5.4, 5.85)
        pose.lift = 0.022 * window(t, 5.8, 6.45)
        pose.stretch += 0.045 * window(t, 5.85, 6.3)
        pose.stretch -= 0.055 * window(t, 6.4, 6.75)
        pose.lift += 0.004 * window(t, 6.75, 7.1)
        pose.tilt += 0.035 * sin((t - 7.5) * 5) * window(t, 7.5, 9.6)
        return pose
    }

    /// Raised cosine: zero velocity at the ends and at the peak.
    private static func window(_ time: Float, _ start: Float, _ end: Float) -> Float {
        guard time > start, time < end else { return 0 }
        return (1 - cos(2 * .pi * (time - start) / (end - start))) / 2
    }
}

@MainActor
final class BoxIdleAnimator {
    private let root: Entity
    private let eyes: [(Entity, Transform)]

    init(box: BoxGeometry) {
        root = box.root
        eyes = ["EyeLeft", "EyeRight"].compactMap { name in
            guard let eye = box.root.findEntity(named: name) else { return nil }
            return (eye, eye.transform)
        }
    }

    func apply(time: TimeInterval) {
        let pose = BoxIdlePose.sample(at: time)
        let width = 1 / sqrt(pose.stretch)
        let rotation = simd_quatf(angle: pose.tilt, axis: [0, 0, 1])
            * simd_quatf(angle: pose.turn, axis: [0, 1, 0])
        // Rotate and breathe around the floor contact, so the body does not sink.
        let bottom = SIMD3<Float>(0, -BoxGeometry.Metrics.bodyHeight / 2, 0)
        let translation = bottom - rotation.act(bottom * SIMD3(width, pose.stretch, width))
            + SIMD3<Float>(0, pose.lift + abs(sin(pose.tilt)) * BoxGeometry.Metrics.bodyWidth / 2, 0)
        root.transform = Transform(scale: [width, pose.stretch, width], rotation: rotation, translation: translation)
        for (eye, rest) in eyes {
            var transform = rest
            transform.scale.y *= pose.eyeOpen
            transform.translation.x += pose.glance
            eye.transform = transform
        }
    }
}

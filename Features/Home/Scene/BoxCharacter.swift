import RealityKit

/// Printed-style facial features; every part stays attached to the container.
@MainActor
enum BoxCharacter {
    static func makeFace() -> Entity {
        let face = Entity()
        face.name = "Face"
        face.position = [0, 0.006, BoxGeometry.Metrics.bodyDepth / 2]
        for side: Float in [-1, 1] {
            let eye = bead(name: side < 0 ? "EyeLeft" : "EyeRight", size: [0.010, 0.014, 0.004])
            eye.position = [side * 0.032, 0.012, 0.001]
            let glint = bead(name: "EyeGlint", size: [0.24, 0.20, 0.24], light: true)
            glint.position = [-0.25, 0.30, 0.90]
            eye.addChild(glint)
            face.addChild(eye)

            let cheek = ModelEntity(mesh: .generateSphere(radius: 1), materials: [BoxMaterials.ceramic(BoxMaterials.Tone.blush)])
            cheek.name = side < 0 ? "CheekLeft" : "CheekRight"
            cheek.scale = [0.013, 0.006, 0.0015]
            cheek.position = [side * 0.053, -0.005, 0.001]
            face.addChild(cheek)
        }
        // A continuous U-shaped smile made from overlapping round beads.
        for index in 0...40 {
            let angle = Float.pi * Float(index) / 40
            let point = bead(name: "Smile\(index)", size: [0.0016, 0.0016, 0.0018])
            point.position = [cos(angle) * 0.011, -0.007 - sin(angle) * 0.006, 0.002]
            face.addChild(point)
        }
        return face
    }

    private static func bead(name: String, size: SIMD3<Float>, light: Bool = false) -> ModelEntity {
        let bead = ModelEntity(
            mesh: .generateSphere(radius: 1),
            materials: [BoxMaterials.ceramic(light ? BoxMaterials.Tone.paper : BoxMaterials.Tone.ink)]
        )
        bead.name = name
        bead.scale = size
        return bead
    }
}

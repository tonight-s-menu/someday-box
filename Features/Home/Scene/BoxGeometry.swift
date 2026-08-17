import Foundation
import RealityKit

/// The box itself, built parametrically: body, a lid on its own pivot, the draw strap, and
/// the structures that only appear once their §10.1 predicates hold.
///
/// Entity names follow specification §15.2 so later work packages address parts by name
/// rather than by position in the graph.
@MainActor
struct BoxGeometry {
    enum NodeName {
        static let box = "Box"
        static let body = "Body"
        static let lidPivot = "LidPivot"
        static let lid = "Lid"
        static let strapAnchor = "StrapAnchor"
        static let strap = "Strap"
        static let memorySeam = "MemorySeam"
        static let letterSlot = "LetterSlot"
        static let bottomSeam = "BottomSeam"
    }

    /// Box dimensions in metres. The scene is authored at real-object scale so motion
    /// curves and camera distances read as a physical object on a table.
    enum Metrics {
        static let bodyWidth: Float = 0.26
        static let bodyHeight: Float = 0.13
        static let bodyDepth: Float = 0.19
        static let cornerRadius: Float = 0.014
        static let wallThickness: Float = 0.010
        static let lidThickness: Float = 0.016
        static let lidOverhang: Float = 0.008
        /// The lid's open angle, in radians, when a sequence lifts it (WP-06, WP-08).
        static let lidOpenAngle: Float = -1.25

        static var interiorFloor: Float { -bodyHeight / 2 + wallThickness }
        static var interiorWidth: Float { bodyWidth - 2 * wallThickness }
        static var interiorDepth: Float { bodyDepth - 2 * wallThickness }
    }

    let root: Entity
    private let lidPivot: Entity
    /// Structures that exist in the graph from the first frame but stay hidden until their
    /// predicates hold: the memory seam (WP-16), the letter slot (WP-17), and the bottom
    /// compartment seam (WP-21). Hidden-by-default is TRC-08's floor.
    private let growthStructures: [String: Entity]

    init() {
        let root = Entity()
        root.name = NodeName.box

        root.addChild(Self.makeBody())

        // The lid hangs off a pivot at the rear top edge, so opening it is a rotation of
        // the pivot rather than a transform the geometry has to compensate for.
        let lidPivot = Entity()
        lidPivot.name = NodeName.lidPivot
        lidPivot.position = [0, Metrics.bodyHeight / 2, -Metrics.bodyDepth / 2]

        let lid = ModelEntity(
            mesh: .generateBox(
                width: Metrics.bodyWidth + Metrics.lidOverhang,
                height: Metrics.lidThickness,
                depth: Metrics.bodyDepth + Metrics.lidOverhang,
                cornerRadius: Metrics.cornerRadius
            ),
            materials: [BoxMaterials.ceramic(BoxMaterials.Tone.lid)]
        )
        lid.name = NodeName.lid
        lid.position = [0, Metrics.lidThickness / 2, (Metrics.bodyDepth + Metrics.lidOverhang) / 2]
        lidPivot.addChild(lid)
        root.addChild(lidPivot)

        root.addChild(Self.makeStrap())

        var structures: [String: Entity] = [:]
        for structure in [Self.makeMemorySeam(), Self.makeLetterSlot(), Self.makeBottomSeam()] {
            structure.isEnabled = false
            structures[structure.name] = structure
            root.addChild(structure)
        }

        self.root = root
        self.lidPivot = lidPivot
        growthStructures = structures
    }

    /// Rotates the lid about its rear hinge. `openness` is 0 for closed and 1 for fully
    /// open; the sequences that drive it arrive with WP-06 and WP-08.
    func setLid(openness: Float, animatedOver duration: TimeInterval = 0) {
        let angle = Metrics.lidOpenAngle * min(max(openness, 0), 1)
        let target = Transform(
            rotation: simd_quatf(angle: angle, axis: [1, 0, 0]),
            translation: lidPivot.position
        )
        if duration > 0 {
            lidPivot.move(to: target, relativeTo: lidPivot.parent, duration: duration, timingFunction: .easeInOut)
        } else {
            lidPivot.transform = target
        }
    }

    /// Shows or hides a §10.1 structure. Hiding is as important as showing: a structure
    /// whose predicate becomes false must disappear again (TRC-08).
    func setStructure(_ name: String, visible: Bool) {
        growthStructures[name]?.isEnabled = visible
    }

    func isStructureVisible(_ name: String) -> Bool {
        growthStructures[name]?.isEnabled ?? false
    }

    // MARK: - Parts

    /// A real container, not a solid block: a floor and four walls enclosing the cavity the
    /// paper stack rests in. RealityKit has no boolean subtraction, so the box is assembled
    /// from rounded slabs — which also keeps every edge soft, per the §15.4 material brief.
    private static func makeBody() -> Entity {
        let body = Entity()
        body.name = NodeName.body

        let material = BoxMaterials.ceramic(BoxMaterials.Tone.body)
        let wallHeight = Metrics.bodyHeight - Metrics.wallThickness
        let wallCentreY = Metrics.interiorFloor + wallHeight / 2
        let slabRadius = Metrics.wallThickness / 2

        let floor = ModelEntity(
            mesh: .generateBox(
                width: Metrics.bodyWidth,
                height: Metrics.wallThickness,
                depth: Metrics.bodyDepth,
                cornerRadius: slabRadius
            ),
            materials: [material]
        )
        floor.name = "Floor"
        floor.position = [0, -Metrics.bodyHeight / 2 + Metrics.wallThickness / 2, 0]
        body.addChild(floor)

        for (name, size, position) in [
            (
                "WallFront",
                SIMD3<Float>(Metrics.bodyWidth, wallHeight, Metrics.wallThickness),
                SIMD3<Float>(0, wallCentreY, (Metrics.bodyDepth - Metrics.wallThickness) / 2)
            ),
            (
                "WallBack",
                SIMD3<Float>(Metrics.bodyWidth, wallHeight, Metrics.wallThickness),
                SIMD3<Float>(0, wallCentreY, -(Metrics.bodyDepth - Metrics.wallThickness) / 2)
            ),
            (
                "WallLeft",
                SIMD3<Float>(Metrics.wallThickness, wallHeight, Metrics.interiorDepth),
                SIMD3<Float>(-(Metrics.bodyWidth - Metrics.wallThickness) / 2, wallCentreY, 0)
            ),
            (
                "WallRight",
                SIMD3<Float>(Metrics.wallThickness, wallHeight, Metrics.interiorDepth),
                SIMD3<Float>((Metrics.bodyWidth - Metrics.wallThickness) / 2, wallCentreY, 0)
            ),
        ] {
            let wall = ModelEntity(
                mesh: .generateBox(
                    width: size.x,
                    height: size.y,
                    depth: size.z,
                    cornerRadius: slabRadius
                ),
                materials: [material]
            )
            wall.name = name
            wall.position = position
            body.addChild(wall)
        }

        return body
    }

    /// A short fabric pull-tab at the lower front — visible but small (§7.2).
    private static func makeStrap() -> Entity {
        let anchor = Entity()
        anchor.name = NodeName.strapAnchor
        anchor.position = [0, -Metrics.bodyHeight / 2 + 0.030, Metrics.bodyDepth / 2]

        let strap = ModelEntity(
            mesh: .generateBox(width: 0.032, height: 0.046, depth: 0.006, cornerRadius: 0.003),
            materials: [BoxMaterials.fabric(BoxMaterials.Tone.strap)]
        )
        strap.name = NodeName.strap
        strap.position = [0, 0, 0.002]
        anchor.addChild(strap)
        return anchor
    }

    private static func makeMemorySeam() -> Entity {
        let seam = ModelEntity(
            mesh: .generateBox(width: 0.004, height: 0.052, depth: 0.001, cornerRadius: 0.0005),
            materials: [BoxMaterials.ceramic(BoxMaterials.Tone.recess)]
        )
        seam.name = NodeName.memorySeam
        seam.position = [Metrics.bodyWidth / 2, -0.01, 0]
        return seam
    }

    private static func makeLetterSlot() -> Entity {
        let slot = ModelEntity(
            mesh: .generateBox(width: 0.072, height: 0.006, depth: 0.001, cornerRadius: 0.003),
            materials: [BoxMaterials.ceramic(BoxMaterials.Tone.recess)]
        )
        slot.name = NodeName.letterSlot
        slot.position = [0, 0.028, Metrics.bodyDepth / 2]
        return slot
    }

    private static func makeBottomSeam() -> Entity {
        let seam = ModelEntity(
            mesh: .generateBox(width: Metrics.interiorWidth * 0.82, height: 0.001, depth: 0.002),
            materials: [BoxMaterials.ceramic(BoxMaterials.Tone.recess)]
        )
        seam.name = NodeName.bottomSeam
        seam.position = [0, Metrics.interiorFloor + 0.0005, 0]
        return seam
    }
}

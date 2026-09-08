import Foundation
import RealityKit

/// The box itself, built parametrically: a hollow body, two folding top flaps, and
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
        static let memorySeam = "MemorySeam"
        static let letterSlot = "LetterSlot"
        static let bottomSeam = "BottomSeam"
    }

    /// Box dimensions in metres. The scene is authored at real-object scale so motion
    /// curves and camera distances read as a physical object on a table.
    enum Metrics {
        static let bodyWidth: Float = 0.24
        static let bodyHeight: Float = 0.17
        static let bodyDepth: Float = 0.19
        static let wallThickness: Float = 0.0045
        static let lidThickness: Float = 0.0035
        /// The lid's open angle, in radians, when a sequence lifts it (WP-06, WP-08).
        static let lidOpenAngle: Float = -1.25

        static var interiorFloor: Float { -bodyHeight / 2 + wallThickness }
        static var interiorWidth: Float { bodyWidth - 2 * wallThickness }
        static var interiorDepth: Float { bodyDepth - 2 * wallThickness }
    }

    let root: Entity
    private let lidPivot: Entity
    private let frontFlapPivot: Entity
    /// Structures that exist in the graph from the first frame but stay hidden until their
    /// predicates hold: the memory seam (WP-16), the letter slot (WP-17), and the bottom
    /// compartment seam (WP-21). Hidden-by-default is TRC-08's floor.
    private let growthStructures: [String: Entity]

    init() throws {
        let root = Entity()
        root.name = NodeName.box

        root.addChild(try Self.makeBody())

        // The lid hangs off a pivot at the rear top edge, so opening it is a rotation of
        // the pivot rather than a transform the geometry has to compensate for.
        let lidPivot = Entity()
        lidPivot.name = NodeName.lidPivot
        lidPivot.position = [0, Metrics.bodyHeight / 2, -Metrics.bodyDepth / 2]

        lidPivot.addChild(try Self.makeFlap(front: false))
        root.addChild(lidPivot)

        let frontFlapPivot = Entity()
        frontFlapPivot.name = "FrontFlapPivot"
        frontFlapPivot.position = [0, Metrics.bodyHeight / 2, Metrics.bodyDepth / 2]
        frontFlapPivot.addChild(try Self.makeFlap(front: true))
        root.addChild(frontFlapPivot)
        self.frontFlapPivot = frontFlapPivot

        root.addChild(BoxCharacter.makeFace())

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
        for (pivot, rotation) in [(lidPivot, angle), (frontFlapPivot, -angle * 2.1)] {
            let target = Transform(
                rotation: simd_quatf(angle: rotation, axis: [1, 0, 0]),
                translation: pivot.position
            )
            if duration > 0 {
                pivot.move(to: target, relativeTo: pivot.parent, duration: duration, timingFunction: .easeInOut)
            } else {
                pivot.transform = target
            }
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
    private static func makeBody() throws -> Entity {
        let body = Entity()
        body.name = NodeName.body

        let material = try BoxMaterials.cardboard(BoxMaterials.Tone.body)
        let wallHeight = Metrics.bodyHeight
        let wallCentreY: Float = 0
        let slabRadius = Metrics.wallThickness / 2

        let floor = ModelEntity(
            mesh: .generateBox(
                width: Metrics.interiorWidth,
                height: Metrics.wallThickness,
                depth: Metrics.interiorDepth,
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

        let tail = ModelEntity(
            mesh: .generateBox(width: 0.039, height: 0.027, depth: 0.00035, cornerRadius: 0.0002),
            materials: [try BoxMaterials.packingTape()]
        )
        tail.name = "TapeEnd"
        tail.position = [0, Metrics.bodyHeight / 2 - 0.0135, Metrics.bodyDepth / 2 + 0.0002]
        body.addChild(tail)
        for side: Float in [-1, 1] {
            let fold = ModelEntity(
                mesh: .generateBox(width: 0.0006, height: Metrics.bodyHeight - 0.004, depth: 0.0003),
                materials: [BoxMaterials.paper(BoxMaterials.Tone.recess)]
            )
            fold.name = side < 0 ? "LeftFold" : "RightFold"
            fold.position = [side * (Metrics.bodyWidth / 2 - 0.003), 0, Metrics.bodyDepth / 2 + 0.0001]
            body.addChild(fold)
        }
        return body
    }

    /// Two thin half-depth flaps meet along a visible centre seam, without an overhanging cap.
    private static func makeFlap(front: Bool) throws -> Entity {
        let lid = Entity()
        lid.name = NodeName.lid
        let direction: Float = front ? -1 : 1
        let depth = Metrics.bodyDepth / 2 - 0.0007
        let panel = ModelEntity(
            mesh: .generateBox(width: Metrics.bodyWidth, height: Metrics.lidThickness, depth: depth, cornerRadius: 0.0006),
            materials: [try BoxMaterials.cardboard(front ? BoxMaterials.Tone.lid : BoxMaterials.Tone.body)]
        )
        panel.name = front ? "FrontFlap" : "RearFlap"
        panel.position = [0, Metrics.lidThickness / 2, direction * depth / 2]
        panel.components.set(InputTargetComponent())
        panel.generateCollisionShapes(recursive: false)
        lid.addChild(panel)

        let tape = ModelEntity(
            mesh: front ? try makeWrappedTape(depth: depth) : .generateBox(
                width: 0.039, height: 0.00035, depth: depth, cornerRadius: 0.0001
            ),
            materials: [try BoxMaterials.packingTape()]
        )
        tape.name = "PackingTape"
        tape.position = front ? .zero : [0, Metrics.lidThickness + 0.0002, direction * depth / 2]
        tape.components.set(InputTargetComponent())
        tape.generateCollisionShapes(recursive: false)
        lid.addChild(tape)

        // Short exposed flutes on the cut edge make the thickness read as corrugated stock.
        let edgeMaterial = BoxMaterials.paper(BoxMaterials.Tone.recess)
        for index in 0..<48 {
            let flute = ModelEntity(
                mesh: .generateBox(width: 0.0015, height: 0.0013, depth: 0.0004, cornerRadius: 0.0002),
                materials: [edgeMaterial]
            )
            flute.name = "Flute\(index)"
            flute.position = [-Metrics.bodyWidth / 2 + 0.0025 + Float(index) * 0.005,
                              Metrics.lidThickness / 2, direction * depth]
            lid.addChild(flute)
        }
        return lid
    }

    /// One solid ribbon crosses the flap edge and meets the fixed front tape below
    /// the hinge. The wrapped part follows the flap when opened, leaving the tail on the body.
    private static func makeWrappedTape(depth: Float) throws -> MeshResource {
        let radius: Float = 0.0008
        let top = Metrics.lidThickness + 0.0002
        var path: [(SIMD3<Float>, SIMD3<Float>)] = [([0, top, -depth], [0, 1, 0])]
        for step in 0...8 {
            let angle = Float(step) / 8 * .pi / 2
            path.append((
                [0, top - radius + radius * cos(angle), 0.0002 - radius + radius * sin(angle)],
                [0, cos(angle), sin(angle)]
            ))
        }
        // Slight overlap hides the joint without attaching the fixed tail to a moving flap.
        path.append(([0, -0.00015, 0.0002], [0, 0, 1]))

        var vertices: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var uv: [SIMD2<Float>] = []
        var triangles: [UInt32] = []
        var distance: Float = 0
        for (index, sample) in path.enumerated() {
            if index > 0 { distance += simd_distance(sample.0, path[index - 1].0) }
            for surface: Float in [1, -1] {
                for side: Float in [-1, 1] {
                    vertices.append(sample.0 + [side * 0.039 / 2, 0, 0] + sample.1 * (surface * 0.000175))
                    normals.append(sample.1 * surface)
                    uv.append([(side + 1) / 2, distance / depth])
                }
            }
            guard index > 0 else { continue }
            let a = UInt32((index - 1) * 4)
            let b = UInt32(index * 4)
            triangles += [a, b, a + 1, a + 1, b, b + 1]
            triangles += [a + 2, a + 3, b + 2, a + 3, b + 3, b + 2]
            triangles += [a, a + 2, b, a + 2, b + 2, b]
            triangles += [a + 1, b + 1, a + 3, a + 3, b + 1, b + 3]
        }
        let end = UInt32(vertices.count - 4)
        triangles += [0, 1, 2, 1, 3, 2, end, end + 2, end + 1, end + 1, end + 2, end + 3]
        var mesh = MeshDescriptor(name: "WrappedPackingTape")
        mesh.positions = MeshBuffers.Positions(vertices)
        mesh.normals = MeshBuffers.Normals(normals)
        mesh.textureCoordinates = MeshBuffers.TextureCoordinates(uv)
        mesh.primitives = .triangles(triangles)
        return try MeshResource.generate(from: [mesh])
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

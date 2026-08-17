import Foundation
import RealityKit

/// The paper stack: one entity per visible instance from `BoxSceneSnapshot`, placed at the
/// seeded resting transform the reducer derived (§6.2 density, §6.3 layout).
///
/// The layer owns no product truth. It diffs whatever snapshot it is handed: papers that
/// entered are added, papers that left are removed, and survivors keep their entity — which
/// is what makes the arrangement stable across relaunches (SCN-03).
///
/// Paper forms and age expression are WP-15's work; every instance here is the same neutral
/// slip, sized only by the shared mesh.
@MainActor
final class PaperStackLayer {
    enum NodeName {
        static let paperStack = "PaperStack"
    }

    private enum Metrics {
        /// Sized so that a paper at its maximum seeded offset and yaw still clears the
        /// interior walls — otherwise the corners of a jittered paper poke through the box.
        static let width: Float = 0.130
        static let depth: Float = 0.086
        static let thickness: Float = 0.0016
        static let cornerRadius: Float = 0.004
        /// Papers compress as the stack grows: 32 instances still have to fit under the lid.
        static let maximumStackHeight: Float = 0.070
        static let restingGap: Float = 0.0026
    }

    let root: Entity

    /// One mesh and one material shared by every instance (§15.2 instanced paper entities).
    private let mesh: MeshResource
    private let material: PhysicallyBasedMaterial
    private var entities: [UUID: Entity] = [:]

    init() {
        let root = Entity()
        root.name = NodeName.paperStack
        self.root = root
        mesh = .generateBox(
            width: Metrics.width,
            height: Metrics.thickness,
            depth: Metrics.depth,
            cornerRadius: Metrics.cornerRadius
        )
        material = BoxMaterials.paper()
    }

    /// Applies a snapshot's visible stack. Enter and leave are instant in B1; the capture
    /// drop and draw slide-out own their own sequences (WP-06, WP-07).
    func apply(papers: [BoxScenePaper]) {
        let incoming = Set(papers.map(\.id))
        for (id, entity) in entities where !incoming.contains(id) {
            entity.removeFromParent()
            entities.removeValue(forKey: id)
        }

        let spacing = spacing(for: papers.count)
        for paper in papers {
            let entity = entities[paper.id] ?? makeInstance(for: paper.id)
            entity.transform = transform(for: paper, spacing: spacing)
        }
    }

    /// The stack has to stay under the lid however full the box is, so the gap between
    /// papers compresses once the resting gap would overflow the interior.
    private func spacing(for count: Int) -> Float {
        guard count > 1 else { return Metrics.restingGap }
        return min(Metrics.restingGap, Metrics.maximumStackHeight / Float(count - 1))
    }

    private func makeInstance(for id: UUID) -> Entity {
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.name = "Paper"
        root.addChild(entity)
        entities[id] = entity
        return entity
    }

    private func transform(for paper: BoxScenePaper, spacing: Float) -> Transform {
        let seeded = paper.transform
        let height = BoxGeometry.Metrics.interiorFloor
            + Metrics.thickness / 2
            + spacing * Float(seeded.stackIndex)
        return Transform(
            rotation: simd_quatf(angle: seeded.yawRadians, axis: [0, 1, 0]),
            translation: [seeded.lateralOffset, height, seeded.depthOffset]
        )
    }
}

#if SOMEDAYBOX_SCENE_SPIKE
import RealityKit
import SwiftUI
import UIKit

/// Builds the placeholder entity graph for the WP-01 rendering spike.
///
/// Node names mirror the entity architecture in the feature specification §15.2 so the
/// work packages that follow attach to a graph that already has the intended shape:
/// WP-03 replaces the environment and camera rigs, WP-04 replaces the box and fills the
/// paper stack.
///
/// Nothing here reads product records. The spike renders fixed geometry; the real
/// snapshot pipeline (`box-scene-v1`) arrives in WP-02 and is applied by WP-03/WP-04.
@MainActor
enum BoxSceneRealityLayer {
    /// Entity names from specification §15.2. They are diagnostics-safe by construction:
    /// structural identifiers only, never record content.
    enum NodeName {
        static let root = "BoxSceneRoot"
        static let environment = "Environment"
        static let ground = "Ground"
        static let keyLight = "KeyLight"
        static let box = "Box"
        static let body = "Body"
        static let lidPivot = "LidPivot"
        static let lid = "Lid"
        static let paperStack = "PaperStack"
        static let focusPaper = "FocusPaper"
        static let cameraRig = "CameraRig"
    }

    /// Placeholder tints for the spike only. The shipped material families are decided at
    /// WP-04's art-direction review, so they deliberately do not enter the brand palette
    /// yet; the box reuses the existing brand tone so the spike is comparable with the
    /// current Home illustration.
    private enum Tint {
        static let body = SomedayBoxBrand.box
        static let lid = Color(red: 0.78, green: 0.52, blue: 0.31)
        static let ground = Color(red: 0.93, green: 0.89, blue: 0.83)
        static let keyLight = Color(red: 1.0, green: 0.96, blue: 0.9)
    }

    /// Box dimensions in metres. The scene is authored at real-object scale so the camera
    /// distances and later motion curves read as a physical object on a table.
    private enum Metrics {
        static let bodyWidth: Float = 0.26
        static let bodyHeight: Float = 0.13
        static let bodyDepth: Float = 0.19
        static let bodyCornerRadius: Float = 0.014
        static let lidThickness: Float = 0.016
        static let lidOverhang: Float = 0.008
        static let groundSize: Float = 1.6
    }

    static func makePlaceholderScene() -> Entity {
        let root = Entity()
        root.name = NodeName.root
        root.addChild(makeEnvironment())
        root.addChild(makePlaceholderBox())
        root.addChild(makeContainer(named: NodeName.paperStack))
        root.addChild(makeContainer(named: NodeName.focusPaper))
        root.addChild(makeCameraRig())
        return root
    }

    /// An empty transform node reserved for a later work package.
    private static func makeContainer(named name: String) -> Entity {
        let container = Entity()
        container.name = name
        return container
    }

    private static func makeEnvironment() -> Entity {
        let environment = Entity()
        environment.name = NodeName.environment

        let key = DirectionalLight()
        key.name = NodeName.keyLight
        key.light.intensity = 2_600
        key.light.color = UIColor(Tint.keyLight)
        key.look(at: .zero, from: [0.45, 0.9, 0.6], relativeTo: nil)
        environment.addChild(key)

        let groundMesh = MeshResource.generateBox(
            width: Metrics.groundSize,
            height: 0.002,
            depth: Metrics.groundSize,
            cornerRadius: 0.001
        )
        let ground = ModelEntity(mesh: groundMesh, materials: [warmMatte(tint: Tint.ground)])
        ground.name = NodeName.ground
        ground.position = [0, -Metrics.bodyHeight / 2 - 0.001, 0]
        environment.addChild(ground)

        return environment
    }

    private static func makePlaceholderBox() -> Entity {
        let box = Entity()
        box.name = NodeName.box

        let bodyMesh = MeshResource.generateBox(
            width: Metrics.bodyWidth,
            height: Metrics.bodyHeight,
            depth: Metrics.bodyDepth,
            cornerRadius: Metrics.bodyCornerRadius
        )
        let body = ModelEntity(mesh: bodyMesh, materials: [warmMatte(tint: Tint.body)])
        body.name = NodeName.body
        box.addChild(body)

        // The lid hangs off a pivot at the rear top edge so WP-06 can rotate the pivot
        // rather than animating a transform the geometry has to compensate for.
        let lidPivot = Entity()
        lidPivot.name = NodeName.lidPivot
        lidPivot.position = [0, Metrics.bodyHeight / 2, -Metrics.bodyDepth / 2]

        let lidMesh = MeshResource.generateBox(
            width: Metrics.bodyWidth + Metrics.lidOverhang,
            height: Metrics.lidThickness,
            depth: Metrics.bodyDepth + Metrics.lidOverhang,
            cornerRadius: Metrics.bodyCornerRadius
        )
        let lid = ModelEntity(mesh: lidMesh, materials: [warmMatte(tint: Tint.lid)])
        lid.name = NodeName.lid
        lid.position = [0, Metrics.lidThickness / 2, (Metrics.bodyDepth + Metrics.lidOverhang) / 2]
        lidPivot.addChild(lid)
        box.addChild(lidPivot)

        return box
    }

    private static func makeCameraRig() -> Entity {
        let rig = Entity()
        rig.name = NodeName.cameraRig

        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = 42
        camera.look(at: [0, 0, 0], from: [0, 0.34, 0.98], relativeTo: nil)
        rig.addChild(camera)

        return rig
    }

    /// The concept's material family: warm, matte, non-metallic, no exposed machinery
    /// (specification §15.4).
    private static func warmMatte(tint: Color) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: UIColor(tint))
        material.roughness = 0.86
        material.metallic = 0.0
        return material
    }
}
#endif

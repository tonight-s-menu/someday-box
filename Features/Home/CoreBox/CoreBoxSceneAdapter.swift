import Foundation
import RealityKit
import simd

@MainActor
final class CoreBoxSceneAdapter: CoreBoxPresentationAdapter {
    private let inventory: CoreBoxValidatedInventory
    private let root: Entity
    private let restTransforms: [String: Transform]
    private(set) var lastSnapshot: CoreBoxSceneSnapshot?
    private(set) var lastMotionName: String?

    init(loadedAsset: CoreBoxLoadedAsset) {
        self.inventory = loadedAsset.validatedInventory
        self.root = loadedAsset.root
        var captured = [String: Transform]()
        for name in loadedAsset.validatedInventory.parentByEntity.keys {
            captured[name] = loadedAsset.root.name == name
                ? loadedAsset.root.transform
                : loadedAsset.root.findEntity(named: name)?.transform
        }
        self.restTransforms = captured
    }

    func apply(snapshot: CoreBoxSceneSnapshot) {
        lastSnapshot = snapshot
    }

    func apply(event: CoreBoxPresentationEvent, sourceSnapshotVersion: UInt64) {
        let motionName: String?
        switch event {
        case .touch: motionName = "react.touch"
        case .captureReceive: motionName = "capture.receive"
        case .captureDeposit: motionName = "capture.deposit"
        case .drawReveal: motionName = "draw.reveal"
        case let .shareArrival(freshItemIDs):
            motionName = freshItemIDs.count <= 3 ? "react.notice.single" : "react.notice.aggregate"
        case .currentAttach: motionName = "current.attach"
        case .paperReturn: motionName = "paper.return"
        case .memoryStamp: motionName = "memory.stamp"
        case .failureSettle, .fallbackSettle: motionName = nil
        }
        guard let motionName else { return }
        lastMotionName = motionName
    }

    func applyRibbon(progress: Double, latched: Bool) {
        guard let sample = interpolatedRibbonSample(progress: progress) else { return }
        // Rebase every sample from authored rest pose so prior proof motion cannot
        // leak into the ribbon safety assertion.
        for keyframe in sample.entities {
            apply(ribbonEntity: keyframe)
        }
    }

    private func interpolatedRibbonSample(progress: Double) -> CoreBoxRibbonSampleContract? {
        guard let first = inventory.ribbonSamples.first,
              let last = inventory.ribbonSamples.last else { return nil }
        let value = min(max(progress, first.progress), last.progress)
        if let exact = inventory.ribbonSamples.first(where: { abs($0.progress - value) <= 0.000_001 }) {
            return exact
        }
        guard let upperIndex = inventory.ribbonSamples.firstIndex(where: { $0.progress > value }), upperIndex > 0 else {
            return last
        }
        let lower = inventory.ribbonSamples[upperIndex - 1]
        let upper = inventory.ribbonSamples[upperIndex]
        let span = max(upper.progress - lower.progress, .ulpOfOne)
        let amount = (value - lower.progress) / span
        let entities = zip(lower.entities, upper.entities).map { left, right in
            CoreBoxRibbonSampleEntity(
                entity: left.entity,
                transform: CoreBoxTransformContract(
                    translation: interpolate(left.transform.translation, right.transform.translation, amount),
                    rotationDegrees: interpolate(left.transform.rotationDegrees, right.transform.rotationDegrees, amount),
                    scale: interpolate(left.transform.scale, right.transform.scale, amount)
                )
            )
        }
        return CoreBoxRibbonSampleContract(progress: value, entities: entities)
    }

    private func interpolate(_ left: [Double], _ right: [Double], _ amount: Double) -> [Double] {
        guard left.count == right.count else { return left }
        return zip(left, right).map { $0 + ($1 - $0) * amount }
    }

    func settle(reason: CoreBoxSettleReason) {
        for (name, transform) in restTransforms {
            entity(named: name)?.transform = transform
        }
    }

    /// Applies the report's selected terminal keyframe and verifies all transform axes.
    func playProofMotion(named name: String) async throws {
        guard let recipe = inventory.runtimeTransformRecipes.first(where: { $0.name == name }),
              let terminal = recipe.keyframes.max(by: { $0.timeMilliseconds < $1.timeMilliseconds })
        else {
            throw CoreBoxAssetValidationError.invalidInventory("Unknown proof recipe: \(name).")
        }
        lastMotionName = name
        apply(keyframe: terminal)
        // The report duration is the deterministic completion contract. RealityKit
        // exposes no animation callback for this SDK/asset combination.
        try await Task.sleep(nanoseconds: UInt64(recipe.durationMilliseconds) * 1_000_000)
        guard recipe.durationMilliseconds == terminal.timeMilliseconds,
              matches(entityNamed: terminal.entity, contract: terminal.transform)
        else {
            throw CoreBoxAssetValidationError.invalidInventory("Recipe terminal did not settle: \(name).")
        }
    }

    func ribbonSampleMatches(_ progress: Double) -> Bool {
        guard let sample = inventory.ribbonSamples.first(where: { abs($0.progress - progress) <= 0.000_001 }) else { return false }
        return sample.entities.allSatisfy { matches(entityNamed: $0.entity, contract: $0.transform) }
    }

    private func apply(keyframe: CoreBoxMotionKeyframe) {
        guard let entity = entity(named: keyframe.entity), let rest = restTransforms[keyframe.entity] else { return }
        entity.transform = transformed(rest, by: keyframe.transform)
    }

    private func apply(ribbonEntity: CoreBoxRibbonSampleEntity) {
        guard let entity = entity(named: ribbonEntity.entity), let rest = restTransforms[ribbonEntity.entity] else { return }
        entity.transform = transformed(rest, by: ribbonEntity.transform)
    }

    private func transformed(_ rest: Transform, by contract: CoreBoxTransformContract) -> Transform {
        guard contract.translation.count == 3, contract.scale.count == 3 else { return rest }
        var value = rest
        value.translation += SIMD3<Float>(Float(contract.translation[0]), Float(contract.translation[1]), Float(contract.translation[2]))
        value.rotation = coreBoxRotation(from: contract.rotationDegrees) * rest.rotation
        value.scale *= SIMD3<Float>(Float(contract.scale[0]), Float(contract.scale[1]), Float(contract.scale[2]))
        return value
    }

    private func matches(entityNamed name: String, contract: CoreBoxTransformContract) -> Bool {
        guard let entity = entity(named: name), let rest = restTransforms[name],
              contract.translation.count == 3, contract.scale.count == 3 else { return false }
        let expected = transformed(rest, by: contract)
        let translationMatch = simd_length(entity.transform.translation - expected.translation) <= 0.0005
        let scaleMatch = simd_length(entity.transform.scale - expected.scale) <= 0.001
        let rotationMatch = coreBoxRotationDegreesBetween(entity.transform.rotation, expected.rotation) <= 0.25
        let finite = [entity.transform.translation.x, entity.transform.translation.y, entity.transform.translation.z,
                      entity.transform.scale.x, entity.transform.scale.y, entity.transform.scale.z,
                      entity.transform.rotation.vector.x, entity.transform.rotation.vector.y,
                      entity.transform.rotation.vector.z, entity.transform.rotation.vector.w].allSatisfy(\.isFinite)
        return translationMatch && scaleMatch && rotationMatch && finite
    }

    private func entity(named name: String) -> Entity? {
        root.name == name ? root : root.findEntity(named: name)
    }
}

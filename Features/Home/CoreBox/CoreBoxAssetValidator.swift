import Foundation
import RealityKit
import simd

struct CoreBoxAssetValidator {
    @MainActor
    func validate(
        tier: CoreBoxRendererTier,
        root: Entity,
        descriptor: CoreBoxProofDescriptor,
        expectedPaperRestCount: Int
    ) throws -> CoreBoxValidatedInventory {
        guard tier != .swiftUI2D else { throw CoreBoxAssetValidationError.noAssetFor2D }
        try validateDescriptorContract(descriptor)
        // RealityKit can wrap the default USDZ prim in a package container.
        guard let sceneRoot = root.name == "BoxRoot" ? root : root.findEntity(named: "BoxRoot") else {
            throw CoreBoxAssetValidationError.invalidInventory("The USDZ must contain BoxRoot.")
        }

        let entities = allEntities(startingAt: sceneRoot)
        guard entities.allSatisfy({ isFinite($0.transform) }) else {
            throw CoreBoxAssetValidationError.invalidInventory("The USDZ contains a non-finite entity transform.")
        }
        let publicNames = Set(descriptor.requiredEntityNames)
        // USD camera/light prims may import as a public Xform plus a same-named
        // component leaf. Only the entity whose parent matches the audited public
        // parent participates in the public-name uniqueness contract.
        let publicEntities = entities.filter { entity in
            guard publicNames.contains(entity.name) else { return false }
            let actualParent = entity.name == "BoxRoot" ? "" : (entity.parent?.name ?? "")
            return descriptor.parentByEntity[entity.name] == actualParent
        }
        let grouped = Dictionary(grouping: publicEntities, by: \.name)
        let duplicateNames = grouped.filter { $0.value.count != 1 }.map(\.key).sorted()
        guard duplicateNames.isEmpty else {
            throw CoreBoxAssetValidationError.invalidInventory("Duplicate public entities: \(duplicateNames.joined(separator: ", ")).")
        }
        guard Set(grouped.keys) == publicNames else {
            let missing = publicNames.subtracting(grouped.keys).sorted()
            throw CoreBoxAssetValidationError.invalidInventory("Missing entities: \(missing.joined(separator: ", ")).")
        }

        for (name, expectedParent) in descriptor.parentByEntity {
            guard let entity = grouped[name]?.first else { continue }
            let actualParent = name == "BoxRoot" ? "" : (entity.parent?.name ?? "")
            guard actualParent == expectedParent else {
                throw CoreBoxAssetValidationError.invalidInventory(
                    "Parent mismatch for \(name): \(actualParent), expected \(expectedParent)."
                )
            }
            guard isFinite(entity.transform) else {
                throw CoreBoxAssetValidationError.invalidInventory("Non-finite transform for \(name).")
            }
        }
        guard matches(sceneRoot.transform, descriptor.rootRestTransform) else {
            throw CoreBoxAssetValidationError.invalidInventory("BoxRoot must start at its identity rest transform.")
        }

        let expectedPaperNames = Set((0 ..< expectedPaperRestCount).map { String(format: "PaperRest_%02d", $0) })
        let actualPaperNames = Set(entities.filter { $0.name.hasPrefix("PaperRest_") }.map(\.name))
        guard actualPaperNames == expectedPaperNames,
              expectedPaperRestCount == tier.maximumVisiblePapers
        else {
            throw CoreBoxAssetValidationError.invalidInventory("PaperRest inventory does not match the selected tier.")
        }
        // Full-only papers must never leak into Lite, and Full must contain each one.
        let fullOnlyNames = Set((10 ..< 24).map { String(format: "PaperRest_%02d", $0) })
        if tier == .lite3D, !actualPaperNames.intersection(fullOnlyNames).isEmpty {
            throw CoreBoxAssetValidationError.invalidInventory("Lite asset contains Full-only PaperRest entities.")
        }

        guard hasContactShadow(sceneRoot) else {
            throw CoreBoxAssetValidationError.invalidInventory("Missing contact-shadow mesh or material binding.")
        }
        let animationNames = Set(entities.flatMap { $0.availableAnimations.compactMap(\.name) })
        let expectedMotions = Set(descriptor.clips)
        if descriptor.animationEncoding == .usdNamedResourcesV1, animationNames != expectedMotions {
            throw CoreBoxAssetValidationError.invalidInventory(
                "RealityKit exposed motions \(animationNames.sorted()), expected \(expectedMotions.sorted())."
            )
        }

        return CoreBoxValidatedInventory(
            animationEncoding: descriptor.animationEncoding,
            parentByEntity: descriptor.parentByEntity,
            publicMotionNames: descriptor.clips.sorted(),
            realityKitAnimationNames: animationNames.sorted(),
            runtimeRecipeNames: descriptor.animationEncoding == .runtimeTransformRecipesV1 ? expectedMotions.sorted() : [],
            paperRestCount: expectedPaperRestCount,
            ribbonSampleProgress: descriptor.ribbonSampleProgress,
            ribbonSamples: descriptor.ribbonSamples,
            rootRestTransform: descriptor.rootRestTransform,
            runtimeTransformRecipes: descriptor.runtimeTransformRecipes
        )
    }

    @MainActor
    private func hasContactShadow(_ root: Entity) -> Bool {
        guard let receiver = root.findEntity(named: "ShadowReceiver") else { return false }
        return allEntities(startingAt: receiver).contains { entity in
            guard let modelEntity = entity as? ModelEntity else { return false }
            return !(modelEntity.model?.materials.isEmpty ?? true)
        }
    }

    @MainActor
    private func allEntities(startingAt root: Entity) -> [Entity] {
        var result = [root]
        var index = 0
        while index < result.count {
            result.append(contentsOf: result[index].children)
            index += 1
        }
        return result
    }

    private func matches(_ transform: Transform, _ contract: CoreBoxTransformContract) -> Bool {
        guard contract.translation.count == 3, contract.rotationDegrees.count == 3, contract.scale.count == 3 else { return false }
        let translation = SIMD3<Float>(Float(contract.translation[0]), Float(contract.translation[1]), Float(contract.translation[2]))
        let scale = SIMD3<Float>(Float(contract.scale[0]), Float(contract.scale[1]), Float(contract.scale[2]))
        let rotation = coreBoxRotation(from: contract.rotationDegrees)
        return simd_length(transform.translation - translation) <= 0.0005
            && simd_length(transform.scale - scale) <= 0.001
            && coreBoxRotationDegreesBetween(transform.rotation, rotation) <= 0.25
    }

    private func isFinite(_ transform: Transform) -> Bool {
        let values = [transform.translation.x, transform.translation.y, transform.translation.z,
                      transform.scale.x, transform.scale.y, transform.scale.z,
                      transform.rotation.vector.x, transform.rotation.vector.y,
                      transform.rotation.vector.z, transform.rotation.vector.w]
        return values.allSatisfy(\.isFinite)
    }

    private func validateDescriptorContract(_ descriptor: CoreBoxProofDescriptor) throws {
        let proofNames = ["idle.listen", "capture.deposit", "draw.reveal"]
        let productionNames = [
            "idle.blink", "idle.listen", "idle.paperRustle", "idle.currentGlance",
            "react.touch", "react.notice.single", "react.notice.aggregate",
            "capture.receive", "capture.deposit", "draw.reveal", "current.attach",
            "paper.return", "memory.stamp",
        ]
        guard descriptor.clips == proofNames || descriptor.clips == productionNames,
              Set(descriptor.clips).count == descriptor.clips.count,
              descriptor.parentByEntity.keys.count == descriptor.requiredEntityNames.count,
              Set(descriptor.parentByEntity.keys) == Set(descriptor.requiredEntityNames),
              descriptor.ribbonSampleProgress == [0, 0.72, 1],
              descriptor.ribbonSamples.map(\.progress) == descriptor.ribbonSampleProgress
        else {
            throw CoreBoxAssetValidationError.invalidInventory("The proof descriptor has an incomplete structural contract.")
        }

        guard descriptor.parentByEntity["BoxRoot"] == "",
              descriptor.parentByEntity["RibbonRoot"] == "BoxRoot",
              descriptor.parentByEntity["RibbonJoint_01"] == "RibbonRoot",
              descriptor.parentByEntity["RibbonTip"] == "RibbonJoint_05",
              matchesIdentity(descriptor.rootRestTransform)
        else {
            throw CoreBoxAssetValidationError.invalidInventory("The proof root or ribbon parent contract is invalid.")
        }

        let expectedRecipes: [String: (entity: String, duration: Int)] = [
            "idle.listen": ("BoxRoot", 1_000),
            "capture.deposit": ("LidPivot", 560),
            "draw.reveal": ("PaperReveal", 750),
        ]
        if descriptor.clips == proofNames {
            guard descriptor.runtimeTransformRecipes.count == expectedRecipes.count else {
                throw CoreBoxAssetValidationError.invalidInventory("The proof runtime recipe count is invalid.")
            }
            for recipe in descriptor.runtimeTransformRecipes {
                guard let expected = expectedRecipes[recipe.name],
                      !recipe.keyframes.isEmpty,
                      recipe.durationMilliseconds == expected.duration,
                      recipe.keyframes.first?.timeMilliseconds == 0,
                      recipe.keyframes.last?.timeMilliseconds == recipe.durationMilliseconds,
                      recipe.keyframes.allSatisfy({ $0.entity == expected.entity && isValid($0.transform) }),
                      recipe.keyframes.map(\.timeMilliseconds) == recipe.keyframes.map(\.timeMilliseconds).sorted(),
                      Set(recipe.keyframes.map(\.timeMilliseconds)).count == recipe.keyframes.count
                else {
                    throw CoreBoxAssetValidationError.invalidInventory("The proof runtime recipe is invalid.")
                }
            }
            guard Set(descriptor.runtimeTransformRecipes.map(\.name)) == Set(expectedRecipes.keys) else {
                throw CoreBoxAssetValidationError.invalidInventory("The proof runtime recipe names are invalid.")
            }
        } else if descriptor.animationEncoding == .runtimeTransformRecipesV1 {
            guard descriptor.runtimeTransformRecipes.count == descriptor.clips.count else {
                throw CoreBoxAssetValidationError.invalidInventory("The production runtime recipe count is invalid.")
            }
            for recipe in descriptor.runtimeTransformRecipes {
                guard descriptor.clips.contains(recipe.name),
                      !recipe.keyframes.isEmpty,
                      recipe.durationMilliseconds > 0,
                      recipe.keyframes.first?.timeMilliseconds == 0,
                      recipe.keyframes.last?.timeMilliseconds == recipe.durationMilliseconds,
                      recipe.keyframes.allSatisfy({ descriptor.requiredEntityNames.contains($0.entity) && isValid($0.transform) }),
                      recipe.keyframes.map(\.timeMilliseconds) == recipe.keyframes.map(\.timeMilliseconds).sorted(),
                      Set(recipe.keyframes.map(\.timeMilliseconds)).count == recipe.keyframes.count
                else {
                    throw CoreBoxAssetValidationError.invalidInventory("The production runtime recipe is invalid.")
                }
            }
            guard Set(descriptor.runtimeTransformRecipes.map(\.name)) == Set(descriptor.clips) else {
                throw CoreBoxAssetValidationError.invalidInventory("The production runtime recipe names are invalid.")
            }
        } else {
            guard descriptor.runtimeTransformRecipes.isEmpty else {
                throw CoreBoxAssetValidationError.invalidInventory("Named-resource production assets cannot embed runtime recipes.")
            }
        }

        let ribbonNames = [
            "BoxRoot", "RibbonRoot", "RibbonJoint_01", "RibbonJoint_02", "RibbonJoint_03",
            "RibbonJoint_04", "RibbonJoint_05", "RibbonTip",
        ]
        guard descriptor.ribbonSamples.count == descriptor.ribbonSampleProgress.count,
              descriptor.ribbonSamples.allSatisfy({
                  $0.entities.map(\.entity) == ribbonNames
                      && $0.entities.allSatisfy({ isValid($0.transform) })
              })
        else {
            throw CoreBoxAssetValidationError.invalidInventory("The proof ribbon sample contract is invalid.")
        }
    }

    private func matchesIdentity(_ contract: CoreBoxTransformContract) -> Bool {
        contract.translation == [0, 0, 0]
            && contract.rotationDegrees == [0, 0, 0]
            && contract.scale == [1, 1, 1]
    }

    private func isValid(_ contract: CoreBoxTransformContract) -> Bool {
        guard contract.translation.count == 3,
              contract.rotationDegrees.count == 3,
              contract.scale.count == 3
        else { return false }
        return (contract.translation + contract.rotationDegrees + contract.scale).allSatisfy(\.isFinite)
    }
}

func coreBoxRotation(from degrees: [Double]) -> simd_quatf {
    guard degrees.count == 3 else { return simd_quatf() }
    let radians = degrees.map { Float($0 * .pi / 180) }
    return simd_quatf(angle: radians[2], axis: [0, 0, 1])
        * simd_quatf(angle: radians[1], axis: [0, 1, 0])
        * simd_quatf(angle: radians[0], axis: [1, 0, 0])
}

func coreBoxRotationDegreesBetween(_ lhs: simd_quatf, _ rhs: simd_quatf) -> Float {
    let dot = min(1, max(-1, abs(simd_dot(lhs.vector, rhs.vector))))
    return 2 * acos(dot) * 180 / .pi
}

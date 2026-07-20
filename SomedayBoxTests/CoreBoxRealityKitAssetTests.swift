import Foundation
import Testing
@testable import SomedayBox

@MainActor
@Suite("RealityKit Core Box proof")
struct CoreBoxRealityKitAssetTests {
    @Test(arguments: [CoreBoxRendererTier.full3D, .lite3D])
    func loadsProofTierWithNamedMotions(_ tier: CoreBoxRendererTier) async throws {
        let bundle = Bundle(for: CoreBoxProofBundleToken.self)
        let loaded = try await CoreBoxAssetLoader(source: CoreBoxProofAssetSource.source(bundle: bundle)).load(tier: tier)

        #expect(Set(loaded.validatedInventory.publicMotionNames) == CoreBoxProofAssetSource.publicMotionNames)
        #expect(loaded.validatedInventory.animationEncoding == .runtimeTransformRecipesV1)
        #expect(loaded.validatedInventory.realityKitAnimationNames.isEmpty)
        #expect(Set(loaded.validatedInventory.runtimeRecipeNames) == CoreBoxProofAssetSource.publicMotionNames)
        #expect(loaded.validatedInventory.paperRestCount == tier.maximumVisiblePapers)
        #expect(loaded.validatedInventory.ribbonSampleProgress == [0, 0.72, 1])
        #expect(loaded.validatedInventory.parentByEntity["BoxRoot"] == "")
        #expect(loaded.validatedInventory.parentByEntity["RibbonTip"] == "RibbonJoint_05")
        #expect(loaded.validatedInventory.runtimeTransformRecipes.map(\.name) == ["idle.listen", "capture.deposit", "draw.reveal"])
        #expect(loaded.validatedInventory.runtimeTransformRecipes.map(\.durationMilliseconds) == [1_000, 560, 750])
        #expect(loaded.validatedInventory.ribbonSamples.map { $0.entities.count } == [8, 8, 8])
        #expect(loaded.validatedInventory.rootRestTransform.translation == [0, 0, 0])
    }

    @Test func structuralFailureRejectsTheEntire3DAssetBeforePresentation() async throws {
        let bundle = Bundle(for: CoreBoxProofBundleToken.self)
        let base = CoreBoxProofAssetSource.source(bundle: bundle)
        let source = CoreBoxAssetSource(
            descriptorData: base.descriptorData,
            assetData: base.assetData,
            assetURL: base.assetURL,
            loadEntity: { url in
                let root = try await base.loadEntity(url)
                root.findEntity(named: "LidPivot")?.removeFromParent()
                return root
            },
            identity: base.identity,
            requiredEntityNames: base.requiredEntityNames,
            publicMotionNames: base.publicMotionNames,
            animationEncoding: base.animationEncoding
        )

        do {
            _ = try await CoreBoxAssetLoader(source: source).load(tier: .full3D)
            Issue.record("A missing required entity must reject the complete 3D asset.")
        } catch let error as CoreBoxAssetValidationError {
            guard case .invalidInventory = error else {
                Issue.record("Expected structural validation failure, got \(error).")
                return
            }
        }
    }

}

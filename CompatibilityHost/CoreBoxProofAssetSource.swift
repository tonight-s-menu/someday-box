import Foundation
import RealityKit

enum CoreBoxCompatibilityProofSource {
    static func source(
        forceStructuralFailure: Bool = false,
        bundle: Bundle = .main
    ) -> CoreBoxAssetSource {
        let source = CoreBoxAssetSource(
            descriptorData: { try Data(contentsOf: try resourceURL("CoreBoxProofReport", "json", bundle)) },
            assetData: { tier in try Data(contentsOf: try assetURL(tier, bundle)) },
            assetURL: { tier in try assetURL(tier, bundle) },
            loadEntity: { url in try await Entity(contentsOf: url) },
            identity: .init(
                descriptorSHA256: CoreBoxProofIdentity.reportSHA256,
                fullTierSHA256: CoreBoxProofIdentity.fullTierSHA256,
                liteTierSHA256: CoreBoxProofIdentity.liteTierSHA256
            ),
            requiredEntityNames: CoreBoxProofContract.requiredEntityNames,
            publicMotionNames: CoreBoxProofContract.publicMotionNames,
            animationEncoding: .runtimeTransformRecipesV1
        )

        guard forceStructuralFailure else { return source }
        return CoreBoxAssetSource(
            descriptorData: source.descriptorData,
            assetData: source.assetData,
            assetURL: source.assetURL,
            loadEntity: { url in
                let root = try await source.loadEntity(url)
                // This test-only switch proves the host rejects a structurally invalid USDZ.
                root.findEntity(named: "LidPivot")?.removeFromParent()
                return root
            },
            identity: source.identity,
            requiredEntityNames: source.requiredEntityNames,
            publicMotionNames: source.publicMotionNames,
            animationEncoding: source.animationEncoding
        )
    }

    private static func assetURL(_ tier: CoreBoxRendererTier, _ bundle: Bundle) throws -> URL {
        switch tier {
        case .full3D: return try resourceURL("CoreBoxProofFull", "usdz", bundle)
        case .lite3D: return try resourceURL("CoreBoxProofLite", "usdz", bundle)
        case .swiftUI2D: throw CoreBoxAssetValidationError.noAssetFor2D
        }
    }

    private static func resourceURL(_ name: String, _ ext: String, _ bundle: Bundle) throws -> URL {
        guard let url = bundle.url(forResource: name, withExtension: ext) else { throw CocoaError(.fileNoSuchFile) }
        return url
    }
}

enum CoreBoxProofContract {
    static let publicMotionNames: Set<String> = ["idle.listen", "capture.deposit", "draw.reveal"]
    static let requiredEntityNames: Set<String> = [
        "BoxRoot", "BoxBody", "LidPivot", "LidMesh", "EyeLeftPivot", "EyeLeftMesh",
        "EyeRightPivot", "EyeRightMesh", "RibbonRoot", "RibbonJoint_01", "RibbonJoint_02",
        "RibbonJoint_03", "RibbonJoint_04", "RibbonJoint_05", "RibbonTip", "PaperPool", "PaperSpawn",
        "PaperExit", "PaperDeposit", "PaperReveal", "CurrentPaperAnchor", "MemorySeam", "DecorationRoot",
        "ShadowReceiver", "Hit_Lid", "Hit_Ribbon", "Hit_Box", "Hit_MemorySeam", "Camera_Default",
        "Camera_Peek", "Camera_Overview", "Light_Key", "Light_Fill"
    ]
}

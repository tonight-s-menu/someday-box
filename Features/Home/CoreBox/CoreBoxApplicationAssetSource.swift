import CryptoKit
import Foundation
import RealityKit

/// Builds the production-bundle source without bypassing the validated loader.
/// Missing production bytes are an explicit load failure and therefore select the
/// functional SwiftUI fallback instead of recreating an unchecked scene.
enum CoreBoxApplicationAssetSource {
    static func make(bundle: Bundle = .main) -> CoreBoxAssetSource {
        let descriptorURL = bundle.url(forResource: "CoreBoxAssetManifest", withExtension: "json")
        let fullURL = bundle.url(forResource: "CoreBoxCharacterFull", withExtension: "usdz")
        let liteURL = bundle.url(forResource: "CoreBoxCharacterLite", withExtension: "usdz")
        let metadata = descriptorURL.flatMap { try? Data(contentsOf: $0) }.flatMap(parseMetadata)

        return CoreBoxAssetSource(
            descriptorData: {
                guard let descriptorURL else { throw CoreBoxApplicationAssetError.missingDescriptor }
                return try Data(contentsOf: descriptorURL)
            },
            assetData: { tier in
                guard let url = tier == .full3D ? fullURL : liteURL else {
                    throw CoreBoxApplicationAssetError.missingTier(tier)
                }
                return try Data(contentsOf: url)
            },
            assetURL: { tier in
                guard let url = tier == .full3D ? fullURL : liteURL else {
                    throw CoreBoxApplicationAssetError.missingTier(tier)
                }
                return url
            },
            loadEntity: { url in try await Entity(contentsOf: url) },
            identity: CoreBoxExpectedAssetIdentity(
                descriptorSHA256: metadata?.descriptorSHA256 ?? "",
                fullTierSHA256: metadata?.fullTierSHA256 ?? "",
                liteTierSHA256: metadata?.liteTierSHA256 ?? ""
            ),
            requiredEntityNames: metadata?.requiredEntityNames ?? [],
            publicMotionNames: metadata?.publicMotionNames ?? [],
            animationEncoding: metadata?.animationEncoding ?? .runtimeTransformRecipesV1
        )
    }

    private static func parseMetadata(_ data: Data) -> Metadata? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let required = object["requiredEntityNames"] as? [String] ?? object["requiredEntities"] as? [String] ?? []
        let clips: [String]
        if let names = object["clips"] as? [String] {
            clips = names
        } else if let entries = object["clips"] as? [[String: Any]] {
            clips = entries.compactMap { $0["name"] as? String }
        } else {
            clips = []
        }
        let encoding = (object["animationEncoding"] as? String).flatMap(CoreBoxAnimationEncoding.init(rawValue:))
        let tiers = object["tiers"] as? [String: [String: Any]]
        let full = tiers?["full"]?["sha256"] as? String ?? object["fullTierSHA256"] as? String
        let lite = tiers?["lite"]?["sha256"] as? String ?? object["liteTierSHA256"] as? String
        let descriptor = object["descriptorSHA256"] as? String
            ?? object["manifestSHA256"] as? String
            ?? SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return Metadata(
            descriptorSHA256: descriptor,
            fullTierSHA256: full ?? "",
            liteTierSHA256: lite ?? "",
            requiredEntityNames: Set(required),
            publicMotionNames: Set(clips),
            animationEncoding: encoding ?? .runtimeTransformRecipesV1
        )
    }

    private struct Metadata {
        let descriptorSHA256: String
        let fullTierSHA256: String
        let liteTierSHA256: String
        let requiredEntityNames: Set<String>
        let publicMotionNames: Set<String>
        let animationEncoding: CoreBoxAnimationEncoding
    }
}

private enum CoreBoxApplicationAssetError: Error {
    case missingDescriptor
    case missingTier(CoreBoxRendererTier)
}

extension CoreBoxAssetLoader {
    static var application: Self { Self(source: CoreBoxApplicationAssetSource.make()) }
    /// Production and application share one validated source contract. Until the
    /// sealed Full/Lite package is present, this loader fails closed to SwiftUI 2D.
    static var production: Self { application }
}

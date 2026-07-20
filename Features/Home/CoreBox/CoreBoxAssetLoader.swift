import CryptoKit
import Foundation
import RealityKit

enum CoreBoxAnimationEncoding: String, Decodable, Equatable, Sendable {
    case usdNamedResourcesV1
    case runtimeTransformRecipesV1
}

/// A relative transform captured in the digest-protected proof report.
struct CoreBoxTransformContract: Decodable, Equatable, Sendable {
    let translation: [Double]
    let rotationDegrees: [Double]
    let scale: [Double]
}

struct CoreBoxMotionKeyframe: Decodable, Equatable, Sendable {
    let entity: String
    let timeMilliseconds: Int
    let transform: CoreBoxTransformContract
}

struct CoreBoxRibbonSampleEntity: Decodable, Equatable, Sendable {
    let entity: String
    let transform: CoreBoxTransformContract
}

struct CoreBoxRuntimeMotionContract: Decodable, Equatable, Sendable {
    let name: String
    let durationMilliseconds: Int
    let keyframes: [CoreBoxMotionKeyframe]
}

struct CoreBoxRibbonSampleContract: Decodable, Equatable, Sendable {
    let progress: Double
    let entities: [CoreBoxRibbonSampleEntity]
}

struct CoreBoxExpectedAssetIdentity: Sendable {
    let descriptorSHA256: String
    let fullTierSHA256: String
    let liteTierSHA256: String

    func digest(for tier: CoreBoxRendererTier) throws -> String {
        switch tier {
        case .full3D: fullTierSHA256
        case .lite3D: liteTierSHA256
        case .swiftUI2D: throw CoreBoxAssetValidationError.noAssetFor2D
        }
    }
}

struct CoreBoxAssetSource: Sendable {
    let descriptorData: @Sendable () throws -> Data
    let assetData: @Sendable (CoreBoxRendererTier) throws -> Data
    let assetURL: @Sendable (CoreBoxRendererTier) throws -> URL
    let loadEntity: @MainActor @Sendable (URL) async throws -> Entity
    let identity: CoreBoxExpectedAssetIdentity
    let requiredEntityNames: Set<String>
    let publicMotionNames: Set<String>
    let animationEncoding: CoreBoxAnimationEncoding
}

enum CoreBoxAssetValidationError: Error, Equatable {
    case noAssetFor2D
    case digestMismatch(expected: String, actual: String)
    case descriptorDecodeFailed(String)
    case invalidInventory(String)
}

struct CoreBoxProofTierDescriptor: Decodable, Sendable {
    let byteCount: Int
    let paperRestCount: Int
    let sha256: String
}

struct CoreBoxProofDescriptor: Decodable, Sendable {
    let animationEncoding: CoreBoxAnimationEncoding
    let clips: [String]
    let parentByEntity: [String: String]
    let profile: String
    let requiredEntityNames: [String]
    let ribbonSampleProgress: [Double]
    let ribbonSamples: [CoreBoxRibbonSampleContract]
    let rootRestTransform: CoreBoxTransformContract
    let runtimeTransformRecipes: [CoreBoxRuntimeMotionContract]
    let tiers: [String: CoreBoxProofTierDescriptor]
}

struct CoreBoxValidatedInventory: Equatable, Sendable {
    let animationEncoding: CoreBoxAnimationEncoding
    let parentByEntity: [String: String]
    let publicMotionNames: [String]
    let realityKitAnimationNames: [String]
    let runtimeRecipeNames: [String]
    let paperRestCount: Int
    let ribbonSampleProgress: [Double]
    let ribbonSamples: [CoreBoxRibbonSampleContract]
    let rootRestTransform: CoreBoxTransformContract
    let runtimeTransformRecipes: [CoreBoxRuntimeMotionContract]
}

/// The marker is intentionally impossible to construct outside this file.
private struct CoreBoxValidationAttestation: Sendable {}

struct CoreBoxLoadedAsset {
    let tier: CoreBoxRendererTier
    let root: Entity
    let validatedInventory: CoreBoxValidatedInventory
    private let attestation: CoreBoxValidationAttestation

    private init(
        tier: CoreBoxRendererTier,
        root: Entity,
        validatedInventory: CoreBoxValidatedInventory,
        attestation: CoreBoxValidationAttestation
    ) {
        self.tier = tier
        self.root = root
        self.validatedInventory = validatedInventory
        self.attestation = attestation
    }

    static func validated(
        tier: CoreBoxRendererTier,
        root: Entity,
        inventory: CoreBoxValidatedInventory
    ) -> CoreBoxLoadedAsset {
        CoreBoxLoadedAsset(tier: tier, root: root, validatedInventory: inventory, attestation: .init())
    }
}

struct CoreBoxAssetLoader: Sendable {
    let source: CoreBoxAssetSource

    @MainActor
    func load(tier: CoreBoxRendererTier) async throws -> CoreBoxLoadedAsset {
        let descriptorData = try source.descriptorData()
        try Self.validateDigest(descriptorData, expected: source.identity.descriptorSHA256)
        let descriptor: CoreBoxProofDescriptor
        do {
            descriptor = try JSONDecoder().decode(CoreBoxProofDescriptor.self, from: descriptorData)
        } catch {
            throw CoreBoxAssetValidationError.descriptorDecodeFailed(String(describing: error))
        }
        try Self.validate(descriptor: descriptor, source: source, tier: tier)

        let assetData = try source.assetData(tier)
        let expectedDigest = try source.identity.digest(for: tier)
        try Self.validateDigest(assetData, expected: expectedDigest)
        guard let expectedTier = descriptor.tiers[Self.descriptorTierName(for: tier)],
              expectedTier.sha256 == expectedDigest,
              expectedTier.byteCount == assetData.count
        else {
            throw CoreBoxAssetValidationError.invalidInventory("Tier descriptor does not match the exact asset bytes.")
        }

        let root = try await source.loadEntity(source.assetURL(tier))
        let inventory = try CoreBoxAssetValidator().validate(
            tier: tier,
            root: root,
            descriptor: descriptor,
            expectedPaperRestCount: expectedTier.paperRestCount
        )
        return .validated(tier: tier, root: root, inventory: inventory)
    }

    private static func validateDigest(_ data: Data, expected: String) throws {
        let actual = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard actual == expected else {
            throw CoreBoxAssetValidationError.digestMismatch(expected: expected, actual: actual)
        }
    }

    private static func validate(
        descriptor: CoreBoxProofDescriptor,
        source: CoreBoxAssetSource,
        tier: CoreBoxRendererTier
    ) throws {
        let recipeNames = Set(descriptor.runtimeTransformRecipes.map(\.name))
        guard descriptor.profile == "pipeline-spike-v1",
              descriptor.animationEncoding == source.animationEncoding,
              Set(descriptor.clips) == source.publicMotionNames,
              Set(descriptor.requiredEntityNames) == source.requiredEntityNames,
              Set(descriptor.parentByEntity.keys) == source.requiredEntityNames,
              descriptor.ribbonSampleProgress == [0, 0.72, 1],
              descriptor.ribbonSamples.map(\.progress) == descriptor.ribbonSampleProgress,
              recipeNames == source.publicMotionNames,
              descriptor.tiers[descriptorTierName(for: tier)] != nil
        else {
            throw CoreBoxAssetValidationError.invalidInventory("Proof descriptor contract does not match the loader source.")
        }
    }

    private static func descriptorTierName(for tier: CoreBoxRendererTier) -> String {
        switch tier {
        case .full3D: "full"
        case .lite3D: "lite"
        case .swiftUI2D: "2d"
        }
    }
}

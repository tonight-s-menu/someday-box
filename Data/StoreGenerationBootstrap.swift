import CryptoKit
import Foundation
import SwiftData

public struct ActiveStoreGeneration: Equatable, Sendable {
    public let id: UUID
    public let schemaVersion: StoreSchemaVersion

    public init(id: UUID, schemaVersion: StoreSchemaVersion) {
        self.id = id
        self.schemaVersion = schemaVersion
    }
}

public struct StoreSchemaVersion: Codable, Equatable, Sendable {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public init(_ version: Schema.Version) {
        self.init(major: version.major, minor: version.minor, patch: version.patch)
    }
}

public enum StoreGenerationBootstrapError: Error, Equatable, Sendable {
    case unsupportedManifestVersion(Int)
    case invalidManifestChecksum
    case unsupportedSchemaVersion(major: Int, minor: Int, patch: Int)
}

public struct StoreGenerationBootstrap {
    public static let manifestFileName = "active-generation.json"

    private let configuration: StoreGenerationConfiguration

    public init(configuration: StoreGenerationConfiguration) {
        self.configuration = configuration
    }

    public func openOrCreateContainer() throws -> (generation: ActiveStoreGeneration, container: ModelContainer) {
        let fileManager = FileManager.default
        let generation = try loadOrCreateActiveGeneration()
        try fileManager.createDirectory(
            at: configuration.generationURL(id: generation.id),
            withIntermediateDirectories: true
        )
        let container = try ModelContainer(
            for: Schema(versionedSchema: SomedayBoxSchemaV1.self),
            migrationPlan: SomedayBoxSchemaMigrationPlan.self,
            configurations: [configuration.modelConfiguration(generationID: generation.id)]
        )
        return (generation, container)
    }

    public func loadOrCreateActiveGeneration() throws -> ActiveStoreGeneration {
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: configuration.applicationSupportURL,
            withIntermediateDirectories: true
        )
        let manifestURL = configuration.applicationSupportURL.appendingPathComponent(Self.manifestFileName)
        if fileManager.fileExists(atPath: manifestURL.path) {
            return try readManifest(at: manifestURL)
        }

        let generation = ActiveStoreGeneration(
            id: UUID(),
            schemaVersion: StoreSchemaVersion(SomedayBoxSchemaV1.versionIdentifier)
        )
        try fileManager.createDirectory(
            at: configuration.generationURL(id: generation.id),
            withIntermediateDirectories: true
        )
        try writeManifest(for: generation, to: manifestURL)
        return generation
    }

    public static func makeInMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(versionedSchema: SomedayBoxSchemaV1.self),
            migrationPlan: SomedayBoxSchemaMigrationPlan.self,
            configurations: [StoreGenerationConfiguration.inMemoryModelConfiguration()]
        )
    }

    private func readManifest(at url: URL) throws -> ActiveStoreGeneration {
        let envelope = try JSONDecoder().decode(ManifestEnvelope.self, from: Data(contentsOf: url))
        guard envelope.payload.formatVersion == 1 else {
            throw StoreGenerationBootstrapError.unsupportedManifestVersion(envelope.payload.formatVersion)
        }
        let payloadData = try Self.encode(envelope.payload)
        guard Self.sha256Hex(payloadData) == envelope.sha256 else {
            throw StoreGenerationBootstrapError.invalidManifestChecksum
        }
        let version = envelope.payload.schemaVersion
        guard version.major == SomedayBoxSchemaV1.versionIdentifier.major,
              version.minor == SomedayBoxSchemaV1.versionIdentifier.minor,
              version.patch == SomedayBoxSchemaV1.versionIdentifier.patch else {
            throw StoreGenerationBootstrapError.unsupportedSchemaVersion(
                major: version.major,
                minor: version.minor,
                patch: version.patch
            )
        }
        return ActiveStoreGeneration(
            id: envelope.payload.generationID,
            schemaVersion: version
        )
    }

    private func writeManifest(for generation: ActiveStoreGeneration, to url: URL) throws {
        let payload = ManifestPayload(
            formatVersion: 1,
            generationID: generation.id,
            schemaVersion: generation.schemaVersion
        )
        let payloadData = try Self.encode(payload)
        let envelope = ManifestEnvelope(payload: payload, sha256: Self.sha256Hex(payloadData))
        try Self.encode(envelope).write(to: url, options: [.atomic])
    }

    private static func encode<Value: Encodable>(_ value: Value) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }

    private static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

private struct ManifestEnvelope: Codable {
    let payload: ManifestPayload
    let sha256: String
}

private struct ManifestPayload: Codable {
    let formatVersion: Int
    let generationID: UUID
    let schemaVersion: StoreSchemaVersion
}

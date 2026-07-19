import CryptoKit
import Foundation

public enum StoreGenerationOperationKind: String, Codable, Equatable, Sendable {
    case migration
    case restore
    case erase
}

public enum StoreGenerationOperationPhase: String, Codable, Equatable, Sendable {
    case prepared
    case validated
    case switching
    case switched
    case committed
    case cleaning
    case finalized

    public var isCommitted: Bool {
        switch self {
        case .committed, .cleaning, .finalized: true
        default: false
        }
    }
}

public struct StoreGenerationOperationJournal: Codable, Equatable, Sendable {
    public let formatVersion: Int
    public let operationID: UUID
    public let kind: StoreGenerationOperationKind
    public let priorGeneration: ActiveStoreGeneration
    public let newGeneration: ActiveStoreGeneration
    public var phase: StoreGenerationOperationPhase
    public let expectedProductDigest: String
    public let rollbackCleanupGenerationIDs: [UUID]
    public let committedCleanupGenerationIDs: [UUID]

    public init(
        operationID: UUID,
        kind: StoreGenerationOperationKind,
        priorGeneration: ActiveStoreGeneration,
        newGeneration: ActiveStoreGeneration,
        phase: StoreGenerationOperationPhase,
        expectedProductDigest: String
    ) {
        formatVersion = 1
        self.operationID = operationID
        self.kind = kind
        self.priorGeneration = priorGeneration
        self.newGeneration = newGeneration
        self.phase = phase
        self.expectedProductDigest = expectedProductDigest
        rollbackCleanupGenerationIDs = [newGeneration.id]
        committedCleanupGenerationIDs = [priorGeneration.id]
    }
}

public enum StoreGenerationJournalError: Error, Equatable, Sendable {
    case unsupportedFormatVersion(Int)
    case invalidChecksum
}

public struct StoreGenerationJournalStore: Sendable {
    private let url: URL

    public init(configuration: StoreGenerationConfiguration) {
        url = configuration.operationJournalURL
    }

    public func load() throws -> StoreGenerationOperationJournal? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let envelope = try JSONDecoder().decode(JournalEnvelope.self, from: Data(contentsOf: url))
        guard envelope.payload.formatVersion == 1 else {
            throw StoreGenerationJournalError.unsupportedFormatVersion(envelope.payload.formatVersion)
        }
        let payloadData = try Self.encode(envelope.payload)
        guard Self.sha256Hex(payloadData) == envelope.sha256 else {
            throw StoreGenerationJournalError.invalidChecksum
        }
        return envelope.payload
    }

    public func write(_ journal: StoreGenerationOperationJournal) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let payloadData = try Self.encode(journal)
        let envelope = JournalEnvelope(payload: journal, sha256: Self.sha256Hex(payloadData))
        try Self.durableAtomicWrite(Self.encode(envelope), to: url)
    }

    public func remove() throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    private static func durableAtomicWrite(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: [.atomic])
        let handle = try FileHandle(forWritingTo: url)
        try handle.synchronize()
        try handle.close()
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

private struct JournalEnvelope: Codable {
    let payload: StoreGenerationOperationJournal
    let sha256: String
}

public struct SharedProductDataOperationJournal: Codable, Equatable, Sendable {
    public let formatVersion: Int
    public let operationID: UUID
    public let kind: StoreGenerationOperationKind
    public let targetProductGenerationID: UUID
    public let mailboxReplacement: ShareMailboxMaintenance.StagedReplacement

    public init(
        operationID: UUID,
        kind: StoreGenerationOperationKind,
        targetProductGenerationID: UUID,
        mailboxReplacement: ShareMailboxMaintenance.StagedReplacement
    ) {
        formatVersion = 1
        self.operationID = operationID
        self.kind = kind
        self.targetProductGenerationID = targetProductGenerationID
        self.mailboxReplacement = mailboxReplacement
    }
}

public struct SharedProductDataJournalStore: Sendable {
    private let url: URL

    public init(applicationSupportURL: URL) {
        url = applicationSupportURL.appendingPathComponent("shared-product-operation.json")
    }

    public func load() throws -> SharedProductDataOperationJournal? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let envelope = try JSONDecoder().decode(SharedJournalEnvelope.self, from: Data(contentsOf: url))
        guard envelope.payload.formatVersion == 1 else {
            throw StoreGenerationJournalError.unsupportedFormatVersion(envelope.payload.formatVersion)
        }
        guard Self.sha256Hex(try Self.encode(envelope.payload)) == envelope.sha256 else {
            throw StoreGenerationJournalError.invalidChecksum
        }
        return envelope.payload
    }

    public func write(_ journal: SharedProductDataOperationJournal) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let envelope = SharedJournalEnvelope(
            payload: journal,
            sha256: Self.sha256Hex(try Self.encode(journal))
        )
        try Self.durableAtomicWrite(Self.encode(envelope), to: url)
    }

    public func remove() throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    private static func durableAtomicWrite(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: [.atomic])
        let handle = try FileHandle(forWritingTo: url)
        try handle.synchronize()
        try handle.close()
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

private struct SharedJournalEnvelope: Codable {
    let payload: SharedProductDataOperationJournal
    let sha256: String
}

import CryptoKit
import Foundation

public struct BackupSessionV3: Codable, Equatable, Sendable {
    public let id: UUID
    public let startedAtMilliseconds: Int64
    public let endedAtMilliseconds: Int64?
    public let contextModeRaw: String
    public let maximumMinutes: Int?
    public let presentationPresetRaw: String?
    public let policyVersion: String
}

public struct BackupProductV3: Codable, Equatable, Sendable {
    public let exportedAtMilliseconds: Int64
    public let appMarketingVersion: String
    public let appBuild: String
    public let schemaVersion: BackupSchemaVersionV1
    public let selectionPolicyVersion: String
    public let items: [BackupItemV1]
    public let currentPick: BackupCurrentPickV1?
    public let sessions: [BackupSessionV3]
    public let attempts: [BackupAttemptV1]
    public let memories: [BackupMemoryV1]
}

public struct BackupDocumentV3: Codable, Equatable, Sendable {
    public static let formatVersion = 3
    public static let canonicalizationVersion = 1

    public let formatVersion: Int
    public let canonicalizationVersion: Int
    public let productV3CanonicalData: Data
    public let sources: [BackupSourceV2]
    public let pendingEnvelopes: [ShareCaptureEnvelopeV1]
    public let checksumSHA256: String

    fileprivate var checksumPayload: BackupChecksumPayloadV3 {
        .init(formatVersion: formatVersion, canonicalizationVersion: canonicalizationVersion, productV3CanonicalData: productV3CanonicalData, sources: sources, pendingEnvelopes: pendingEnvelopes)
    }
}

public struct BackupDocumentCodecV3: Sendable {
    public init() {}

    public func encode(
        state: PersistedProductState,
        pendingEnvelopes: [ShareCaptureEnvelopeV1],
        metadata: BackupDocumentMetadataV1
    ) throws -> Data {
        try PersistedStateValidator().validate(state)
        let product = BackupProductV3(
            exportedAtMilliseconds: try milliseconds(metadata.exportedAt),
            appMarketingVersion: metadata.appMarketingVersion,
            appBuild: metadata.appBuild,
            schemaVersion: metadata.schemaVersion,
            selectionPolicyVersion: metadata.selectionPolicyVersion,
            items: try state.items.map {
                .init(id: $0.id, title: $0.title, note: $0.note, durationBucketRaw: $0.durationBucketRaw, lifecycleRaw: $0.lifecycleRaw, createdAtMilliseconds: try milliseconds($0.createdAt), updatedAtMilliseconds: try milliseconds($0.updatedAt), completedAtMilliseconds: try $0.completedAt.map(milliseconds), lastShownAtMilliseconds: try $0.lastShownAt.map(milliseconds))
            }.sorted { uuidLess($0.id, $1.id) },
            currentPick: try state.currentPick.map { .init(itemID: $0.itemID, acceptedAtMilliseconds: try milliseconds($0.acceptedAt)) },
            sessions: try state.sessions.map {
                .init(id: $0.id, startedAtMilliseconds: try milliseconds($0.startedAt), endedAtMilliseconds: try $0.endedAt.map(milliseconds), contextModeRaw: $0.context.mode.rawValue, maximumMinutes: $0.context.maximumMinutes, presentationPresetRaw: $0.context.presentationPreset?.rawValue, policyVersion: $0.policyVersion)
            }.sorted { uuidLess($0.id, $1.id) },
            attempts: try state.attempts.map {
                .init(id: $0.id, sessionID: $0.sessionID, sequence: $0.sequence, itemID: $0.itemID, eligibleCount: $0.eligibleCount, policyVersion: $0.policyVersion, shownAtMilliseconds: try milliseconds($0.shownAt), outcomeRaw: $0.outcomeRaw, resolvedAtMilliseconds: try $0.resolvedAt.map(milliseconds))
            }.sorted { uuidLess($0.id, $1.id) },
            memories: try state.memories.map {
                .init(id: $0.id, sourceItemID: $0.sourceItemID, titleSnapshot: $0.titleSnapshot, noteSnapshot: $0.noteSnapshot, durationSnapshotRaw: $0.durationSnapshotRaw, completedAtMilliseconds: try milliseconds($0.completedAt))
            }.sorted { uuidLess($0.id, $1.id) }
        )
        let sources = try state.sources.map {
            BackupSourceV2(id: $0.id, itemID: $0.itemID, importEnvelopeID: $0.importEnvelopeID, acceptedURLString: $0.acceptedURLString, sourceKindRaw: $0.sourceKindRaw, capturedAtMilliseconds: try milliseconds($0.capturedAt))
        }.sorted { uuidLess($0.id, $1.id) }
        let envelopes = pendingEnvelopes.sorted { uuidLess($0.envelopeID, $1.envelopeID) }
        let payload = BackupChecksumPayloadV3(formatVersion: 3, canonicalizationVersion: 1, productV3CanonicalData: try canonicalEncode(product), sources: sources, pendingEnvelopes: envelopes)
        let document = BackupDocumentV3(formatVersion: 3, canonicalizationVersion: 1, productV3CanonicalData: payload.productV3CanonicalData, sources: sources, pendingEnvelopes: envelopes, checksumSHA256: sha256Hex(try canonicalEncode(payload)))
        let data = try canonicalEncode(document)
        guard data.count <= BackupFormatV2Limits.encodedByteCount else { throw BackupDocumentError.encodedByteLimitExceeded(limit: BackupFormatV2Limits.encodedByteCount, actual: data.count) }
        _ = try decode(data)
        return data
    }

    public func decode(_ data: Data) throws -> BackupRestorePayload {
        guard !data.isEmpty else { throw BackupDocumentError.emptyDocument }
        guard data.count <= BackupFormatV2Limits.encodedByteCount else { throw BackupDocumentError.encodedByteLimitExceeded(limit: BackupFormatV2Limits.encodedByteCount, actual: data.count) }
        let format: Int
        do { format = try JSONDecoder().decode(BackupV3FormatProbe.self, from: data).formatVersion }
        catch { throw BackupDocumentError.malformedDocument }
        if format == 1 || format == 2 { return try BackupDocumentCodecV2().decode(data) }
        guard format == 3 else { throw BackupDocumentError.unsupportedFormatVersion(format) }
        let document: BackupDocumentV3
        do { document = try JSONDecoder().decode(BackupDocumentV3.self, from: data) }
        catch { throw BackupDocumentError.malformedDocument }
        guard document.canonicalizationVersion == 1 else { throw BackupDocumentError.unsupportedCanonicalizationVersion(document.canonicalizationVersion) }
        guard try canonicalEncode(document) == data else { throw BackupDocumentError.nonCanonicalEncoding }
        guard document.checksumSHA256 == sha256Hex(try canonicalEncode(document.checksumPayload)) else { throw BackupDocumentError.invalidChecksum }
        guard document.sources.count <= BackupFormatV2Limits.sourceCount else { throw BackupDocumentError.countLimitExceeded(kind: .source, limit: BackupFormatV2Limits.sourceCount, actual: document.sources.count) }
        guard document.pendingEnvelopes.count <= BackupFormatV2Limits.envelopeCount else { throw BackupDocumentError.countLimitExceeded(kind: .envelope, limit: BackupFormatV2Limits.envelopeCount, actual: document.pendingEnvelopes.count) }
        let product: BackupProductV3
        do { product = try JSONDecoder().decode(BackupProductV3.self, from: document.productV3CanonicalData) }
        catch { throw BackupDocumentError.malformedDocument }
        guard try canonicalEncode(product) == document.productV3CanonicalData else { throw BackupDocumentError.nonCanonicalEncoding }
        try validateOrdering(product.items.map(\.id), kind: .item)
        try validateOrdering(product.sessions.map(\.id), kind: .session)
        try validateOrdering(product.attempts.map(\.id), kind: .attempt)
        try validateOrdering(product.memories.map(\.id), kind: .memory)
        try validateOrdering(document.sources.map(\.id), kind: .source)
        try validateOrdering(document.pendingEnvelopes.map(\.envelopeID), kind: .envelope)
        guard product.items.count <= BackupFormatV1Limits.itemCount else { throw BackupDocumentError.countLimitExceeded(kind: .item, limit: BackupFormatV1Limits.itemCount, actual: product.items.count) }
        guard product.sessions.count <= BackupFormatV1Limits.sessionCount else { throw BackupDocumentError.countLimitExceeded(kind: .session, limit: BackupFormatV1Limits.sessionCount, actual: product.sessions.count) }
        guard product.attempts.count <= BackupFormatV1Limits.attemptCount else { throw BackupDocumentError.countLimitExceeded(kind: .attempt, limit: BackupFormatV1Limits.attemptCount, actual: product.attempts.count) }
        guard product.memories.count <= BackupFormatV1Limits.memoryCount else { throw BackupDocumentError.countLimitExceeded(kind: .memory, limit: BackupFormatV1Limits.memoryCount, actual: product.memories.count) }
        let state = try makeState(product: product, sources: document.sources)
        do { try PersistedStateValidator().validate(state) }
        catch let issue as PersistedStateValidationIssue { throw BackupDocumentError.invalidPersistedState(issue) }
        for envelope in document.pendingEnvelopes { _ = try envelope.canonicalData() }
        return BackupRestorePayload(state: state, pendingEnvelopes: document.pendingEnvelopes)
    }

    private func makeState(product: BackupProductV3, sources: [BackupSourceV2]) throws -> PersistedProductState {
        let items = try product.items.map { value -> BoxItem in
            guard let lifecycle = PaperLifecycle(rawValue: value.lifecycleRaw) else { throw BackupDocumentError.unsupportedLifecycle(rawValue: value.lifecycleRaw) }
            return BoxItem(id: value.id, title: value.title, note: value.note, durationBucketRaw: value.durationBucketRaw, lifecycle: lifecycle, createdAt: date(value.createdAtMilliseconds), updatedAt: date(value.updatedAtMilliseconds), completedAt: value.completedAtMilliseconds.map(date), lastShownAt: value.lastShownAtMilliseconds.map(date))
        }
        let sessions = try product.sessions.map { value -> DrawSession in
            guard let mode = DrawContextMode(rawValue: value.contextModeRaw) else { throw BackupDocumentError.unsupportedAvailableTime(rawValue: value.contextModeRaw) }
            let context: DrawContext
            switch mode {
            case .preset:
                guard let raw = value.presentationPresetRaw, let preset = DrawPresentationPreset(rawValue: raw), preset.maximumMinutes == value.maximumMinutes else { throw BackupDocumentError.unsupportedAvailableTime(rawValue: value.contextModeRaw) }
                context = .init(preset: preset)
            case .custom:
                guard let minutes = value.maximumMinutes else { throw BackupDocumentError.unsupportedAvailableTime(rawValue: value.contextModeRaw) }
                context = .init(customMinutes: minutes)
            case .notSure: context = .notSure
            }
            guard context.isValid, context.maximumMinutes == value.maximumMinutes, context.presentationPreset?.rawValue == value.presentationPresetRaw else { throw BackupDocumentError.unsupportedAvailableTime(rawValue: value.contextModeRaw) }
            return DrawSession(id: value.id, startedAt: date(value.startedAtMilliseconds), endedAt: value.endedAtMilliseconds.map(date), context: context, policyVersion: value.policyVersion)
        }
        let attempts = try product.attempts.map { value -> DrawAttempt in
            guard DrawAttemptOutcome(rawValue: value.outcomeRaw) != nil else { throw BackupDocumentError.unsupportedAttemptOutcome(rawValue: value.outcomeRaw) }
            return DrawAttempt(id: value.id, sessionID: value.sessionID, sequence: value.sequence, itemID: value.itemID, eligibleCount: value.eligibleCount, policyVersion: value.policyVersion, shownAt: date(value.shownAtMilliseconds), outcomeRaw: value.outcomeRaw, resolvedAt: value.resolvedAtMilliseconds.map(date))
        }
        return PersistedProductState(
            items: items,
            currentPick: product.currentPick.map { CurrentPick(itemID: $0.itemID, acceptedAt: date($0.acceptedAtMilliseconds)) },
            sessions: sessions,
            attempts: attempts,
            memories: product.memories.map { CompletionMemory(id: $0.id, sourceItemID: $0.sourceItemID, titleSnapshot: $0.titleSnapshot, noteSnapshot: $0.noteSnapshot, durationSnapshotRaw: $0.durationSnapshotRaw, completedAt: date($0.completedAtMilliseconds)) },
            sources: sources.map { SourceReference(id: $0.id, itemID: $0.itemID, importEnvelopeID: $0.importEnvelopeID, acceptedURLString: $0.acceptedURLString, sourceKindRaw: $0.sourceKindRaw, capturedAt: date($0.capturedAtMilliseconds)) }
        )
    }

    private func validateOrdering(_ ids: [UUID], kind: BackupRecordKind) throws {
        guard zip(ids, ids.dropFirst()).allSatisfy({ uuidLess($0, $1) }) else { throw BackupDocumentError.recordsNotInCanonicalOrder(kind: kind) }
    }
    private func milliseconds(_ date: Date) throws -> Int64 {
        let value = date.timeIntervalSince1970 * 1_000
        guard value.isFinite, value >= Double(Int64.min), value < Double(Int64.max) else { throw BackupDocumentError.invalidTimestamp }
        return Int64(value.rounded(.toNearestOrAwayFromZero))
    }
    private func date(_ value: Int64) -> Date { Date(timeIntervalSince1970: Double(value) / 1_000) }
    private func canonicalEncode<T: Encodable>(_ value: T) throws -> Data { let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]; return try encoder.encode(value) }
    private func sha256Hex(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    private func uuidLess(_ lhs: UUID, _ rhs: UUID) -> Bool { withUnsafeBytes(of: lhs.uuid) { left in withUnsafeBytes(of: rhs.uuid) { left.lexicographicallyPrecedes($0) } } }
}

private struct BackupV3FormatProbe: Decodable { let formatVersion: Int }
private struct BackupChecksumPayloadV3: Codable, Equatable {
    let formatVersion: Int
    let canonicalizationVersion: Int
    let productV3CanonicalData: Data
    let sources: [BackupSourceV2]
    let pendingEnvelopes: [ShareCaptureEnvelopeV1]
}

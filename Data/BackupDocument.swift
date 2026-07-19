import CryptoKit
import Foundation

public enum BackupFormatV1Limits {
    public static let encodedByteCount = 134_217_728
    public static let itemCount = 5_000
    public static let currentPickCount = 1
    public static let sessionCount = 10_000
    public static let attemptCount = 50_000
    public static let memoryCount = 5_000
}

public enum BackupRecordKind: String, Equatable, Sendable {
    case item
    case currentPick
    case session
    case attempt
    case memory
    case source
    case envelope
}

public enum BackupFormatV2Limits {
    public static let encodedByteCount = 159_383_552
    public static let sourceCount = 5_000
    public static let envelopeCount = 256
}

public struct BackupSourceV2: Codable, Equatable, Sendable {
    public let id: UUID
    public let itemID: UUID
    public let importEnvelopeID: UUID
    public let acceptedURLString: String?
    public let sourceKindRaw: String
    public let capturedAtMilliseconds: Int64
}

public struct BackupRestorePayload: Equatable, Sendable {
    public let state: PersistedProductState
    public let pendingEnvelopes: [ShareCaptureEnvelopeV1]

    public init(state: PersistedProductState, pendingEnvelopes: [ShareCaptureEnvelopeV1]) {
        self.state = state
        self.pendingEnvelopes = pendingEnvelopes
    }
}

public struct BackupDocumentV2: Codable, Equatable, Sendable {
    public static let formatVersion = 2
    public static let canonicalizationVersion = 1

    public let formatVersion: Int
    public let canonicalizationVersion: Int
    public let productV1CanonicalData: Data
    public let sources: [BackupSourceV2]
    public let pendingEnvelopes: [ShareCaptureEnvelopeV1]
    public let checksumSHA256: String

    fileprivate var checksumPayload: BackupChecksumPayloadV2 {
        BackupChecksumPayloadV2(
            formatVersion: formatVersion,
            canonicalizationVersion: canonicalizationVersion,
            productV1CanonicalData: productV1CanonicalData,
            sources: sources,
            pendingEnvelopes: pendingEnvelopes
        )
    }
}

public struct BackupDocumentCodecV2: Sendable {
    public init() {}

    public func encode(
        state: PersistedProductState,
        pendingEnvelopes: [ShareCaptureEnvelopeV1],
        metadata: BackupDocumentMetadataV1
    ) throws -> Data {
        try PersistedStateValidator().validate(state)
        try validateEnvelopeSet(pendingEnvelopes, state: state)
        let productV1Data = try BackupDocumentCodecV1().encode(
            state: PersistedProductState(
                items: state.items,
                currentPick: state.currentPick,
                sessions: state.sessions,
                attempts: state.attempts,
                memories: state.memories
            ),
            metadata: metadata
        )
        let sources = try state.sources.map {
            BackupSourceV2(
                id: $0.id,
                itemID: $0.itemID,
                importEnvelopeID: $0.importEnvelopeID,
                acceptedURLString: $0.acceptedURLString,
                sourceKindRaw: $0.sourceKindRaw,
                capturedAtMilliseconds: try milliseconds($0.capturedAt)
            )
        }.sorted { uuidLess($0.id, $1.id) }
        let envelopes = pendingEnvelopes.sorted { uuidLess($0.envelopeID, $1.envelopeID) }
        let payload = BackupChecksumPayloadV2(
            formatVersion: BackupDocumentV2.formatVersion,
            canonicalizationVersion: BackupDocumentV2.canonicalizationVersion,
            productV1CanonicalData: productV1Data,
            sources: sources,
            pendingEnvelopes: envelopes
        )
        let document = BackupDocumentV2(
            formatVersion: payload.formatVersion,
            canonicalizationVersion: payload.canonicalizationVersion,
            productV1CanonicalData: payload.productV1CanonicalData,
            sources: payload.sources,
            pendingEnvelopes: payload.pendingEnvelopes,
            checksumSHA256: sha256Hex(try canonicalEncode(payload))
        )
        let data = try canonicalEncode(document)
        guard data.count <= BackupFormatV2Limits.encodedByteCount else {
            throw BackupDocumentError.encodedByteLimitExceeded(limit: BackupFormatV2Limits.encodedByteCount, actual: data.count)
        }
        _ = try decode(data)
        return data
    }

    public func decode(_ data: Data) throws -> BackupRestorePayload {
        guard !data.isEmpty else { throw BackupDocumentError.emptyDocument }
        guard data.count <= BackupFormatV2Limits.encodedByteCount else {
            throw BackupDocumentError.encodedByteLimitExceeded(limit: BackupFormatV2Limits.encodedByteCount, actual: data.count)
        }
        let probe: BackupFormatProbe
        do { probe = try JSONDecoder().decode(BackupFormatProbe.self, from: data) }
        catch { throw BackupDocumentError.malformedDocument }
        if probe.formatVersion == BackupDocumentV1.formatVersion {
            return BackupRestorePayload(state: try BackupDocumentCodecV1().decode(data), pendingEnvelopes: [])
        }
        guard probe.formatVersion == BackupDocumentV2.formatVersion else {
            throw BackupDocumentError.unsupportedFormatVersion(probe.formatVersion)
        }
        let document: BackupDocumentV2
        do { document = try JSONDecoder().decode(BackupDocumentV2.self, from: data) }
        catch { throw BackupDocumentError.malformedDocument }
        guard document.canonicalizationVersion == BackupDocumentV2.canonicalizationVersion else {
            throw BackupDocumentError.unsupportedCanonicalizationVersion(document.canonicalizationVersion)
        }
        guard try canonicalEncode(document) == data else { throw BackupDocumentError.nonCanonicalEncoding }
        guard document.checksumSHA256 == sha256Hex(try canonicalEncode(document.checksumPayload)) else {
            throw BackupDocumentError.invalidChecksum
        }
        guard document.sources.count <= BackupFormatV2Limits.sourceCount else {
            throw BackupDocumentError.countLimitExceeded(kind: .source, limit: BackupFormatV2Limits.sourceCount, actual: document.sources.count)
        }
        guard document.pendingEnvelopes.count <= BackupFormatV2Limits.envelopeCount else {
            throw BackupDocumentError.countLimitExceeded(kind: .envelope, limit: BackupFormatV2Limits.envelopeCount, actual: document.pendingEnvelopes.count)
        }
        try validateOrdering(document.sources.map(\.id), kind: .source)
        try validateOrdering(document.pendingEnvelopes.map(\.envelopeID), kind: .envelope)
        var state = try BackupDocumentCodecV1().decode(document.productV1CanonicalData)
        state.sources = document.sources.map {
            SourceReference(
                id: $0.id,
                itemID: $0.itemID,
                importEnvelopeID: $0.importEnvelopeID,
                acceptedURLString: $0.acceptedURLString,
                sourceKindRaw: $0.sourceKindRaw,
                capturedAt: Date(timeIntervalSince1970: Double($0.capturedAtMilliseconds) / 1_000)
            )
        }
        do { try PersistedStateValidator().validate(state) }
        catch let issue as PersistedStateValidationIssue { throw BackupDocumentError.invalidPersistedState(issue) }
        try validateEnvelopeSet(document.pendingEnvelopes, state: state)
        return BackupRestorePayload(state: state, pendingEnvelopes: document.pendingEnvelopes)
    }

    private func validateEnvelopeSet(_ envelopes: [ShareCaptureEnvelopeV1], state: PersistedProductState) throws {
        guard envelopes.count <= BackupFormatV2Limits.envelopeCount else {
            throw BackupDocumentError.countLimitExceeded(kind: .envelope, limit: BackupFormatV2Limits.envelopeCount, actual: envelopes.count)
        }
        var ids = Set<UUID>()
        let sourcesByEnvelope = Dictionary(uniqueKeysWithValues: state.sources.map { ($0.importEnvelopeID, $0) })
        for envelope in envelopes {
            guard ids.insert(envelope.envelopeID).inserted else {
                throw BackupDocumentError.recordsNotInCanonicalOrder(kind: .envelope)
            }
            _ = try envelope.canonicalData()
            if let source = sourcesByEnvelope[envelope.envelopeID] {
                guard let item = state.items.first(where: { $0.id == source.itemID }),
                      item.title == envelope.title,
                      item.note == envelope.note,
                      item.durationBucketRaw == envelope.durationBucketRaw,
                      source.acceptedURLString == envelope.acceptedURLString,
                      source.sourceKindRaw == envelope.sourceKindRaw
                else { throw BackupDocumentError.invalidPersistedState(.invalidSource(id: source.id)) }
            }
        }
    }

    private func validateOrdering(_ ids: [UUID], kind: BackupRecordKind) throws {
        guard zip(ids, ids.dropFirst()).allSatisfy({ uuidLess($0, $1) }) else {
            throw BackupDocumentError.recordsNotInCanonicalOrder(kind: kind)
        }
    }

    private func milliseconds(_ date: Date) throws -> Int64 {
        let value = date.timeIntervalSince1970 * 1_000
        guard value.isFinite, value >= Double(Int64.min), value < Double(Int64.max) else {
            throw BackupDocumentError.invalidTimestamp
        }
        return Int64(value.rounded(.toNearestOrAwayFromZero))
    }

    private func canonicalEncode<Value: Encodable>(_ value: Value) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    private func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func uuidLess(_ lhs: UUID, _ rhs: UUID) -> Bool {
        withUnsafeBytes(of: lhs.uuid) { lhsBytes in
            withUnsafeBytes(of: rhs.uuid) { rhsBytes in lhsBytes.lexicographicallyPrecedes(rhsBytes) }
        }
    }
}

private struct BackupChecksumPayloadV2: Codable, Equatable {
    let formatVersion: Int
    let canonicalizationVersion: Int
    let productV1CanonicalData: Data
    let sources: [BackupSourceV2]
    let pendingEnvelopes: [ShareCaptureEnvelopeV1]
}

public enum BackupDocumentError: Error, Equatable, Sendable {
    case emptyDocument
    case encodedByteLimitExceeded(limit: Int, actual: Int)
    case malformedDocument
    case unsupportedFormatVersion(Int)
    case unsupportedCanonicalizationVersion(Int)
    case nonCanonicalEncoding
    case invalidChecksum
    case invalidMetadata
    case invalidTimestamp
    case countLimitExceeded(kind: BackupRecordKind, limit: Int, actual: Int)
    case recordsNotInCanonicalOrder(kind: BackupRecordKind)
    case unsupportedLifecycle(rawValue: String)
    case unsupportedAvailableTime(rawValue: String)
    case unsupportedAttemptOutcome(rawValue: String)
    case invalidPersistedState(PersistedStateValidationIssue)
}

public struct BackupSchemaVersionV1: Codable, Equatable, Sendable {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }
}

public struct BackupItemV1: Codable, Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let note: String?
    public let durationBucketRaw: String
    public let lifecycleRaw: String
    public let createdAtMilliseconds: Int64
    public let updatedAtMilliseconds: Int64
    public let completedAtMilliseconds: Int64?
    public let lastShownAtMilliseconds: Int64?
}

public struct BackupCurrentPickV1: Codable, Equatable, Sendable {
    public let itemID: UUID
    public let acceptedAtMilliseconds: Int64
}

public struct BackupSessionV1: Codable, Equatable, Sendable {
    public let id: UUID
    public let startedAtMilliseconds: Int64
    public let endedAtMilliseconds: Int64?
    public let availableTimeRaw: String
    public let policyVersion: String
}

public struct BackupAttemptV1: Codable, Equatable, Sendable {
    public let id: UUID
    public let sessionID: UUID
    public let sequence: Int
    public let itemID: UUID
    public let eligibleCount: Int
    public let policyVersion: String
    public let shownAtMilliseconds: Int64
    public let outcomeRaw: String
    public let resolvedAtMilliseconds: Int64?
}

public struct BackupMemoryV1: Codable, Equatable, Sendable {
    public let id: UUID
    public let sourceItemID: UUID
    public let titleSnapshot: String
    public let noteSnapshot: String?
    public let durationSnapshotRaw: String
    public let completedAtMilliseconds: Int64
}

public struct BackupDocumentV1: Codable, Equatable, Sendable {
    public static let formatVersion = 1
    public static let canonicalizationVersion = 1

    public let formatVersion: Int
    public let exportedAtMilliseconds: Int64
    public let appMarketingVersion: String
    public let appBuild: String
    public let schemaVersion: BackupSchemaVersionV1
    public let selectionPolicyVersion: String
    public let canonicalizationVersion: Int
    public let items: [BackupItemV1]
    public let currentPick: BackupCurrentPickV1?
    public let sessions: [BackupSessionV1]
    public let attempts: [BackupAttemptV1]
    public let memories: [BackupMemoryV1]
    public let checksumSHA256: String

    fileprivate var checksumPayload: BackupChecksumPayloadV1 {
        BackupChecksumPayloadV1(
            formatVersion: formatVersion,
            exportedAtMilliseconds: exportedAtMilliseconds,
            appMarketingVersion: appMarketingVersion,
            appBuild: appBuild,
            schemaVersion: schemaVersion,
            selectionPolicyVersion: selectionPolicyVersion,
            canonicalizationVersion: canonicalizationVersion,
            items: items,
            currentPick: currentPick,
            sessions: sessions,
            attempts: attempts,
            memories: memories
        )
    }
}

public struct BackupDocumentMetadataV1: Equatable, Sendable {
    public let exportedAt: Date
    public let appMarketingVersion: String
    public let appBuild: String
    public let schemaVersion: BackupSchemaVersionV1
    public let selectionPolicyVersion: String

    public init(
        exportedAt: Date,
        appMarketingVersion: String,
        appBuild: String,
        schemaVersion: BackupSchemaVersionV1,
        selectionPolicyVersion: String
    ) {
        self.exportedAt = exportedAt
        self.appMarketingVersion = appMarketingVersion
        self.appBuild = appBuild
        self.schemaVersion = schemaVersion
        self.selectionPolicyVersion = selectionPolicyVersion
    }
}

public struct BackupDocumentCodecV1: Sendable {
    public init() {}

    public func encode(
        state: PersistedProductState,
        metadata: BackupDocumentMetadataV1
    ) throws -> Data {
        try validateDomainState(state)
        try validateMetadata(metadata)
        let payload = try makePayload(state: state, metadata: metadata)
        let payloadData = try Self.canonicalEncode(payload)
        let document = BackupDocumentV1(
            formatVersion: payload.formatVersion,
            exportedAtMilliseconds: payload.exportedAtMilliseconds,
            appMarketingVersion: payload.appMarketingVersion,
            appBuild: payload.appBuild,
            schemaVersion: payload.schemaVersion,
            selectionPolicyVersion: payload.selectionPolicyVersion,
            canonicalizationVersion: payload.canonicalizationVersion,
            items: payload.items,
            currentPick: payload.currentPick,
            sessions: payload.sessions,
            attempts: payload.attempts,
            memories: payload.memories,
            checksumSHA256: Self.sha256Hex(payloadData)
        )
        _ = try validatedState(from: document)
        let data = try Self.canonicalEncode(document)
        try validateEncodedByteCount(data.count)
        return data
    }

    public func decode(_ data: Data) throws -> PersistedProductState {
        guard !data.isEmpty else { throw BackupDocumentError.emptyDocument }
        try validateEncodedByteCount(data.count)

        let probe: BackupFormatProbe
        do {
            probe = try JSONDecoder().decode(BackupFormatProbe.self, from: data)
        } catch {
            throw BackupDocumentError.malformedDocument
        }
        guard probe.formatVersion == BackupDocumentV1.formatVersion else {
            throw BackupDocumentError.unsupportedFormatVersion(probe.formatVersion)
        }

        let document: BackupDocumentV1
        do {
            document = try JSONDecoder().decode(BackupDocumentV1.self, from: data)
        } catch {
            throw BackupDocumentError.malformedDocument
        }
        guard document.canonicalizationVersion == BackupDocumentV1.canonicalizationVersion else {
            throw BackupDocumentError.unsupportedCanonicalizationVersion(document.canonicalizationVersion)
        }
        guard try Self.canonicalEncode(document) == data else {
            throw BackupDocumentError.nonCanonicalEncoding
        }
        let expectedChecksum = Self.sha256Hex(try Self.canonicalEncode(document.checksumPayload))
        guard document.checksumSHA256 == expectedChecksum else {
            throw BackupDocumentError.invalidChecksum
        }
        return try validatedState(from: document)
    }

    private func makePayload(
        state: PersistedProductState,
        metadata: BackupDocumentMetadataV1
    ) throws -> BackupChecksumPayloadV1 {
        let items = try state.items.map {
            BackupItemV1(
                id: $0.id,
                title: $0.title,
                note: $0.note,
                durationBucketRaw: $0.durationBucketRaw,
                lifecycleRaw: $0.lifecycleRaw,
                createdAtMilliseconds: try Self.milliseconds($0.createdAt),
                updatedAtMilliseconds: try Self.milliseconds($0.updatedAt),
                completedAtMilliseconds: try $0.completedAt.map(Self.milliseconds),
                lastShownAtMilliseconds: try $0.lastShownAt.map(Self.milliseconds)
            )
        }.sorted { Self.uuidLess($0.id, $1.id) }
        let sessions = try state.sessions.map {
            BackupSessionV1(
                id: $0.id,
                startedAtMilliseconds: try Self.milliseconds($0.startedAt),
                endedAtMilliseconds: try $0.endedAt.map(Self.milliseconds),
                availableTimeRaw: $0.availableTimeRaw,
                policyVersion: $0.policyVersion
            )
        }.sorted { Self.uuidLess($0.id, $1.id) }
        let attempts = try state.attempts.map {
            BackupAttemptV1(
                id: $0.id,
                sessionID: $0.sessionID,
                sequence: $0.sequence,
                itemID: $0.itemID,
                eligibleCount: $0.eligibleCount,
                policyVersion: $0.policyVersion,
                shownAtMilliseconds: try Self.milliseconds($0.shownAt),
                outcomeRaw: $0.outcomeRaw,
                resolvedAtMilliseconds: try $0.resolvedAt.map(Self.milliseconds)
            )
        }.sorted { Self.uuidLess($0.id, $1.id) }
        let memories = try state.memories.map {
            BackupMemoryV1(
                id: $0.id,
                sourceItemID: $0.sourceItemID,
                titleSnapshot: $0.titleSnapshot,
                noteSnapshot: $0.noteSnapshot,
                durationSnapshotRaw: $0.durationSnapshotRaw,
                completedAtMilliseconds: try Self.milliseconds($0.completedAt)
            )
        }.sorted { Self.uuidLess($0.id, $1.id) }
        return BackupChecksumPayloadV1(
            formatVersion: BackupDocumentV1.formatVersion,
            exportedAtMilliseconds: try Self.milliseconds(metadata.exportedAt),
            appMarketingVersion: metadata.appMarketingVersion,
            appBuild: metadata.appBuild,
            schemaVersion: metadata.schemaVersion,
            selectionPolicyVersion: metadata.selectionPolicyVersion,
            canonicalizationVersion: BackupDocumentV1.canonicalizationVersion,
            items: items,
            currentPick: try state.currentPick.map {
                BackupCurrentPickV1(
                    itemID: $0.itemID,
                    acceptedAtMilliseconds: try Self.milliseconds($0.acceptedAt)
                )
            },
            sessions: sessions,
            attempts: attempts,
            memories: memories
        )
    }

    private func validatedState(from document: BackupDocumentV1) throws -> PersistedProductState {
        guard document.formatVersion == BackupDocumentV1.formatVersion else {
            throw BackupDocumentError.unsupportedFormatVersion(document.formatVersion)
        }
        guard document.canonicalizationVersion == BackupDocumentV1.canonicalizationVersion else {
            throw BackupDocumentError.unsupportedCanonicalizationVersion(document.canonicalizationVersion)
        }
        try validateMetadata(document)
        try validateCounts(document)
        try validateCanonicalOrdering(document.items.map(\.id), kind: .item)
        try validateCanonicalOrdering(document.sessions.map(\.id), kind: .session)
        try validateCanonicalOrdering(document.attempts.map(\.id), kind: .attempt)
        try validateCanonicalOrdering(document.memories.map(\.id), kind: .memory)

        let items = try document.items.map { item -> BoxItem in
            guard let lifecycle = PaperLifecycle(rawValue: item.lifecycleRaw) else {
                throw BackupDocumentError.unsupportedLifecycle(rawValue: item.lifecycleRaw)
            }
            return BoxItem(
                id: item.id,
                title: item.title,
                note: item.note,
                durationBucketRaw: item.durationBucketRaw,
                lifecycle: lifecycle,
                createdAt: Self.date(item.createdAtMilliseconds),
                updatedAt: Self.date(item.updatedAtMilliseconds),
                completedAt: item.completedAtMilliseconds.map(Self.date),
                lastShownAt: item.lastShownAtMilliseconds.map(Self.date)
            )
        }
        let sessions = try document.sessions.map { session -> DrawSession in
            guard DrawContext(storageValue: session.availableTimeRaw) != nil else {
                throw BackupDocumentError.unsupportedAvailableTime(rawValue: session.availableTimeRaw)
            }
            return DrawSession(
                id: session.id,
                startedAt: Self.date(session.startedAtMilliseconds),
                endedAt: session.endedAtMilliseconds.map(Self.date),
                availableTimeRaw: session.availableTimeRaw,
                policyVersion: session.policyVersion
            )
        }
        let attempts = try document.attempts.map { attempt -> DrawAttempt in
            guard DrawAttemptOutcome(rawValue: attempt.outcomeRaw) != nil else {
                throw BackupDocumentError.unsupportedAttemptOutcome(rawValue: attempt.outcomeRaw)
            }
            return DrawAttempt(
                id: attempt.id,
                sessionID: attempt.sessionID,
                sequence: attempt.sequence,
                itemID: attempt.itemID,
                eligibleCount: attempt.eligibleCount,
                policyVersion: attempt.policyVersion,
                shownAt: Self.date(attempt.shownAtMilliseconds),
                outcomeRaw: attempt.outcomeRaw,
                resolvedAt: attempt.resolvedAtMilliseconds.map(Self.date)
            )
        }
        let memories = document.memories.map {
            CompletionMemory(
                id: $0.id,
                sourceItemID: $0.sourceItemID,
                titleSnapshot: $0.titleSnapshot,
                noteSnapshot: $0.noteSnapshot,
                durationSnapshotRaw: $0.durationSnapshotRaw,
                completedAt: Self.date($0.completedAtMilliseconds)
            )
        }
        let state = PersistedProductState(
            items: items,
            currentPick: document.currentPick.map {
                CurrentPick(itemID: $0.itemID, acceptedAt: Self.date($0.acceptedAtMilliseconds))
            },
            sessions: sessions,
            attempts: attempts,
            memories: memories
        )
        try validateDomainState(state)
        return state
    }

    private func validateDomainState(_ state: PersistedProductState) throws {
        do {
            try PersistedStateValidator().validate(state)
        } catch let issue as PersistedStateValidationIssue {
            throw BackupDocumentError.invalidPersistedState(issue)
        }
    }

    private func validateMetadata(_ metadata: BackupDocumentMetadataV1) throws {
        _ = try Self.milliseconds(metadata.exportedAt)
        try validateMetadataStrings(
            marketingVersion: metadata.appMarketingVersion,
            build: metadata.appBuild,
            selectionPolicyVersion: metadata.selectionPolicyVersion,
            schemaVersion: metadata.schemaVersion
        )
    }

    private func validateMetadata(_ document: BackupDocumentV1) throws {
        try validateMetadataStrings(
            marketingVersion: document.appMarketingVersion,
            build: document.appBuild,
            selectionPolicyVersion: document.selectionPolicyVersion,
            schemaVersion: document.schemaVersion
        )
    }

    private func validateMetadataStrings(
        marketingVersion: String,
        build: String,
        selectionPolicyVersion: String,
        schemaVersion: BackupSchemaVersionV1
    ) throws {
        do {
            try OpenRawValueValidator().validate(marketingVersion, requiresPrintableASCII: true)
            try OpenRawValueValidator().validate(build, requiresPrintableASCII: true)
            try OpenRawValueValidator().validate(selectionPolicyVersion, requiresPrintableASCII: true)
            guard schemaVersion.major >= 0, schemaVersion.minor >= 0, schemaVersion.patch >= 0 else {
                throw BackupDocumentError.invalidMetadata
            }
        } catch is RawValueValidationFailure {
            throw BackupDocumentError.invalidMetadata
        }
    }

    private func validateCounts(_ document: BackupDocumentV1) throws {
        try validateCount(document.items.count, limit: BackupFormatV1Limits.itemCount, kind: .item)
        try validateCount(document.sessions.count, limit: BackupFormatV1Limits.sessionCount, kind: .session)
        try validateCount(document.attempts.count, limit: BackupFormatV1Limits.attemptCount, kind: .attempt)
        try validateCount(document.memories.count, limit: BackupFormatV1Limits.memoryCount, kind: .memory)
        try validateCount(document.currentPick == nil ? 0 : 1, limit: BackupFormatV1Limits.currentPickCount, kind: .currentPick)
    }

    private func validateCount(_ count: Int, limit: Int, kind: BackupRecordKind) throws {
        guard count <= limit else {
            throw BackupDocumentError.countLimitExceeded(kind: kind, limit: limit, actual: count)
        }
    }

    private func validateCanonicalOrdering(_ ids: [UUID], kind: BackupRecordKind) throws {
        guard zip(ids, ids.dropFirst()).allSatisfy({ Self.uuidLess($0, $1) }) else {
            throw BackupDocumentError.recordsNotInCanonicalOrder(kind: kind)
        }
    }

    private func validateEncodedByteCount(_ count: Int) throws {
        guard count <= BackupFormatV1Limits.encodedByteCount else {
            throw BackupDocumentError.encodedByteLimitExceeded(
                limit: BackupFormatV1Limits.encodedByteCount,
                actual: count
            )
        }
    }

    private static func canonicalEncode<Value: Encodable>(_ value: Value) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    private static func milliseconds(_ date: Date) throws -> Int64 {
        let value = date.timeIntervalSince1970 * 1_000
        guard value.isFinite, value >= Double(Int64.min), value < Double(Int64.max) else {
            throw BackupDocumentError.invalidTimestamp
        }
        return Int64(value.rounded(.toNearestOrAwayFromZero))
    }

    private static func date(_ milliseconds: Int64) -> Date {
        Date(timeIntervalSince1970: Double(milliseconds) / 1_000)
    }

    private static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func uuidLess(_ lhs: UUID, _ rhs: UUID) -> Bool {
        withUnsafeBytes(of: lhs.uuid) { lhsBytes in
            withUnsafeBytes(of: rhs.uuid) { rhsBytes in
                lhsBytes.lexicographicallyPrecedes(rhsBytes)
            }
        }
    }
}

private struct BackupFormatProbe: Decodable {
    let formatVersion: Int
}

private struct BackupChecksumPayloadV1: Codable {
    let formatVersion: Int
    let exportedAtMilliseconds: Int64
    let appMarketingVersion: String
    let appBuild: String
    let schemaVersion: BackupSchemaVersionV1
    let selectionPolicyVersion: String
    let canonicalizationVersion: Int
    let items: [BackupItemV1]
    let currentPick: BackupCurrentPickV1?
    let sessions: [BackupSessionV1]
    let attempts: [BackupAttemptV1]
    let memories: [BackupMemoryV1]
}

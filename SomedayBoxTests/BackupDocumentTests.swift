import CryptoKit
import Foundation
import XCTest

#if canImport(SomedayBox)
@testable import SomedayBox

final class BackupDocumentTests: XCTestCase {
    private let codec = BackupDocumentCodecV1()
    private let instant = Date(timeIntervalSince1970: 2_000_000)

    func testV3RoundTripStoresCanonicalContextUnionAndReadsV2() throws {
        let item = BoxItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!, title: "Exact time", durationBucketRaw: DurationBucket.upTo30Minutes.rawValue, createdAt: instant, updatedAt: instant, lastShownAt: instant)
        let session = DrawSession(id: UUID(uuidString: "00000000-0000-0000-0000-000000000012")!, startedAt: instant, endedAt: instant, context: DrawContext(customMinutes: 45))
        let attempt = DrawAttempt(id: UUID(uuidString: "00000000-0000-0000-0000-000000000013")!, sessionID: session.id, sequence: 1, itemID: item.id, eligibleCount: 1, shownAt: instant, outcome: .dismissed, resolvedAt: instant)
        let state = PersistedProductState(items: [item], sessions: [session], attempts: [attempt])
        let v3 = BackupDocumentCodecV3()
        let data = try v3.encode(state: state, pendingEnvelopes: [], metadata: BackupDocumentMetadataV1(exportedAt: instant, appMarketingVersion: "0.3.0", appBuild: "3", schemaVersion: .init(major: 3, minor: 0, patch: 0), selectionPolicyVersion: DrawSelectionPolicy.version))
        XCTAssertEqual(try v3.decode(data).state, state)
        let document = try JSONDecoder().decode(BackupDocumentV3.self, from: data)
        let product = try JSONDecoder().decode(BackupProductV3.self, from: document.productV3CanonicalData)
        XCTAssertEqual(product.sessions.first?.contextModeRaw, "custom")
        XCTAssertEqual(product.sessions.first?.maximumMinutes, 45)
        XCTAssertNil(product.sessions.first?.presentationPresetRaw)

        let v2 = try BackupDocumentCodecV2().encode(state: state, pendingEnvelopes: [], metadata: metadata())
        XCTAssertEqual(try v3.decode(v2).state, state)
    }

    func testCanonicalRoundTripPreservesCompleteDomainStateAndOpenDurationValues() throws {
        let state = completeState()
        let first = try codec.encode(state: state, metadata: metadata())
        let second = try codec.encode(state: state, metadata: metadata())

        XCTAssertEqual(first, second)
        XCTAssertEqual(try codec.decode(first), state)
        let json = try XCTUnwrap(String(data: first, encoding: .utf8))
        XCTAssertTrue(json.contains("\"exportedAtMilliseconds\":2000000000"))
        XCTAssertFalse(json.contains("2000000000.0"))
        XCTAssertTrue(json.contains("future_duration_v1"))
    }

    func testChecksumIsCanonicalPayloadDigestWithoutChecksumField() throws {
        let data = try codec.encode(state: completeState(), metadata: metadata())
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let checksum = try XCTUnwrap(object.removeValue(forKey: "checksumSHA256") as? String)
        let payload = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
        let expected = SHA256.hash(data: payload).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(checksum, expected)
    }

    func testRejectsFutureFormatBeforeAcceptingPayload() throws {
        let data = try codec.encode(state: completeState(), metadata: metadata())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["formatVersion"] = 2
        let future = try canonicalJSON(object)

        XCTAssertThrowsError(try codec.decode(future)) { error in
            XCTAssertEqual(error as? BackupDocumentError, .unsupportedFormatVersion(2))
        }
    }

    func testRejectsCorruptChecksum() throws {
        let data = try codec.encode(state: completeState(), metadata: metadata())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["checksumSHA256"] = String(repeating: "0", count: 64)
        let corrupt = try canonicalJSON(object)

        XCTAssertThrowsError(try codec.decode(corrupt)) { error in
            XCTAssertEqual(error as? BackupDocumentError, .invalidChecksum)
        }
    }

    func testRejectsUnknownClosedValueEvenWithMatchingChecksum() throws {
        let data = try codec.encode(state: completeState(), metadata: metadata())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var items = try XCTUnwrap(object["items"] as? [[String: Any]])
        items[0]["lifecycleRaw"] = "future_lifecycle"
        object["items"] = items
        object.removeValue(forKey: "checksumSHA256")
        let payload = try canonicalJSON(object)
        object["checksumSHA256"] = SHA256.hash(data: payload)
            .map { String(format: "%02x", $0) }
            .joined()
        let invalid = try canonicalJSON(object)

        XCTAssertThrowsError(try codec.decode(invalid)) { error in
            XCTAssertEqual(
                error as? BackupDocumentError,
                .unsupportedLifecycle(rawValue: "future_lifecycle")
            )
        }
    }

    func testRejectsRecordCountAboveFrozenFormatLimit() throws {
        let data = try codec.encode(state: completeState(), metadata: metadata())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let item = try XCTUnwrap((object["items"] as? [[String: Any]])?.first)
        object["items"] = Array(repeating: item, count: BackupFormatV1Limits.itemCount + 1)
        object.removeValue(forKey: "checksumSHA256")
        let payload = try canonicalJSON(object)
        object["checksumSHA256"] = SHA256.hash(data: payload)
            .map { String(format: "%02x", $0) }
            .joined()
        let oversizedCount = try canonicalJSON(object)

        XCTAssertThrowsError(try codec.decode(oversizedCount)) { error in
            XCTAssertEqual(
                error as? BackupDocumentError,
                .countLimitExceeded(
                    kind: .item,
                    limit: BackupFormatV1Limits.itemCount,
                    actual: BackupFormatV1Limits.itemCount + 1
                )
            )
        }
    }

    func testRejectsNonCanonicalJSONAndOversizedInputBeforeDecode() throws {
        let data = try codec.encode(state: completeState(), metadata: metadata())
        var nonCanonical = data
        nonCanonical.append(0x0A)
        XCTAssertThrowsError(try codec.decode(nonCanonical)) { error in
            XCTAssertEqual(error as? BackupDocumentError, .nonCanonicalEncoding)
        }

        let oversized = Data(count: BackupFormatV1Limits.encodedByteCount + 1)
        XCTAssertThrowsError(try codec.decode(oversized)) { error in
            XCTAssertEqual(
                error as? BackupDocumentError,
                .encodedByteLimitExceeded(
                    limit: BackupFormatV1Limits.encodedByteCount,
                    actual: BackupFormatV1Limits.encodedByteCount + 1
                )
            )
        }
    }

    func testV2RoundTripPreservesSourcesAndPendingEnvelopesAndReadsV1() throws {
        var state = completeState()
        let source = SourceReference(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000006")!,
            itemID: state.items[0].id,
            importEnvelopeID: UUID(uuidString: "00000000-0000-0000-0000-000000000007")!,
            acceptedURLString: "https://example.com/source",
            sourceKindRaw: "url",
            capturedAt: instant
        )
        state.sources = [source]
        let pending = try ShareCaptureEnvelopeV1(
            envelopeID: UUID(uuidString: "00000000-0000-0000-0000-000000000008")!,
            createdAt: instant,
            appBuild: "1",
            title: "Pending paper",
            note: nil,
            durationBucketRaw: DurationBucket.upTo30Minutes.rawValue,
            acceptedURLString: nil,
            sourceKindRaw: "shared_text"
        )
        let codecV2 = BackupDocumentCodecV2()

        let data = try codecV2.encode(state: state, pendingEnvelopes: [pending], metadata: metadata())
        let decoded = try codecV2.decode(data)
        XCTAssertEqual(decoded, BackupRestorePayload(state: state, pendingEnvelopes: [pending]))

        let v1Data = try codec.encode(state: completeState(), metadata: metadata())
        XCTAssertEqual(
            try codecV2.decode(v1Data),
            BackupRestorePayload(state: completeState(), pendingEnvelopes: [])
        )
    }

    private func completeState() -> PersistedProductState {
        let itemID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let sessionID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        let item = BoxItem(
            id: itemID,
            title: "Read beside the window",
            note: "A quiet note\nkept exactly",
            durationBucketRaw: "future_duration_v1",
            lifecycle: .active,
            createdAt: instant,
            updatedAt: instant,
            lastShownAt: instant
        )
        let session = DrawSession(
            id: sessionID,
            startedAt: instant,
            endedAt: instant,
            availableTime: .notSure
        )
        let attempt = DrawAttempt(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
            sessionID: sessionID,
            sequence: 1,
            itemID: itemID,
            eligibleCount: 1,
            shownAt: instant,
            outcome: .dismissed,
            resolvedAt: instant
        )
        let memory = CompletionMemory(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
            sourceItemID: itemID,
            titleSnapshot: item.title,
            noteSnapshot: item.note,
            durationSnapshotRaw: "future_duration_v1",
            completedAt: instant
        )
        return PersistedProductState(
            items: [item],
            currentPick: CurrentPick(itemID: itemID, acceptedAt: instant),
            sessions: [session],
            attempts: [attempt],
            memories: [memory]
        )
    }

    private func metadata() -> BackupDocumentMetadataV1 {
        BackupDocumentMetadataV1(
            exportedAt: instant,
            appMarketingVersion: "0.1.0",
            appBuild: "1",
            schemaVersion: BackupSchemaVersionV1(major: 1, minor: 0, patch: 0),
            selectionPolicyVersion: DrawSelectionPolicy.version
        )
    }

    private func canonicalJSON(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
    }
}
#endif

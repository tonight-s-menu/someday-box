import CryptoKit
import Foundation
import XCTest

#if canImport(SomedayBox)
@testable import SomedayBox

final class BackupDocumentTests: XCTestCase {
    private let codec = BackupDocumentCodecV1()
    private let instant = Date(timeIntervalSince1970: 2_000_000)

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

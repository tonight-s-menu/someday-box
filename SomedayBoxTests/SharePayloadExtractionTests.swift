import XCTest
@testable import SomedayBox

final class SharePayloadExtractionTests: XCTestCase {
    private let extractor = SharePayloadExtractor()

    func testExplicitHTTPSURLWinsOverTextURLWithoutRewritingIt() throws {
        let candidate = try extractor.extract(from: SharedPayload(
            explicitURLString: "https://example.com/Path?utm=kept",
            plainText: "https://other.example/first\nA title",
            attributedTitle: "A confirmed host title"
        ))

        XCTAssertEqual(candidate.acceptedURLString, "https://example.com/Path?utm=kept")
        XCTAssertEqual(candidate.titleCandidate, "A confirmed host title")
    }

    func testTextURLUsesFirstHTTPSubstringAndDerivesTitleFromNextLine() throws {
        let candidate = try extractor.extract(from: SharedPayload(
            plainText: "https://example.com/one\nTry this walk\nhttps://example.com/two"
        ))

        XCTAssertEqual(candidate.acceptedURLString, "https://example.com/one")
        XCTAssertEqual(candidate.titleCandidate, "Try this walk")
    }

    func testUnsupportedSchemeDoesNotBecomeAnAcceptedURL() throws {
        let candidate = try extractor.extract(from: SharedPayload(
            explicitURLString: "javascript:alert(1)",
            plainText: "A safe title"
        ))

        XCTAssertNil(candidate.acceptedURLString)
        XCTAssertEqual(candidate.titleCandidate, "A safe title")
    }

    func testOversizedPlainTextIsRejected() {
        XCTAssertThrowsError(try extractor.extract(from: SharedPayload(plainText: String(repeating: "a", count: 32 * 1_024 + 1)))) { error in
            XCTAssertEqual(error as? SharePayloadValidationFailure, .textTooLarge(limit: 32 * 1_024, actual: 32 * 1_024 + 1))
        }
    }

    func testMailboxReaderReturnsPublishedEnvelopeAndRemovesOnlyMatchingFile() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let envelope = try ShareCaptureEnvelopeV1(
            appBuild: "1",
            title: "Read this later",
            note: nil,
            durationBucketRaw: DurationBucket.upTo30Minutes.rawValue,
            acceptedURLString: "https://example.com/read",
            sourceKindRaw: "url"
        )

        _ = try ShareMailboxWriter().publish(envelope, at: root)
        let reader = ShareMailboxReader()
        let entries = try reader.entries(at: root)
        XCTAssertEqual(entries.map(\.envelope), [envelope])
        try reader.remove(try XCTUnwrap(entries.first), at: root)
        XCTAssertTrue(try reader.entries(at: root).isEmpty)
    }
}

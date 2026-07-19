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
}

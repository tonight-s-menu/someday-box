import Foundation
import XCTest
#if canImport(SomedayBox)
@testable import SomedayBox
#else
@testable import SomedayBoxDomain
#endif

final class DomainValidationTests: XCTestCase {
    private let validator = PaperContentValidator()

    func testTrimsValidTitleWithoutChangingNote() throws {
        let content = try validator.validate(title: "  A quiet walk  ", note: "line one\nline two\tend")
        XCTAssertEqual(content.title, "A quiet walk")
        XCTAssertEqual(content.note, "line one\nline two\tend")
    }

    func testValidatesTitleCharacterBoundaries() throws {
        XCTAssertNoThrow(try validator.validate(title: String(repeating: "a", count: 120), note: nil))
        XCTAssertThrowsError(try validator.validate(title: String(repeating: "a", count: 121), note: nil)) { error in
            XCTAssertEqual(error as? BoxItemValidationFailure, .title(.tooManyCharacters(limit: 120, actual: 121)))
        }
    }

    func testValidatesTitleByteBoundaryIndependentlyOfCharacters() {
        let title = String(repeating: "👨‍👩‍👧‍👦", count: 21)
        XCTAssertEqual(title.count, 21)
        XCTAssertGreaterThan(title.utf8.count, DomainLimits.titleUTF8ByteCount)
        XCTAssertThrowsError(try validator.validate(title: title, note: nil)) { error in
            XCTAssertEqual(
                error as? BoxItemValidationFailure,
                .title(.tooManyUTF8Bytes(limit: DomainLimits.titleUTF8ByteCount, actual: title.utf8.count))
            )
        }
    }

    func testRejectsControlCharactersWithoutSilentlyTrimmingThem() {
        XCTAssertThrowsError(try validator.validate(title: "\nPaper", note: nil)) { error in
            XCTAssertEqual(error as? BoxItemValidationFailure, .title(.unsupportedControlCharacter))
        }
        XCTAssertThrowsError(try validator.validate(title: "Paper", note: "bad\rnote")) { error in
            XCTAssertEqual(error as? BoxItemValidationFailure, .note(.unsupportedControlCharacter))
        }
    }

    func testValidatesOpenRawValuesWithoutReinterpretingUnknownValues() throws {
        XCTAssertNoThrow(try OpenRawValueValidator().validate("future_duration"))
        XCTAssertThrowsError(try OpenRawValueValidator().validate("")) { error in
            XCTAssertEqual(error as? RawValueValidationFailure, .empty)
        }
        XCTAssertThrowsError(try OpenRawValueValidator().validate(String(repeating: "a", count: 65))) { error in
            XCTAssertEqual(error as? RawValueValidationFailure, .tooManyUTF8Bytes(limit: 64, actual: 65))
        }
    }

    func testEnforcesLifecycleTransitions() throws {
        let policy = PaperLifecyclePolicy()
        XCTAssertEqual(try policy.resultingLifecycle(from: .active, applying: .complete), .completed)
        XCTAssertEqual(try policy.resultingLifecycle(from: .active, applying: .archive), .archived)
        XCTAssertEqual(try policy.resultingLifecycle(from: .archived, applying: .restore), .active)
        XCTAssertEqual(try policy.resultingLifecycle(from: .completed, applying: .putBack), .active)
        XCTAssertThrowsError(try policy.resultingLifecycle(from: .completed, applying: .complete)) { error in
            XCTAssertEqual(
                error as? LifecycleTransitionFailure,
                .invalidTransition(from: .completed, transition: .complete)
            )
        }
    }
}

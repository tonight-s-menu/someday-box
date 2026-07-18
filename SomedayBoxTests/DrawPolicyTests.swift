import Foundation
#if canImport(SomedayBox)
@testable import SomedayBox
#else
@testable import SomedayBoxDomain
#endif

private struct FixedGenerator: RandomNumberGenerating {
    var value: Double

    mutating func nextUnitInterval() -> Double { value }
}

#if canImport(Testing)
import Testing

@Suite("Draw policy")
struct DrawPolicyTests {
    @Test func excludesOversizedPaper() { #expect(policyResult() == .candidates([shortItem])) }
    @Test func excludesUnsupportedDuration() { #expect(unsupportedResult() == .empty(.unsupportedDurations)) }
    @Test func injectedRandomSourceSelectsCandidate() { #expect(selectedItemID() == secondItem.id) }
}
#else
import XCTest

final class DrawPolicyTests: XCTestCase {
    func testTimedDrawsExcludePapersLargerThanSelectedTime() { XCTAssertEqual(policyResult(), .candidates([shortItem])) }
    func testUnknownDurationIsNeverEligible() { XCTAssertEqual(unsupportedResult(), .empty(.unsupportedDurations)) }
    func testInjectedRandomSourceSelectsCandidate() { XCTAssertEqual(selectedItemID(), secondItem.id) }
}
#endif

private let now = Date(timeIntervalSince1970: 1_000_000)
private let shortItem = item(duration: .upTo30Minutes)
private let secondItem = item(duration: .upTo30Minutes)

private func policyResult() -> CandidatePoolResult {
    CandidatePoolBuilder().build(
        items: [shortItem, item(duration: .upTo120Minutes)],
        availableTime: .upTo60Minutes,
        currentPick: nil,
        reservedItemID: nil,
        shownItemIDs: []
    )
}

private func unsupportedResult() -> CandidatePoolResult {
    CandidatePoolBuilder().build(
        items: [item(durationRaw: "future_duration")],
        availableTime: .notSure,
        currentPick: nil,
        reservedItemID: nil,
        shownItemIDs: []
    )
}

private func selectedItemID() -> UUID? {
    var generator = FixedGenerator(value: 0.99)
    return DrawSelectionPolicy().select(
        from: [shortItem, secondItem],
        availableTime: .upTo30Minutes,
        now: now,
        using: &generator
    )?.id
}

private func item(duration: DurationBucket) -> BoxItem {
    item(durationRaw: duration.rawValue)
}

private func item(durationRaw: String) -> BoxItem {
    BoxItem(title: "Paper", durationBucketRaw: durationRaw, createdAt: now, updatedAt: now)
}

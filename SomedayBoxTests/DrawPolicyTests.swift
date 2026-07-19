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

    @Test func usesDiscreteDurationBucketsForTimeFit() {
        let policy = DrawSelectionPolicy()
        let tenMinutes = item(duration: .upTo10Minutes)
        #expect(policy.weight(for: tenMinutes, availableTime: .upTo30Minutes, eligibleCount: 1, now: now) == 1.275)
        #expect(policy.weight(for: tenMinutes, availableTime: .upTo60Minutes, eligibleCount: 1, now: now) == 1.05)
    }

    @Test func everyDurationBoundaryIsAHardGate() {
        for availableTime in AvailableTime.allCases where availableTime != .notSure {
            let candidates = DurationBucket.allCases.map { item(duration: $0) }
            let result = CandidatePoolBuilder().build(
                items: candidates,
                availableTime: availableTime,
                currentPick: nil,
                reservedItemID: nil,
                shownItemIDs: []
            )
            let expected = candidates.filter { $0.supportedDuration!.maximumMinutes <= availableTime.maximumMinutes! }
            #expect(result == .candidates(expected))
        }
    }

    @Test func excludesCurrentPickAndUnresolvedReservation() {
        let reserved = item(duration: .upTo30Minutes)
        let result = CandidatePoolBuilder().build(
            items: [shortItem, secondItem, reserved],
            availableTime: .notSure,
            currentPick: CurrentPick(itemID: shortItem.id, acceptedAt: now),
            reservedItemID: reserved.id,
            shownItemIDs: []
        )
        #expect(result == .candidates([secondItem]))
    }

    @Test func classifiesEveryEmptyPoolReason() {
        let unsupported = item(durationRaw: "future_duration")
        let oversized = item(duration: .upTo120Minutes)
        #expect(pool(items: []) == .empty(.noActivePapers))
        #expect(pool(items: [unsupported]) == .empty(.unsupportedDurations))
        #expect(pool(items: [oversized]) == .empty(.overTimeBudget))
        #expect(pool(items: [shortItem], shown: [shortItem.id]) == .empty(.alreadyShownInSession))
    }

    @Test func freshnessAndRecentRepeatUseExactElapsedBoundaries() {
        let policy = DrawSelectionPolicy()
        let day: TimeInterval = 86_400
        let exactlyRecentBoundary = item(duration: .upTo30Minutes, lastShownAt: now.addingTimeInterval(-24 * day))
        let belowRecentBoundary = item(duration: .upTo30Minutes, lastShownAt: now.addingTimeInterval(-24 * day + 1))
        let exactlyFreshBoundary = item(duration: .upTo30Minutes, lastShownAt: now.addingTimeInterval(-30 * day))
        #expect(policy.weight(for: exactlyRecentBoundary, availableTime: .upTo30Minutes, eligibleCount: 2, now: now) > 1)
        #expect(policy.weight(for: belowRecentBoundary, availableTime: .upTo30Minutes, eligibleCount: 2, now: now) < 0.4)
        #expect(policy.weight(for: exactlyFreshBoundary, availableTime: .upTo30Minutes, eligibleCount: 2, now: now) == 1.5)
    }

    @Test func exactWeightedBoundarySelectsNextCandidate() {
        var generator = FixedGenerator(value: 0.5)
        let selected = DrawSelectionPolicy().select(
            from: [shortItem, secondItem],
            availableTime: .upTo30Minutes,
            now: now,
            using: &generator
        )
        #expect(selected?.id == secondItem.id)
    }
}
#else
import XCTest

final class DrawPolicyTests: XCTestCase {
    func testTimedDrawsExcludePapersLargerThanSelectedTime() { XCTAssertEqual(policyResult(), .candidates([shortItem])) }
    func testUnknownDurationIsNeverEligible() { XCTAssertEqual(unsupportedResult(), .empty(.unsupportedDurations)) }
    func testInjectedRandomSourceSelectsCandidate() { XCTAssertEqual(selectedItemID(), secondItem.id) }

    func testUsesDiscreteDurationBucketsForTimeFit() {
        let policy = DrawSelectionPolicy()
        let tenMinutes = item(duration: .upTo10Minutes)
        XCTAssertEqual(policy.weight(for: tenMinutes, availableTime: .upTo30Minutes, eligibleCount: 1, now: now), 1.275)
        XCTAssertEqual(policy.weight(for: tenMinutes, availableTime: .upTo60Minutes, eligibleCount: 1, now: now), 1.05)
    }

    func testEveryDurationBoundaryIsAHardGate() {
        for availableTime in AvailableTime.allCases where availableTime != .notSure {
            let candidates = DurationBucket.allCases.map { item(duration: $0) }
            let result = CandidatePoolBuilder().build(
                items: candidates,
                availableTime: availableTime,
                currentPick: nil,
                reservedItemID: nil,
                shownItemIDs: []
            )
            let expected = candidates.filter { $0.supportedDuration!.maximumMinutes <= availableTime.maximumMinutes! }
            XCTAssertEqual(result, .candidates(expected))
        }
    }

    func testExcludesCurrentPickAndUnresolvedReservation() {
        let reserved = item(duration: .upTo30Minutes)
        XCTAssertEqual(
            CandidatePoolBuilder().build(
                items: [shortItem, secondItem, reserved],
                availableTime: .notSure,
                currentPick: CurrentPick(itemID: shortItem.id, acceptedAt: now),
                reservedItemID: reserved.id,
                shownItemIDs: []
            ),
            .candidates([secondItem])
        )
    }

    func testClassifiesEveryEmptyPoolReason() {
        XCTAssertEqual(pool(items: []), .empty(.noActivePapers))
        XCTAssertEqual(pool(items: [item(durationRaw: "future_duration")]), .empty(.unsupportedDurations))
        XCTAssertEqual(pool(items: [item(duration: .upTo120Minutes)]), .empty(.overTimeBudget))
        XCTAssertEqual(pool(items: [shortItem], shown: [shortItem.id]), .empty(.alreadyShownInSession))
    }

    func testFreshnessAndRecentRepeatUseExactElapsedBoundaries() {
        let policy = DrawSelectionPolicy()
        let day: TimeInterval = 86_400
        let exactlyRecentBoundary = item(duration: .upTo30Minutes, lastShownAt: now.addingTimeInterval(-24 * day))
        let belowRecentBoundary = item(duration: .upTo30Minutes, lastShownAt: now.addingTimeInterval(-24 * day + 1))
        let exactlyFreshBoundary = item(duration: .upTo30Minutes, lastShownAt: now.addingTimeInterval(-30 * day))
        XCTAssertGreaterThan(policy.weight(for: exactlyRecentBoundary, availableTime: .upTo30Minutes, eligibleCount: 2, now: now), 1)
        XCTAssertLessThan(policy.weight(for: belowRecentBoundary, availableTime: .upTo30Minutes, eligibleCount: 2, now: now), 0.4)
        XCTAssertEqual(policy.weight(for: exactlyFreshBoundary, availableTime: .upTo30Minutes, eligibleCount: 2, now: now), 1.5)
    }

    func testExactWeightedBoundarySelectsNextCandidate() {
        var generator = FixedGenerator(value: 0.5)
        let selected = DrawSelectionPolicy().select(
            from: [shortItem, secondItem],
            availableTime: .upTo30Minutes,
            now: now,
            using: &generator
        )
        XCTAssertEqual(selected?.id, secondItem.id)
    }
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
    item(durationRaw: durationRaw, lastShownAt: nil)
}

private func item(duration: DurationBucket, lastShownAt: Date?) -> BoxItem {
    item(durationRaw: duration.rawValue, lastShownAt: lastShownAt)
}

private func item(durationRaw: String, lastShownAt: Date?) -> BoxItem {
    BoxItem(
        title: "Paper",
        durationBucketRaw: durationRaw,
        createdAt: now,
        updatedAt: now,
        lastShownAt: lastShownAt
    )
}

private func pool(items: [BoxItem], shown: Set<UUID> = []) -> CandidatePoolResult {
    CandidatePoolBuilder().build(
        items: items,
        availableTime: .upTo30Minutes,
        currentPick: nil,
        reservedItemID: nil,
        shownItemIDs: shown
    )
}

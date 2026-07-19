import Foundation
import XCTest
#if canImport(SomedayBox)
@testable import SomedayBox
#else
@testable import SomedayBoxDomain
#endif

final class PersistedStateValidatorTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 2_000_000)

    func testAcceptsAValidOpenReveal() throws {
        try PersistedStateValidator().validate(openRevealFixture().state)
    }

    func testRejectsCurrentPickAlongsideUnresolvedReveal() {
        let fixture = openRevealFixture()
        var state = fixture.state
        state.currentPick = CurrentPick(itemID: fixture.item.id, acceptedAt: now)
        XCTAssertThrowsError(try PersistedStateValidator().validate(state)) { error in
            XCTAssertEqual(error as? PersistedStateValidationIssue, .currentPickConflictsWithUnresolvedAttempt)
        }
    }

    func testRejectsUnknownClosedBehavioralValue() {
        let fixture = openRevealFixture()
        var state = fixture.state
        state.attempts[0].outcomeRaw = "future_outcome"
        XCTAssertThrowsError(try PersistedStateValidator().validate(state)) { error in
            XCTAssertEqual(error as? PersistedStateValidationIssue, .invalidAttempt(id: fixture.attempt.id))
        }
    }

    func testRejectsNoncontiguousSessionSequence() {
        let fixture = openRevealFixture(sequence: 2)
        XCTAssertThrowsError(try PersistedStateValidator().validate(fixture.state)) { error in
            XCTAssertEqual(
                error as? PersistedStateValidationIssue,
                .invalidSessionSequence(sessionID: fixture.session.id)
            )
        }
    }

    func testRejectsCompletedItemWithoutExactMatchingMemory() {
        let item = BoxItem(
            title: "Paper",
            durationBucketRaw: DurationBucket.upTo30Minutes.rawValue,
            lifecycle: .completed,
            createdAt: now,
            updatedAt: now,
            completedAt: now
        )
        let oldMemory = CompletionMemory(
            sourceItemID: item.id,
            titleSnapshot: item.title,
            durationSnapshotRaw: item.durationBucketRaw,
            completedAt: now.addingTimeInterval(1)
        )
        XCTAssertThrowsError(
            try PersistedStateValidator().validate(PersistedProductState(items: [item], memories: [oldMemory]))
        ) { error in
            XCTAssertEqual(
                error as? PersistedStateValidationIssue,
                .completedItemHasNoMatchingMemory(itemID: item.id)
            )
        }
    }

    func testCompactionRetainsTheLongestWholeSessionPrefix() {
        let newest = endedSession(seconds: 3)
        let middle = endedSession(seconds: 2)
        let oldest = endedSession(seconds: 1)
        let attempts = [
            resolvedAttempt(session: newest, sequence: 1),
            resolvedAttempt(session: middle, sequence: 1),
            resolvedAttempt(session: middle, sequence: 2),
            resolvedAttempt(session: oldest, sequence: 1),
        ]
        let plan = DrawJournalCompactionPolicy(sessionLimit: 3, attemptLimit: 2)
            .plan(sessions: [oldest, newest, middle], attempts: attempts)
        XCTAssertEqual(plan.retainedSessionIDs, [newest.id])
        XCTAssertEqual(plan.deletedSessionIDs, [middle.id, oldest.id])
    }

    func testCompactionUsesUUIDBytesAsFinalTieBreaker() {
        let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let first = endedSession(seconds: 1, id: firstID)
        let second = endedSession(seconds: 1, id: secondID)
        let plan = DrawJournalCompactionPolicy(sessionLimit: 1, attemptLimit: 10)
            .plan(sessions: [second, first], attempts: [])
        XCTAssertEqual(plan.retainedSessionIDs, [firstID])
    }

    private func openRevealFixture(sequence: Int = 1) -> (
        state: PersistedProductState,
        item: BoxItem,
        session: DrawSession,
        attempt: DrawAttempt
    ) {
        let session = DrawSession(startedAt: now, availableTime: .upTo30Minutes)
        let attempt = DrawAttempt(
            sessionID: session.id,
            sequence: sequence,
            itemID: UUID(),
            eligibleCount: 1,
            shownAt: now,
            outcome: .unresolved
        )
        let item = BoxItem(
            id: attempt.itemID,
            title: "Paper",
            durationBucketRaw: DurationBucket.upTo30Minutes.rawValue,
            createdAt: now,
            updatedAt: now,
            lastShownAt: now
        )
        return (PersistedProductState(items: [item], sessions: [session], attempts: [attempt]), item, session, attempt)
    }

    private func endedSession(seconds: TimeInterval, id: UUID = UUID()) -> DrawSession {
        DrawSession(id: id, startedAt: now, endedAt: now.addingTimeInterval(seconds), availableTime: .notSure)
    }

    private func resolvedAttempt(session: DrawSession, sequence: Int) -> DrawAttempt {
        DrawAttempt(
            sessionID: session.id,
            sequence: sequence,
            itemID: UUID(),
            eligibleCount: 1,
            shownAt: now,
            outcome: .redrawn,
            resolvedAt: now
        )
    }
}

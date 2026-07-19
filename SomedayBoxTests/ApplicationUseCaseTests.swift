import Foundation
import XCTest
#if canImport(SomedayBox)
@testable import SomedayBox
#else
@testable import SomedayBoxDomain
#endif

final class ApplicationUseCaseTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 3_000_000)

    func testCaptureCommitsValidatedPaper() async throws {
        let repository = InMemoryProductRepository()
        let arbiter = MutationArbiter(repository: repository)
        let itemID = try await CapturePaperUseCase(arbiter: arbiter, clock: FixedClock(value: now))
            .execute(title: "  Read outside  ", note: nil, durationBucketRaw: DurationBucket.upTo30Minutes.rawValue)

        let state = try await repository.snapshot()
        XCTAssertEqual(state.items.count, 1)
        XCTAssertEqual(state.items.first?.id, itemID)
        XCTAssertEqual(state.items.first?.title, "Read outside")
    }

    func testUnresolvedGateTakesPriorityOverCaptureAndEditValidation() async throws {
        let fixture = unresolvedFixture(items: [item()])
        let repository = InMemoryProductRepository(state: fixture)
        let arbiter = MutationArbiter(repository: repository)

        do {
            _ = try await CapturePaperUseCase(arbiter: arbiter, clock: FixedClock(value: now))
                .execute(title: "", note: nil, durationBucketRaw: "unsupported_duration")
            XCTFail("Capture should be blocked by the unresolved draw.")
        } catch {
            XCTAssertEqual(error as? ApplicationError, .drawResolutionRequired)
        }

        do {
            try await EditPaperUseCase(arbiter: arbiter, clock: FixedClock(value: now)).execute(
                itemID: fixture.items[0].id,
                title: "",
                note: nil,
                durationBucketRaw: "unsupported_duration"
            )
            XCTFail("Edit should be blocked by the unresolved draw.")
        } catch {
            XCTAssertEqual(error as? ApplicationError, .drawResolutionRequired)
        }

        let stateAfterFailures = try await repository.snapshot()
        XCTAssertEqual(stateAfterFailures, fixture)
    }

    func testStartDrawCommitsRevealBeforeReturningIt() async throws {
        let repository = InMemoryProductRepository(state: PersistedProductState(items: [item()]))
        let arbiter = MutationArbiter(repository: repository)
        let result = try await StartDrawUseCase(
            arbiter: arbiter,
            clock: FixedClock(value: now),
            randomUnitInterval: { 0 }
        ).execute(availableTime: .upTo30Minutes)

        guard case let .revealed(returnedAttempt) = result else {
            return XCTFail("Expected a persisted reveal.")
        }
        let state = try await repository.snapshot()
        XCTAssertEqual(state.attempts, [returnedAttempt])
        XCTAssertEqual(state.items.first?.lastShownAt, returnedAttempt.shownAt)
        XCTAssertEqual(returnedAttempt.outcome, .unresolved)
    }

    func testRedrawNeverRepeatsAnItemWithinTheSession() async throws {
        let first = item(title: "First")
        let second = item(title: "Second")
        let repository = InMemoryProductRepository(state: PersistedProductState(items: [first, second]))
        let arbiter = MutationArbiter(repository: repository)
        _ = try await StartDrawUseCase(
            arbiter: arbiter,
            clock: FixedClock(value: now),
            randomUnitInterval: { 0 }
        ).execute(availableTime: .upTo30Minutes)
        let result = try await RedrawUseCase(
            arbiter: arbiter,
            clock: FixedClock(value: now.addingTimeInterval(1)),
            randomUnitInterval: { 0 }
        ).execute()

        guard case let .revealed(nextAttempt) = result else {
            return XCTFail("Expected the unseen paper.")
        }
        let state = try await repository.snapshot()
        XCTAssertEqual(Set(state.attempts.map(\.itemID)), [first.id, second.id])
        XCTAssertEqual(nextAttempt.itemID, second.id)
        XCTAssertEqual(state.attempts.first?.outcome, .redrawn)
    }

    func testAcceptCreatesTheSingletonCurrentPick() async throws {
        let source = item()
        let repository = InMemoryProductRepository(state: PersistedProductState(items: [source]))
        let arbiter = MutationArbiter(repository: repository)
        _ = try await StartDrawUseCase(
            arbiter: arbiter,
            clock: FixedClock(value: now),
            randomUnitInterval: { 0 }
        ).execute(availableTime: .upTo30Minutes)
        try await AcceptDrawUseCase(arbiter: arbiter, clock: FixedClock(value: now.addingTimeInterval(1))).execute()

        let state = try await repository.snapshot()
        XCTAssertEqual(state.currentPick?.itemID, source.id)
        XCTAssertEqual(state.attempts.first?.outcome, .accepted)
        XCTAssertNotNil(state.sessions.first?.endedAt)
    }

    func testCompletionCreatesImmutableMemoryAndClearsCurrentPick() async throws {
        let source = item()
        let repository = InMemoryProductRepository(state: PersistedProductState(items: [source]))
        let arbiter = MutationArbiter(repository: repository)
        _ = try await StartDrawUseCase(
            arbiter: arbiter,
            clock: FixedClock(value: now),
            randomUnitInterval: { 0 }
        ).execute(availableTime: .upTo30Minutes)
        try await AcceptDrawUseCase(arbiter: arbiter, clock: FixedClock(value: now)).execute()
        try await CompletePaperUseCase(arbiter: arbiter, clock: FixedClock(value: now.addingTimeInterval(-1)))
            .execute(itemID: source.id)

        let state = try await repository.snapshot()
        XCTAssertNil(state.currentPick)
        XCTAssertEqual(state.items.first?.lifecycle, .completed)
        XCTAssertEqual(state.memories.first?.titleSnapshot, source.title)
        XCTAssertEqual(state.memories.first?.completedAt, now.addingTimeInterval(-1))
        XCTAssertEqual(state.items.first?.completedAt, state.memories.first?.completedAt)
    }

    func testDeleteRemovesEveryWholeSessionContainingThePaper() async throws {
        let target = item(title: "Target")
        let survivor = item(title: "Survivor")
        let session = DrawSession(startedAt: now, endedAt: now, availableTime: .notSure)
        let attempts = [
            DrawAttempt(
                sessionID: session.id,
                sequence: 1,
                itemID: target.id,
                eligibleCount: 2,
                shownAt: now,
                outcome: .redrawn,
                resolvedAt: now
            ),
            DrawAttempt(
                sessionID: session.id,
                sequence: 2,
                itemID: survivor.id,
                eligibleCount: 1,
                shownAt: now,
                outcome: .dismissed,
                resolvedAt: now
            ),
        ]
        let repository = InMemoryProductRepository(
            state: PersistedProductState(items: [target, survivor], sessions: [session], attempts: attempts)
        )
        let arbiter = MutationArbiter(repository: repository)
        try await DeletePaperUseCase(arbiter: arbiter).execute(itemID: target.id)

        let state = try await repository.snapshot()
        XCTAssertEqual(state.items.map(\.id), [survivor.id])
        XCTAssertTrue(state.sessions.isEmpty)
        XCTAssertTrue(state.attempts.isEmpty)
    }

    private func item(title: String = "Paper") -> BoxItem {
        BoxItem(
            title: title,
            durationBucketRaw: DurationBucket.upTo30Minutes.rawValue,
            createdAt: now,
            updatedAt: now
        )
    }

    private func unresolvedFixture(items: [BoxItem]) -> PersistedProductState {
        var items = items
        let session = DrawSession(startedAt: now, availableTime: .upTo30Minutes)
        let attempt = DrawAttempt(
            sessionID: session.id,
            sequence: 1,
            itemID: items[0].id,
            eligibleCount: items.count,
            shownAt: now,
            outcome: .unresolved
        )
        items[0].lastShownAt = now
        return PersistedProductState(items: items, sessions: [session], attempts: [attempt])
    }
}

private struct FixedClock: Clock {
    let value: Date

    func now() -> Date { value }
}

private actor InMemoryProductRepository: ProductRepository {
    private var state: PersistedProductState

    init(state: PersistedProductState = PersistedProductState(items: [])) {
        self.state = state
    }

    func snapshot() -> PersistedProductState {
        state
    }

    func withTransaction(
        _ mutation: @escaping @Sendable (inout PersistedProductState) throws -> Void
    ) throws -> PersistedProductState {
        var candidate = state
        try mutation(&candidate)
        state = candidate
        return candidate
    }
}

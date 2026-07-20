import Foundation
import Testing
@testable import SomedayBox

@Suite("Atomic Core Box transaction receipts")
struct CoreBoxTransactionReceiptTests {
    @Test func completeReturnsTheCommittedMemoryIdentity() async throws {
        let repository = CoreBoxTestRepository(state: CoreBoxTestFixtures.coreBoxFixture())
        let transaction = try await CompletePaperUseCase(
            arbiter: MutationArbiter(repository: repository),
            clock: CoreBoxFixedClock(date: CoreBoxTestFixtures.date),
            makeID: { CoreBoxTestFixtures.memoryID }
        ).execute(itemID: CoreBoxTestFixtures.itemID)

        #expect(transaction.outcome == CompletePaperResult(
            itemID: CoreBoxTestFixtures.itemID,
            memoryID: CoreBoxTestFixtures.memoryID
        ))
        #expect(transaction.state.memories.map(\.id) == [CoreBoxTestFixtures.memoryID])
    }

    @Test func redrawExhaustionCarriesTheEndedSession() async throws {
        let repository = CoreBoxTestRepository(
            state: CoreBoxTestFixtures.coreBoxFixtureWithExhaustedUnresolvedAttempt()
        )
        let transaction = try await RedrawUseCase(
            arbiter: MutationArbiter(repository: repository),
            clock: CoreBoxFixedClock(date: CoreBoxTestFixtures.date)
        ).execute()

        #expect(transaction.outcome == .exhausted(
            previousAttemptID: CoreBoxTestFixtures.attemptID,
            previousItemID: CoreBoxTestFixtures.itemID,
            sessionID: CoreBoxTestFixtures.sessionID,
            context: DrawContext(preset: .fewMinutes)
        ))
        #expect(transaction.state.sessions.first?.endedAt == CoreBoxTestFixtures.date)
    }

    @Test func presentationMapperUsesExactCommittedReceiptIDs() {
        let itemID = CoreBoxTestFixtures.itemID
        let attemptID = CoreBoxTestFixtures.attemptID
        let snapshot = CoreBoxSceneSnapshot(
            inBoxCount: 1,
            drawableCount: 1,
            memoryCount: 0,
            hasCurrentPick: false,
            papers: [],
            rendererTier: .swiftUI2D,
            motionMode: .normal,
            snapshotVersion: 1
        )
        let accept = AppMutationProjection<AcceptDrawResult>.committed(
            outcome: AcceptDrawResult(attemptID: attemptID, sessionID: CoreBoxTestFixtures.sessionID, itemID: itemID),
            snapshot: snapshot
        )
        #expect(CoreBoxPresentationEventMapper.accept(accept) == .currentAttach(attemptID: attemptID, itemID: itemID))

        let failed = AppMutationProjection<PutBackPaperResult>.notCommitted(failure: .persistenceUnavailable)
        #expect(CoreBoxPresentationEventMapper.putBack(failed) == nil)
    }

    @Test func shareBatchCountsFreshReceiptsWithoutInferringFromDensity() {
        var batch = ShareImportBatchAccumulator()
        let first = UUID()
        batch.append(.imported(itemID: first, sourceID: UUID()))
        batch.append(.alreadyImported(itemID: UUID(), sourceID: UUID()))
        for _ in 0..<4 { batch.append(.imported(itemID: UUID(), sourceID: UUID())) }
        #expect(batch.value.freshItemIDs.count == 5)
        #expect(batch.value.alreadyImportedCount == 1)
        #expect(batch.boundedFreshItemIDs.count == 3)
    }

    @Test func sharePresentationCarriesAllFreshIDsForAggregateNotice() {
        let ids = (0..<4).map { _ in UUID() }
        let event = CoreBoxPresentationEventMapper.share(
            ShareImportBatchResult(freshItemIDs: ids, alreadyImportedCount: 2)
        )
        #expect(event == .shareArrival(freshItemIDs: ids))
    }
}

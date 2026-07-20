import Foundation
import Testing
@testable import SomedayBox

@MainActor
@Suite("AppModel presentation truth")
struct AppModelPresentationTests {
    @Test func failedCommitReturnsNotCommitted() async throws {
        let harness = try await CoreBoxAppModelHarness.make(
            forcedMutationFailure: .capacityExceeded(resource: .boxItems, limit: 1)
        )
        defer { try? FileManager.default.removeItem(at: harness.root) }

        let result = await harness.model.capture(title: "Walk", note: nil, duration: .upTo30Minutes)

        #expect(result == .notCommitted(failure: .application(.capacityExceeded(resource: .boxItems, limit: 1))))
        #expect(harness.model.requiresProjectionReconciliation == false)
    }

    @Test func committedCaptureReturnsReceiptAndMonotonicSnapshot() async throws {
        let harness = try await CoreBoxAppModelHarness.make()
        defer { try? FileManager.default.removeItem(at: harness.root) }

        let result = await harness.model.capture(title: "Walk", note: nil, duration: .upTo30Minutes)

        guard case let .committed(outcome, snapshot) = result else {
            Issue.record("Expected committed projection")
            return
        }
        #expect(outcome.itemID == CoreBoxTestIdentity.itemID)
        #expect(snapshot.snapshotVersion == 1)
        #expect(harness.model.snapshotVersion == 1)
    }

    @Test func projectionFailureBlocksDuplicateMutationAndReconcilesStableTruth() async throws {
        let harness = try await CoreBoxAppModelHarness.make(projectionFailures: 1)
        defer { try? FileManager.default.removeItem(at: harness.root) }

        let first = await harness.model.capture(title: "Walk", note: nil, duration: .upTo30Minutes)
        let second = await harness.model.capture(title: "Walk again", note: nil, duration: .upTo30Minutes)

        #expect(first.isCommittedButProjectionUnavailable)
        #expect(second == .notCommitted(failure: .reconciliationRequired))
        #expect(harness.model.state.items.map(\.title) == ["Walk"])

        await harness.model.retryProjection()

        #expect(harness.model.requiresProjectionReconciliation == false)
        #expect(harness.model.sceneSnapshot?.inBoxCount == 1)
    }

    @Test func failedProjectionAfterDrawStillExposesPersistedUnresolvedResult() async throws {
        let harness = try await CoreBoxAppModelHarness.make(projectionFailures: 1, drawReady: true)
        defer { try? FileManager.default.removeItem(at: harness.root) }

        let result = await harness.model.startDraw(context: DrawContext(preset: .fewMinutes))

        #expect(result.isCommittedButProjectionUnavailable)
        #expect(harness.model.unresolvedAttempt?.id == CoreBoxTestIdentity.attemptID)
        #expect(harness.model.requiresProjectionReconciliation)
    }

    @Test func anInFlightMutationRejectsASecondSubmission() async throws {
        let barrier = CoreBoxMutationBarrier()
        let harness = try await CoreBoxAppModelHarness.make(mutationBarrier: barrier)
        defer { try? FileManager.default.removeItem(at: harness.root) }

        async let first = harness.model.capture(title: "Walk", note: nil, duration: .upTo30Minutes)
        await barrier.waitUntilEntered()
        let second = await harness.model.capture(title: "Walk again", note: nil, duration: .upTo30Minutes)
        #expect(second == .notCommitted(failure: .operationInProgress))
        await barrier.release()
        _ = await first
        #expect(harness.model.state.items.map(\.title) == ["Walk"])
    }
}

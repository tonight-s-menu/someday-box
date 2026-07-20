import Foundation
import Testing
@testable import SomedayBox

@MainActor
@Suite("Core Box presentation coordinator")
struct CoreBoxPresentationCoordinatorTests {
    @Test func rejectsStaleSequenceAndSnapshotVersion() {
        let coordinator = CoreBoxPresentationCoordinator(snapshot: Self.snapshot(version: 8))
        #expect(coordinator.accept(CoreBoxSceneCommand(sequence: 1, kind: .reset, sourceSnapshotVersion: 7, motion: .normal)) == false)
        #expect(coordinator.accept(CoreBoxSceneCommand(sequence: 1, kind: .reset, sourceSnapshotVersion: 8, motion: .normal)))
        #expect(coordinator.accept(CoreBoxSceneCommand(sequence: 1, kind: .reset, sourceSnapshotVersion: 8, motion: .normal)) == false)
    }

    @Test func committedPresentationInterruptsGestureAndOwnsOnlyDeclaredChannels() {
        let coordinator = CoreBoxPresentationCoordinator(snapshot: Self.snapshot(version: 4))
        #expect(coordinator.beginRibbonPull(context: DrawContext(preset: .fewMinutes), nativeDrawEnabled: true))
        coordinator.updateRibbonPull(progress: 0.8)
        let result = coordinator.enqueue(event: CoreBoxPresentationEvent.captureDeposit(itemID: UUID()), sourceSnapshotVersion: 4)
        #expect(result?.cancelledOwner == .directGesture)
        #expect(coordinator.owner(of: CoreBoxChannel.paper) == .committedTransaction)
        #expect(coordinator.owner(of: CoreBoxChannel.leftEye) == nil)
        #expect(coordinator.owner(of: CoreBoxChannel.rightEye) == nil)
    }

    @Test func motionTimingUsesTheFrozenMatrix() {
        #expect(timing(family: .lid, motionMode: .normal, hasSeenFirstAnimation: false).durationMilliseconds == 400)
        #expect(timing(family: .lid, motionMode: .normal, hasSeenFirstAnimation: true).durationMilliseconds == 280)
        #expect(timing(family: .captureDeposit, motionMode: .quick, hasSeenFirstAnimation: true).durationMilliseconds == 220)
        #expect(timing(family: .drawReveal, motionMode: .reduced, hasSeenFirstAnimation: true).usesDepthMotion == false)
        #expect(timing(family: .completion, motionMode: .normal, hasSeenFirstAnimation: true).durationMilliseconds == 525)
    }

    @Test func hapticsAreGatedByPreference() {
        let policy = CoreBoxHapticPolicy()
        for event in [
            CoreBoxHapticEvent.thresholdLatch,
            .committedDeposit,
            .committedReveal,
            .committedCompletion
        ] {
            #expect(policy.permits(event, hapticsEnabled: false) == false)
            #expect(policy.permits(event, hapticsEnabled: true))
        }
    }

    @Test func committedSequenceReservesUnionAndRejectsReplay() {
        let coordinator = CoreBoxPresentationCoordinator(snapshot: Self.snapshot(version: 6))
        let sequence = CoreBoxCorrelatedSequence(
            sequence: 4,
            sourceSnapshotVersion: 6,
            motionMode: .normal,
            events: [
                .paperReturn(itemID: UUID()),
                .drawReveal(attemptID: UUID(), itemID: UUID())
            ]
        )
        #expect(coordinator.enqueue(sequence: sequence))
        #expect(coordinator.owner(of: .paper) == .committedTransaction)
        #expect(coordinator.owner(of: .lid) == .committedTransaction)
        #expect(coordinator.owner(of: .camera) == .committedTransaction)
        #expect(coordinator.enqueue(sequence: sequence) == false)
    }

    private static func snapshot(version: UInt64) -> CoreBoxSceneSnapshot {
        CoreBoxSceneSnapshot(
            inBoxCount: 1,
            drawAvailability: CoreBoxDrawAvailability(totalSupportedCount: 1, selectedContextEligibleCount: 1, presetCounts: []),
            memoryCount: 0,
            hasCurrentPick: false,
            papers: [],
            rendererTier: .full3D,
            motionMode: .normal,
            snapshotVersion: version
        )
    }
}

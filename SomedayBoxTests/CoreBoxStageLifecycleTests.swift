import Foundation
import RealityKit
import Testing
@testable import SomedayBox

@MainActor
@Suite("Core Box stage lifecycle")
struct CoreBoxStageLifecycleTests {
    @Test func aNewSnapshotUpdatesAnExistingAdapter() {
        let adapter = RecordingCoreBoxAdapter()
        let controller = CoreBoxStageController(loader: CoreBoxStageTestSupport.failingLoader, adapter: adapter)
        controller.update(snapshot: .fixture(version: 1, inBoxCount: 2), event: nil)
        controller.update(snapshot: .fixture(version: 2, inBoxCount: 3), event: nil)
        #expect(adapter.appliedSnapshotVersions == [1, 2])
        #expect(adapter.stablePaperCounts == [2, 3])
    }

    @Test func sameSnapshotEventDoesNotReapplyStablePoseFirst() {
        let adapter = RecordingCoreBoxAdapter()
        let controller = CoreBoxStageController(loader: CoreBoxStageTestSupport.failingLoader, adapter: adapter)
        let snapshot = CoreBoxSceneSnapshot.fixture(version: 4, inBoxCount: 2)
        controller.update(snapshot: snapshot, event: nil)
        controller.update(
            snapshot: snapshot,
            event: CoreBoxCorrelatedEvent(
                sequence: 9,
                event: .touch,
                sourceSnapshotVersion: 4,
                motionMode: .normal
            )
        )
        #expect(adapter.appliedSnapshotVersions == [4])
        #expect(adapter.appliedEvents.count == 1)
    }

    @Test func staleSnapshotCannotReplaceTheLatestStablePose() {
        let adapter = RecordingCoreBoxAdapter()
        let controller = CoreBoxStageController(loader: CoreBoxStageTestSupport.failingLoader, adapter: adapter)
        controller.update(snapshot: .fixture(version: 5, inBoxCount: 5), event: nil)
        controller.update(snapshot: .fixture(version: 4, inBoxCount: 4), event: nil)
        #expect(adapter.appliedSnapshotVersions == [5])
    }
}

@MainActor
private final class RecordingCoreBoxAdapter: CoreBoxPresentationAdapter {
    private(set) var appliedSnapshotVersions = [UInt64]()
    private(set) var stablePaperCounts = [Int]()
    private(set) var appliedEvents = [CoreBoxPresentationEvent]()
    private(set) var settleReasons = [CoreBoxSettleReason]()

    func apply(snapshot: CoreBoxSceneSnapshot) {
        appliedSnapshotVersions.append(snapshot.snapshotVersion)
        stablePaperCounts.append(snapshot.inBoxCount)
    }

    func apply(event: CoreBoxPresentationEvent, sourceSnapshotVersion _: UInt64) {
        appliedEvents.append(event)
    }

    func applyRibbon(progress _: Double, latched _: Bool) {}

    func settle(reason: CoreBoxSettleReason) {
        settleReasons.append(reason)
    }
}

private enum CoreBoxStageTestError: Error {
    case unavailable
}

private enum CoreBoxStageTestSupport {
    static let failingLoader: CoreBoxAssetLoader = {
        let source = CoreBoxAssetSource(
            descriptorData: { throw CoreBoxStageTestError.unavailable },
            assetData: { _ in throw CoreBoxStageTestError.unavailable },
            assetURL: { _ in throw CoreBoxStageTestError.unavailable },
            loadEntity: { _ in throw CoreBoxStageTestError.unavailable },
            identity: CoreBoxExpectedAssetIdentity(descriptorSHA256: "", fullTierSHA256: "", liteTierSHA256: ""),
            requiredEntityNames: [],
            publicMotionNames: [],
            animationEncoding: .runtimeTransformRecipesV1
        )
        return CoreBoxAssetLoader(source: source)
    }()
}

private extension CoreBoxSceneSnapshot {
    static func fixture(version: UInt64, inBoxCount: Int) -> Self {
        Self(
            inBoxCount: inBoxCount,
            drawableCount: inBoxCount,
            memoryCount: 0,
            hasCurrentPick: false,
            papers: [],
            rendererTier: .swiftUI2D,
            motionMode: .normal,
            snapshotVersion: version
        )
    }
}

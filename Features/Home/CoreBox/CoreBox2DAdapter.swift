import Foundation

@MainActor
final class CoreBox2DAdapter: CoreBoxPresentationAdapter {
    static let semanticActionIDs = ["capture", "draw", "peek", "current", "memories", "settings", "recovery"]

    private(set) var lastSnapshot: CoreBoxSceneSnapshot?
    private(set) var stablePose: CoreBoxStablePose?
    private(set) var events = [CoreBoxPresentationEvent]()
    private(set) var ribbonProgress = 0.0
    private(set) var lastSettleReason: CoreBoxSettleReason?
    private(set) var lastSemanticAction = ""

    var availableSemanticActionIDs: [String] { Self.semanticActionIDs }

    func apply(snapshot: CoreBoxSceneSnapshot) {
        lastSnapshot = snapshot
        stablePose = CoreBoxStablePose(snapshot: snapshot)
    }

    func apply(event: CoreBoxPresentationEvent, sourceSnapshotVersion: UInt64) {
        events.append(event)
        guard var pose = stablePose, pose.snapshotVersion == sourceSnapshotVersion else { return }
        switch event {
        case .captureReceive, .captureDeposit, .drawReveal, .currentAttach, .memoryStamp:
            pose = CoreBoxStablePose(
                snapshotVersion: pose.snapshotVersion,
                inBoxCount: pose.inBoxCount,
                visiblePapers: pose.visiblePapers,
                hasCurrentPick: pose.hasCurrentPick,
                memorySeamVisible: pose.memorySeamVisible,
                lid: pose.lid,
                draw: pose.draw,
                rendererTier: pose.rendererTier,
                motionMode: pose.motionMode
            )
        case .paperReturn, .touch, .failureSettle, .fallbackSettle:
            break
        }
        stablePose = pose
    }

    func applyRibbon(progress: Double, latched: Bool) {
        ribbonProgress = min(max(progress, 0), 1)
        guard let pose = stablePose else { return }
        stablePose = CoreBoxStablePose(
            snapshotVersion: pose.snapshotVersion,
            inBoxCount: pose.inBoxCount,
            visiblePapers: pose.visiblePapers,
            hasCurrentPick: pose.hasCurrentPick,
            memorySeamVisible: pose.memorySeamVisible,
            lid: pose.lid,
            draw: latched ? .pulling(progress: ribbonProgress) : pose.draw,
            rendererTier: pose.rendererTier,
            motionMode: pose.motionMode
        )
    }

    func settle(reason: CoreBoxSettleReason) {
        lastSettleReason = reason
        ribbonProgress = 0
    }

    /// Routes fallback controls through the same semantic action vocabulary as the 3D path.
    func performSemanticAction(_ actionID: String) {
        guard Self.semanticActionIDs.contains(actionID) else { return }
        lastSemanticAction = actionID
    }
}

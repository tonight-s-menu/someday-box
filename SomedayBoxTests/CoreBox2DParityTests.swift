import Testing
@testable import SomedayBox

@MainActor
@Suite("Core Box 2D fallback")
struct CoreBox2DParityTests {
    @Test func forcedAssetFailureKeepsAllSemanticActionsAvailable() {
        let adapter = CoreBox2DAdapter()
        adapter.apply(event: .fallbackSettle(.assetValidation), sourceSnapshotVersion: 1)
        adapter.applyRibbon(progress: 0.9, latched: true)
        adapter.settle(reason: .validationFailure)

        #expect(CoreBox2DAdapter.semanticActionIDs == ["capture", "draw", "peek", "current", "memories", "settings", "recovery"])
        #expect(adapter.events == [.fallbackSettle(.assetValidation)])
        #expect(adapter.ribbonProgress == 0)
        #expect(adapter.lastSettleReason == .validationFailure)
        for actionID in CoreBox2DAdapter.semanticActionIDs {
            adapter.performSemanticAction(actionID)
            #expect(adapter.lastSemanticAction == actionID)
        }
    }
}

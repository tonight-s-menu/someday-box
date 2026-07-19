import XCTest
@testable import SomedayBox

final class CoreBoxPresentationTests: XCTestCase {
    func testPullBelowThresholdDoesNotCommit() {
        var machine = CoreBoxPresentationStateMachine(renderer: .full3D)
        XCTAssertTrue(machine.beginPull())
        machine.updatePull(progress: 0.71)
        XCTAssertFalse(machine.releasePull())
        XCTAssertEqual(machine.interaction, .idle)
    }

    func testPullAtThresholdCommitsOnlyOnce() {
        var machine = CoreBoxPresentationStateMachine(renderer: .full3D)
        XCTAssertTrue(machine.beginPull())
        machine.updatePull(progress: 0.72)
        XCTAssertTrue(machine.releasePull())
        XCTAssertFalse(machine.releasePull())
    }

    func testBackgroundSettlesPresentationTruth() {
        var machine = CoreBoxPresentationStateMachine(renderer: .full3D)
        XCTAssertTrue(machine.begin(.peeking))
        machine.suspend()
        XCTAssertEqual(machine.lifecycle, .suspended)
        XCTAssertEqual(machine.interaction, .idle)
        XCTAssertEqual(machine.lid, .closed)
    }

    func testFallbackOnlyOccursAtStableBoundary() {
        var machine = CoreBoxPresentationStateMachine(renderer: .full3D)
        XCTAssertTrue(machine.begin(.capturing))
        machine.degrade(for: .memoryPressure)
        XCTAssertEqual(machine.renderer, .full3D)
        machine.finishInteraction()
        machine.degrade(for: .memoryPressure)
        XCTAssertEqual(machine.renderer, .lite3D)
    }

    func testStaleCommandsCannotOverrideNewProjection() {
        var machine = CoreBoxPresentationStateMachine(renderer: .full3D)
        XCTAssertTrue(machine.accept(command: .init(sequence: 2, kind: .reset, sourceSnapshotVersion: 3, motion: .normal)))
        XCTAssertFalse(machine.accept(command: .init(sequence: 1, kind: .openPeek, sourceSnapshotVersion: 2, motion: .normal)))
    }

    func testSceneProjectionCapsEntitiesAndContainsNoProductText() {
        let papers = (0..<5_000).map { CoreBoxPaperProjection(visualSeed: UInt64($0), imported: false, ageBand: 0) }
        let full = CoreBoxSceneSnapshot(inBoxCount: 5_000, drawableCount: 4_999, memoryCount: 1, hasCurrentPick: true, papers: papers, rendererTier: .full3D, motionMode: .normal, snapshotVersion: 1)
        let lite = CoreBoxSceneSnapshot(inBoxCount: 5_000, drawableCount: 4_999, memoryCount: 1, hasCurrentPick: true, papers: papers, rendererTier: .lite3D, motionMode: .normal, snapshotVersion: 1)
        XCTAssertEqual(full.papers.count, 24)
        XCTAssertEqual(lite.papers.count, 10)
    }

    func testPreferenceResetRestoresSafeDefaults() {
        let suite = "CoreBoxPresentationTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = CoreBoxPresentationPreferenceStore(defaults: defaults)
        store.save(.init(renderer: .swiftUI2D, quickAnimations: true, soundEnabled: false, hapticsEnabled: false, ambienceEnabled: false, lastDrawContext: "custom:45", hasSeenFirstAnimation: true))
        XCTAssertEqual(store.load().renderer, .swiftUI2D)
        store.reset()
        XCTAssertEqual(store.load(), .init())
    }
}

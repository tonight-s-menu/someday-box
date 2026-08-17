import RealityKit
import XCTest
@testable import SomedayBox

@MainActor
final class LidCaptureCoordinatorTests: XCTestCase {
    func testFirstThreeCompletedCapturesAreFullThenStandard() {
        let engine = AnimationTierEngine()
        let now = Date(timeIntervalSince1970: 10_000)
        var history = SceneAnimationHistory.empty

        for offset in 0..<3 {
            let occurrence = now.addingTimeInterval(TimeInterval(offset * 60))
            XCTAssertEqual(
                engine.tier(for: history, now: occurrence, forcedMinimal: false),
                .full
            )
            history = engine.recordingCompletion(in: history, at: occurrence)
        }

        XCTAssertEqual(
            engine.tier(
                for: history,
                now: now.addingTimeInterval(3 * 60),
                forcedMinimal: false
            ),
            .standard
        )
    }

    func testRepeatWithinThirtySecondsAndForcedQuickModeAreMinimal() {
        let engine = AnimationTierEngine()
        let last = Date(timeIntervalSince1970: 10_000)
        let history = SceneAnimationHistory(completedCount: 1, lastCompletedAt: last)

        XCTAssertEqual(
            engine.tier(for: history, now: last.addingTimeInterval(30), forcedMinimal: false),
            .minimal
        )
        XCTAssertEqual(
            engine.tier(for: history, now: last.addingTimeInterval(31), forcedMinimal: false),
            .full
        )
        XCTAssertEqual(
            engine.tier(for: .empty, now: last, forcedMinimal: true),
            .minimal
        )
    }

    func testEveryCaptureDropTimingMeetsItsBudget() {
        XCTAssertLessThanOrEqual(
            LidCaptureTiming.timing(for: .full).captureDropTotal.timeInterval,
            1.2
        )
        XCTAssertLessThanOrEqual(
            LidCaptureTiming.timing(for: .standard).captureDropTotal.timeInterval,
            0.5
        )
        XCTAssertLessThanOrEqual(
            LidCaptureTiming.timing(for: .minimal).captureDropTotal.timeInterval,
            0.25
        )
    }

    func testNormalEntryOpensAndRisesBeforePresentingTheSheet() async {
        let fixture = makeFixture()
        var slept: [Duration] = []
        let coordinator = LidCaptureCoordinator(
            historyStore: fixture.store,
            now: { fixture.now },
            sleep: { duration in slept.append(duration) }
        )

        coordinator.beginNormalCapture(reduceMotion: false)
        await coordinator.waitForCurrentSequence()

        XCTAssertEqual(coordinator.phase, .editing(.full))
        XCTAssertTrue(coordinator.presentsCaptureSheet)
        XCTAssertEqual(
            slept,
            [
                LidCaptureTiming.timing(for: .full).lidOpen,
                LidCaptureTiming.timing(for: .full).paperRise,
            ]
        )
    }

    func testLongPressPresentsImmediatelyWithoutPreamble() {
        let fixture = makeFixture()
        let coordinator = LidCaptureCoordinator(
            historyStore: fixture.store,
            now: { fixture.now },
            sleep: { _ in XCTFail("Fast capture must not sleep before showing the sheet.") }
        )

        coordinator.beginFastCapture()

        XCTAssertEqual(coordinator.phase, .editing(.minimal))
        XCTAssertTrue(coordinator.presentsCaptureSheet)
    }

    func testFailureKeepsTheDraftPresentationHoveringUntilUserCancels() async {
        let fixture = makeFixture()
        let coordinator = LidCaptureCoordinator(
            historyStore: fixture.store,
            now: { fixture.now },
            sleep: { _ in }
        )
        coordinator.beginFastCapture()

        coordinator.captureFailed()
        XCTAssertEqual(coordinator.phase, .failureHover(.minimal))
        XCTAssertTrue(coordinator.presentsCaptureSheet)

        coordinator.captureSheetDismissed(reduceMotion: true)
        await coordinator.waitForCurrentSequence()
        XCTAssertEqual(coordinator.phase, .idle)
    }

    func testSuccessfulCommitRunsDropThenReturnsToIdle() async {
        let fixture = makeFixture()
        var slept: [Duration] = []
        let coordinator = LidCaptureCoordinator(
            historyStore: fixture.store,
            now: { fixture.now },
            sleep: { duration in slept.append(duration) }
        )
        coordinator.beginFastCapture()

        coordinator.captureSucceeded(reduceMotion: false)
        await coordinator.waitForCurrentSequence()

        XCTAssertEqual(coordinator.phase, .idle)
        XCTAssertFalse(coordinator.presentsCaptureSheet)
        XCTAssertEqual(
            slept,
            [
                LidCaptureTiming.timing(for: .full).fold,
                LidCaptureTiming.timing(for: .full).drop,
                LidCaptureTiming.timing(for: .full).lidClose,
            ]
        )
    }

    func testFailurePhaseKeepsTheLidOpenAndFocusPaperVisible() throws {
        let box = BoxGeometry()
        let animator = LidCaptureSceneAnimator(box: box)
        let pivot = try XCTUnwrap(box.root.findEntity(named: BoxGeometry.NodeName.lidPivot))
        let focus = try XCTUnwrap(animator.root.findEntity(named: "CapturePaper"))

        animator.apply(.failureHover(.full), reduceMotion: false)

        XCTAssertTrue(focus.isEnabled)
        XCTAssertEqual(
            pivot.transform.rotation.angle,
            abs(BoxGeometry.Metrics.lidOpenAngle),
            accuracy: 1e-5
        )
    }

    func testLidHasTargetingAndCollisionComponents() throws {
        let box = BoxGeometry()
        let lid = try XCTUnwrap(box.root.findEntity(named: BoxGeometry.NodeName.lid))

        XCTAssertNotNil(lid.components[InputTargetComponent.self])
        XCTAssertNotNil(lid.components[CollisionComponent.self])
    }

    private func makeFixture() -> (store: AnimationTierHistoryStore, now: Date) {
        let suiteName = "LidCaptureCoordinatorTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock { defaults.removePersistentDomain(forName: suiteName) }
        return (
            AnimationTierHistoryStore(defaults: defaults),
            Date(timeIntervalSince1970: 10_000)
        )
    }
}

private extension Duration {
    var timeInterval: TimeInterval {
        let components = self.components
        return TimeInterval(components.seconds)
            + TimeInterval(components.attoseconds) / 1_000_000_000_000_000_000
    }
}

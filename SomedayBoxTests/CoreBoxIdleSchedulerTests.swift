import Foundation
import Testing
@testable import SomedayBox

@Suite("Core Box idle scheduler")
struct CoreBoxIdleSchedulerTests {
    @Test func opportunitiesStayWithinTwelveToTwentyFourSeconds() {
        var scheduler = CoreBoxIdleScheduler(seed: 42)
        let delays = (0..<20).map { _ in scheduler.nextDelaySeconds() }
        var repeatedScheduler = CoreBoxIdleScheduler(seed: 42)
        let repeated = (0..<20).map { _ in repeatedScheduler.nextDelaySeconds() }
        #expect(delays.allSatisfy { 12...24 ~= $0 })
        #expect(delays == repeated)
    }

    @Test func preconditionsFilterVocabulary() {
        var scheduler = CoreBoxIdleScheduler(seed: 7)
        let empty = scheduler.nextAction(preconditions: .stableEmpty)
        #expect([.blink, .listen].contains(empty))
        let current = scheduler.nextAction(preconditions: .stableWithPapersAndCurrent)
        #expect([.blink, .listen, .paperRustle, .currentGlance].contains(current))
    }

    @Test func coveringGateCancelsSleepAndTerminalSchedulesNextOpportunity() async {
        let clock = TestIdleClock()
        let recorder = CoreBoxIdleActionRecorder()
        let controller = CoreBoxIdleController(clock: clock, seed: 9) { action in
            await recorder.record(action)
        }
        await controller.begin(preconditions: .stableEmpty)
        // Let the controller's child task register its virtual sleep before asserting state.
        await Task.yield()
        #expect(await clock.pendingSleepCount == 1)
        await clock.advanceNextSleep()
        await Task.yield()
        #expect(await recorder.actions.count == 1)
        await controller.actionDidSettle(preconditions: .stableEmpty)
        await Task.yield()
        #expect(await clock.pendingSleepCount == 1)
        await controller.cancel(reason: .coveringGate)
        await Task.yield()
        #expect(await clock.cancelledSleepCount == 1)
        #expect(await clock.pendingSleepCount == 0)
    }
}

actor TestIdleClock: CoreBoxIdleClock {
    private var sleepers: [CheckedContinuation<Void, Error>] = []
    private(set) var cancelledSleepCount = 0

    var pendingSleepCount: Int { sleepers.count }

    func sleep(for _: Duration) async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                sleepers.append(continuation)
            }
        } onCancel: {
            Task { await self.cancelOne() }
        }
    }

    func advanceNextSleep() {
        guard !sleepers.isEmpty else { return }
        sleepers.removeFirst().resume()
    }

    private func cancelOne() {
        guard !sleepers.isEmpty else { return }
        cancelledSleepCount += 1
        sleepers.removeFirst().resume(throwing: CancellationError())
    }
}

actor CoreBoxIdleActionRecorder {
    private(set) var actions: [CoreBoxIdleAction] = []

    func record(_ action: CoreBoxIdleAction) { actions.append(action) }
}

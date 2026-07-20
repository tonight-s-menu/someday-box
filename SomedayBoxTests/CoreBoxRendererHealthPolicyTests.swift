import Testing
@testable import SomedayBox

@Suite("Core Box renderer health policy")
struct CoreBoxRendererHealthPolicyTests {
    @Test func lowPowerCapsFullAtLiteAndNeverUpgradesExplicit2D() {
        var full = CoreBoxRendererHealthPolicy(preference: .full3D, effectiveTier: .full3D)
        #expect(full.receive(.lowPowerChanged(true), nowSeconds: 10) == .lite3D)
        var twoD = CoreBoxRendererHealthPolicy(preference: .simplified2D, effectiveTier: .swiftUI2D)
        #expect(twoD.receive(.lowPowerChanged(false), nowSeconds: 10) == nil)
    }

    @Test func frameBudgetRequiresTwoConsecutiveCompleteBreachWindows() {
        var policy = CoreBoxRendererHealthPolicy(preference: .automatic, effectiveTier: .full3D)
        let breach = CoreBoxFrameWindow(sampleCount: 120, elapsedMilliseconds: 3_000, p95Milliseconds: 26, hardBudgetFraction: 0.11)
        #expect(policy.receive(.frameWindow(breach), nowSeconds: 10) == nil)
        #expect(policy.receive(.frameWindow(breach), nowSeconds: 14) == .lite3D)
    }

    @Test func accumulatorCarriesActiveSamplesAcrossSettledActionGaps() {
        var accumulator = CoreBoxFrameWindowAccumulator(requiredSampleCount: 120)
        for _ in 0..<60 { #expect(accumulator.appendActiveFrame(milliseconds: 26) == nil) }
        accumulator.suspendAtStableBoundary()
        #expect(accumulator.sampleCount == 60)
        for index in 0..<60 {
            let window = accumulator.appendActiveFrame(milliseconds: 26)
            #expect((index == 59) == (window != nil))
        }
        #expect(accumulator.sampleCount == 0)
    }

    @Test func accumulatorResetsOnlyForLifecycleOrTierDiscontinuity() {
        var accumulator = CoreBoxFrameWindowAccumulator(requiredSampleCount: 120)
        _ = accumulator.appendActiveFrame(milliseconds: 16)
        accumulator.suspendAtStableBoundary()
        #expect(accumulator.sampleCount == 1)
        accumulator.reset(reason: .background)
        #expect(accumulator.sampleCount == 0)
    }

    @Test func sustainedSlowWindowsRemainBreachesBeyondFourSeconds() {
        let fullSlow = CoreBoxFrameWindow(sampleCount: 120, elapsedMilliseconds: 4_080, p95Milliseconds: 34, hardBudgetFraction: 1.0)
        var full = CoreBoxRendererHealthPolicy(preference: .automatic, effectiveTier: .full3D)
        #expect(full.receive(.frameWindow(fullSlow), nowSeconds: 1) == nil)
        #expect(full.receive(.frameWindow(fullSlow), nowSeconds: 6) == .lite3D)

        let liteSlow = CoreBoxFrameWindow(sampleCount: 120, elapsedMilliseconds: 4_920, p95Milliseconds: 41, hardBudgetFraction: 0.0)
        var lite = CoreBoxRendererHealthPolicy(preference: .automatic, effectiveTier: .lite3D)
        #expect(lite.receive(.frameWindow(liteSlow), nowSeconds: 1) == nil)
        #expect(lite.receive(.frameWindow(liteSlow), nowSeconds: 7) == .swiftUI2D)
    }

    @Test func healthyWindowResetsBreachAndCooldownCoalescesStrongestRequest() {
        var policy = CoreBoxRendererHealthPolicy(preference: .automatic, effectiveTier: .full3D)
        let breach = CoreBoxFrameWindow(sampleCount: 120, elapsedMilliseconds: 3_000, p95Milliseconds: 26, hardBudgetFraction: 0.11)
        let healthy = CoreBoxFrameWindow(sampleCount: 120, elapsedMilliseconds: 3_000, p95Milliseconds: 16, hardBudgetFraction: 0.0)
        _ = policy.receive(.frameWindow(breach), nowSeconds: 1)
        #expect(policy.receive(.frameWindow(healthy), nowSeconds: 5) == nil)
        #expect(policy.receive(.frameWindow(breach), nowSeconds: 9) == nil)
        #expect(policy.receive(.memoryWarning, nowSeconds: 10) == .lite3D)
        policy.didPublish(tier: .lite3D, nowSeconds: 10)
        #expect(policy.receive(.thermal(.critical), nowSeconds: 15) == nil)
        #expect(policy.poll(nowSeconds: 40) == .swiftUI2D)
    }
}

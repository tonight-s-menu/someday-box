import Testing
@testable import SomedayBox

@Suite("Core Box ribbon interaction")
struct CoreBoxRibbonInteractionTests {
    @Test func unselectedOrDisabledRibbonCannotBegin() {
        var state = CoreBoxRibbonInteractionState()
        let unselected = state.begin(context: nil, nativeDrawEnabled: true, pointerCount: 1)
        #expect(unselected == false)
        let disabled = state.begin(context: DrawContext(preset: .fewMinutes), nativeDrawEnabled: false, pointerCount: 1)
        #expect(disabled == false)
    }

    @Test func thresholdLatchesOnceAndRearmsAtPointFiveFive() {
        var state = CoreBoxRibbonInteractionState()
        let began = state.begin(context: DrawContext(preset: .fewMinutes), nativeDrawEnabled: true, pointerCount: 1)
        #expect(began)
        #expect(state.update(progress: 0.73) == .thresholdLatched)
        #expect(state.update(progress: 0.71) == .progressChanged)
        #expect(state.update(progress: 0.73) == .progressChanged)
        #expect(state.update(progress: 0.54) == .thresholdRearmed)
        #expect(state.update(progress: 0.73) == .thresholdLatched)
    }

    @Test func releaseEmitsExactlyOneIntentOnlyAtOrAbovePointSevenTwo() {
        var state = CoreBoxRibbonInteractionState()
        let began = state.begin(context: DrawContext(preset: .fewMinutes), nativeDrawEnabled: true, pointerCount: 1)
        #expect(began)
        _ = state.update(progress: 0.72)
        #expect(state.release() == .draw(DrawContext(preset: .fewMinutes)))
        #expect(state.release() == .none)
    }

    @Test func secondPointerCancelsToRest() {
        var state = CoreBoxRibbonInteractionState.armedFixture
        _ = state.update(progress: 1.0)
        #expect(state.pointerCountChanged(to: 2) == .cancelled)
        #expect(state.progress == 0)
        #expect(state.isLatched == false)
    }

    @Test func resolvedBodyTapReactsThenPeeksOnlyWhenSemanticTargetIsAvailable() {
        #expect(CoreBoxBodyTapPolicy().disposition(peekIntentAvailable: true) == .reactThenPeek)
        #expect(CoreBoxBodyTapPolicy().disposition(peekIntentAvailable: false) == .reactOnly)
    }
}

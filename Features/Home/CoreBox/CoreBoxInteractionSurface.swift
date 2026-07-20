import Foundation

public enum CoreBoxRibbonFeedback: Equatable, Sendable {
    case none
    case progressChanged
    case thresholdLatched
    case thresholdRearmed
    case cancelled
    case draw(DrawContext)
}

public enum CoreBoxBodyTapDisposition: Equatable, Sendable {
    case reactOnly
    case reactThenPeek
}

public struct CoreBoxBodyTapPolicy: Sendable {
    public init() {}

    public func disposition(peekIntentAvailable: Bool) -> CoreBoxBodyTapDisposition {
        peekIntentAvailable ? .reactThenPeek : .reactOnly
    }
}

public struct CoreBoxRibbonInteractionState: Equatable, Sendable {
    public static let threshold = 0.72
    public static let hysteresisRearm = 0.55

    public private(set) var context: DrawContext?
    public private(set) var progress = 0.0
    public private(set) var isLatched = false
    public private(set) var isActive = false
    public private(set) var hasEmittedIntent = false

    public init() {}

    public static var armedFixture: Self {
        var state = Self()
        _ = state.begin(context: DrawContext(preset: .fewMinutes), nativeDrawEnabled: true, pointerCount: 1)
        return state
    }

    @discardableResult
    public mutating func begin(
        context: DrawContext?,
        nativeDrawEnabled: Bool,
        pointerCount: Int,
        foreground: Bool = true,
        coveringGate: Bool = false
    ) -> Bool {
        guard foreground, !coveringGate, nativeDrawEnabled, pointerCount == 1, context?.isValid == true else {
            reset()
            return false
        }
        self.context = context
        progress = 0
        isLatched = false
        hasEmittedIntent = false
        isActive = true
        return true
    }

    public mutating func update(progress value: Double) -> CoreBoxRibbonFeedback {
        guard isActive, !hasEmittedIntent else { return .none }
        let next = min(max(value, 0), 1)
        let feedback: CoreBoxRibbonFeedback
        if !isLatched, next >= Self.threshold {
            isLatched = true
            feedback = .thresholdLatched
        } else if isLatched, next < Self.hysteresisRearm {
            isLatched = false
            feedback = .thresholdRearmed
        } else {
            feedback = .progressChanged
        }
        progress = next
        return feedback
    }

    public mutating func release() -> CoreBoxRibbonFeedback {
        guard isActive, !hasEmittedIntent else { return .none }
        guard isLatched, progress >= Self.threshold, let context else {
            reset()
            return .none
        }
        hasEmittedIntent = true
        isActive = false
        return .draw(context)
    }

    public mutating func pointerCountChanged(to count: Int) -> CoreBoxRibbonFeedback {
        guard count <= 1 else {
            reset()
            return .cancelled
        }
        return .none
    }

    public mutating func cancel() -> CoreBoxRibbonFeedback {
        reset()
        return .cancelled
    }

    private mutating func reset() {
        context = nil
        progress = 0
        isLatched = false
        isActive = false
        hasEmittedIntent = false
    }
}

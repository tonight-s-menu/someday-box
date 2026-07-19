import Foundation

public enum PaperLifecycleTransition: Sendable {
    case complete
    case archive
    case restore
    case putBack
}

public enum LifecycleTransitionFailure: Error, Equatable, Sendable {
    case invalidTransition(from: PaperLifecycle, transition: PaperLifecycleTransition)
}

extension PaperLifecycleTransition: Equatable {}

public struct PaperLifecyclePolicy: Sendable {
    public init() {}

    public func resultingLifecycle(
        from lifecycle: PaperLifecycle,
        applying transition: PaperLifecycleTransition
    ) throws -> PaperLifecycle {
        switch (lifecycle, transition) {
        case (.active, .complete): .completed
        case (.active, .archive): .archived
        case (.archived, .restore), (.completed, .putBack): .active
        default: throw LifecycleTransitionFailure.invalidTransition(from: lifecycle, transition: transition)
        }
    }
}

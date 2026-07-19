import Foundation

public protocol ProductRepository: Sendable {
    /// Returns the latest committed state for launch and explicit UI refreshes.
    func snapshot() async throws -> PersistedProductState

    /// Applies one mutation atomically and returns the committed domain state.
    /// Actor-backed adapters must serialize this entire closure, including persistence.
    func withTransaction(
        _ mutation: @escaping @Sendable (inout PersistedProductState) throws -> Void
    ) async throws -> PersistedProductState
}

public enum ProductMutationKind: Equatable, Sendable {
    case capture
    case edit
    case startDraw
    case redraw
    case accept
    case dismiss
    case complete
    case putBack
    case archive
    case restore
    case delete

    var mayResolveUnresolvedDraw: Bool {
        switch self {
        case .redraw, .accept, .dismiss: true
        default: false
        }
    }
}

public enum ApplicationError: Error, Equatable, Sendable {
    case invalidContent(BoxItemValidationFailure)
    case unsupportedDuration
    case itemNotFound(UUID)
    case sessionNotFound(UUID)
    case unresolvedAttemptNotFound
    case currentPickExists
    case drawResolutionRequired
    case unsupportedPolicy(String)
    case invalidLifecycle(LifecycleTransitionFailure)
    case emptyPool(EmptyPoolReason)
    case invalidPersistedState(PersistedStateValidationIssue)
}

import Foundation

/// A composition-owned application service that enforces mutation policy.
///
/// This type is intentionally not a lock. The shared repository serializes transactions;
/// app composition retains one arbiter and injects it into every mutation use case.
public struct MutationArbiter: Sendable {
    private let repository: any ProductRepository
    private let validator: PersistedStateValidator

    public init(
        repository: any ProductRepository,
        validator: PersistedStateValidator = PersistedStateValidator()
    ) {
        self.repository = repository
        self.validator = validator
    }

    public func perform(
        _ kind: ProductMutationKind,
        mutation: @escaping @Sendable (inout PersistedProductState) throws -> Void
    ) async throws -> PersistedProductState {
        try await repository.withTransaction { state in
            try validate(state)
            let hasUnresolvedAttempt = state.attempts.contains { $0.outcome == .unresolved }
            if hasUnresolvedAttempt && !kind.mayResolveUnresolvedDraw {
                throw ApplicationError.drawResolutionRequired
            }
            try mutation(&state)
            try validate(state)
        }
    }

    public func snapshotForIdempotencyCheck() async throws -> PersistedProductState {
        try await repository.snapshot()
    }

    private func validate(_ state: PersistedProductState) throws {
        do {
            try validator.validate(state)
        } catch let issue as PersistedStateValidationIssue {
            throw ApplicationError.invalidPersistedState(issue)
        }
    }
}

enum ApplicationDomainRules {
    static func requireCapacity(
        for resource: StoreCapacityResource,
        currentCount: Int,
        adding additionalCount: Int = 1
    ) throws {
        do {
            try StoreCountCapacityPolicy().requireCapacity(
                for: resource,
                currentCount: currentCount,
                adding: additionalCount
            )
        } catch let violation as StoreCountCapacityViolation {
            throw ApplicationError.capacityExceeded(
                resource: violation.resource,
                limit: violation.limit
            )
        }
    }

    static func validatedContent(title: String, note: String?) throws -> ValidatedPaperContent {
        do {
            return try PaperContentValidator().validate(title: title, note: note)
        } catch let failure as BoxItemValidationFailure {
            throw ApplicationError.invalidContent(failure)
        }
    }

    static func requireSupportedDuration(_ rawValue: String) throws {
        guard DurationBucket(rawValue: rawValue) != nil else {
            throw ApplicationError.unsupportedDuration
        }
    }

    static func compactEndedJournal(_ state: inout PersistedProductState) {
        let plan = DrawJournalCompactionPolicy().plan(sessions: state.sessions, attempts: state.attempts)
        guard !plan.deletedSessionIDs.isEmpty else { return }
        state.sessions.removeAll { plan.deletedSessionIDs.contains($0.id) }
        state.attempts.removeAll { plan.deletedSessionIDs.contains($0.sessionID) }
    }

    static func unresolvedAttemptIndex(in state: PersistedProductState) throws -> Int {
        guard let index = state.attempts.firstIndex(where: { $0.outcome == .unresolved }) else {
            throw ApplicationError.unresolvedAttemptNotFound
        }
        return index
    }

    static func sessionIndex(id: UUID, in state: PersistedProductState) throws -> Int {
        guard let index = state.sessions.firstIndex(where: { $0.id == id }) else {
            throw ApplicationError.sessionNotFound(id)
        }
        return index
    }

    static func itemIndex(id: UUID, in state: PersistedProductState) throws -> Int {
        guard let index = state.items.firstIndex(where: { $0.id == id }) else {
            throw ApplicationError.itemNotFound(id)
        }
        return index
    }

    static func transition(
        _ item: inout BoxItem,
        applying transition: PaperLifecycleTransition
    ) throws {
        do {
            item.lifecycle = try PaperLifecyclePolicy().resultingLifecycle(
                from: item.lifecycle,
                applying: transition
            )
        } catch let failure as LifecycleTransitionFailure {
            throw ApplicationError.invalidLifecycle(failure)
        }
    }
}

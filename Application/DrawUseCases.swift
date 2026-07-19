import Foundation

public enum StartDrawResult: Equatable, Sendable {
    case revealed(DrawAttempt)
}

public enum RedrawResult: Equatable, Sendable {
    case revealed(DrawAttempt)
    case exhausted
}

private struct SuppliedUnitRandomGenerator: RandomNumberGenerating {
    let value: Double

    mutating func nextUnitInterval() -> Double { value }
}

public struct StartDrawUseCase: Sendable {
    private let arbiter: MutationArbiter
    private let clock: any Clock
    private let makeID: @Sendable () -> UUID
    private let randomUnitInterval: @Sendable () -> Double

    public init(
        arbiter: MutationArbiter,
        clock: any Clock = SystemClock(),
        makeID: @escaping @Sendable () -> UUID = { UUID() },
        randomUnitInterval: @escaping @Sendable () -> Double = { Double.random(in: 0..<1) }
    ) {
        self.arbiter = arbiter
        self.clock = clock
        self.makeID = makeID
        self.randomUnitInterval = randomUnitInterval
    }

    public func execute(availableTime: AvailableTime) async throws -> StartDrawResult {
        guard let context = DrawContext(storageValue: availableTime.rawValue) else {
            throw ApplicationError.emptyPool(.overTimeBudget)
        }
        return try await execute(context: context)
    }

    public func execute(context: DrawContext) async throws -> StartDrawResult {
        guard context.isValid else { throw ApplicationError.emptyPool(.overTimeBudget) }
        let sessionID = makeID()
        let attemptID = makeID()
        let timestamp = clock.now()
        let randomValue = randomUnitInterval()
        let state = try await arbiter.perform(.startDraw) { state in
            guard state.currentPick == nil else { throw ApplicationError.currentPickExists }
            ApplicationDomainRules.compactEndedJournal(&state)

            let candidates: [BoxItem]
            switch CandidatePoolBuilder().build(
                items: state.items,
                context: context,
                currentPick: nil,
                reservedItemID: nil,
                shownItemIDs: []
            ) {
            case let .candidates(values): candidates = values
            case let .empty(reason): throw ApplicationError.emptyPool(reason)
            }

            var generator = SuppliedUnitRandomGenerator(value: randomValue)
            guard let selected = DrawSelectionPolicy().select(
                from: candidates,
                context: context,
                now: timestamp,
                using: &generator
            ) else {
                throw ApplicationError.emptyPool(.noActivePapers)
            }

            try ApplicationDomainRules.requireCapacity(
                for: .drawSessions,
                currentCount: state.sessions.count
            )
            try ApplicationDomainRules.requireCapacity(
                for: .drawAttempts,
                currentCount: state.attempts.count
            )

            state.sessions.append(
                DrawSession(id: sessionID, startedAt: timestamp, context: context)
            )
            state.attempts.append(
                DrawAttempt(
                    id: attemptID,
                    sessionID: sessionID,
                    sequence: 1,
                    itemID: selected.id,
                    eligibleCount: candidates.count,
                    shownAt: timestamp,
                    outcome: .unresolved
                )
            )
            let itemIndex = try ApplicationDomainRules.itemIndex(id: selected.id, in: state)
            state.items[itemIndex].lastShownAt = timestamp
        }
        return .revealed(state.attempts.first { $0.id == attemptID }!)
    }
}

public struct RedrawUseCase: Sendable {
    private let arbiter: MutationArbiter
    private let clock: any Clock
    private let makeID: @Sendable () -> UUID
    private let randomUnitInterval: @Sendable () -> Double

    public init(
        arbiter: MutationArbiter,
        clock: any Clock = SystemClock(),
        makeID: @escaping @Sendable () -> UUID = { UUID() },
        randomUnitInterval: @escaping @Sendable () -> Double = { Double.random(in: 0..<1) }
    ) {
        self.arbiter = arbiter
        self.clock = clock
        self.makeID = makeID
        self.randomUnitInterval = randomUnitInterval
    }

    public func execute() async throws -> RedrawResult {
        let nextAttemptID = makeID()
        let timestamp = clock.now()
        let randomValue = randomUnitInterval()
        let state = try await arbiter.perform(.redraw) { state in
            ApplicationDomainRules.compactEndedJournal(&state)
            let unresolvedIndex = try ApplicationDomainRules.unresolvedAttemptIndex(in: state)
            let unresolved = state.attempts[unresolvedIndex]
            guard DrawSelectionPolicy.supportedVersions.contains(unresolved.policyVersion) else {
                throw ApplicationError.unsupportedPolicy(unresolved.policyVersion)
            }
            let sessionIndex = try ApplicationDomainRules.sessionIndex(id: unresolved.sessionID, in: state)
            let context = state.sessions[sessionIndex].context
            guard context.isValid else {
                throw ApplicationError.invalidPersistedState(.invalidSession(id: unresolved.sessionID))
            }

            let shownItemIDs = Set(
                state.attempts.lazy.filter { $0.sessionID == unresolved.sessionID }.map(\.itemID)
            )
            let pool = CandidatePoolBuilder().build(
                items: state.items,
                context: context,
                currentPick: nil,
                reservedItemID: nil,
                shownItemIDs: shownItemIDs
            )

            guard case let .candidates(candidates) = pool else {
                state.attempts[unresolvedIndex].outcomeRaw = DrawAttemptOutcome.redrawn.rawValue
                state.attempts[unresolvedIndex].resolvedAt = timestamp
                state.sessions[sessionIndex].endedAt = timestamp
                return
            }

            var generator = SuppliedUnitRandomGenerator(value: randomValue)
            guard let selected = DrawSelectionPolicy().select(
                from: candidates,
                context: context,
                now: timestamp,
                using: &generator
            ) else {
                state.attempts[unresolvedIndex].outcomeRaw = DrawAttemptOutcome.redrawn.rawValue
                state.attempts[unresolvedIndex].resolvedAt = timestamp
                state.sessions[sessionIndex].endedAt = timestamp
                return
            }
            try ApplicationDomainRules.requireCapacity(
                for: .drawAttempts,
                currentCount: state.attempts.count
            )
            state.attempts[unresolvedIndex].outcomeRaw = DrawAttemptOutcome.redrawn.rawValue
            state.attempts[unresolvedIndex].resolvedAt = timestamp
            state.attempts.append(
                DrawAttempt(
                    id: nextAttemptID,
                    sessionID: unresolved.sessionID,
                    sequence: unresolved.sequence + 1,
                    itemID: selected.id,
                    eligibleCount: candidates.count,
                    shownAt: timestamp,
                    outcome: .unresolved
                )
            )
            let itemIndex = try ApplicationDomainRules.itemIndex(id: selected.id, in: state)
            state.items[itemIndex].lastShownAt = timestamp
        }
        if let attempt = state.attempts.first(where: { $0.id == nextAttemptID }) {
            return .revealed(attempt)
        }
        return .exhausted
    }
}

public struct AcceptDrawUseCase: Sendable {
    private let arbiter: MutationArbiter
    private let clock: any Clock

    public init(arbiter: MutationArbiter, clock: any Clock = SystemClock()) {
        self.arbiter = arbiter
        self.clock = clock
    }

    public func execute() async throws {
        let timestamp = clock.now()
        _ = try await arbiter.perform(.accept) { state in
            ApplicationDomainRules.compactEndedJournal(&state)
            let attemptIndex = try ApplicationDomainRules.unresolvedAttemptIndex(in: state)
            let attempt = state.attempts[attemptIndex]
            guard state.currentPick == nil else { throw ApplicationError.currentPickExists }
            state.attempts[attemptIndex].outcomeRaw = DrawAttemptOutcome.accepted.rawValue
            state.attempts[attemptIndex].resolvedAt = timestamp
            let sessionIndex = try ApplicationDomainRules.sessionIndex(id: attempt.sessionID, in: state)
            state.sessions[sessionIndex].endedAt = timestamp
            state.currentPick = CurrentPick(itemID: attempt.itemID, acceptedAt: timestamp)
        }
    }
}

public struct DismissDrawUseCase: Sendable {
    private let arbiter: MutationArbiter
    private let clock: any Clock

    public init(arbiter: MutationArbiter, clock: any Clock = SystemClock()) {
        self.arbiter = arbiter
        self.clock = clock
    }

    public func execute() async throws {
        let timestamp = clock.now()
        _ = try await arbiter.perform(.dismiss) { state in
            ApplicationDomainRules.compactEndedJournal(&state)
            let attemptIndex = try ApplicationDomainRules.unresolvedAttemptIndex(in: state)
            let sessionID = state.attempts[attemptIndex].sessionID
            state.attempts[attemptIndex].outcomeRaw = DrawAttemptOutcome.dismissed.rawValue
            state.attempts[attemptIndex].resolvedAt = timestamp
            let sessionIndex = try ApplicationDomainRules.sessionIndex(id: sessionID, in: state)
            state.sessions[sessionIndex].endedAt = timestamp
        }
    }
}

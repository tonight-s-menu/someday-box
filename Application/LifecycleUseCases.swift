import Foundation

public struct CompletePaperUseCase: Sendable {
    private let arbiter: MutationArbiter
    private let clock: any Clock
    private let makeID: @Sendable () -> UUID

    public init(
        arbiter: MutationArbiter,
        clock: any Clock = SystemClock(),
        makeID: @escaping @Sendable () -> UUID = { UUID() }
    ) {
        self.arbiter = arbiter
        self.clock = clock
        self.makeID = makeID
    }

    public func execute(itemID: UUID) async throws {
        let timestamp = clock.now()
        let memoryID = makeID()
        _ = try await arbiter.perform(.complete) { state in
            let itemIndex = try ApplicationDomainRules.itemIndex(id: itemID, in: state)
            try ApplicationDomainRules.requireCapacity(
                for: .completionMemories,
                currentCount: state.memories.count
            )
            try ApplicationDomainRules.transition(&state.items[itemIndex], applying: .complete)
            state.items[itemIndex].completedAt = timestamp
            state.items[itemIndex].updatedAt = timestamp
            let item = state.items[itemIndex]
            state.memories.append(
                CompletionMemory(
                    id: memoryID,
                    sourceItemID: item.id,
                    titleSnapshot: item.title,
                    noteSnapshot: item.note,
                    durationSnapshotRaw: item.durationBucketRaw,
                    completedAt: timestamp
                )
            )
            if state.currentPick?.itemID == itemID { state.currentPick = nil }
        }
    }
}

public struct PutBackPaperUseCase: Sendable {
    private let arbiter: MutationArbiter
    private let clock: any Clock

    public init(arbiter: MutationArbiter, clock: any Clock = SystemClock()) {
        self.arbiter = arbiter
        self.clock = clock
    }

    public func execute(itemID: UUID) async throws {
        let timestamp = clock.now()
        _ = try await arbiter.perform(.putBack) { state in
            let itemIndex = try ApplicationDomainRules.itemIndex(id: itemID, in: state)
            if state.currentPick?.itemID == itemID {
                state.currentPick = nil
                state.items[itemIndex].updatedAt = timestamp
                return
            }
            try ApplicationDomainRules.transition(&state.items[itemIndex], applying: .putBack)
            state.items[itemIndex].completedAt = nil
            state.items[itemIndex].updatedAt = timestamp
        }
    }
}

public struct ArchivePaperUseCase: Sendable {
    private let arbiter: MutationArbiter
    private let clock: any Clock

    public init(arbiter: MutationArbiter, clock: any Clock = SystemClock()) {
        self.arbiter = arbiter
        self.clock = clock
    }

    public func execute(itemID: UUID) async throws {
        let timestamp = clock.now()
        _ = try await arbiter.perform(.archive) { state in
            let itemIndex = try ApplicationDomainRules.itemIndex(id: itemID, in: state)
            try ApplicationDomainRules.transition(&state.items[itemIndex], applying: .archive)
            state.items[itemIndex].updatedAt = timestamp
            if state.currentPick?.itemID == itemID { state.currentPick = nil }
        }
    }
}

public struct RestorePaperUseCase: Sendable {
    private let arbiter: MutationArbiter
    private let clock: any Clock

    public init(arbiter: MutationArbiter, clock: any Clock = SystemClock()) {
        self.arbiter = arbiter
        self.clock = clock
    }

    public func execute(itemID: UUID) async throws {
        let timestamp = clock.now()
        _ = try await arbiter.perform(.restore) { state in
            let itemIndex = try ApplicationDomainRules.itemIndex(id: itemID, in: state)
            try ApplicationDomainRules.transition(&state.items[itemIndex], applying: .restore)
            state.items[itemIndex].updatedAt = timestamp
        }
    }
}

public struct DeletePaperUseCase: Sendable {
    private let arbiter: MutationArbiter

    public init(arbiter: MutationArbiter) {
        self.arbiter = arbiter
    }

    public func execute(itemID: UUID) async throws {
        _ = try await arbiter.perform(.delete) { state in
            _ = try ApplicationDomainRules.itemIndex(id: itemID, in: state)
            let sessionIDs = Set(
                state.attempts.lazy.filter { $0.itemID == itemID }.map(\.sessionID)
            )
            state.items.removeAll { $0.id == itemID }
            state.memories.removeAll { $0.sourceItemID == itemID }
            state.sessions.removeAll { sessionIDs.contains($0.id) }
            state.attempts.removeAll { sessionIDs.contains($0.sessionID) }
            if state.currentPick?.itemID == itemID { state.currentPick = nil }
        }
    }
}

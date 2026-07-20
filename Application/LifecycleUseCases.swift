import Foundation

public struct CompletePaperResult: Equatable, Sendable {
    public let itemID: UUID
    public let memoryID: UUID

    public init(itemID: UUID, memoryID: UUID) {
        self.itemID = itemID
        self.memoryID = memoryID
    }
}

public struct PutBackPaperResult: Equatable, Sendable {
    public let itemID: UUID

    public init(itemID: UUID) { self.itemID = itemID }
}

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

    public func execute(itemID: UUID) async throws -> ProductTransaction<CompletePaperResult> {
        let timestamp = clock.now()
        let memoryID = makeID()
        return try await arbiter.perform(.complete) { state in
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
            return CompletePaperResult(itemID: itemID, memoryID: memoryID)
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

    public func execute(itemID: UUID) async throws -> ProductTransaction<PutBackPaperResult> {
        let timestamp = clock.now()
        return try await arbiter.perform(.putBack) { state in
            let itemIndex = try ApplicationDomainRules.itemIndex(id: itemID, in: state)
            if state.currentPick?.itemID == itemID {
                state.currentPick = nil
                state.items[itemIndex].updatedAt = timestamp
                return PutBackPaperResult(itemID: itemID)
            }
            try ApplicationDomainRules.transition(&state.items[itemIndex], applying: .putBack)
            state.items[itemIndex].completedAt = nil
            state.items[itemIndex].updatedAt = timestamp
            return PutBackPaperResult(itemID: itemID)
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

    public func execute(itemID: UUID) async throws -> ProductTransaction<Void> {
        let timestamp = clock.now()
        return try await arbiter.perform(.archive) { state in
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

    public func execute(itemID: UUID) async throws -> ProductTransaction<Void> {
        let timestamp = clock.now()
        return try await arbiter.perform(.restore) { state in
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

    public func execute(itemID: UUID) async throws -> ProductTransaction<Void> {
        return try await arbiter.perform(.delete) { state in
            _ = try ApplicationDomainRules.itemIndex(id: itemID, in: state)
            let sessionIDs = Set(
                state.attempts.lazy.filter { $0.itemID == itemID }.map(\.sessionID)
            )
            state.items.removeAll { $0.id == itemID }
            state.memories.removeAll { $0.sourceItemID == itemID }
            state.sources.removeAll { $0.itemID == itemID }
            state.sessions.removeAll { sessionIDs.contains($0.id) }
            state.attempts.removeAll { sessionIDs.contains($0.sessionID) }
            if state.currentPick?.itemID == itemID { state.currentPick = nil }
        }
    }
}

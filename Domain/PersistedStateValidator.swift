import Foundation

public enum DomainRecordKind: String, Equatable, Sendable {
    case item
    case session
    case attempt
    case memory
}

public enum PersistedStateValidationIssue: Error, Equatable, Sendable {
    case duplicateID(kind: DomainRecordKind, id: UUID)
    case invalidItem(id: UUID)
    case invalidSession(id: UUID)
    case invalidAttempt(id: UUID)
    case invalidMemory(id: UUID)
    case missingSession(attemptID: UUID)
    case missingItem(recordID: UUID)
    case sessionHasNoAttempts(sessionID: UUID)
    case invalidSessionSequence(sessionID: UUID)
    case repeatedItemInSession(sessionID: UUID, itemID: UUID)
    case policyMismatch(attemptID: UUID)
    case invalidOpenSession(sessionID: UUID)
    case multipleOpenSessions
    case multipleUnresolvedAttempts
    case invalidUnresolvedReservation(attemptID: UUID)
    case invalidCurrentPick
    case currentPickConflictsWithUnresolvedAttempt
    case completedItemHasNoMatchingMemory(itemID: UUID)
}

public struct PersistedProductState: Equatable, Sendable {
    public var items: [BoxItem]
    public var currentPick: CurrentPick?
    public var sessions: [DrawSession]
    public var attempts: [DrawAttempt]
    public var memories: [CompletionMemory]

    public init(
        items: [BoxItem],
        currentPick: CurrentPick? = nil,
        sessions: [DrawSession] = [],
        attempts: [DrawAttempt] = [],
        memories: [CompletionMemory] = []
    ) {
        self.items = items
        self.currentPick = currentPick
        self.sessions = sessions
        self.attempts = attempts
        self.memories = memories
    }
}

public struct PersistedStateValidator: Sendable {
    public init() {}

    public func validate(_ state: PersistedProductState) throws {
        try validateUniqueIDs(state.items.map(\.id), kind: .item)
        try validateUniqueIDs(state.sessions.map(\.id), kind: .session)
        try validateUniqueIDs(state.attempts.map(\.id), kind: .attempt)
        try validateUniqueIDs(state.memories.map(\.id), kind: .memory)

        let itemsByID = Dictionary(uniqueKeysWithValues: state.items.map { ($0.id, $0) })
        let sessionsByID = Dictionary(uniqueKeysWithValues: state.sessions.map { ($0.id, $0) })
        let attemptsBySession = Dictionary(grouping: state.attempts, by: \.sessionID)
        let memoriesByItem = Dictionary(grouping: state.memories, by: \.sourceItemID)

        for item in state.items {
            do { try PaperContentValidator().validate(item) } catch {
                throw PersistedStateValidationIssue.invalidItem(id: item.id)
            }
        }

        for memory in state.memories {
            guard itemsByID[memory.sourceItemID] != nil else {
                throw PersistedStateValidationIssue.missingItem(recordID: memory.id)
            }
            do {
                _ = try PaperContentValidator().validate(title: memory.titleSnapshot, note: memory.noteSnapshot)
                try OpenRawValueValidator().validate(memory.durationSnapshotRaw)
            } catch {
                throw PersistedStateValidationIssue.invalidMemory(id: memory.id)
            }
        }

        for item in state.items where item.lifecycle == .completed {
            guard memoriesByItem[item.id, default: []].contains(where: { $0.completedAt == item.completedAt }) else {
                throw PersistedStateValidationIssue.completedItemHasNoMatchingMemory(itemID: item.id)
            }
        }

        for attempt in state.attempts {
            guard let session = sessionsByID[attempt.sessionID] else {
                throw PersistedStateValidationIssue.missingSession(attemptID: attempt.id)
            }
            guard itemsByID[attempt.itemID] != nil else {
                throw PersistedStateValidationIssue.missingItem(recordID: attempt.id)
            }
            guard attempt.policyVersion == session.policyVersion else {
                throw PersistedStateValidationIssue.policyMismatch(attemptID: attempt.id)
            }
            guard attempt.eligibleCount > 0,
                  let outcome = attempt.outcome,
                  (outcome == .unresolved) == (attempt.resolvedAt == nil) else {
                throw PersistedStateValidationIssue.invalidAttempt(id: attempt.id)
            }
        }

        let openSessions = state.sessions.filter { $0.endedAt == nil }
        guard openSessions.count <= 1 else { throw PersistedStateValidationIssue.multipleOpenSessions }

        let unresolvedAttempts = state.attempts.filter { $0.outcome == .unresolved }
        guard unresolvedAttempts.count <= 1 else {
            throw PersistedStateValidationIssue.multipleUnresolvedAttempts
        }

        for session in state.sessions {
            do {
                guard session.availableTime != nil else { throw RawValueValidationFailure.empty }
                try OpenRawValueValidator().validate(session.policyVersion, requiresPrintableASCII: true)
            } catch {
                throw PersistedStateValidationIssue.invalidSession(id: session.id)
            }

            let sessionAttempts = attemptsBySession[session.id, default: []].sorted { $0.sequence < $1.sequence }
            guard !sessionAttempts.isEmpty else {
                throw PersistedStateValidationIssue.sessionHasNoAttempts(sessionID: session.id)
            }
            guard sessionAttempts.map(\.sequence) == Array(1...sessionAttempts.count) else {
                throw PersistedStateValidationIssue.invalidSessionSequence(sessionID: session.id)
            }

            var seenItems = Set<UUID>()
            for attempt in sessionAttempts {
                guard seenItems.insert(attempt.itemID).inserted else {
                    throw PersistedStateValidationIssue.repeatedItemInSession(
                        sessionID: session.id,
                        itemID: attempt.itemID
                    )
                }
            }

            let finalOutcome = sessionAttempts.last?.outcome
            guard sessionAttempts.dropLast().allSatisfy({ $0.outcome == .redrawn }) else {
                throw PersistedStateValidationIssue.invalidOpenSession(sessionID: session.id)
            }
            let isOpen = session.endedAt == nil
            guard isOpen == (finalOutcome == .unresolved) else {
                throw PersistedStateValidationIssue.invalidOpenSession(sessionID: session.id)
            }
        }

        if let unresolved = unresolvedAttempts.first {
            guard let item = itemsByID[unresolved.itemID],
                  item.lifecycle == .active,
                  item.supportedDuration != nil,
                  item.lastShownAt == unresolved.shownAt else {
                throw PersistedStateValidationIssue.invalidUnresolvedReservation(attemptID: unresolved.id)
            }
        }

        if let currentPick = state.currentPick {
            guard let item = itemsByID[currentPick.itemID], item.lifecycle == .active else {
                throw PersistedStateValidationIssue.invalidCurrentPick
            }
            guard unresolvedAttempts.isEmpty else {
                throw PersistedStateValidationIssue.currentPickConflictsWithUnresolvedAttempt
            }
        }
    }

    private func validateUniqueIDs(_ ids: [UUID], kind: DomainRecordKind) throws {
        var seen = Set<UUID>()
        for id in ids where !seen.insert(id).inserted {
            throw PersistedStateValidationIssue.duplicateID(kind: kind, id: id)
        }
    }
}

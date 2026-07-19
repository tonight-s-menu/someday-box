import Foundation
import SwiftData

public enum SwiftDataRepositoryError: Error, Equatable, Sendable {
    case multipleCurrentPickRecords
}

public actor SwiftDataProductRepository: ProductRepository {
    private let context: ModelContext
    private let validator: PersistedStateValidator

    public init(container: ModelContainer, validator: PersistedStateValidator = PersistedStateValidator()) {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        self.context = context
        self.validator = validator
    }

    public func snapshot() throws -> PersistedProductState {
        try loadValidatedState()
    }

    public func withTransaction(
        _ mutation: @escaping @Sendable (inout PersistedProductState) throws -> Void
    ) async throws -> PersistedProductState {
        do {
            var committedState: PersistedProductState?
            try context.transaction {
                var state = try loadValidatedState()
                try mutation(&state)
                try validator.validate(state)
                try synchronize(state)
                try context.save()
                committedState = state
            }
            guard let committedState else {
                preconditionFailure("A successful SwiftData transaction must produce a committed state")
            }
            return committedState
        } catch {
            context.rollback()
            throw error
        }
    }

    private func loadValidatedState() throws -> PersistedProductState {
        let itemRecords = try context.fetch(FetchDescriptor<SomedayBoxSchemaV1.ItemRecord>())
        let currentPickRecords = try context.fetch(FetchDescriptor<SomedayBoxSchemaV1.CurrentPickRecord>())
        let sessionRecords = try context.fetch(FetchDescriptor<SomedayBoxSchemaV1.SessionRecord>())
        let attemptRecords = try context.fetch(FetchDescriptor<SomedayBoxSchemaV1.AttemptRecord>())
        let memoryRecords = try context.fetch(FetchDescriptor<SomedayBoxSchemaV1.MemoryRecord>())

        guard currentPickRecords.count <= 1 else {
            throw SwiftDataRepositoryError.multipleCurrentPickRecords
        }
        let state = PersistedProductState(
            items: try itemRecords.map { try $0.domainValue() },
            currentPick: currentPickRecords.first?.domainValue(),
            sessions: try sessionRecords.map { try $0.domainValue() },
            attempts: try attemptRecords.map { try $0.domainValue() },
            memories: memoryRecords.map { $0.domainValue() }
        )
        try validator.validate(state)
        return state
    }

    private func synchronize(_ state: PersistedProductState) throws {
        try synchronizeItems(state.items)
        try synchronizeCurrentPick(state.currentPick)
        try synchronizeSessions(state.sessions)
        try synchronizeAttempts(state.attempts)
        try synchronizeMemories(state.memories)
    }

    private func synchronizeItems(_ items: [BoxItem]) throws {
        let records = try context.fetch(FetchDescriptor<SomedayBoxSchemaV1.ItemRecord>())
        var recordsByID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        for item in items {
            if let record = recordsByID.removeValue(forKey: item.id) {
                record.title = item.title
                record.note = item.note
                record.durationBucketRaw = item.durationBucketRaw
                record.lifecycleRaw = item.lifecycleRaw
                record.createdAt = item.createdAt
                record.updatedAt = item.updatedAt
                record.completedAt = item.completedAt
                record.lastShownAt = item.lastShownAt
            } else {
                context.insert(SomedayBoxSchemaV1.ItemRecord(domain: item))
            }
        }
        recordsByID.values.forEach(context.delete)
    }

    private func synchronizeCurrentPick(_ currentPick: CurrentPick?) throws {
        let records = try context.fetch(FetchDescriptor<SomedayBoxSchemaV1.CurrentPickRecord>())
        guard let currentPick else {
            records.forEach(context.delete)
            return
        }
        if let record = records.first {
            record.itemID = currentPick.itemID
            record.acceptedAt = currentPick.acceptedAt
            records.dropFirst().forEach(context.delete)
        } else {
            context.insert(SomedayBoxSchemaV1.CurrentPickRecord(domain: currentPick))
        }
    }

    private func synchronizeSessions(_ sessions: [DrawSession]) throws {
        let records = try context.fetch(FetchDescriptor<SomedayBoxSchemaV1.SessionRecord>())
        var recordsByID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        for session in sessions {
            if let record = recordsByID.removeValue(forKey: session.id) {
                record.startedAt = session.startedAt
                record.endedAt = session.endedAt
                record.availableTimeRaw = session.availableTimeRaw
                record.policyVersion = session.policyVersion
            } else {
                context.insert(SomedayBoxSchemaV1.SessionRecord(domain: session))
            }
        }
        recordsByID.values.forEach(context.delete)
    }

    private func synchronizeAttempts(_ attempts: [DrawAttempt]) throws {
        let records = try context.fetch(FetchDescriptor<SomedayBoxSchemaV1.AttemptRecord>())
        var recordsByID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        for attempt in attempts {
            if let record = recordsByID.removeValue(forKey: attempt.id) {
                record.sessionID = attempt.sessionID
                record.sequence = attempt.sequence
                record.itemID = attempt.itemID
                record.eligibleCount = attempt.eligibleCount
                record.policyVersion = attempt.policyVersion
                record.shownAt = attempt.shownAt
                record.outcomeRaw = attempt.outcomeRaw
                record.resolvedAt = attempt.resolvedAt
            } else {
                context.insert(SomedayBoxSchemaV1.AttemptRecord(domain: attempt))
            }
        }
        recordsByID.values.forEach(context.delete)
    }

    private func synchronizeMemories(_ memories: [CompletionMemory]) throws {
        let records = try context.fetch(FetchDescriptor<SomedayBoxSchemaV1.MemoryRecord>())
        var recordsByID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        for memory in memories {
            if let record = recordsByID.removeValue(forKey: memory.id) {
                record.sourceItemID = memory.sourceItemID
                record.titleSnapshot = memory.titleSnapshot
                record.noteSnapshot = memory.noteSnapshot
                record.durationSnapshotRaw = memory.durationSnapshotRaw
                record.completedAt = memory.completedAt
            } else {
                context.insert(SomedayBoxSchemaV1.MemoryRecord(domain: memory))
            }
        }
        recordsByID.values.forEach(context.delete)
    }
}

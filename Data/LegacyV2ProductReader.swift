import SwiftData

public actor LegacyV2ProductReader {
    private let context: ModelContext
    private let validator: PersistedStateValidator

    public init(container: ModelContainer, validator: PersistedStateValidator = PersistedStateValidator()) {
        context = ModelContext(container)
        context.autosaveEnabled = false
        self.validator = validator
    }

    public func snapshot() throws -> PersistedProductState {
        let items = try context.fetch(FetchDescriptor<SomedayBoxSchemaV2.ItemRecord>())
        let picks = try context.fetch(FetchDescriptor<SomedayBoxSchemaV2.CurrentPickRecord>())
        let sessions = try context.fetch(FetchDescriptor<SomedayBoxSchemaV2.SessionRecord>())
        let attempts = try context.fetch(FetchDescriptor<SomedayBoxSchemaV2.AttemptRecord>())
        let memories = try context.fetch(FetchDescriptor<SomedayBoxSchemaV2.MemoryRecord>())
        let sources = try context.fetch(FetchDescriptor<SomedayBoxSchemaV2.SourceRecord>())
        guard picks.count <= 1 else { throw SwiftDataRepositoryError.multipleCurrentPickRecords }
        let state = PersistedProductState(
            items: try items.map { try $0.domainValue() },
            currentPick: picks.first?.domainValue(),
            sessions: try sessions.map { try $0.domainValue() },
            attempts: try attempts.map { try $0.domainValue() },
            memories: memories.map { $0.domainValue() },
            sources: sources.map { $0.domainValue() }
        )
        try validator.validate(state)
        return state
    }
}

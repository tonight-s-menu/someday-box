import Foundation

public actor StoreRecoveryService {
    private let configuration: StoreGenerationConfiguration
    private let bootstrap: StoreGenerationBootstrap
    private let journalStore: StoreGenerationJournalStore

    public init(configuration: StoreGenerationConfiguration) {
        self.configuration = configuration
        bootstrap = StoreGenerationBootstrap(configuration: configuration)
        journalStore = StoreGenerationJournalStore(configuration: configuration)
    }

    public func recover(from backupData: Data) async throws {
        let payload = try BackupDocumentCodecV3().decode(backupData)
        try PersistedStateValidator().validate(payload.state)
        let prior = try? bootstrap.loadOrCreateActiveGeneration()
        let target = try bootstrap.createGeneration()
        var journal = prior.map {
            StoreGenerationOperationJournal(
                operationID: UUID(),
                kind: .restore,
                priorGeneration: $0,
                newGeneration: target,
                phase: .prepared,
                expectedProductDigest: "recovery-v3",
                committedCleanupGenerationIDs: []
            )
        }
        do {
            if let journal { try journalStore.write(journal) }
            let repository = SwiftDataProductRepository(container: try bootstrap.openContainer(for: target))
            _ = try await repository.withTransaction { $0 = payload.state }
            let reopened = SwiftDataProductRepository(container: try bootstrap.openContainer(for: target))
            guard try await reopened.snapshot() == payload.state else { throw GenerationRepositoryError.stagedDigestMismatch }
            if var value = journal {
                value.phase = .validated; try journalStore.write(value)
                value.phase = .switching; try journalStore.write(value)
                try bootstrap.activate(target)
                value.phase = .switched; try journalStore.write(value)
                value.phase = .committed; try journalStore.write(value)
                value.phase = .cleaning; try journalStore.write(value)
                value.phase = .finalized; try journalStore.write(value)
                try journalStore.remove()
                journal = value
            } else {
                try bootstrap.activate(target)
            }
        } catch {
            if journal?.phase.isCommitted != true { try? bootstrap.removeGeneration(id: target.id) }
            throw error
        }
    }

    public func eraseAllAfterExplicitConfirmation() async throws {
        let target = try bootstrap.createGeneration()
        let repository = SwiftDataProductRepository(container: try bootstrap.openContainer(for: target))
        _ = try await repository.snapshot()
        try bootstrap.activate(target)
        let generations = (try? FileManager.default.contentsOfDirectory(at: configuration.generationsURL, includingPropertiesForKeys: nil)) ?? []
        for url in generations where url.lastPathComponent != target.id.uuidString {
            guard UUID(uuidString: url.lastPathComponent) != nil else { continue }
            try FileManager.default.removeItem(at: url)
        }
        try? journalStore.remove()
        CoreBoxPresentationPreferenceStore().resetAllNamespaces()
        UserDefaults.standard.removeObject(forKey: "hasSeenIntroduction")
    }
}

import CryptoKit
import Foundation

public enum GenerationRepositoryError: Error, Equatable, Sendable {
    case operationInProgress
    case stagedDigestMismatch
    case recoveryRequired
    case committedCleanupIncomplete
}

public actor GenerationProductRepository: ProductRepository {
    private enum GateState: Equatable {
        case idle
        case ordinaryMutation
        case exporting
        case generationOperation
    }

    private let bootstrap: StoreGenerationBootstrap
    private let journalStore: StoreGenerationJournalStore
    private var currentGeneration: ActiveStoreGeneration
    private var currentRepository: SwiftDataProductRepository
    private var gateState = GateState.idle

    private init(
        configuration: StoreGenerationConfiguration,
        generation: ActiveStoreGeneration,
        repository: SwiftDataProductRepository
    ) {
        bootstrap = StoreGenerationBootstrap(configuration: configuration)
        journalStore = StoreGenerationJournalStore(configuration: configuration)
        currentGeneration = generation
        currentRepository = repository
    }

    public static func open(configuration: StoreGenerationConfiguration) async throws -> GenerationProductRepository {
        let bootstrap = StoreGenerationBootstrap(configuration: configuration)
        let journalStore = StoreGenerationJournalStore(configuration: configuration)
        var active = try bootstrap.loadOrCreateActiveGeneration()

        if var journal = try journalStore.load() {
            if journal.phase.isCommitted {
                do {
                    let container = try bootstrap.openContainer(for: journal.newGeneration)
                    let repository = SwiftDataProductRepository(container: container)
                    let state = try await repository.snapshot()
                    guard try productDigest(state) == journal.expectedProductDigest else {
                        throw GenerationRepositoryError.stagedDigestMismatch
                    }
                }
                try bootstrap.activate(journal.newGeneration)
                journal.phase = .cleaning
                try journalStore.write(journal)
                for id in journal.committedCleanupGenerationIDs {
                    try bootstrap.removeGeneration(id: id)
                }
                journal.phase = .finalized
                try journalStore.write(journal)
                try journalStore.remove()
                active = journal.newGeneration
            } else {
                try bootstrap.activate(journal.priorGeneration)
                for id in journal.rollbackCleanupGenerationIDs {
                    try bootstrap.removeGeneration(id: id)
                }
                try journalStore.remove()
                active = journal.priorGeneration
            }
        }

        let container = try bootstrap.openContainer(for: active)
        let repository = SwiftDataProductRepository(container: container)
        _ = try await repository.snapshot()
        let currentSchema = StoreSchemaVersion(SomedayBoxSchemaV2.versionIdentifier)
        if active.schemaVersion != currentSchema {
            active = ActiveStoreGeneration(id: active.id, schemaVersion: currentSchema)
            try bootstrap.activate(active)
        }
        return GenerationProductRepository(
            configuration: configuration,
            generation: active,
            repository: repository
        )
    }

    public func snapshot() async throws -> PersistedProductState {
        try await currentRepository.snapshot()
    }

    public func exportSnapshot() async throws -> PersistedProductState {
        guard gateState == .idle else { throw GenerationRepositoryError.operationInProgress }
        gateState = .exporting
        defer { gateState = .idle }
        let state = try await currentRepository.snapshot()
        guard !state.attempts.contains(where: { $0.outcome == .unresolved }) else {
            throw ApplicationError.drawResolutionRequired
        }
        return state
    }

    public func withTransaction(
        _ mutation: @escaping @Sendable (inout PersistedProductState) throws -> Void
    ) async throws -> PersistedProductState {
        guard gateState == .idle else { throw GenerationRepositoryError.operationInProgress }
        gateState = .ordinaryMutation
        defer { gateState = .idle }
        return try await currentRepository.withTransaction(mutation)
    }

    public func restore(validatedState: PersistedProductState) async throws -> PersistedProductState {
        try await replaceAll(with: validatedState, kind: .restore)
    }

    public func eraseAll() async throws -> PersistedProductState {
        try await replaceAll(with: PersistedProductState(items: []), kind: .erase)
    }

    public func activeGeneration() -> ActiveStoreGeneration {
        currentGeneration
    }

    private func replaceAll(
        with targetState: PersistedProductState,
        kind: StoreGenerationOperationKind
    ) async throws -> PersistedProductState {
        guard gateState == .idle else { throw GenerationRepositoryError.operationInProgress }
        gateState = .generationOperation

        do {
            let currentState = try await currentRepository.snapshot()
            guard !currentState.attempts.contains(where: { $0.outcome == .unresolved }) else {
                throw ApplicationError.drawResolutionRequired
            }
        } catch {
            gateState = .idle
            throw error
        }

        let expectedDigest: String
        do {
            expectedDigest = try Self.productDigest(targetState)
        } catch {
            gateState = .idle
            throw error
        }

        let priorGeneration = currentGeneration
        let newGeneration = ActiveStoreGeneration(
            id: UUID(),
            schemaVersion: StoreSchemaVersion(SomedayBoxSchemaV2.versionIdentifier)
        )
        var journal = StoreGenerationOperationJournal(
            operationID: UUID(),
            kind: kind,
            priorGeneration: priorGeneration,
            newGeneration: newGeneration,
            phase: .prepared,
            expectedProductDigest: expectedDigest
        )
        var didSwitchRepository = false
        var committedDurably = false

        do {
            try journalStore.write(journal)
            _ = try bootstrap.createGeneration(id: newGeneration.id)
            try await Self.populate(
                targetState,
                generation: newGeneration,
                bootstrap: bootstrap
            )
            let freshContainer = try bootstrap.openContainer(for: newGeneration)
            let freshRepository = SwiftDataProductRepository(container: freshContainer)
            let reopenedState = try await freshRepository.snapshot()
            guard try Self.productDigest(reopenedState) == expectedDigest else {
                throw GenerationRepositoryError.stagedDigestMismatch
            }
            journal.phase = .validated
            try journalStore.write(journal)
            journal.phase = .switching
            try journalStore.write(journal)
            try bootstrap.activate(newGeneration)
            journal.phase = .switched
            try journalStore.write(journal)

            currentRepository = freshRepository
            currentGeneration = newGeneration
            didSwitchRepository = true
            journal.phase = .committed
            try journalStore.write(journal)
            committedDurably = true
            journal.phase = .cleaning
            try journalStore.write(journal)
            for id in journal.committedCleanupGenerationIDs {
                try bootstrap.removeGeneration(id: id)
            }
            journal.phase = .finalized
            try journalStore.write(journal)
            try journalStore.remove()
            gateState = .idle
            return reopenedState
        } catch {
            if committedDurably {
                // The new generation is authoritative after the durable commit boundary.
                // Keep the gate closed until startup reconciliation completes cleanup.
                throw GenerationRepositoryError.committedCleanupIncomplete
            }
            do {
                try bootstrap.activate(priorGeneration)
                if didSwitchRepository {
                    let priorContainer = try bootstrap.openContainer(for: priorGeneration)
                    let priorRepository = SwiftDataProductRepository(container: priorContainer)
                    _ = try await priorRepository.snapshot()
                    currentRepository = priorRepository
                    currentGeneration = priorGeneration
                }
                try bootstrap.removeGeneration(id: newGeneration.id)
                try journalStore.remove()
                gateState = .idle
            } catch {
                throw GenerationRepositoryError.recoveryRequired
            }
            throw error
        }
    }

    private static func populate(
        _ state: PersistedProductState,
        generation: ActiveStoreGeneration,
        bootstrap: StoreGenerationBootstrap
    ) async throws {
        let container = try bootstrap.openContainer(for: generation)
        let repository = SwiftDataProductRepository(container: container)
        _ = try await repository.withTransaction { stagedState in
            stagedState = state
        }
    }

    private static func productDigest(_ state: PersistedProductState) throws -> String {
        let data = try BackupDocumentCodecV1().encode(
            state: state,
            metadata: BackupDocumentMetadataV1(
                exportedAt: Date(timeIntervalSince1970: 0),
                appMarketingVersion: "generation-digest-v1",
                appBuild: "1",
                schemaVersion: BackupSchemaVersionV1(major: 1, minor: 0, patch: 0),
                selectionPolicyVersion: DrawSelectionPolicy.version
            )
        )
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

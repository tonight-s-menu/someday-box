import Observation
import SwiftUI

enum ShareCaptureRecoveryItem: Equatable, Identifiable {
    case pending(ShareMailboxEntry, message: String)
    case invalid(ShareMailboxProblem)

    var id: UUID {
        switch self {
        case let .pending(entry, _): entry.envelope.envelopeID
        case let .invalid(problem): problem.id
        }
    }
}

struct SharedImportPresentationBatch: Equatable {
    var count: Int
    var boundedItemIDs: [UUID]
    var expiresAt: Date
}

private struct VoidMutationReceipt: Equatable, Sendable {}

@main
struct SomedayBoxApp: App {
    @State private var appModel: AppModel?
    @State private var startupError: String?
    @State private var recoveryService: StoreRecoveryService?

    var body: some Scene {
        WindowGroup {
            Group {
                if let appModel {
                    RootTabView()
                        .environment(appModel)
                        .tint(SomedayBoxBrand.tint)
                } else if let recoveryService {
                    StoreRecoveryView(service: recoveryService) {
                        self.recoveryService = nil
                        startupError = nil
                        Task { await start() }
                    }
                } else if let startupError {
                    ContentUnavailableView {
                        Label("Your Box needs attention", systemImage: "externaldrive.badge.exclamationmark")
                    } description: {
                        Text(startupError)
                    } actions: {
                        Button("Try again") { Task { await start() } }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    ProgressView("Opening your Box…")
                        .accessibilityLabel("Opening your Box")
                }
            }
            .task { await start() }
        }
    }

    @MainActor
    private func start() async {
        guard appModel == nil else { return }
        startupError = nil
        do {
            appModel = try await AppComposition.make()
        } catch {
            startupError = String(localized: "We couldn't open your Box. Your data was not changed.")
            if let supportRoot = try? AppComposition.supportRoot() {
                recoveryService = StoreRecoveryService(
                    configuration: StoreGenerationConfiguration(applicationSupportURL: supportRoot)
                )
            }
        }
    }
}

@MainActor
enum AppComposition {
    static func supportRoot() throws -> URL {
        try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("SomedayBox", isDirectory: true)
    }

    static func make() async throws -> AppModel {
        let launchConfiguration = UITestLaunchConfiguration.current
        let supportRoot = try launchConfiguration.supportRoot(defaultRoot: supportRoot())
        let repository = try await GenerationProductRepository.open(
            configuration: StoreGenerationConfiguration(applicationSupportURL: supportRoot)
        )
        if launchConfiguration.enabled, let fixture = launchConfiguration.fixture {
            let count: Int
            switch fixture {
            case .emptyBox: count = 0
            case let .activePapers(value): count = value
            case .drawReady: count = 1
            }
            let now = Date()
            let items = (0..<count).map { index in
                BoxItem(
                    id: UUID(),
                    title: fixture == .drawReady ? "Fixture paper title" : "Fixture paper \(index + 1)",
                    durationBucketRaw: DurationBucket.upTo30Minutes.rawValue,
                    createdAt: now.addingTimeInterval(TimeInterval(-index)),
                    updatedAt: now
                )
            }
            _ = try await repository.withTransaction { $0 = PersistedProductState(items: items) }
            UserDefaults.standard.removeObject(forKey: "lastDrawContext")
        }
        let groupContainerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.somedaybox.app.share"
        )
        let sharedJournalStore = SharedProductDataJournalStore(applicationSupportURL: supportRoot)
        if let groupContainerURL {
            let maintenance = ShareMailboxMaintenance()
            if let journal = try sharedJournalStore.load() {
                if await repository.activeGeneration().id == journal.targetProductGenerationID {
                    try maintenance.commit(journal.mailboxReplacement, at: groupContainerURL)
                } else {
                    try maintenance.discard(journal.mailboxReplacement, at: groupContainerURL)
                }
                try sharedJournalStore.remove()
            } else {
                try maintenance.recoverAbandonedMaintenance(at: groupContainerURL)
            }
        } else if try sharedJournalStore.load() != nil {
            throw ShareCaptureError.publicationFailed
        }
        let model = AppModel(
            repository: repository,
            shareGroupContainerURL: groupContainerURL,
            sharedJournalStore: sharedJournalStore
        )
        if let renderer = launchConfiguration.renderer {
            model.presentationPreferences.renderer = renderer
        }
        return model
    }
}

@MainActor
@Observable
final class AppModel {
    private let repository: GenerationProductRepository
    private let captureUseCase: CapturePaperUseCase
    private let editUseCase: EditPaperUseCase
    private let startDrawUseCase: StartDrawUseCase
    private let redrawUseCase: RedrawUseCase
    private let acceptUseCase: AcceptDrawUseCase
    private let dismissUseCase: DismissDrawUseCase
    private let completeUseCase: CompletePaperUseCase
    private let putBackUseCase: PutBackPaperUseCase
    private let archiveUseCase: ArchivePaperUseCase
    private let restoreUseCase: RestorePaperUseCase
    private let deleteUseCase: DeletePaperUseCase
    private let importSharedPaperUseCase: ImportSharedPaperUseCase
    private let removeSourceUseCase: RemoveSourceUseCase
    private let shareGroupContainerURL: URL?
    private let shareMailboxReader = ShareMailboxReader()
    private let shareMailboxMaintenance = ShareMailboxMaintenance()
    private let sharedJournalStore: SharedProductDataJournalStore
    private let presentationPreferenceStore = CoreBoxPresentationPreferenceStore()
    private let projectionLoader: CoreBoxProjectionLoader
    private let mutationHooks: AppModelMutationHooks
    private var isRefreshingSharedCaptures = false
    private var effectiveRendererTierOverride: CoreBoxRendererTier?

    var state = PersistedProductState(items: [])
    var isLoading = true
    var loadFailed = false
    var isMutating = false
    var errorMessage: String?
    var shareRecoveryItems: [ShareCaptureRecoveryItem] = []
    var sharedImportPresentation: SharedImportPresentationBatch?
    var sceneSnapshot: CoreBoxSceneSnapshot?
    var snapshotVersion: UInt64 = 0
    var requiresProjectionReconciliation = false
    private(set) var selectedDrawContext: DrawContext?
    var presentationPreferences: CoreBoxPresentationPreferences {
        didSet { presentationPreferenceStore.save(presentationPreferences) }
    }
    var hapticsEnabled: Bool {
        get { presentationPreferences.hapticsEnabled }
        set { presentationPreferences.hapticsEnabled = newValue }
    }
    var hasSeenIntroduction: Bool {
        didSet { UserDefaults.standard.set(hasSeenIntroduction, forKey: "hasSeenIntroduction") }
    }

    init(
        repository: GenerationProductRepository,
        shareGroupContainerURL: URL? = nil,
        sharedJournalStore: SharedProductDataJournalStore? = nil,
        projectionLoader: CoreBoxProjectionLoader = .live,
        mutationHooks: AppModelMutationHooks = .live,
        clock: any Clock = SystemClock(),
        makeID: @escaping @Sendable () -> UUID = { UUID() }
    ) {
        self.repository = repository
        self.shareGroupContainerURL = shareGroupContainerURL
        self.projectionLoader = projectionLoader
        self.mutationHooks = mutationHooks
        self.sharedJournalStore = sharedJournalStore ?? SharedProductDataJournalStore(
            applicationSupportURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("SomedayBox-\(UUID().uuidString)", isDirectory: true)
        )
        presentationPreferences = presentationPreferenceStore.load()
        hasSeenIntroduction = UserDefaults.standard.bool(forKey: "hasSeenIntroduction")
        if let data = UserDefaults.standard.data(forKey: "lastDrawContext"),
           let context = try? JSONDecoder().decode(DrawContext.self, from: data) {
            selectedDrawContext = context
        }
        let arbiter = MutationArbiter(repository: repository)
        captureUseCase = CapturePaperUseCase(arbiter: arbiter, clock: clock, makeID: makeID)
        editUseCase = EditPaperUseCase(arbiter: arbiter, clock: clock)
        startDrawUseCase = StartDrawUseCase(arbiter: arbiter, clock: clock, makeID: makeID)
        redrawUseCase = RedrawUseCase(arbiter: arbiter, clock: clock, makeID: makeID)
        acceptUseCase = AcceptDrawUseCase(arbiter: arbiter, clock: clock)
        dismissUseCase = DismissDrawUseCase(arbiter: arbiter, clock: clock)
        completeUseCase = CompletePaperUseCase(arbiter: arbiter, clock: clock, makeID: makeID)
        putBackUseCase = PutBackPaperUseCase(arbiter: arbiter, clock: clock)
        archiveUseCase = ArchivePaperUseCase(arbiter: arbiter, clock: clock)
        restoreUseCase = RestorePaperUseCase(arbiter: arbiter, clock: clock)
        deleteUseCase = DeletePaperUseCase(arbiter: arbiter)
        importSharedPaperUseCase = ImportSharedPaperUseCase(arbiter: arbiter, clock: clock, makeItemID: makeID, makeSourceID: makeID)
        removeSourceUseCase = RemoveSourceUseCase(arbiter: arbiter)
    }

    var unresolvedAttempt: DrawAttempt? {
        state.attempts.first { $0.outcome == .unresolved }
    }

    var unresolvedItem: BoxItem? {
        guard let itemID = unresolvedAttempt?.itemID else { return nil }
        return item(id: itemID)
    }

    var currentItem: BoxItem? {
        guard let itemID = state.currentPick?.itemID else { return nil }
        return item(id: itemID)
    }

    var drawableCount: Int {
        let excluded = Set([state.currentPick?.itemID, unresolvedAttempt?.itemID].compactMap { $0 })
        return state.items.filter {
            $0.lifecycle == .active && $0.supportedDuration != nil && !excluded.contains($0.id)
        }.count
    }

    var drawAvailability: CoreBoxDrawAvailability {
        sceneSnapshot?.drawAvailability ?? CoreBoxDrawAvailability(
            totalSupportedCount: drawableCount,
            selectedContextEligibleCount: drawableCount,
            presetCounts: []
        )
    }

    func item(id: UUID) -> BoxItem? {
        state.items.first { $0.id == id }
    }

    func source(itemID: UUID) -> SourceReference? {
        state.sources.first { $0.itemID == itemID }
    }

    var currentShareRecovery: ShareCaptureRecoveryItem? { shareRecoveryItems.first }

    func load() async {
        isLoading = true
        do {
            state = try await repository.snapshot()
            if unresolvedAttempt == nil {
                await ingestSharedCaptures()
                state = try await repository.snapshot()
            }
            try await publishProjection(for: state)
            errorMessage = nil
            loadFailed = false
        } catch {
            errorMessage = message(for: error)
            loadFailed = true
        }
        isLoading = false
    }

    func capture(title: String, note: String?, duration: DurationBucket) async -> AppMutationProjection<CapturePaperResult> {
        await projectMutation {
            try await self.captureUseCase.execute(
                title: title,
                note: note,
                durationBucketRaw: duration.rawValue
            )
        }
    }

    func edit(itemID: UUID, title: String, note: String?, duration: DurationBucket) async -> Bool {
        await mutate {
            try await self.editUseCase.execute(
                itemID: itemID,
                title: title,
                note: note,
                durationBucketRaw: duration.rawValue
            )
        }
    }

    func startDraw(availableTime: AvailableTime) async -> AppMutationProjection<StartDrawResult> {
        await projectMutation { try await self.startDrawUseCase.execute(availableTime: availableTime) }
    }

    func startDraw(context: DrawContext) async -> AppMutationProjection<StartDrawResult> {
        await projectMutation { try await self.startDrawUseCase.execute(context: context) }
    }

    func redraw() async -> AppMutationProjection<RedrawResult> {
        await projectMutation { try await self.redrawUseCase.execute() }
    }

    func acceptDraw() async -> AppMutationProjection<AcceptDrawResult> {
        let accepted = await projectMutation { try await self.acceptUseCase.execute() }
        if accepted.isCommitted { await refreshSharedCaptures() }
        return accepted
    }

    func dismissDraw() async -> AppMutationProjection<DismissDrawResult> {
        let dismissed = await projectMutation { try await self.dismissUseCase.execute() }
        if dismissed.isCommitted { await refreshSharedCaptures() }
        return dismissed
    }

    func complete(itemID: UUID) async -> AppMutationProjection<CompletePaperResult> {
        await projectMutation { try await self.completeUseCase.execute(itemID: itemID) }
    }

    func putBack(itemID: UUID) async -> AppMutationProjection<PutBackPaperResult> {
        await projectMutation { try await self.putBackUseCase.execute(itemID: itemID) }
    }

    func archive(itemID: UUID) async -> Bool {
        await mutate { try await self.archiveUseCase.execute(itemID: itemID) }
    }

    func restore(itemID: UUID) async -> Bool {
        await mutate { try await self.restoreUseCase.execute(itemID: itemID) }
    }

    func delete(itemID: UUID) async -> Bool {
        await mutate { try await self.deleteUseCase.execute(itemID: itemID) }
    }

    func removeSource(itemID: UUID) async -> Bool {
        await mutate { try await self.removeSourceUseCase.execute(itemID: itemID) }
    }

    func exportBackupData() async -> Data? {
        guard !isMutating else { return nil }
        isMutating = true
        defer { isMutating = false }
        do {
            let info = Bundle.main.infoDictionary ?? [:]
            let metadata = BackupDocumentMetadataV1(
                exportedAt: Date(),
                appMarketingVersion: info["CFBundleShortVersionString"] as? String ?? "0",
                appBuild: info["CFBundleVersion"] as? String ?? "0",
                schemaVersion: BackupSchemaVersionV1(major: 3, minor: 0, patch: 0),
                selectionPolicyVersion: DrawSelectionPolicy.version
            )
            let groupURL = shareGroupContainerURL
            let reader = shareMailboxReader
            let data = try await repository.exportSnapshotWithParticipant { snapshot in
                let envelopes = try groupURL.map { try reader.entries(at: $0).map(\.envelope) } ?? []
                return try BackupDocumentCodecV3().encode(
                    state: snapshot,
                    pendingEnvelopes: envelopes,
                    metadata: metadata
                )
            }
            errorMessage = nil
            return data
        } catch {
            errorMessage = message(for: error)
            return nil
        }
    }

    func prepareRestore(data: Data) async -> BackupRestorePayload? {
        do {
            let restoredPayload = try await Task.detached {
                try BackupDocumentCodecV3().decode(data)
            }.value
            errorMessage = nil
            return restoredPayload
        } catch {
            errorMessage = message(for: error)
            return nil
        }
    }

    func restoreBackup(_ payload: BackupRestorePayload) async -> Bool {
        await replaceProductData {
            try await self.replaceAllAuthorities(
                productState: payload.state,
                envelopes: payload.pendingEnvelopes,
                kind: .restore
            )
        }
    }

    func eraseAllData() async -> Bool {
        let erased = await replaceProductData {
            try await self.replaceAllAuthorities(
                productState: PersistedProductState(items: []),
                envelopes: [],
                kind: .erase
            )
        }
        if erased {
            presentationPreferenceStore.resetAllNamespaces()
            presentationPreferences = .init()
            hasSeenIntroduction = false
            UserDefaults.standard.removeObject(forKey: "hasSeenIntroduction")
            selectedDrawContext = nil
            UserDefaults.standard.removeObject(forKey: "lastDrawContext")
        }
        return erased
    }

    func finishIntroduction() {
        hasSeenIntroduction = true
    }

    func clearError() {
        errorMessage = nil
    }

    /// Updates only the presentation context; drawing remains an explicit second action.
    func updateDrawContext(_ context: DrawContext?) async {
        guard !isMutating, !requiresProjectionReconciliation else { return }
        selectedDrawContext = context
        if let context, let data = try? JSONEncoder().encode(context) {
            UserDefaults.standard.set(data, forKey: "lastDrawContext")
        } else {
            UserDefaults.standard.removeObject(forKey: "lastDrawContext")
        }
        do {
            try await publishProjection(for: state)
            errorMessage = nil
        } catch {
            requiresProjectionReconciliation = true
            errorMessage = message(for: error)
        }
    }

    func requestRendererPreference(_ preference: CoreBoxRendererPreference) async {
        presentationPreferences.renderer = preference
        effectiveRendererTierOverride = nil
        do { try await publishProjection(for: state) }
        catch { requiresProjectionReconciliation = true; errorMessage = message(for: error) }
    }

    func requestEffectiveRendererTier(_ tier: CoreBoxRendererTier, reason _: CoreBoxFallbackReason) async {
        effectiveRendererTierOverride = tier
        do { try await publishProjection(for: state) }
        catch { requiresProjectionReconciliation = true; errorMessage = message(for: error) }
    }

    func retryProjection() async {
        guard requiresProjectionReconciliation else { return }
        do {
            let latestState = try await repository.snapshot()
            guard snapshotVersion < UInt64.max else { throw AppMutationFailure.reconciliationRequired }
            let nextVersion = snapshotVersion + 1
            let snapshot = try await projectionLoader.load(
                latestState,
                nextVersion,
                projectionInputs
            )
            state = latestState
            snapshotVersion = nextVersion
            sceneSnapshot = snapshot
            requiresProjectionReconciliation = false
            errorMessage = nil
        } catch {
            requiresProjectionReconciliation = true
            errorMessage = message(for: error)
        }
    }

    func report(_ error: Error) {
        errorMessage = message(for: error)
    }

    func retryCurrentShareRecovery() async -> AppMutationProjection<ImportSharedPaperResult> {
        guard let current = currentShareRecovery, let groupURL = shareGroupContainerURL else {
            return .notCommitted(failure: .persistenceUnavailable)
        }
        switch current {
        case let .pending(entry, _):
            let projection = await projectMutation {
                try await self.importSharedPaperUseCase.execute(envelope: entry.envelope)
            }
            guard let outcome = projection.outcome else { return projection }
            do {
                recordFreshSharedImport(outcome)
                try shareMailboxReader.remove(entry, at: groupURL)
                shareRecoveryItems.removeFirst()
                errorMessage = nil
                return projection
            } catch {
                errorMessage = message(for: error)
                return .notCommitted(failure: .persistenceUnavailable)
            }
        case .invalid:
            errorMessage = shareFeatureText("This capture cannot be read safely. Export or discard it, or update someday-box if it came from a newer version.")
            return .notCommitted(failure: .persistenceUnavailable)
        }
    }

    func discardCurrentShareRecovery() async -> Bool {
        guard let current = currentShareRecovery, let groupURL = shareGroupContainerURL else { return false }
        do {
            switch current {
            case let .pending(entry, _): try shareMailboxReader.remove(entry, at: groupURL)
            case let .invalid(problem): try shareMailboxReader.discard(problem, at: groupURL)
            }
            shareRecoveryItems.removeFirst()
            errorMessage = nil
            return true
        } catch {
            errorMessage = message(for: error)
            return false
        }
    }

    func currentRawRecoveryData() -> Data? {
        guard case let .invalid(problem) = currentShareRecovery else { return nil }
        do { return try shareMailboxReader.rawRecoveryData(problem) }
        catch { errorMessage = message(for: error); return nil }
    }

    func refreshSharedCaptures() async {
        guard !isLoading,
              !isMutating,
              unresolvedAttempt == nil,
              !isRefreshingSharedCaptures else { return }
        isRefreshingSharedCaptures = true
        defer { isRefreshingSharedCaptures = false }

        await ingestSharedCaptures()
        do {
            state = try await repository.snapshot()
            try await publishProjection(for: state)
        } catch {
            errorMessage = message(for: error)
        }
    }

    func dropSharedImportPresentation() {
        sharedImportPresentation = nil
    }

    private func ingestSharedCaptures() async {
        guard let shareGroupContainerURL else { return }
        do {
            let inspection = try shareMailboxReader.inspect(at: shareGroupContainerURL)
            shareRecoveryItems = inspection.problems.map { .invalid($0) }
            for entry in inspection.entries {
                let projection = await projectMutation {
                    try await self.importSharedPaperUseCase.execute(envelope: entry.envelope)
                }
                guard let outcome = projection.outcome else {
                    shareRecoveryItems.append(.pending(entry, message: errorMessage ?? ""))
                    continue
                }
                do {
                    recordFreshSharedImport(outcome)
                    try shareMailboxReader.remove(entry, at: shareGroupContainerURL)
                } catch {
                    shareRecoveryItems.append(.pending(entry, message: message(for: error)))
                }
            }
        } catch {
            errorMessage = message(for: error)
        }
    }

    private func recordFreshSharedImport(_ result: ImportSharedPaperResult) {
        guard case let .imported(itemID, _) = result else { return }
        let now = Date()
        if var batch = sharedImportPresentation, batch.expiresAt > now {
            batch.count += 1
            if batch.boundedItemIDs.count < 3 { batch.boundedItemIDs.append(itemID) }
            batch.expiresAt = now.addingTimeInterval(30)
            sharedImportPresentation = batch
        } else {
            sharedImportPresentation = .init(count: 1, boundedItemIDs: [itemID], expiresAt: now.addingTimeInterval(30))
        }
    }

    private func mutate(
        _ operation: () async throws -> ProductTransaction<Void>
    ) async -> Bool {
        await projectMutation {
            let transaction = try await operation()
            return ProductTransaction(outcome: VoidMutationReceipt(), state: transaction.state)
        }.isCommitted
    }

    private func projectMutation<Outcome: Equatable & Sendable>(
        _ operation: () async throws -> ProductTransaction<Outcome>
    ) async -> AppMutationProjection<Outcome> {
        guard !requiresProjectionReconciliation else {
            return .notCommitted(failure: .reconciliationRequired)
        }
        guard !isMutating else {
            return .notCommitted(failure: .operationInProgress)
        }
        isMutating = true
        defer { isMutating = false }

        do {
            try await mutationHooks.beforeOperation()
            let transaction = try await operation()
            state = transaction.state
            guard snapshotVersion < UInt64.max else {
                requiresProjectionReconciliation = true
                return .committedButProjectionUnavailable(outcome: transaction.outcome)
            }
            let nextVersion = snapshotVersion + 1
            do {
                let snapshot = try await projectionLoader.load(
                    transaction.state,
                    nextVersion,
                    projectionInputs
                )
                snapshotVersion = nextVersion
                sceneSnapshot = snapshot
                requiresProjectionReconciliation = false
                errorMessage = nil
                return .committed(outcome: transaction.outcome, snapshot: snapshot)
            } catch {
                requiresProjectionReconciliation = true
                return .committedButProjectionUnavailable(outcome: transaction.outcome)
            }
        } catch let error as ApplicationError {
            errorMessage = message(for: error)
            return .notCommitted(failure: .application(error))
        } catch let error as AppMutationFailure {
            return .notCommitted(failure: error)
        } catch {
            errorMessage = message(for: error)
            return .notCommitted(failure: .persistenceUnavailable)
        }
    }

    private var projectionInputs: CoreBoxProjectionInputs {
        CoreBoxProjectionInputs(
            rendererTier: effectiveRendererTierOverride ?? presentationPreferences.renderer.maximumTier,
            motionMode: presentationPreferences.quickAnimations ? .quick : .normal,
            drawContext: selectedDrawContext ?? unresolvedAttempt.flatMap { attempt in
                state.sessions.first(where: { $0.id == attempt.sessionID })?.context
            },
            now: Date()
        )
    }

    private func publishProjection(for committedState: PersistedProductState) async throws {
        guard snapshotVersion < UInt64.max else {
            requiresProjectionReconciliation = true
            throw AppMutationFailure.reconciliationRequired
        }
        let nextVersion = snapshotVersion + 1
        let snapshot = try await projectionLoader.load(committedState, nextVersion, projectionInputs)
        state = committedState
        snapshotVersion = nextVersion
        sceneSnapshot = snapshot
        requiresProjectionReconciliation = false
    }

    private func replaceProductData(
        _ operation: () async throws -> PersistedProductState
    ) async -> Bool {
        guard !isMutating else { return false }
        isMutating = true
        defer { isMutating = false }
        do {
            state = try await operation()
            errorMessage = nil
            return true
        } catch {
            errorMessage = message(for: error)
            return false
        }
    }

    private func replaceAllAuthorities(
        productState: PersistedProductState,
        envelopes: [ShareCaptureEnvelopeV1],
        kind: StoreGenerationOperationKind
    ) async throws -> PersistedProductState {
        guard let groupURL = shareGroupContainerURL else {
            guard envelopes.isEmpty else { throw ShareCaptureError.publicationFailed }
            switch kind {
            case .migration: throw GenerationRepositoryError.recoveryRequired
            case .restore: return try await repository.restore(validatedState: productState)
            case .erase: return try await repository.eraseAll()
            }
        }

        let operationID = UUID()
        let targetProductGenerationID = UUID()
        let mailboxReplacement = try shareMailboxMaintenance.stageReplacement(
            with: envelopes,
            operationID: operationID,
            at: groupURL
        )
        let journal = SharedProductDataOperationJournal(
            operationID: operationID,
            kind: kind,
            targetProductGenerationID: targetProductGenerationID,
            mailboxReplacement: mailboxReplacement
        )
        do {
            try sharedJournalStore.write(journal)
            let result: PersistedProductState
            switch kind {
            case .migration:
                throw GenerationRepositoryError.recoveryRequired
            case .restore:
                result = try await repository.restore(
                    validatedState: productState,
                    targetGenerationID: targetProductGenerationID
                )
            case .erase:
                result = try await repository.eraseAll(targetGenerationID: targetProductGenerationID)
            }
            try shareMailboxMaintenance.commit(mailboxReplacement, at: groupURL)
            try sharedJournalStore.remove()
            return result
        } catch {
            if await repository.activeGeneration().id == targetProductGenerationID {
                // Product truth crossed its durable commit boundary. Startup recovery must
                // finish the mailbox switch; rolling either authority back is unsafe now.
                throw GenerationRepositoryError.committedCleanupIncomplete
            }
            try? shareMailboxMaintenance.discard(mailboxReplacement, at: groupURL)
            try? sharedJournalStore.remove()
            throw error
        }
    }

    private func message(for error: Error) -> String {
        switch error {
        case ApplicationError.drawResolutionRequired:
            String(localized: "Finish the paper on screen before changing your Box.")
        case ApplicationError.currentPickExists:
            String(localized: "Finish or put back your current paper before drawing another.")
        case ApplicationError.emptyPool(.noActivePapers):
            String(localized: "There are no papers ready to draw yet.")
        case ApplicationError.emptyPool(.unsupportedDurations):
            String(localized: "Some papers need a duration update before they can be drawn.")
        case ApplicationError.emptyPool(.overTimeBudget):
            String(localized: "No papers fit the time you selected.")
        case ApplicationError.emptyPool(.alreadyShownInSession):
            String(localized: "You've seen every fitting paper in this round.")
        case ApplicationError.unsupportedPolicy:
            String(localized: "This result came from an older draw version. You can do it or dismiss it.")
        case ApplicationError.invalidContent:
            String(localized: "Check the title and note limits, then try again.")
        case ApplicationError.capacityExceeded:
            String(localized: "Your Box has reached a local format limit. Export or remove content before adding more.")
        case BackupDocumentError.invalidChecksum, BackupDocumentError.nonCanonicalEncoding:
            String(localized: "This backup is damaged or was changed after export.")
        case BackupDocumentError.unsupportedFormatVersion:
            String(localized: "This backup was created by a newer, unsupported format.")
        case is BackupDocumentError, is BackupFileReaderError:
            String(localized: "This file is not a valid someday-box backup.")
        case GenerationRepositoryError.operationInProgress:
            String(localized: "A local data operation is already in progress.")
        case ShareCaptureError.mailboxFull:
            shareFeatureText("Shared captures are using the available local mailbox space. Export or remove content, then try again.")
        case is ShareCaptureError:
            shareFeatureText("A shared capture needs attention. Its local bytes were kept.")
        default:
            String(localized: "Something went wrong locally. Your previous state was kept.")
        }
    }
}

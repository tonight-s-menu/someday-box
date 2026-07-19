import Observation
import SwiftUI

@main
struct SomedayBoxApp: App {
    @State private var appModel: AppModel?
    @State private var startupError: String?

    var body: some Scene {
        WindowGroup {
            Group {
                if let appModel {
                    RootTabView()
                        .environment(appModel)
                        .tint(SomedayBoxBrand.tint)
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
        }
    }
}

@MainActor
enum AppComposition {
    static func make() async throws -> AppModel {
        let supportRoot = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("SomedayBox", isDirectory: true)
        let repository = try await GenerationProductRepository.open(
            configuration: StoreGenerationConfiguration(applicationSupportURL: supportRoot)
        )
        return AppModel(repository: repository)
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

    var state = PersistedProductState(items: [])
    var isLoading = true
    var loadFailed = false
    var isMutating = false
    var errorMessage: String?

    init(repository: GenerationProductRepository) {
        self.repository = repository
        let arbiter = MutationArbiter(repository: repository)
        captureUseCase = CapturePaperUseCase(arbiter: arbiter)
        editUseCase = EditPaperUseCase(arbiter: arbiter)
        startDrawUseCase = StartDrawUseCase(arbiter: arbiter)
        redrawUseCase = RedrawUseCase(arbiter: arbiter)
        acceptUseCase = AcceptDrawUseCase(arbiter: arbiter)
        dismissUseCase = DismissDrawUseCase(arbiter: arbiter)
        completeUseCase = CompletePaperUseCase(arbiter: arbiter)
        putBackUseCase = PutBackPaperUseCase(arbiter: arbiter)
        archiveUseCase = ArchivePaperUseCase(arbiter: arbiter)
        restoreUseCase = RestorePaperUseCase(arbiter: arbiter)
        deleteUseCase = DeletePaperUseCase(arbiter: arbiter)
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

    func item(id: UUID) -> BoxItem? {
        state.items.first { $0.id == id }
    }

    func load() async {
        isLoading = true
        do {
            state = try await repository.snapshot()
            errorMessage = nil
            loadFailed = false
        } catch {
            errorMessage = message(for: error)
            loadFailed = true
        }
        isLoading = false
    }

    func capture(title: String, note: String?, duration: DurationBucket) async -> Bool {
        await mutate {
            _ = try await self.captureUseCase.execute(
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

    func startDraw(availableTime: AvailableTime) async -> Bool {
        await mutate { _ = try await self.startDrawUseCase.execute(availableTime: availableTime) }
    }

    func redraw() async -> Bool {
        await mutate { _ = try await self.redrawUseCase.execute() }
    }

    func acceptDraw() async -> Bool {
        await mutate { try await self.acceptUseCase.execute() }
    }

    func dismissDraw() async -> Bool {
        await mutate { try await self.dismissUseCase.execute() }
    }

    func complete(itemID: UUID) async -> Bool {
        await mutate { try await self.completeUseCase.execute(itemID: itemID) }
    }

    func putBack(itemID: UUID) async -> Bool {
        await mutate { try await self.putBackUseCase.execute(itemID: itemID) }
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

    func exportBackupData() async -> Data? {
        guard !isMutating else { return nil }
        isMutating = true
        defer { isMutating = false }
        do {
            let snapshot = try await repository.exportSnapshot()
            let info = Bundle.main.infoDictionary ?? [:]
            let metadata = BackupDocumentMetadataV1(
                exportedAt: Date(),
                appMarketingVersion: info["CFBundleShortVersionString"] as? String ?? "0",
                appBuild: info["CFBundleVersion"] as? String ?? "0",
                schemaVersion: BackupSchemaVersionV1(major: 1, minor: 0, patch: 0),
                selectionPolicyVersion: DrawSelectionPolicy.version
            )
            let data = try await Task.detached {
                try BackupDocumentCodecV1().encode(state: snapshot, metadata: metadata)
            }.value
            errorMessage = nil
            return data
        } catch {
            errorMessage = message(for: error)
            return nil
        }
    }

    func prepareRestore(data: Data) async -> PersistedProductState? {
        do {
            let restoredState = try await Task.detached {
                try BackupDocumentCodecV1().decode(data)
            }.value
            errorMessage = nil
            return restoredState
        } catch {
            errorMessage = message(for: error)
            return nil
        }
    }

    func restoreBackup(_ restoredState: PersistedProductState) async -> Bool {
        await replaceProductData { try await self.repository.restore(validatedState: restoredState) }
    }

    func eraseAllData() async -> Bool {
        await replaceProductData { try await self.repository.eraseAll() }
    }

    func clearError() {
        errorMessage = nil
    }

    func report(_ error: Error) {
        errorMessage = message(for: error)
    }

    private func mutate(_ operation: () async throws -> Void) async -> Bool {
        guard !isMutating else { return false }
        isMutating = true
        defer { isMutating = false }
        do {
            try await operation()
            state = try await repository.snapshot()
            errorMessage = nil
            return true
        } catch {
            errorMessage = message(for: error)
            return false
        }
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
        case BackupDocumentError, BackupFileReaderError:
            String(localized: "This file is not a valid someday-box backup.")
        case GenerationRepositoryError.operationInProgress:
            String(localized: "A local data operation is already in progress.")
        default:
            String(localized: "Something went wrong locally. Your previous state was kept.")
        }
    }
}

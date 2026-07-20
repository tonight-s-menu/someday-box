import Foundation
import Observation
import RealityKit

/// Owns the lifecycle boundary between one validated asset and its adapter.
@MainActor
@Observable
final class CoreBoxStageController {
    private let loader: CoreBoxAssetLoader
    private var adapter: any CoreBoxPresentationAdapter
    private var latestSnapshotVersion: UInt64?
    private var latestEventSequence: UInt64 = 0
    private var preparedReplacement: CoreBoxLoadedAsset?
    private var installedTier: CoreBoxRendererTier?
    private var requestedTier: CoreBoxRendererTier?
    private var activeReplacementRequestID: UUID?
    private let requestEffectiveTier: @MainActor (CoreBoxRendererTier, CoreBoxFallbackReason) -> Void

    private(set) var replacementGeneration: UInt64 = 0
    private(set) var isAwaitingTierProjection = false
    var hasInstalledAsset: Bool { installedTier != nil }

    init(
        loader: CoreBoxAssetLoader,
        adapter: any CoreBoxPresentationAdapter,
        requestEffectiveTier: @escaping @MainActor (CoreBoxRendererTier, CoreBoxFallbackReason) -> Void = { _, _ in }
    ) {
        self.loader = loader
        self.adapter = adapter
        self.requestEffectiveTier = requestEffectiveTier
    }

    func load(tier: CoreBoxRendererTier) async throws -> CoreBoxLoadedAsset {
        try await loader.load(tier: tier)
    }

    func install(_ loaded: CoreBoxLoadedAsset) {
        adapter.settle(reason: .rendererTransition)
        installedTier = loaded.tier
        requestedTier = nil
        activeReplacementRequestID = nil
        preparedReplacement = nil
        adapter = CoreBoxSceneAdapter(loadedAsset: loaded)
        latestSnapshotVersion = nil
        isAwaitingTierProjection = false
    }

    func prepareReplacement(tier: CoreBoxRendererTier) async {
        guard hasInstalledAsset else { return }
        if tier == installedTier {
            requestedTier = nil
            activeReplacementRequestID = nil
            preparedReplacement = nil
            return
        }
        guard tier != requestedTier else { return }
        let requestID = UUID()
        requestedTier = tier
        activeReplacementRequestID = requestID
        do {
            let loaded = try await loader.load(tier: tier)
            guard !Task.isCancelled,
                  activeReplacementRequestID == requestID,
                  requestedTier == tier else { return }
            guard replacementGeneration < UInt64.max else {
                reject3DForLaunch(CoreBoxStageError.generationExhausted)
                return
            }
            preparedReplacement = loaded
            replacementGeneration += 1
        } catch {
            guard !Task.isCancelled,
                  activeReplacementRequestID == requestID,
                  requestedTier == tier else { return }
            reject3DForLaunch(error)
        }
    }

    func takePreparedReplacement() -> CoreBoxLoadedAsset? {
        defer { preparedReplacement = nil }
        return preparedReplacement
    }

    func update(snapshot: CoreBoxSceneSnapshot, event: CoreBoxCorrelatedEvent?) {
        if snapshot.rendererTier == .swiftUI2D {
            isAwaitingTierProjection = false
        }
        if let latestSnapshotVersion {
            guard snapshot.snapshotVersion >= latestSnapshotVersion else { return }
            if snapshot.snapshotVersion > latestSnapshotVersion {
                adapter.apply(snapshot: snapshot)
                self.latestSnapshotVersion = snapshot.snapshotVersion
            }
        } else {
            adapter.apply(snapshot: snapshot)
            latestSnapshotVersion = snapshot.snapshotVersion
        }
        guard let event,
              event.sourceSnapshotVersion == snapshot.snapshotVersion,
              event.sequence > latestEventSequence else { return }
        latestEventSequence = event.sequence
        adapter.apply(event: event.event, sourceSnapshotVersion: event.sourceSnapshotVersion)
    }

    func reject3DForLaunch(_ error: any Error) {
        adapter.settle(reason: .validationFailure)
        requestedTier = nil
        activeReplacementRequestID = nil
        isAwaitingTierProjection = true
        let reason: CoreBoxFallbackReason =
            (error is CoreBoxAssetValidationError || error is CoreBoxStageError) ? .assetValidation : .assetLoad
        requestEffectiveTier(.swiftUI2D, reason)
    }

    func teardown() {
        requestedTier = nil
        activeReplacementRequestID = nil
        preparedReplacement = nil
        adapter.settle(reason: .cancelled)
    }
}

enum CoreBoxStageError: Error {
    case generationExhausted
}

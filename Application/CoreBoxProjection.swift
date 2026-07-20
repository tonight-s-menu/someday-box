import Foundation

public struct CoreBoxProjectionInputs: Equatable, Sendable {
    public let rendererTier: CoreBoxRendererTier
    public let motionMode: CoreBoxMotionMode
    public let drawContext: DrawContext?
    public let now: Date

    public init(
        rendererTier: CoreBoxRendererTier,
        motionMode: CoreBoxMotionMode,
        drawContext: DrawContext?,
        now: Date
    ) {
        self.rendererTier = rendererTier
        self.motionMode = motionMode
        self.drawContext = drawContext
        self.now = now
    }
}

public struct CoreBoxProjectionLoader: Sendable {
    public var load: @Sendable (
        _ state: PersistedProductState,
        _ snapshotVersion: UInt64,
        _ inputs: CoreBoxProjectionInputs
    ) async throws -> CoreBoxSceneSnapshot

    public init(
        load: @escaping @Sendable (
            _ state: PersistedProductState,
            _ snapshotVersion: UInt64,
            _ inputs: CoreBoxProjectionInputs
        ) async throws -> CoreBoxSceneSnapshot
    ) {
        self.load = load
    }

    public static let live = Self { state, snapshotVersion, inputs in
        CoreBoxSceneSnapshotBuilder().build(
            state: state,
            inputs: inputs,
            snapshotVersion: snapshotVersion
        )
    }
}

public struct CoreBoxSceneSnapshotBuilder: Sendable {
    public init() {}

    public func build(
        state: PersistedProductState,
        inputs: CoreBoxProjectionInputs,
        snapshotVersion: UInt64
    ) -> CoreBoxSceneSnapshot {
        let excludedIDs = Set(
            [state.currentPick?.itemID, state.attempts.first(where: { $0.outcome == .unresolved })?.itemID]
                .compactMap { $0 }
        )
        let activeItems = state.items
            .filter { $0.lifecycle == .active && !excludedIDs.contains($0.id) }
            .sorted {
                if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
                return $0.id.uuidString < $1.id.uuidString
            }
        let supportedItems = activeItems.filter { $0.supportedDuration != nil }

        let selectedCount: Int
        if let context = inputs.drawContext {
            selectedCount = candidateCount(
                context: context,
                stableItems: activeItems
            )
        } else {
            selectedCount = 0
        }
        let presetCounts = DrawPresentationPreset.allCases.map { preset in
            CoreBoxPresetDrawCount(
                preset: preset,
                count: candidateCount(
                    context: DrawContext(preset: preset),
                    stableItems: activeItems
                )
            )
        }
        let availability = CoreBoxDrawAvailability(
            totalSupportedCount: supportedItems.count,
            selectedContextEligibleCount: selectedCount,
            presetCounts: presetCounts
        )
        let importedIDs = Set(state.sources.map(\.itemID))
        let papers = activeItems.map { item in
            CoreBoxPaperProjection(
                visualSeed: Self.fnv1a64(item.id.uuidString.lowercased().utf8),
                imported: importedIDs.contains(item.id),
                ageBand: Self.ageBand(createdAt: item.createdAt, now: inputs.now)
            )
        }
        return CoreBoxSceneSnapshot(
            inBoxCount: activeItems.count,
            drawAvailability: availability,
            memoryCount: state.memories.count,
            hasCurrentPick: state.currentPick != nil,
            papers: papers,
            rendererTier: inputs.rendererTier,
            motionMode: inputs.motionMode,
            snapshotVersion: snapshotVersion
        )
    }

    private func candidateCount(
        context: DrawContext,
        stableItems: [BoxItem]
    ) -> Int {
        switch CandidatePoolBuilder().build(
            items: stableItems,
            context: context,
            currentPick: nil,
            reservedItemID: nil,
            shownItemIDs: []
        ) {
        case let .candidates(candidates): return candidates.count
        case .empty: return 0
        }
    }

    private static func fnv1a64<S: Sequence>(_ bytes: S) -> UInt64 where S.Element == UInt8 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in bytes {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return hash
    }

    private static func ageBand(createdAt: Date, now: Date) -> Int {
        let ageDays = max(0, now.timeIntervalSince(createdAt)) / (24 * 60 * 60)
        switch ageDays {
        case ..<7: return 0
        case ..<30: return 1
        case ..<90: return 2
        default: return 3
        }
    }
}

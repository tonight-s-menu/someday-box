import Foundation

public enum CoreBoxRendererTier: String, CaseIterable, Codable, Sendable, Comparable {
    case full3D
    case lite3D
    case swiftUI2D

    public var maximumVisiblePapers: Int {
        switch self {
        case .full3D: 24
        case .lite3D: 10
        case .swiftUI2D: 0
        }
    }

    public var degraded: CoreBoxRendererTier {
        switch self {
        case .full3D: .lite3D
        case .lite3D, .swiftUI2D: .swiftUI2D
        }
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        func rank(_ tier: Self) -> Int {
            switch tier {
            case .swiftUI2D: 0
            case .lite3D: 1
            case .full3D: 2
            }
        }
        return rank(lhs) < rank(rhs)
    }
}

public enum CoreBoxRendererPreference: String, CaseIterable, Codable, Sendable {
    case automatic
    case full3D
    case simplified2D

    public var maximumTier: CoreBoxRendererTier {
        switch self {
        case .automatic, .full3D: .full3D
        case .simplified2D: .swiftUI2D
        }
    }
}

public enum CoreBoxMotionMode: String, CaseIterable, Codable, Sendable {
    case normal
    case quick
    case reduced
}

public enum CoreBoxInteractionMode: Equatable, Sendable {
    case idle
    case capturing
    case drawing
    case peeking
    case completing
}

public enum CoreBoxSceneLifecycle: Equatable, Sendable {
    case foreground
    case suspended
}

public enum CoreBoxLidPurpose: Equatable, Sendable {
    case capture
    case peek
    case deposit
    case memoryFeedback
}

public enum CoreBoxLidState: Equatable, Sendable {
    case closed
    case opening(CoreBoxLidPurpose)
    case open(CoreBoxLidPurpose)
    case closing(CoreBoxLidPurpose)
}

public enum CoreBoxDrawState: Equatable, Sendable {
    case idle
    case selectingContext
    case armed
    case pulling(progress: Double)
    case returning
    case committingSelection
    case revealing
    case resultVisible
    case exhausted
}

public enum CoreBoxSceneCommandKind: Equatable, Sendable {
    case openCapture
    case openPeek
    case pull(Double)
    case commitDraw
    case complete
    case reset
}

public struct CoreBoxSceneCommand: Equatable, Sendable {
    public let sequence: UInt64
    public let kind: CoreBoxSceneCommandKind
    public let sourceSnapshotVersion: UInt64
    public let motion: CoreBoxMotionMode

    public init(sequence: UInt64, kind: CoreBoxSceneCommandKind, sourceSnapshotVersion: UInt64, motion: CoreBoxMotionMode) {
        self.sequence = sequence
        self.kind = kind
        self.sourceSnapshotVersion = sourceSnapshotVersion
        self.motion = motion
    }
}

public struct CoreBoxPaperProjection: Equatable, Sendable {
    public let visualSeed: UInt64
    public let imported: Bool
    public let ageBand: Int

    public init(visualSeed: UInt64, imported: Bool, ageBand: Int) {
        self.visualSeed = visualSeed
        self.imported = imported
        self.ageBand = ageBand
    }
}

public struct CoreBoxPresetDrawCount: Equatable, Sendable {
    public let preset: DrawPresentationPreset
    public let count: Int

    public init(preset: DrawPresentationPreset, count: Int) {
        self.preset = preset
        self.count = count
    }
}

public struct CoreBoxDrawAvailability: Equatable, Sendable {
    public let totalSupportedCount: Int
    public let selectedContextEligibleCount: Int
    public let presetCounts: [CoreBoxPresetDrawCount]

    public init(
        totalSupportedCount: Int,
        selectedContextEligibleCount: Int,
        presetCounts: [CoreBoxPresetDrawCount]
    ) {
        self.totalSupportedCount = totalSupportedCount
        self.selectedContextEligibleCount = selectedContextEligibleCount
        self.presetCounts = presetCounts
    }
}

public struct CoreBoxSceneSnapshot: Equatable, Sendable {
    public let inBoxCount: Int
    public let drawAvailability: CoreBoxDrawAvailability
    public let memoryCount: Int
    public let hasCurrentPick: Bool
    public let papers: [CoreBoxPaperProjection]
    public let rendererTier: CoreBoxRendererTier
    public let motionMode: CoreBoxMotionMode
    public let snapshotVersion: UInt64

    public init(
        inBoxCount: Int,
        drawAvailability: CoreBoxDrawAvailability,
        memoryCount: Int,
        hasCurrentPick: Bool,
        papers: [CoreBoxPaperProjection],
        rendererTier: CoreBoxRendererTier,
        motionMode: CoreBoxMotionMode,
        snapshotVersion: UInt64
    ) {
        self.inBoxCount = inBoxCount
        self.drawAvailability = drawAvailability
        self.memoryCount = memoryCount
        self.hasCurrentPick = hasCurrentPick
        self.papers = Array(papers.prefix(rendererTier.maximumVisiblePapers))
        self.rendererTier = rendererTier
        self.motionMode = motionMode
        self.snapshotVersion = snapshotVersion
    }

    /// Compatibility accessor for older presentation surfaces; new code should use
    /// `drawAvailability.totalSupportedCount` so context-specific counts stay visible.
    public var drawableCount: Int { drawAvailability.totalSupportedCount }

    public init(
        inBoxCount: Int,
        drawableCount: Int,
        memoryCount: Int,
        hasCurrentPick: Bool,
        papers: [CoreBoxPaperProjection],
        rendererTier: CoreBoxRendererTier,
        motionMode: CoreBoxMotionMode,
        snapshotVersion: UInt64
    ) {
        self.init(
            inBoxCount: inBoxCount,
            drawAvailability: CoreBoxDrawAvailability(
                totalSupportedCount: drawableCount,
                selectedContextEligibleCount: drawableCount,
                presetCounts: []
            ),
            memoryCount: memoryCount,
            hasCurrentPick: hasCurrentPick,
            papers: papers,
            rendererTier: rendererTier,
            motionMode: motionMode,
            snapshotVersion: snapshotVersion
        )
    }
}

/// Adapter-neutral stable state used by both RealityKit and the functional 2D fallback.
struct CoreBoxStablePose: Equatable, Sendable {
    var snapshotVersion: UInt64
    var inBoxCount: Int
    var visiblePapers: [CoreBoxPaperProjection]
    var hasCurrentPick: Bool
    var memorySeamVisible: Bool
    var lid: CoreBoxLidState
    var draw: CoreBoxDrawState
    var rendererTier: CoreBoxRendererTier
    var motionMode: CoreBoxMotionMode

    init(
        snapshotVersion: UInt64,
        inBoxCount: Int,
        visiblePapers: [CoreBoxPaperProjection],
        hasCurrentPick: Bool,
        memorySeamVisible: Bool,
        lid: CoreBoxLidState,
        draw: CoreBoxDrawState,
        rendererTier: CoreBoxRendererTier,
        motionMode: CoreBoxMotionMode
    ) {
        self.snapshotVersion = snapshotVersion
        self.inBoxCount = inBoxCount
        self.visiblePapers = visiblePapers
        self.hasCurrentPick = hasCurrentPick
        self.memorySeamVisible = memorySeamVisible
        self.lid = lid
        self.draw = draw
        self.rendererTier = rendererTier
        self.motionMode = motionMode
    }

    init(snapshot: CoreBoxSceneSnapshot) {
        snapshotVersion = snapshot.snapshotVersion
        inBoxCount = snapshot.inBoxCount
        visiblePapers = snapshot.papers
        hasCurrentPick = snapshot.hasCurrentPick
        memorySeamVisible = snapshot.memoryCount > 0
        lid = .closed
        draw = snapshot.drawAvailability.selectedContextEligibleCount > 0 ? .armed : .idle
        rendererTier = snapshot.rendererTier
        motionMode = snapshot.motionMode
    }
}

public enum CoreBoxFallbackReason: String, Codable, Sendable {
    case assetLoad
    case assetValidation
    case memoryPressure
    case thermalPressure
    case sustainedFrameBudget
    case lowPowerMode
}

/// Presentation events are deliberately independent of RealityKit so the 2D fallback
/// can preserve product semantics when a 3D asset is rejected.
public enum CoreBoxPresentationEvent: Equatable, Sendable {
    case touch
    case captureReceive
    case captureDeposit(itemID: UUID)
    case drawReveal(attemptID: UUID, itemID: UUID)
    case shareArrival(freshItemIDs: [UUID])
    case currentAttach(attemptID: UUID, itemID: UUID)
    case paperReturn(itemID: UUID)
    case memoryStamp(itemID: UUID, memoryID: UUID)
    case failureSettle
    case fallbackSettle(CoreBoxFallbackReason)
}

public enum CoreBoxSettleReason: Equatable, Sendable {
    case completed
    case cancelled
    case background
    case coveringGate
    case rendererTransition
    case reconciliation
    case validationFailure
}

@MainActor
protocol CoreBoxPresentationAdapter: AnyObject {
    func apply(snapshot: CoreBoxSceneSnapshot)
    func apply(event: CoreBoxPresentationEvent, sourceSnapshotVersion: UInt64)
    func applyRibbon(progress: Double, latched: Bool)
    func settle(reason: CoreBoxSettleReason)
}

public struct CoreBoxPresentationStateMachine: Equatable, Sendable {
    public private(set) var interaction: CoreBoxInteractionMode = .idle
    public private(set) var lifecycle: CoreBoxSceneLifecycle = .foreground
    public private(set) var lid: CoreBoxLidState = .closed
    public private(set) var draw: CoreBoxDrawState = .idle
    public private(set) var renderer: CoreBoxRendererTier
    public private(set) var fallbackReason: CoreBoxFallbackReason?
    public private(set) var latestSequence: UInt64 = 0

    public init(renderer: CoreBoxRendererTier) {
        self.renderer = renderer
    }

    public mutating func begin(_ mode: CoreBoxInteractionMode) -> Bool {
        guard lifecycle == .foreground, interaction == .idle, mode != .idle else { return false }
        interaction = mode
        return true
    }

    public mutating func beginPull() -> Bool {
        guard begin(.drawing) else { return false }
        draw = .armed
        return true
    }

    public mutating func updatePull(progress: Double) {
        guard interaction == .drawing else { return }
        draw = .pulling(progress: min(max(progress, 0), 1))
    }

    public mutating func releasePull(threshold: Double = 0.72) -> Bool {
        guard case let .pulling(progress) = draw else { return false }
        if progress < threshold {
            draw = .returning
            interaction = .idle
            return false
        }
        draw = .committingSelection
        return true
    }

    public mutating func finishInteraction() {
        interaction = .idle
        lid = .closed
        draw = .idle
    }

    public mutating func suspend() {
        lifecycle = .suspended
        interaction = .idle
        lid = .closed
        draw = .idle
    }

    public mutating func resume() {
        lifecycle = .foreground
    }

    public mutating func degrade(for reason: CoreBoxFallbackReason) {
        guard interaction == .idle else { return }
        renderer = renderer.degraded
        fallbackReason = reason
    }

    public mutating func accept(command: CoreBoxSceneCommand) -> Bool {
        guard lifecycle == .foreground, command.sequence > latestSequence else { return false }
        latestSequence = command.sequence
        return true
    }
}

public struct CoreBoxPresentationPreferences: Equatable, Sendable {
    public static let namespace = "core-box-presentation-v2"
    public static let legacyNamespace = "core-box-presentation-v1"

    public var renderer: CoreBoxRendererPreference
    public var quickAnimations: Bool
    public var soundEnabled: Bool
    public var hapticsEnabled: Bool
    public var ambienceEnabled: Bool
    public var lastDrawContext: String?
    public var hasSeenFirstAnimation: Bool

    public init(
        renderer: CoreBoxRendererPreference = .automatic,
        quickAnimations: Bool = false,
        soundEnabled: Bool = true,
        hapticsEnabled: Bool = true,
        ambienceEnabled: Bool = true,
        lastDrawContext: String? = nil,
        hasSeenFirstAnimation: Bool = false
    ) {
        self.renderer = renderer
        self.quickAnimations = quickAnimations
        self.soundEnabled = soundEnabled
        self.hapticsEnabled = hapticsEnabled
        self.ambienceEnabled = ambienceEnabled
        self.lastDrawContext = lastDrawContext
        self.hasSeenFirstAnimation = hasSeenFirstAnimation
    }
}

public struct CoreBoxPresentationPreferenceStore: @unchecked Sendable {
    private enum Key {
        static let renderer = "renderer"
        static let quick = "quick"
        static let sound = "sound"
        static let haptics = "haptics"
        static let ambience = "ambience"
        static let lastContext = "last-context"
        static let firstAnimation = "first-animation"
    }

    public static let migrationCompletedKey = "\(CoreBoxPresentationPreferences.namespace).migrationCompleted"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private func key(_ value: String) -> String { "\(CoreBoxPresentationPreferences.namespace).\(value)" }

    public func load() -> CoreBoxPresentationPreferences {
        _ = loadMigratingIfNeeded()
        let renderer = defaults.string(forKey: key(Key.renderer)).flatMap(CoreBoxRendererPreference.init(rawValue:)) ?? .automatic
        return CoreBoxPresentationPreferences(
            renderer: renderer,
            quickAnimations: defaults.object(forKey: key(Key.quick)) as? Bool ?? false,
            soundEnabled: defaults.object(forKey: key(Key.sound)) as? Bool ?? true,
            hapticsEnabled: defaults.object(forKey: key(Key.haptics)) as? Bool ?? true,
            ambienceEnabled: defaults.object(forKey: key(Key.ambience)) as? Bool ?? true,
            lastDrawContext: defaults.string(forKey: key(Key.lastContext)),
            hasSeenFirstAnimation: defaults.object(forKey: key(Key.firstAnimation)) as? Bool ?? false
        )
    }

    public func save(_ value: CoreBoxPresentationPreferences) {
        defaults.set(value.renderer.rawValue, forKey: key(Key.renderer))
        defaults.set(value.quickAnimations, forKey: key(Key.quick))
        defaults.set(value.soundEnabled, forKey: key(Key.sound))
        defaults.set(value.hapticsEnabled, forKey: key(Key.haptics))
        defaults.set(value.ambienceEnabled, forKey: key(Key.ambience))
        defaults.set(value.lastDrawContext, forKey: key(Key.lastContext))
        defaults.set(value.hasSeenFirstAnimation, forKey: key(Key.firstAnimation))
    }

    public func reset() {
        resetAllNamespaces()
    }

    public func loadMigratingIfNeeded() -> CoreBoxPresentationPreferences {
        if !defaults.bool(forKey: Self.migrationCompletedKey) {
            let writes = CoreBoxPreferenceMigrator().v2Writes(from: defaults)
            for write in writes {
                switch write.value {
                case let .string(value): defaults.set(value, forKey: write.key)
                case let .bool(value): defaults.set(value, forKey: write.key)
                }
            }
            removeLegacyKeys()
        } else {
            removeLegacyKeys()
        }
        return readV2()
    }

    public func resetAllNamespaces() {
        for namespace in [CoreBoxPresentationPreferences.legacyNamespace, CoreBoxPresentationPreferences.namespace] {
            for value in [Key.renderer, Key.quick, Key.sound, Key.haptics, Key.ambience, Key.lastContext, Key.firstAnimation, "migrationCompleted"] {
                defaults.removeObject(forKey: "\(namespace).\(value)")
            }
        }
    }

    private func readV2() -> CoreBoxPresentationPreferences {
        let renderer = defaults.string(forKey: key(Key.renderer)).flatMap(CoreBoxRendererPreference.init(rawValue:)) ?? .automatic
        return CoreBoxPresentationPreferences(
            renderer: renderer,
            quickAnimations: defaults.object(forKey: key(Key.quick)) as? Bool ?? false,
            soundEnabled: defaults.object(forKey: key(Key.sound)) as? Bool ?? true,
            hapticsEnabled: defaults.object(forKey: key(Key.haptics)) as? Bool ?? true,
            ambienceEnabled: defaults.object(forKey: key(Key.ambience)) as? Bool ?? true,
            lastDrawContext: defaults.string(forKey: key(Key.lastContext)),
            hasSeenFirstAnimation: defaults.object(forKey: key(Key.firstAnimation)) as? Bool ?? false
        )
    }

    private func removeLegacyKeys() {
        for value in [Key.renderer, Key.quick, Key.sound, Key.haptics, Key.ambience, Key.lastContext, Key.firstAnimation] {
            defaults.removeObject(forKey: "\(CoreBoxPresentationPreferences.legacyNamespace).\(value)")
        }
    }
}

public enum CoreBoxPreferenceValue: Equatable, Sendable {
    case string(String)
    case bool(Bool)
}

public struct CoreBoxPreferenceWrite: Equatable, Sendable {
    public let key: String
    public let value: CoreBoxPreferenceValue

    public init(key: String, value: CoreBoxPreferenceValue) {
        self.key = key
        self.value = value
    }
}

public struct CoreBoxPreferenceMigrator: Sendable {
    public init() {}

    public func v2Writes(from defaults: UserDefaults) -> [CoreBoxPreferenceWrite] {
        let legacy = CoreBoxPresentationPreferences.legacyNamespace
        let current = CoreBoxPresentationPreferences.namespace
        let legacyRenderer = defaults.string(forKey: "\(legacy).renderer").flatMap { value -> String? in
            switch value {
            case "full3D": return CoreBoxRendererPreference.full3D.rawValue
            case "swiftUI2D": return CoreBoxRendererPreference.simplified2D.rawValue
            case "lite3D", "automatic": return CoreBoxRendererPreference.automatic.rawValue
            default: return CoreBoxRendererPreference.automatic.rawValue
            }
        } ?? CoreBoxRendererPreference.automatic.rawValue
        let renderer = defaults.string(forKey: "\(current).renderer")
            .flatMap(CoreBoxRendererPreference.init(rawValue:))?.rawValue ?? legacyRenderer
        var writes: [CoreBoxPreferenceWrite] = [
            .init(key: "\(current).renderer", value: .string(renderer))
        ]
        let boolKeys = ["quick", "sound", "haptics", "ambience", "first-animation"]
        let defaultsByKey: [String: Bool] = ["quick": false, "sound": true, "haptics": true, "ambience": true, "first-animation": false]
        for value in boolKeys {
            let key = "\(legacy).\(value)"
            let currentKey = "\(current).\(value)"
            let boolValue = defaults.object(forKey: currentKey) as? Bool
                ?? defaults.object(forKey: key) as? Bool
                ?? defaultsByKey[value]!
            writes.append(.init(key: currentKey, value: .bool(boolValue)))
        }
        if let context = defaults.string(forKey: "\(current).last-context") ?? defaults.string(forKey: "\(legacy).last-context") {
            writes.append(.init(key: "\(current).last-context", value: .string(context)))
        }
        writes.append(.init(key: CoreBoxPresentationPreferenceStore.migrationCompletedKey, value: .bool(true)))
        return writes
    }
}

import Foundation

public enum CoreBoxRendererTier: String, CaseIterable, Codable, Sendable {
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

public struct CoreBoxSceneSnapshot: Equatable, Sendable {
    public let inBoxCount: Int
    public let drawableCount: Int
    public let memoryCount: Int
    public let hasCurrentPick: Bool
    public let papers: [CoreBoxPaperProjection]
    public let rendererTier: CoreBoxRendererTier
    public let motionMode: CoreBoxMotionMode
    public let snapshotVersion: UInt64

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
        self.inBoxCount = inBoxCount
        self.drawableCount = drawableCount
        self.memoryCount = memoryCount
        self.hasCurrentPick = hasCurrentPick
        self.papers = Array(papers.prefix(rendererTier.maximumVisiblePapers))
        self.rendererTier = rendererTier
        self.motionMode = motionMode
        self.snapshotVersion = snapshotVersion
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
    public static let namespace = "core-box-presentation-v1"

    public var renderer: CoreBoxRendererTier
    public var quickAnimations: Bool
    public var soundEnabled: Bool
    public var hapticsEnabled: Bool
    public var ambienceEnabled: Bool
    public var lastDrawContext: String?
    public var hasSeenFirstAnimation: Bool

    public init(
        renderer: CoreBoxRendererTier = .full3D,
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

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private func key(_ value: String) -> String { "\(CoreBoxPresentationPreferences.namespace).\(value)" }

    public func load() -> CoreBoxPresentationPreferences {
        let renderer = defaults.string(forKey: key(Key.renderer)).flatMap(CoreBoxRendererTier.init(rawValue:)) ?? .full3D
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
        for value in [Key.renderer, Key.quick, Key.sound, Key.haptics, Key.ambience, Key.lastContext, Key.firstAnimation] {
            defaults.removeObject(forKey: key(value))
        }
    }
}

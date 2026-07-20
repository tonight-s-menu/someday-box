import Observation

public enum CoreBoxChannel: CaseIterable, Hashable, Sendable {
    case root, lid, leftEye, rightEye, ribbon, paper, camera, memorySeam
}

public enum CoreBoxPresentationOwner: Int, Comparable, Sendable {
    case idle = 0
    case notice = 1
    case directGesture = 2
    case committedTransaction = 3
    case lifecycle = 4
    case rootGate = 5

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

public struct CoreBoxCorrelatedEvent: Equatable, Sendable {
    public let sequence: UInt64
    public let event: CoreBoxPresentationEvent
    public let sourceSnapshotVersion: UInt64
    public let motionMode: CoreBoxMotionMode

    public init(
        sequence: UInt64,
        event: CoreBoxPresentationEvent,
        sourceSnapshotVersion: UInt64,
        motionMode: CoreBoxMotionMode
    ) {
        self.sequence = sequence
        self.event = event
        self.sourceSnapshotVersion = sourceSnapshotVersion
        self.motionMode = motionMode
    }
}

public struct CoreBoxEnqueueResult: Equatable, Sendable {
    public let event: CoreBoxCorrelatedEvent
    public let cancelledOwner: CoreBoxPresentationOwner?

    public init(event: CoreBoxCorrelatedEvent, cancelledOwner: CoreBoxPresentationOwner?) {
        self.event = event
        self.cancelledOwner = cancelledOwner
    }
}

/// A committed transaction may own several correlated motion segments as one unit.
public struct CoreBoxCorrelatedSequence: Equatable, Sendable {
    public let sequence: UInt64
    public let sourceSnapshotVersion: UInt64
    public let motionMode: CoreBoxMotionMode
    public let events: [CoreBoxPresentationEvent]

    public init(
        sequence: UInt64,
        sourceSnapshotVersion: UInt64,
        motionMode: CoreBoxMotionMode,
        events: [CoreBoxPresentationEvent]
    ) {
        self.sequence = sequence
        self.sourceSnapshotVersion = sourceSnapshotVersion
        self.motionMode = motionMode
        self.events = events
    }
}

public enum CoreBoxMotionTimingProfile: Equatable, Sendable {
    case first
    case normal
    case rapid
    case reduced
}

public enum CoreBoxMotionFamily: Equatable, Sendable {
    case lid, captureDeposit, ribbonReturn, drawReveal, peek, completion
}

public struct CoreBoxMotionTiming: Equatable, Sendable {
    public let durationMilliseconds: Int
    public let usesDepthMotion: Bool

    public init(durationMilliseconds: Int, usesDepthMotion: Bool) {
        self.durationMilliseconds = durationMilliseconds
        self.usesDepthMotion = usesDepthMotion
    }
}

public func timingProfile(
    motionMode: CoreBoxMotionMode,
    hasSeenFirstAnimation: Bool
) -> CoreBoxMotionTimingProfile {
    switch motionMode {
    case .reduced: .reduced
    case .quick: .rapid
    case .normal: hasSeenFirstAnimation ? .normal : .first
    }
}

public func timing(
    family: CoreBoxMotionFamily,
    motionMode: CoreBoxMotionMode,
    hasSeenFirstAnimation: Bool
) -> CoreBoxMotionTiming {
    let profile = timingProfile(motionMode: motionMode, hasSeenFirstAnimation: hasSeenFirstAnimation)
    let duration: Int
    let depth: Bool
    switch (family, profile) {
    case (.lid, .first): (duration, depth) = (400, true)
    case (.lid, .normal): (duration, depth) = (280, true)
    case (.lid, .rapid): (duration, depth) = (150, true)
    case (.lid, .reduced): (duration, depth) = (120, false)
    case (.captureDeposit, .first): (duration, depth) = (775, true)
    case (.captureDeposit, .normal): (duration, depth) = (470, true)
    case (.captureDeposit, .rapid): (duration, depth) = (220, true)
    case (.captureDeposit, .reduced): (duration, depth) = (150, false)
    case (.ribbonReturn, _): (duration, depth) = (220, profile != .reduced)
    case (.drawReveal, .first): (duration, depth) = (850, true)
    case (.drawReveal, .normal): (duration, depth) = (625, true)
    case (.drawReveal, .rapid): (duration, depth) = (340, true)
    case (.drawReveal, .reduced): (duration, depth) = (180, false)
    case (.peek, .first): (duration, depth) = (550, true)
    case (.peek, .normal): (duration, depth) = (425, true)
    case (.peek, .rapid): (duration, depth) = (220, true)
    case (.peek, .reduced): (duration, depth) = (150, false)
    case (.completion, .first): (duration, depth) = (750, true)
    case (.completion, .normal): (duration, depth) = (525, true)
    case (.completion, .rapid): (duration, depth) = (285, true)
    case (.completion, .reduced): (duration, depth) = (150, false)
    }
    return CoreBoxMotionTiming(durationMilliseconds: duration, usesDepthMotion: depth)
}

public enum CoreBoxHapticEvent: Equatable, Sendable {
    case thresholdLatch
    case committedDeposit
    case committedReveal
    case committedCompletion
}

public struct CoreBoxHapticPolicy: Sendable {
    public init() {}
    public func permits(_ event: CoreBoxHapticEvent, hapticsEnabled: Bool) -> Bool {
        _ = event
        return hapticsEnabled
    }
}

@MainActor
@Observable
public final class CoreBoxPresentationCoordinator {
    public private(set) var snapshot: CoreBoxSceneSnapshot
    public private(set) var latestSequence: UInt64 = 0
    private var owners: [CoreBoxChannel: CoreBoxPresentationOwner] = [:]
    private var ribbonProgress = 0.0
    private var ribbonLatched = false

    public init(snapshot: CoreBoxSceneSnapshot) {
        self.snapshot = snapshot
    }

    public func update(snapshot: CoreBoxSceneSnapshot) {
        guard snapshot.snapshotVersion >= self.snapshot.snapshotVersion else { return }
        self.snapshot = snapshot
        owners.removeAll()
        ribbonProgress = 0
        ribbonLatched = false
    }

    public func accept(_ command: CoreBoxSceneCommand) -> Bool {
        guard command.sourceSnapshotVersion == snapshot.snapshotVersion,
              command.sequence > latestSequence else { return false }
        latestSequence = command.sequence
        return true
    }

    public func beginRibbonPull(context: DrawContext, nativeDrawEnabled: Bool) -> Bool {
        guard nativeDrawEnabled,
              context.isValid,
              snapshot.drawAvailability.selectedContextEligibleCount > 0,
              canClaim([.ribbon], owner: .directGesture) else { return false }
        owners[.ribbon] = .directGesture
        ribbonProgress = 0
        ribbonLatched = false
        return true
    }

    public func updateRibbonPull(progress: Double) {
        guard owners[.ribbon] == .directGesture else { return }
        ribbonProgress = min(max(progress, 0), 1)
        if ribbonProgress >= 0.72 { ribbonLatched = true }
    }

    public func enqueue(
        event: CoreBoxPresentationEvent,
        sourceSnapshotVersion: UInt64
    ) -> CoreBoxEnqueueResult? {
        guard sourceSnapshotVersion == snapshot.snapshotVersion else { return nil }
        latestSequence += 1
        let owner: CoreBoxPresentationOwner = .committedTransaction
        let channels = channels(for: event)
        let channelOwners = channels.compactMap { channel -> CoreBoxPresentationOwner? in
            guard let existing = owners[channel], existing < owner else { return nil }
            return existing
        }
        let cancelled = (channelOwners + owners.values.filter { $0 < owner }).max()
        if cancelled != nil {
            owners = owners.filter { $0.value >= owner || channels.contains($0.key) }
        }
        for channel in channels { owners[channel] = owner }
        return CoreBoxEnqueueResult(
            event: CoreBoxCorrelatedEvent(
                sequence: latestSequence,
                event: event,
                sourceSnapshotVersion: sourceSnapshotVersion,
                motionMode: snapshot.motionMode
            ),
            cancelledOwner: cancelled
        )
    }

    /// Reserves all channels for an ordered committed sequence before playback begins.
    public func enqueue(sequence: CoreBoxCorrelatedSequence) -> Bool {
        guard sequence.sourceSnapshotVersion == snapshot.snapshotVersion,
              sequence.sequence > latestSequence,
              !sequence.events.isEmpty else { return false }
        let channels = sequence.events.flatMap(channels(for:))
        let owner: CoreBoxPresentationOwner = .committedTransaction
        let cancelled = owners.values.filter { $0 < owner }.max()
        if cancelled != nil {
            owners = owners.filter { $0.value >= owner || channels.contains($0.key) }
        }
        channels.forEach { owners[$0] = owner }
        latestSequence = sequence.sequence
        return true
    }

    public func owner(of channel: CoreBoxChannel) -> CoreBoxPresentationOwner? {
        owners[channel]
    }

    public func settleAll() {
        owners.removeAll()
        ribbonProgress = 0
        ribbonLatched = false
    }

    private func canClaim(_ channels: [CoreBoxChannel], owner: CoreBoxPresentationOwner) -> Bool {
        channels.allSatisfy { owners[$0].map { $0 <= owner } ?? true }
    }

    private func channels(for event: CoreBoxPresentationEvent) -> [CoreBoxChannel] {
        switch event {
        case .captureDeposit: return [.lid, .paper]
        case .drawReveal: return [.lid, .paper, .camera]
        case .currentAttach: return [.paper, .memorySeam]
        case .paperReturn: return [.paper, .lid]
        case .memoryStamp: return [.paper, .memorySeam]
        case .captureReceive: return [.lid, .paper]
        case .touch: return [.root]
        case .failureSettle, .fallbackSettle: return CoreBoxChannel.allCases
        }
    }
}

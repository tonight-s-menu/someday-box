import Foundation
import Observation
import RealityKit

enum LidCapturePhase: Equatable {
    case idle
    case openingLid(SceneAnimationTier)
    case risingPaper(SceneAnimationTier)
    case editing(SceneAnimationTier)
    case failureHover(SceneAnimationTier)
    case folding(SceneAnimationTier)
    case dropping(SceneAnimationTier)
    case closingLid(SceneAnimationTier)
    case cancelling

    var tier: SceneAnimationTier? {
        switch self {
        case .idle, .cancelling: nil
        case let .openingLid(tier), let .risingPaper(tier), let .editing(tier),
             let .failureHover(tier), let .folding(tier), let .dropping(tier),
             let .closingLid(tier): tier
        }
    }
}

struct LidCaptureTiming: Equatable, Sendable {
    let lidOpen: Duration
    let paperRise: Duration
    let fold: Duration
    let drop: Duration
    let lidClose: Duration

    static func timing(for tier: SceneAnimationTier) -> LidCaptureTiming {
        switch tier {
        case .full:
            LidCaptureTiming(
                lidOpen: .milliseconds(320),
                paperRise: .milliseconds(360),
                fold: .milliseconds(300),
                drop: .milliseconds(550),
                lidClose: .milliseconds(350)
            )
        case .standard:
            LidCaptureTiming(
                lidOpen: .milliseconds(180),
                paperRise: .milliseconds(180),
                fold: .milliseconds(100),
                drop: .milliseconds(230),
                lidClose: .milliseconds(170)
            )
        case .minimal:
            LidCaptureTiming(
                lidOpen: .zero,
                paperRise: .zero,
                fold: .milliseconds(50),
                drop: .milliseconds(120),
                lidClose: .milliseconds(80)
            )
        }
    }

    var captureDropTotal: Duration { fold + drop + lidClose }
}

/// Owns only the presentation sequence around the existing capture sheet. Product commit
/// still happens inside `CapturePaperUseCase`; this coordinator is notified only after that
/// commit succeeds or fails.
@MainActor
@Observable
final class LidCaptureCoordinator {
    typealias Sleep = @MainActor @Sendable (Duration) async -> Void

    private(set) var phase: LidCapturePhase = .idle
    private(set) var presentsCaptureSheet = false

    private let historyStore: AnimationTierHistoryStore
    private let now: @MainActor () -> Date
    private let sleep: Sleep
    private var sequenceTask: Task<Void, Never>?

    init(
        historyStore: AnimationTierHistoryStore = AnimationTierHistoryStore(),
        now: @escaping @MainActor () -> Date = { Date() },
        sleep: @escaping Sleep = { duration in try? await Task.sleep(for: duration) }
    ) {
        self.historyStore = historyStore
        self.now = now
        self.sleep = sleep
    }

    func beginNormalCapture(reduceMotion: Bool) {
        guard phase == .idle else { return }
        let tier = historyStore.previewTier(
            for: .captureDrop,
            now: now(),
            forcedMinimal: reduceMotion
        )
        sequenceTask?.cancel()
        sequenceTask = Task { [weak self] in
            guard let self else { return }
            let timing = LidCaptureTiming.timing(for: tier)
            phase = .openingLid(tier)
            await sleep(timing.lidOpen)
            guard !Task.isCancelled else { return }
            phase = .risingPaper(tier)
            await sleep(timing.paperRise)
            guard !Task.isCancelled else { return }
            phase = .editing(tier)
            presentsCaptureSheet = true
        }
    }

    /// The long-press path has no preamble animation (LID-04, FST-02).
    func beginFastCapture() {
        guard phase == .idle else { return }
        sequenceTask?.cancel()
        phase = .editing(.minimal)
        presentsCaptureSheet = true
    }

    func captureFailed() {
        guard case let .editing(tier) = phase else { return }
        phase = .failureHover(tier)
    }

    func captureSucceeded(reduceMotion: Bool) {
        guard phase.tier != nil else { return }
        presentsCaptureSheet = false
        let tier = historyStore.recordAndSelectTier(
            for: .captureDrop,
            now: now(),
            forcedMinimal: reduceMotion
        )
        sequenceTask?.cancel()
        sequenceTask = Task { [weak self] in
            guard let self else { return }
            let timing = LidCaptureTiming.timing(for: tier)
            phase = .folding(tier)
            await sleep(timing.fold)
            guard !Task.isCancelled else { return }
            phase = .dropping(tier)
            await sleep(timing.drop)
            guard !Task.isCancelled else { return }
            phase = .closingLid(tier)
            await sleep(timing.lidClose)
            guard !Task.isCancelled else { return }
            phase = .idle
        }
    }

    /// Called by the sheet boundary. A successful save has already entered its fold/drop
    /// sequence; only cancellation of a still-editing draft retracts the presentation.
    func captureSheetDismissed(reduceMotion: Bool) {
        presentsCaptureSheet = false
        switch phase {
        case .editing, .failureHover:
            sequenceTask?.cancel()
            sequenceTask = Task { [weak self] in
                guard let self else { return }
                phase = .cancelling
                if !reduceMotion { await sleep(.milliseconds(180)) }
                guard !Task.isCancelled else { return }
                phase = .idle
            }
        default:
            break
        }
    }

    func waitForCurrentSequence() async {
        await sequenceTask?.value
    }
}

/// Applies `LidCapturePhase` to the entities. It never reads or writes product records;
/// the resting paper stack separately diff-applies the already-committed snapshot.
@MainActor
final class LidCaptureSceneAnimator {
    enum NodeName {
        static let focusPaper = "FocusPaper"
    }

    private enum Metrics {
        static let paperWidth: Float = 0.132
        static let paperDepth: Float = 0.088
        static let paperThickness: Float = 0.0018
        static let insideY = BoxGeometry.Metrics.interiorFloor + 0.014
        static let hoverY = BoxGeometry.Metrics.bodyHeight / 2 + 0.065
    }

    let root: Entity
    private let box: BoxGeometry
    private let focusPaper: ModelEntity
    private var appliedPhase: LidCapturePhase?

    init(box: BoxGeometry) {
        self.box = box
        let root = Entity()
        root.name = NodeName.focusPaper
        let paper = ModelEntity(
            mesh: .generateBox(
                width: Metrics.paperWidth,
                height: Metrics.paperThickness,
                depth: Metrics.paperDepth,
                cornerRadius: 0.004
            ),
            materials: [BoxMaterials.paper()]
        )
        paper.name = "CapturePaper"
        paper.isEnabled = false
        root.addChild(paper)
        self.root = root
        focusPaper = paper
    }

    func apply(_ phase: LidCapturePhase, reduceMotion: Bool) {
        guard phase != appliedPhase else { return }
        appliedPhase = phase

        switch phase {
        case .idle:
            focusPaper.isEnabled = false
            focusPaper.transform = insideTransform
            box.setLid(openness: 0)
        case let .openingLid(tier):
            focusPaper.isEnabled = false
            box.setLid(
                openness: 1,
                animatedOver: reduceMotion ? 0 : LidCaptureTiming.timing(for: tier).lidOpen.timeInterval
            )
        case let .risingPaper(tier):
            box.setLid(openness: 1)
            focusPaper.isEnabled = true
            focusPaper.transform = insideTransform
            movePaper(
                to: hoverTransform,
                over: reduceMotion ? 0 : LidCaptureTiming.timing(for: tier).paperRise.timeInterval
            )
        case .editing, .failureHover:
            box.setLid(openness: 1)
            focusPaper.isEnabled = true
            focusPaper.transform = hoverTransform
        case let .folding(tier):
            box.setLid(openness: 1)
            focusPaper.isEnabled = true
            movePaper(
                to: foldedTransform,
                over: reduceMotion ? 0 : LidCaptureTiming.timing(for: tier).fold.timeInterval
            )
        case let .dropping(tier):
            movePaper(
                to: droppedTransform,
                over: reduceMotion ? 0 : LidCaptureTiming.timing(for: tier).drop.timeInterval
            )
        case let .closingLid(tier):
            focusPaper.isEnabled = false
            box.setLid(
                openness: 0,
                animatedOver: reduceMotion ? 0 : LidCaptureTiming.timing(for: tier).lidClose.timeInterval
            )
        case .cancelling:
            focusPaper.isEnabled = false
            box.setLid(openness: 0, animatedOver: reduceMotion ? 0 : 0.18)
        }
    }

    private var insideTransform: Transform {
        Transform(translation: [0, Metrics.insideY, 0])
    }

    private var hoverTransform: Transform {
        Transform(
            rotation: simd_quatf(angle: -0.10, axis: [0, 0, 1]),
            translation: [0, Metrics.hoverY, 0.004]
        )
    }

    private var foldedTransform: Transform {
        Transform(
            scale: [1, 1, 0.46],
            rotation: simd_quatf(angle: 0.08, axis: [0, 0, 1]),
            translation: [0, Metrics.hoverY - 0.012, 0]
        )
    }

    private var droppedTransform: Transform {
        Transform(
            scale: [0.74, 1, 0.42],
            rotation: simd_quatf(angle: -0.16, axis: [0, 1, 0]),
            translation: [0.012, Metrics.insideY, -0.008]
        )
    }

    private func movePaper(to transform: Transform, over duration: TimeInterval) {
        if duration > 0 {
            focusPaper.move(
                to: transform,
                relativeTo: focusPaper.parent,
                duration: duration,
                timingFunction: .easeInOut
            )
        } else {
            focusPaper.transform = transform
        }
    }
}

private extension Duration {
    var timeInterval: TimeInterval {
        let components = self.components
        return TimeInterval(components.seconds)
            + TimeInterval(components.attoseconds) / 1_000_000_000_000_000_000
    }
}

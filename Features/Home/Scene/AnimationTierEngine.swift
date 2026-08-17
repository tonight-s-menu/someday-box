import Foundation

enum SceneAnimationTier: String, Equatable, Sendable {
    case full
    case standard
    case minimal
}

struct SceneAnimationHistory: Equatable, Sendable {
    var completedCount: Int
    var lastCompletedAt: Date?

    static let empty = SceneAnimationHistory(completedCount: 0, lastCompletedAt: nil)
}

/// Selects presentation duration without owning product truth. The first three completed
/// occurrences use the full sequence, while a repeat within 30 seconds and every forced
/// quick path use the minimal sequence (§11.2).
struct AnimationTierEngine: Sendable {
    static let repeatWindow: TimeInterval = 30

    func tier(
        for history: SceneAnimationHistory,
        now: Date,
        forcedMinimal: Bool
    ) -> SceneAnimationTier {
        if forcedMinimal { return .minimal }
        if let lastCompletedAt = history.lastCompletedAt,
           now.timeIntervalSince(lastCompletedAt) <= Self.repeatWindow,
           now >= lastCompletedAt {
            return .minimal
        }
        return history.completedCount < 3 ? .full : .standard
    }

    func recordingCompletion(
        in history: SceneAnimationHistory,
        at date: Date
    ) -> SceneAnimationHistory {
        SceneAnimationHistory(
            completedCount: history.completedCount + 1,
            lastCompletedAt: date
        )
    }
}

/// Non-authoritative presentation history. It is intentionally excluded from backups and
/// may reset on reinstall, just like the other §16.2 presentation preferences.
@MainActor
final class AnimationTierHistoryStore {
    enum Sequence: String {
        case captureDrop = "capture-drop"
    }

    private let defaults: UserDefaults
    private let engine = AnimationTierEngine()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func previewTier(
        for sequence: Sequence,
        now: Date,
        forcedMinimal: Bool
    ) -> SceneAnimationTier {
        engine.tier(for: history(for: sequence), now: now, forcedMinimal: forcedMinimal)
    }

    func recordAndSelectTier(
        for sequence: Sequence,
        now: Date,
        forcedMinimal: Bool
    ) -> SceneAnimationTier {
        let history = history(for: sequence)
        let tier = engine.tier(for: history, now: now, forcedMinimal: forcedMinimal)
        let updated = engine.recordingCompletion(in: history, at: now)
        defaults.set(updated.completedCount, forKey: countKey(for: sequence))
        defaults.set(updated.lastCompletedAt, forKey: lastCompletedKey(for: sequence))
        return tier
    }

    private func history(for sequence: Sequence) -> SceneAnimationHistory {
        SceneAnimationHistory(
            completedCount: defaults.integer(forKey: countKey(for: sequence)),
            lastCompletedAt: defaults.object(forKey: lastCompletedKey(for: sequence)) as? Date
        )
    }

    private func countKey(for sequence: Sequence) -> String {
        "animation.\(sequence.rawValue).completedCount"
    }

    private func lastCompletedKey(for sequence: Sequence) -> String {
        "animation.\(sequence.rawValue).lastCompletedAt"
    }
}

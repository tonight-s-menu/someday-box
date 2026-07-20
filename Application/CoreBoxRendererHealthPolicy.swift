import Foundation

public enum CoreBoxThermalLevel: Equatable, Sendable {
    case nominal, fair, serious, critical
}

public struct CoreBoxFrameWindow: Equatable, Sendable {
    public let sampleCount: Int
    public let elapsedMilliseconds: Int
    public let p95Milliseconds: Double
    public let hardBudgetFraction: Double

    public init(sampleCount: Int, elapsedMilliseconds: Int, p95Milliseconds: Double, hardBudgetFraction: Double) {
        self.sampleCount = sampleCount
        self.elapsedMilliseconds = elapsedMilliseconds
        self.p95Milliseconds = p95Milliseconds
        self.hardBudgetFraction = hardBudgetFraction
    }
}

public enum CoreBoxRendererHealthSignal: Equatable, Sendable {
    case lowPowerChanged(Bool)
    case memoryWarning
    case thermal(CoreBoxThermalLevel)
    case frameWindow(CoreBoxFrameWindow)
}

public struct CoreBoxFrameWindowAccumulator: Sendable {
    public let requiredSampleCount: Int
    private var samples: [Double] = []

    public init(requiredSampleCount: Int = 120) {
        self.requiredSampleCount = requiredSampleCount
    }

    public var sampleCount: Int { samples.count }

    public mutating func appendActiveFrame(milliseconds: Double) -> CoreBoxFrameWindow? {
        guard milliseconds.isFinite, milliseconds > 0 else {
            reset(reason: .cancelled)
            return nil
        }
        samples.append(milliseconds)
        guard samples.count == requiredSampleCount else { return nil }
        let sorted = samples.sorted()
        let rank = max(0, Int(ceil(Double(sorted.count) * 0.95)) - 1)
        let p95 = sorted[rank]
        let elapsed = Int(samples.reduce(0, +).rounded())
        let hardFraction = Double(samples.filter { $0 > 33.3 }.count) / Double(samples.count)
        samples.removeAll(keepingCapacity: true)
        return CoreBoxFrameWindow(sampleCount: requiredSampleCount, elapsedMilliseconds: elapsed, p95Milliseconds: p95, hardBudgetFraction: hardFraction)
    }

    public mutating func suspendAtStableBoundary() {}

    public mutating func reset(reason _: CoreBoxSettleReason) {
        samples.removeAll(keepingCapacity: true)
    }
}

public struct CoreBoxRendererHealthPolicy: Sendable {
    private let preference: CoreBoxRendererPreference
    private var effectiveTier: CoreBoxRendererTier
    private var breachStreak = 0
    private var pendingCap: CoreBoxRendererTier?
    private var cooldownUntil: TimeInterval?

    public init(preference: CoreBoxRendererPreference, effectiveTier: CoreBoxRendererTier) {
        self.preference = preference
        self.effectiveTier = effectiveTier
    }

    public mutating func receive(_ signal: CoreBoxRendererHealthSignal, nowSeconds: TimeInterval) -> CoreBoxRendererTier? {
        guard preference != .simplified2D else { return nil }
        let requested: CoreBoxRendererTier?
        switch signal {
        case let .lowPowerChanged(enabled): requested = enabled ? .lite3D : nil
        case .memoryWarning: requested = lowerTier(from: effectiveTier)
        case let .thermal(level):
            switch level {
            case .critical: requested = .swiftUI2D
            case .serious: requested = .lite3D
            case .nominal, .fair: requested = nil
            }
        case let .frameWindow(window):
            guard isComplete(window) else { breachStreak = 0; return nil }
            if isBreach(window) {
                breachStreak += 1
                requested = breachStreak >= 2 ? lowerTier(from: effectiveTier) : nil
            } else {
                breachStreak = 0
                return nil
            }
        }
        guard let requested else { return nil }
        return accept(requested, nowSeconds: nowSeconds)
    }

    public mutating func didPublish(tier: CoreBoxRendererTier, nowSeconds: TimeInterval) {
        effectiveTier = tier
        cooldownUntil = nowSeconds + 30
        pendingCap = nil
        breachStreak = 0
    }

    public mutating func poll(nowSeconds: TimeInterval) -> CoreBoxRendererTier? {
        guard let cooldownUntil, nowSeconds >= cooldownUntil else { return nil }
        self.cooldownUntil = nil
        guard let pendingCap else { return nil }
        self.pendingCap = nil
        return pendingCap
    }

    private func isComplete(_ window: CoreBoxFrameWindow) -> Bool {
        window.sampleCount == 120 && window.elapsedMilliseconds > 0 && window.p95Milliseconds.isFinite && window.p95Milliseconds > 0 && (0...1).contains(window.hardBudgetFraction)
    }

    private func isBreach(_ window: CoreBoxFrameWindow) -> Bool {
        switch effectiveTier {
        case .full3D: return window.p95Milliseconds > 25 || window.hardBudgetFraction > 0.10
        case .lite3D: return window.p95Milliseconds > 40 || window.hardBudgetFraction > 0.10
        case .swiftUI2D: return false
        }
    }

    private func lowerTier(from tier: CoreBoxRendererTier) -> CoreBoxRendererTier? {
        switch tier {
        case .full3D: .lite3D
        case .lite3D: .swiftUI2D
        case .swiftUI2D: nil
        }
    }

    private mutating func accept(_ requested: CoreBoxRendererTier, nowSeconds: TimeInterval) -> CoreBoxRendererTier? {
        guard requested < effectiveTier else { return nil }
        if let cooldownUntil, nowSeconds < cooldownUntil {
            if pendingCap == nil || requested < pendingCap! { pendingCap = requested }
            return nil
        }
        return requested
    }
}

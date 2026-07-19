import Foundation

public enum EmptyPoolReason: Equatable, Sendable {
    case noActivePapers
    case unsupportedDurations
    case overTimeBudget
    case alreadyShownInSession
}

public enum CandidatePoolResult: Equatable, Sendable {
    case candidates([BoxItem])
    case empty(EmptyPoolReason)
}

public struct CandidatePoolBuilder: Sendable {
    public init() {}

    public func build(
        items: [BoxItem],
        availableTime: AvailableTime,
        currentPick: CurrentPick?,
        reservedItemID: UUID?,
        shownItemIDs: Set<UUID>
    ) -> CandidatePoolResult {
        let active = items.filter {
            $0.lifecycle == .active && $0.id != currentPick?.itemID && $0.id != reservedItemID
        }
        guard !active.isEmpty else { return .empty(.noActivePapers) }

        let actionable = active.filter { $0.supportedDuration != nil }
        guard !actionable.isEmpty else { return .empty(.unsupportedDurations) }

        let timeFitting = actionable.filter { item in
            guard let limit = availableTime.maximumMinutes else { return true }
            return item.supportedDuration!.maximumMinutes <= limit
        }
        guard !timeFitting.isEmpty else { return .empty(.overTimeBudget) }

        let unseen = timeFitting.filter { !shownItemIDs.contains($0.id) }
        guard !unseen.isEmpty else { return .empty(.alreadyShownInSession) }
        return .candidates(unseen)
    }
}

public protocol RandomNumberGenerating: Sendable {
    /// Returns a value in the half-open interval `0..<1`.
    mutating func nextUnitInterval() -> Double
}

public protocol Clock: Sendable {
    func now() -> Date
}

public struct SystemClock: Clock {
    public init() {}

    public func now() -> Date { Date() }
}

public struct PlatformRandomNumberGenerator: RandomNumberGenerating {
    private var generator = SystemRandomNumberGeneratorBase()

    public init() {}

    public mutating func nextUnitInterval() -> Double {
        Double(generator.next()) / 18_446_744_073_709_551_616
    }
}

private struct SystemRandomNumberGeneratorBase {
    private var generator = Swift.SystemRandomNumberGenerator()

    mutating func next() -> UInt64 {
        generator.next()
    }
}

public struct DrawSelectionPolicy: Sendable {
    public static let version = "mvp-v1"
    public static let supportedVersions: Set<String> = [version]

    public init() {}

    public func weight(
        for item: BoxItem,
        availableTime: AvailableTime,
        eligibleCount: Int,
        now: Date
    ) -> Double {
        guard let bucket = item.supportedDuration else { return 0 }
        let timeFit: Double
        if let available = availableTime.maximumMinutes {
            guard bucket.maximumMinutes <= available,
                  let availableBucket = DurationBucket(rawValue: availableTime.rawValue) else {
                return 0
            }
            let stepsShorter = availableBucket.policyIndex - bucket.policyIndex
            switch stepsShorter {
            case 0: timeFit = 1
            case 1: timeFit = 0.85
            case 2: timeFit = 0.70
            case 3: timeFit = 0.55
            default: timeFit = 0.45
            }
        } else {
            timeFit = 1
        }

        let freshness: Double
        let recentRepeat: Double
        if let lastShownAt = item.lastShownAt {
            let age = max(0, now.timeIntervalSince(lastShownAt))
            freshness = 1 + 0.5 * min(age, 30 * 86_400) / (30 * 86_400)
            recentRepeat = age < 24 * 86_400 && eligibleCount > 1 ? 0.25 : 1
        } else {
            freshness = 1.5
            recentRepeat = 1
        }
        return timeFit * freshness * recentRepeat
    }

    public func select<Generator: RandomNumberGenerating>(
        from candidates: [BoxItem],
        availableTime: AvailableTime,
        now: Date,
        using generator: inout Generator
    ) -> BoxItem? {
        let weights = candidates.map { weight(for: $0, availableTime: availableTime, eligibleCount: candidates.count, now: now) }
        let total = weights.reduce(0, +)
        guard total > 0 else { return nil }

        let unitValue = generator.nextUnitInterval()
        precondition(unitValue >= 0 && unitValue < 1, "Random generators must return a value in 0..<1.")
        let threshold = unitValue * total
        var cumulativeWeight = 0.0
        for (item, weight) in zip(candidates, weights) {
            cumulativeWeight += weight
            if threshold < cumulativeWeight { return item }
        }
        return candidates.last
    }
}

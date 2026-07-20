import Foundation

public enum CoreBoxIdleAction: CaseIterable, Equatable, Sendable {
    case blink, listen, paperRustle, currentGlance
}

public struct CoreBoxIdlePreconditions: Equatable, Sendable {
    public let isEligible: Bool
    public let hasPapers: Bool
    public let hasCurrentPick: Bool

    public init(isEligible: Bool, hasPapers: Bool, hasCurrentPick: Bool) {
        self.isEligible = isEligible
        self.hasPapers = hasPapers
        self.hasCurrentPick = hasCurrentPick
    }

    public static let stableEmpty = Self(isEligible: true, hasPapers: false, hasCurrentPick: false)
    public static let stableWithPapersAndCurrent = Self(isEligible: true, hasPapers: true, hasCurrentPick: true)
}

public protocol CoreBoxIdleClock: Sendable {
    func sleep(for duration: Duration) async throws
}

public struct SplitMix64: Sendable {
    private var state: UInt64

    public init(seed: UInt64) { state = seed }

    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}

public struct CoreBoxIdleScheduler: Sendable {
    private var generator: SplitMix64

    public init(seed: UInt64) { generator = SplitMix64(seed: seed) }

    public mutating func nextDelaySeconds() -> Int {
        12 + Int(generator.next() % 13)
    }

    public mutating func nextAction(preconditions: CoreBoxIdlePreconditions) -> CoreBoxIdleAction? {
        guard preconditions.isEligible else { return nil }
        var actions: [CoreBoxIdleAction] = [.blink, .listen]
        if preconditions.hasPapers { actions.append(.paperRustle) }
        if preconditions.hasCurrentPick { actions.append(.currentGlance) }
        return actions[Int(generator.next() % UInt64(actions.count))]
    }
}

public actor CoreBoxIdleController {
    private let clock: any CoreBoxIdleClock
    private var scheduler: CoreBoxIdleScheduler
    private var task: Task<Void, Never>?
    private let onAction: @Sendable (CoreBoxIdleAction) async -> Void
    private var lastPreconditions: CoreBoxIdlePreconditions?

    public init(
        clock: any CoreBoxIdleClock,
        seed: UInt64,
        onAction: @escaping @Sendable (CoreBoxIdleAction) async -> Void = { _ in }
    ) {
        self.clock = clock
        scheduler = CoreBoxIdleScheduler(seed: seed)
        self.onAction = onAction
    }

    public func begin(preconditions: CoreBoxIdlePreconditions) {
        task?.cancel()
        lastPreconditions = preconditions
        guard let action = scheduler.nextAction(preconditions: preconditions) else {
            task = nil
            return
        }
        let delay = scheduler.nextDelaySeconds()
        task = Task {
            do {
                try await clock.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { return }
                await onAction(action)
            } catch {
                return
            }
        }
    }

    public func actionDidSettle(preconditions: CoreBoxIdlePreconditions) {
        guard lastPreconditions != nil else { return }
        begin(preconditions: preconditions)
    }

    public func cancel(reason _: CoreBoxSettleReason) {
        task?.cancel()
        task = nil
        lastPreconditions = nil
    }
}

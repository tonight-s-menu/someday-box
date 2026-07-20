import Foundation
@testable import SomedayBox

actor CoreBoxTestRepository: ProductRepository {
    private var state: PersistedProductState

    init(state: PersistedProductState = PersistedProductState(items: [])) {
        self.state = state
    }

    func snapshot() -> PersistedProductState { state }

    func withTransaction<Outcome: Sendable>(
        _ mutation: @escaping @Sendable (inout PersistedProductState) throws -> Outcome
    ) throws -> ProductTransaction<Outcome> {
        var candidate = state
        let outcome = try mutation(&candidate)
        state = candidate
        return ProductTransaction(outcome: outcome, state: candidate)
    }
}

struct CoreBoxFixedClock: Clock {
    let date: Date

    func now() -> Date { date }
}

enum CoreBoxTestFixtures {
    static let itemID = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
    static let memoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000201")!
    static let attemptID = UUID(uuidString: "00000000-0000-0000-0000-000000000301")!
    static let sessionID = UUID(uuidString: "00000000-0000-0000-0000-000000000401")!
    static let date = Date(timeIntervalSince1970: 100)

    static func item(id: UUID = itemID) -> BoxItem {
        BoxItem(
            id: id,
            title: "Core Box paper",
            durationBucketRaw: DurationBucket.upTo30Minutes.rawValue,
            createdAt: date,
            updatedAt: date
        )
    }

    static func coreBoxFixture(activeItemID: UUID = itemID) -> PersistedProductState {
        PersistedProductState(items: [item(id: activeItemID)])
    }

    static func coreBoxFixtureWithExhaustedUnresolvedAttempt() -> PersistedProductState {
        let session = DrawSession(
            id: sessionID,
            startedAt: date,
            context: DrawContext(preset: .fewMinutes)
        )
        let attempt = DrawAttempt(
            id: attemptID,
            sessionID: session.id,
            sequence: 1,
            itemID: itemID,
            eligibleCount: 1,
            shownAt: date,
            outcome: .unresolved
        )
        var paper = item()
        paper.lastShownAt = date
        return PersistedProductState(items: [paper], sessions: [session], attempts: [attempt])
    }
}

enum CoreBoxTestIdentity {
    static let itemID = CoreBoxTestFixtures.itemID
    static let memoryID = CoreBoxTestFixtures.memoryID
    static let attemptID = CoreBoxTestFixtures.attemptID
    static let sessionID = CoreBoxTestFixtures.sessionID
}

actor CoreBoxMutationBarrier {
    private var entered = false
    private var released = false
    private var enteredWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

    func waitUntilEntered() async {
        if entered { return }
        await withCheckedContinuation { continuation in
            enteredWaiters.append(continuation)
        }
    }

    func enterAndWait() async {
        entered = true
        enteredWaiters.forEach { $0.resume() }
        enteredWaiters.removeAll()
        if released { return }
        await withCheckedContinuation { continuation in
            releaseWaiters.append(continuation)
        }
    }

    func release() {
        released = true
        releaseWaiters.forEach { $0.resume() }
        releaseWaiters.removeAll()
    }
}

private actor CoreBoxProjectionFailureCounter {
    private var remaining: Int

    init(remaining: Int) { self.remaining = remaining }

    func consumeFailure() -> Bool {
        guard remaining > 0 else { return false }
        remaining -= 1
        return true
    }
}

private struct CoreBoxProjectionFailure: Error {}

private final class CoreBoxIDGenerator: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [UUID]

    init(values: [UUID]) { self.values = values }

    func next() -> UUID {
        lock.lock()
        defer { lock.unlock() }
        return values.isEmpty ? UUID() : values.removeFirst()
    }
}

struct CoreBoxAppModelHarness {
    let model: AppModel
    let repository: GenerationProductRepository
    let root: URL

    @MainActor
    static func make(
        forcedMutationFailure: ApplicationError? = nil,
        projectionFailures: Int = 0,
        drawReady: Bool = false,
        mutationBarrier: CoreBoxMutationBarrier? = nil
    ) async throws -> CoreBoxAppModelHarness {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SomedayBox-CoreBoxHarness-\(UUID().uuidString)", isDirectory: true)
        let support = root.appendingPathComponent("support", isDirectory: true)
        let repository = try await GenerationProductRepository.open(
            configuration: StoreGenerationConfiguration(applicationSupportURL: support)
        )
        let state = drawReady ? CoreBoxTestFixtures.coreBoxFixture() : PersistedProductState(items: [])
        _ = try await repository.withTransaction { $0 = state }

        let failures = CoreBoxProjectionFailureCounter(remaining: projectionFailures)
        let loader = CoreBoxProjectionLoader { state, version, inputs in
            if await failures.consumeFailure() { throw CoreBoxProjectionFailure() }
            return CoreBoxSceneSnapshotBuilder().build(state: state, inputs: inputs, snapshotVersion: version)
        }
        let hooks = AppModelMutationHooks {
            if let forcedMutationFailure { throw forcedMutationFailure }
            await mutationBarrier?.enterAndWait()
        }
        let ids = CoreBoxIDGenerator(values: drawReady ? [
            CoreBoxTestIdentity.sessionID,
            CoreBoxTestIdentity.attemptID,
            CoreBoxTestIdentity.memoryID
        ] : [
            CoreBoxTestIdentity.itemID,
            CoreBoxTestIdentity.sessionID,
            CoreBoxTestIdentity.attemptID,
            CoreBoxTestIdentity.memoryID
        ])
        let model = AppModel(
            repository: repository,
            projectionLoader: loader,
            mutationHooks: hooks,
            clock: CoreBoxFixedClock(date: CoreBoxTestFixtures.date),
            makeID: { ids.next() }
        )
        return CoreBoxAppModelHarness(model: model, repository: repository, root: root)
    }
}

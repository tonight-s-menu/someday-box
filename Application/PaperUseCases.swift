import Foundation

public struct CapturePaperUseCase: Sendable {
    private let arbiter: MutationArbiter
    private let clock: any Clock
    private let makeID: @Sendable () -> UUID

    public init(
        arbiter: MutationArbiter,
        clock: any Clock = SystemClock(),
        makeID: @escaping @Sendable () -> UUID = { UUID() }
    ) {
        self.arbiter = arbiter
        self.clock = clock
        self.makeID = makeID
    }

    @discardableResult
    public func execute(title: String, note: String?, durationBucketRaw: String) async throws -> UUID {
        let id = makeID()
        let timestamp = clock.now()
        _ = try await arbiter.perform(.capture) { state in
            let content = try ApplicationDomainRules.validatedContent(title: title, note: note)
            try ApplicationDomainRules.requireSupportedDuration(durationBucketRaw)
            state.items.append(
                BoxItem(
                    id: id,
                    title: content.title,
                    note: content.note,
                    durationBucketRaw: durationBucketRaw,
                    createdAt: timestamp,
                    updatedAt: timestamp
                )
            )
        }
        return id
    }
}

public struct EditPaperUseCase: Sendable {
    private let arbiter: MutationArbiter
    private let clock: any Clock

    public init(arbiter: MutationArbiter, clock: any Clock = SystemClock()) {
        self.arbiter = arbiter
        self.clock = clock
    }

    public func execute(
        itemID: UUID,
        title: String,
        note: String?,
        durationBucketRaw: String
    ) async throws {
        let timestamp = clock.now()
        _ = try await arbiter.perform(.edit) { state in
            let content = try ApplicationDomainRules.validatedContent(title: title, note: note)
            try ApplicationDomainRules.requireSupportedDuration(durationBucketRaw)
            let index = try ApplicationDomainRules.itemIndex(id: itemID, in: state)
            state.items[index].title = content.title
            state.items[index].note = content.note
            state.items[index].durationBucketRaw = durationBucketRaw
            state.items[index].updatedAt = timestamp
        }
    }
}

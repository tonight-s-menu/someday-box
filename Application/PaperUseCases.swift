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
            try ApplicationDomainRules.requireCapacity(
                for: .boxItems,
                currentCount: state.items.count
            )
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

public enum ImportSharedPaperResult: Equatable, Sendable {
    case imported(itemID: UUID, sourceID: UUID)
    case alreadyImported(itemID: UUID, sourceID: UUID)
}

public struct ImportSharedPaperUseCase: Sendable {
    private let arbiter: MutationArbiter
    private let clock: any Clock
    private let makeItemID: @Sendable () -> UUID
    private let makeSourceID: @Sendable () -> UUID

    public init(
        arbiter: MutationArbiter,
        clock: any Clock = SystemClock(),
        makeItemID: @escaping @Sendable () -> UUID = { UUID() },
        makeSourceID: @escaping @Sendable () -> UUID = { UUID() }
    ) {
        self.arbiter = arbiter
        self.clock = clock
        self.makeItemID = makeItemID
        self.makeSourceID = makeSourceID
    }

    public func execute(envelope: ShareCaptureEnvelopeV1) async throws -> ImportSharedPaperResult {
        if let existing = try await existingSource(for: envelope) {
            return .alreadyImported(itemID: existing.itemID, sourceID: existing.id)
        }

        let itemID = makeItemID()
        let sourceID = makeSourceID()
        let ingestedAt = clock.now()
        let committed = try await arbiter.perform(.importShared) { state in
            if let existing = state.sources.first(where: { $0.importEnvelopeID == envelope.envelopeID }) {
                guard Self.matches(existing, envelope: envelope, state: state) else {
                    throw ApplicationError.invalidPersistedState(.invalidSource(id: existing.id))
                }
                return
            }
            let content = try ApplicationDomainRules.validatedContent(title: envelope.title, note: envelope.note)
            try ApplicationDomainRules.requireSupportedDuration(envelope.durationBucketRaw)
            try ApplicationDomainRules.requireCapacity(for: .boxItems, currentCount: state.items.count)
            try ApplicationDomainRules.requireCapacity(for: .sourceReferences, currentCount: state.sources.count)
            state.items.append(
                BoxItem(
                    id: itemID,
                    title: content.title,
                    note: content.note,
                    durationBucketRaw: envelope.durationBucketRaw,
                    createdAt: ingestedAt,
                    updatedAt: ingestedAt
                )
            )
            state.sources.append(
                SourceReference(
                    id: sourceID,
                    itemID: itemID,
                    importEnvelopeID: envelope.envelopeID,
                    acceptedURLString: envelope.acceptedURLString,
                    sourceKindRaw: envelope.sourceKindRaw,
                    capturedAt: Date(timeIntervalSince1970: Double(envelope.createdAtMilliseconds) / 1_000)
                )
            )
        }
        guard let committedSource = committed.sources.first(where: { $0.importEnvelopeID == envelope.envelopeID }) else {
            throw ApplicationError.invalidPersistedState(.invalidSource(id: sourceID))
        }
        return committedSource.id == sourceID
            ? .imported(itemID: committedSource.itemID, sourceID: committedSource.id)
            : .alreadyImported(itemID: committedSource.itemID, sourceID: committedSource.id)
    }

    private func existingSource(for envelope: ShareCaptureEnvelopeV1) async throws -> SourceReference? {
        let state = try await arbiter.snapshotForIdempotencyCheck()
        guard let source = state.sources.first(where: { $0.importEnvelopeID == envelope.envelopeID }) else {
            return nil
        }
        guard Self.matches(source, envelope: envelope, state: state) else {
            throw ApplicationError.invalidPersistedState(.invalidSource(id: source.id))
        }
        return source
    }

    private static func matches(
        _ source: SourceReference,
        envelope: ShareCaptureEnvelopeV1,
        state: PersistedProductState
    ) -> Bool {
        guard let item = state.items.first(where: { $0.id == source.itemID }) else { return false }
        return item.title == envelope.title
            && item.note == envelope.note
            && item.durationBucketRaw == envelope.durationBucketRaw
            && source.acceptedURLString == envelope.acceptedURLString
            && source.sourceKindRaw == envelope.sourceKindRaw
            && abs(source.capturedAt.timeIntervalSince1970 - Double(envelope.createdAtMilliseconds) / 1_000) < 0.001
    }
}

public struct RemoveSourceUseCase: Sendable {
    private let arbiter: MutationArbiter

    public init(arbiter: MutationArbiter) {
        self.arbiter = arbiter
    }

    public func execute(itemID: UUID) async throws {
        _ = try await arbiter.perform(.removeSource) { state in
            guard state.items.contains(where: { $0.id == itemID }) else {
                throw ApplicationError.itemNotFound(itemID)
            }
            state.sources.removeAll { $0.itemID == itemID }
        }
    }
}

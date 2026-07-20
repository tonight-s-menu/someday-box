import Foundation

public enum AppMutationFailure: Error, Equatable, Sendable {
    case application(ApplicationError)
    case persistenceUnavailable
    case reconciliationRequired
    case operationInProgress
}

public enum AppMutationProjection<Outcome: Equatable & Sendable>: Equatable, Sendable {
    case notCommitted(failure: AppMutationFailure)
    case committed(outcome: Outcome, snapshot: CoreBoxSceneSnapshot)
    case committedButProjectionUnavailable(outcome: Outcome)

    public var isNotCommitted: Bool {
        if case .notCommitted = self { return true }
        return false
    }

    public var isCommitted: Bool {
        switch self {
        case .committed, .committedButProjectionUnavailable: return true
        case .notCommitted: return false
        }
    }

    public var isCommittedButProjectionUnavailable: Bool {
        if case .committedButProjectionUnavailable = self { return true }
        return false
    }

    public var outcome: Outcome? {
        switch self {
        case let .committed(outcome, _), let .committedButProjectionUnavailable(outcome): return outcome
        case .notCommitted: return nil
        }
    }
}

public struct AppModelMutationHooks: Sendable {
    public var beforeOperation: @Sendable () async throws -> Void

    public init(beforeOperation: @escaping @Sendable () async throws -> Void) {
        self.beforeOperation = beforeOperation
    }

    public static let live = Self(beforeOperation: {})
}

public struct ShareImportBatchResult: Equatable, Sendable {
    public let freshItemIDs: [UUID]
    public let alreadyImportedCount: Int
    public let recoveryEnvelopeID: UUID?

    public init(freshItemIDs: [UUID], alreadyImportedCount: Int, recoveryEnvelopeID: UUID? = nil) {
        self.freshItemIDs = freshItemIDs
        self.alreadyImportedCount = alreadyImportedCount
        self.recoveryEnvelopeID = recoveryEnvelopeID
    }

    public var isFresh: Bool { !freshItemIDs.isEmpty }
}

public struct ShareImportBatchAccumulator: Sendable {
    private(set) public var freshItemIDs: [UUID] = []
    private(set) public var alreadyImportedCount = 0
    private(set) public var recoveryEnvelopeID: UUID?

    public init() {}

    public mutating func append(_ result: ImportSharedPaperResult) {
        switch result {
        case let .imported(itemID, _):
            freshItemIDs.append(itemID)
        case .alreadyImported:
            alreadyImportedCount += 1
        }
    }

    public mutating func stopForRecovery(envelopeID: UUID) {
        recoveryEnvelopeID = envelopeID
    }

    public var value: ShareImportBatchResult {
        ShareImportBatchResult(
            freshItemIDs: freshItemIDs,
            alreadyImportedCount: alreadyImportedCount,
            recoveryEnvelopeID: recoveryEnvelopeID
        )
    }

    public var boundedFreshItemIDs: [UUID] { Array(freshItemIDs.prefix(3)) }
}

public enum CoreBoxPresentationEventMapper {
    public static func share(_ result: ShareImportBatchResult) -> CoreBoxPresentationEvent? {
        guard !result.freshItemIDs.isEmpty else { return nil }
        return .shareArrival(freshItemIDs: result.freshItemIDs)
    }

    public static func capture(_ projection: AppMutationProjection<CapturePaperResult>) -> CoreBoxPresentationEvent? {
        guard case let .committed(outcome, _) = projection else { return nil }
        return .captureDeposit(itemID: outcome.itemID)
    }

    public static func startDraw(_ projection: AppMutationProjection<StartDrawResult>) -> CoreBoxPresentationEvent? {
        guard case let .committed(outcome, _) = projection,
              case let .revealed(attempt) = outcome else { return nil }
        return .drawReveal(attemptID: attempt.id, itemID: attempt.itemID)
    }

    public static func accept(_ projection: AppMutationProjection<AcceptDrawResult>) -> CoreBoxPresentationEvent? {
        guard case let .committed(outcome, _) = projection else { return nil }
        return .currentAttach(attemptID: outcome.attemptID, itemID: outcome.itemID)
    }

    public static func dismiss(_ projection: AppMutationProjection<DismissDrawResult>) -> CoreBoxPresentationEvent? {
        guard case let .committed(outcome, _) = projection else { return nil }
        return .paperReturn(itemID: outcome.itemID)
    }

    public static func redraw(_ projection: AppMutationProjection<RedrawResult>) -> [CoreBoxPresentationEvent] {
        guard case let .committed(outcome, _) = projection else { return [] }
        switch outcome {
        case let .revealed(previousAttemptID: _, previousItemID, attempt):
            return [.paperReturn(itemID: previousItemID), .drawReveal(attemptID: attempt.id, itemID: attempt.itemID)]
        case let .exhausted(previousAttemptID: _, previousItemID, sessionID: _, context: _):
            return [.paperReturn(itemID: previousItemID)]
        }
    }

    public static func complete(_ projection: AppMutationProjection<CompletePaperResult>) -> CoreBoxPresentationEvent? {
        guard case let .committed(outcome, _) = projection else { return nil }
        return .memoryStamp(itemID: outcome.itemID, memoryID: outcome.memoryID)
    }

    public static func putBack(_ projection: AppMutationProjection<PutBackPaperResult>) -> CoreBoxPresentationEvent? {
        guard case let .committed(outcome, _) = projection else { return nil }
        return .paperReturn(itemID: outcome.itemID)
    }
}

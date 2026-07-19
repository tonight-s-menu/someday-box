import Foundation

public enum DrawAttemptOutcome: String, Codable, CaseIterable, Sendable {
    case unresolved
    case accepted
    case redrawn
    case dismissed
}

public struct DrawSession: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let startedAt: Date
    public var endedAt: Date?
    public let availableTimeRaw: String
    public let policyVersion: String

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date? = nil,
        availableTimeRaw: String,
        policyVersion: String
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.availableTimeRaw = availableTimeRaw
        self.policyVersion = policyVersion
    }

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date? = nil,
        availableTime: AvailableTime,
        policyVersion: String = DrawSelectionPolicy.version
    ) {
        self.init(
            id: id,
            startedAt: startedAt,
            endedAt: endedAt,
            availableTimeRaw: availableTime.rawValue,
            policyVersion: policyVersion
        )
    }

    public var availableTime: AvailableTime? {
        AvailableTime(rawValue: availableTimeRaw)
    }
}

public struct DrawAttempt: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let sessionID: UUID
    public let sequence: Int
    public let itemID: UUID
    public let eligibleCount: Int
    public let policyVersion: String
    public let shownAt: Date
    public var outcomeRaw: String
    public var resolvedAt: Date?

    public init(
        id: UUID = UUID(),
        sessionID: UUID,
        sequence: Int,
        itemID: UUID,
        eligibleCount: Int,
        policyVersion: String,
        shownAt: Date,
        outcomeRaw: String,
        resolvedAt: Date? = nil
    ) {
        self.id = id
        self.sessionID = sessionID
        self.sequence = sequence
        self.itemID = itemID
        self.eligibleCount = eligibleCount
        self.policyVersion = policyVersion
        self.shownAt = shownAt
        self.outcomeRaw = outcomeRaw
        self.resolvedAt = resolvedAt
    }

    public init(
        id: UUID = UUID(),
        sessionID: UUID,
        sequence: Int,
        itemID: UUID,
        eligibleCount: Int,
        policyVersion: String = DrawSelectionPolicy.version,
        shownAt: Date,
        outcome: DrawAttemptOutcome,
        resolvedAt: Date? = nil
    ) {
        self.init(
            id: id,
            sessionID: sessionID,
            sequence: sequence,
            itemID: itemID,
            eligibleCount: eligibleCount,
            policyVersion: policyVersion,
            shownAt: shownAt,
            outcomeRaw: outcome.rawValue,
            resolvedAt: resolvedAt
        )
    }

    public var outcome: DrawAttemptOutcome? {
        DrawAttemptOutcome(rawValue: outcomeRaw)
    }
}

public struct CompletionMemory: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let sourceItemID: UUID
    public let titleSnapshot: String
    public let noteSnapshot: String?
    public let durationSnapshotRaw: String
    public let completedAt: Date

    public init(
        id: UUID = UUID(),
        sourceItemID: UUID,
        titleSnapshot: String,
        noteSnapshot: String? = nil,
        durationSnapshotRaw: String,
        completedAt: Date
    ) {
        self.id = id
        self.sourceItemID = sourceItemID
        self.titleSnapshot = titleSnapshot
        self.noteSnapshot = noteSnapshot
        self.durationSnapshotRaw = durationSnapshotRaw
        self.completedAt = completedAt
    }
}

public struct DrawJournalCompactionPlan: Equatable, Sendable {
    public let retainedSessionIDs: Set<UUID>
    public let deletedSessionIDs: Set<UUID>

    public init(retainedSessionIDs: Set<UUID>, deletedSessionIDs: Set<UUID>) {
        self.retainedSessionIDs = retainedSessionIDs
        self.deletedSessionIDs = deletedSessionIDs
    }
}

public struct DrawJournalCompactionPolicy: Sendable {
    public static let version = "draw-journal-v1"
    public static let maximumEndedSessionCount = 1_000
    public static let maximumResolvedAttemptCount = 25_000

    private let sessionLimit: Int
    private let attemptLimit: Int

    public init() {
        sessionLimit = Self.maximumEndedSessionCount
        attemptLimit = Self.maximumResolvedAttemptCount
    }

    init(sessionLimit: Int, attemptLimit: Int) {
        precondition(sessionLimit >= 0 && attemptLimit >= 0)
        self.sessionLimit = sessionLimit
        self.attemptLimit = attemptLimit
    }

    public func plan(sessions: [DrawSession], attempts: [DrawAttempt]) -> DrawJournalCompactionPlan {
        let endedSessions = sessions.filter { $0.endedAt != nil }.sorted(by: Self.isNewer)
        let resolvedAttemptCounts = Dictionary(grouping: attempts.filter { $0.outcome != .unresolved }, by: \.sessionID)
            .mapValues(\.count)

        var retained = Set<UUID>()
        var resolvedAttemptCount = 0
        for session in endedSessions {
            let sessionAttemptCount = resolvedAttemptCounts[session.id, default: 0]
            guard retained.count + 1 <= sessionLimit,
                  resolvedAttemptCount + sessionAttemptCount <= attemptLimit else {
                break
            }
            retained.insert(session.id)
            resolvedAttemptCount += sessionAttemptCount
        }

        let endedIDs = Set(endedSessions.map(\.id))
        return DrawJournalCompactionPlan(
            retainedSessionIDs: retained,
            deletedSessionIDs: endedIDs.subtracting(retained)
        )
    }

    private static func isNewer(_ lhs: DrawSession, _ rhs: DrawSession) -> Bool {
        if lhs.endedAt != rhs.endedAt { return lhs.endedAt! > rhs.endedAt! }
        if lhs.startedAt != rhs.startedAt { return lhs.startedAt > rhs.startedAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}

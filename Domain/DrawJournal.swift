import Foundation

public enum DrawAttemptOutcome: String, Codable, CaseIterable, Sendable {
    case unresolved
    case accepted
    case redrawn
    case dismissed
}

public enum DrawContextMode: String, Codable, CaseIterable, Sendable {
    case preset
    case custom
    case notSure = "not_sure"
}

public enum DrawPresentationPreset: String, Codable, CaseIterable, Sendable {
    case fewMinutes = "few_minutes"
    case aboutAnHour = "about_an_hour"
    case aFewHours = "a_few_hours"
    case mostOfTheDay = "most_of_the_day"

    public var maximumMinutes: Int {
        switch self {
        case .fewMinutes: 30
        case .aboutAnHour: 60
        case .aFewHours: 240
        case .mostOfTheDay: 480
        }
    }
}

/// The canonical time contract for newly created Draw Sessions.
public struct DrawContext: Codable, Equatable, Hashable, Sendable {
    public let mode: DrawContextMode
    public let maximumMinutes: Int?
    public let presentationPreset: DrawPresentationPreset?

    public init(preset: DrawPresentationPreset) {
        mode = .preset
        maximumMinutes = preset.maximumMinutes
        presentationPreset = preset
    }

    public init(customMinutes: Int) {
        mode = .custom
        maximumMinutes = customMinutes
        presentationPreset = nil
    }

    public static let notSure = DrawContext(mode: .notSure, maximumMinutes: nil, presentationPreset: nil)

    private init(mode: DrawContextMode, maximumMinutes: Int?, presentationPreset: DrawPresentationPreset?) {
        self.mode = mode
        self.maximumMinutes = maximumMinutes
        self.presentationPreset = presentationPreset
    }

    public var isValid: Bool {
        switch mode {
        case .preset:
            return presentationPreset?.maximumMinutes == maximumMinutes
        case .custom:
            guard let maximumMinutes else { return false }
            return presentationPreset == nil && (10...480).contains(maximumMinutes) && maximumMinutes.isMultiple(of: 5)
        case .notSure:
            return maximumMinutes == nil && presentationPreset == nil
        }
    }

    public var effectiveFitBucket: DurationBucket? {
        guard let maximumMinutes else { return nil }
        return DurationBucket.allCases.filter { $0.maximumMinutes <= maximumMinutes }.max { $0.maximumMinutes < $1.maximumMinutes }
    }

    public var storageValue: String {
        switch mode {
        case .preset: "preset:\(presentationPreset!.rawValue)"
        case .custom: "custom:\(maximumMinutes!)"
        case .notSure: "not_sure"
        }
    }

    public init?(storageValue: String) {
        if let legacy = AvailableTime(rawValue: storageValue) {
            switch legacy {
            case .upTo30Minutes: self.init(preset: .fewMinutes)
            case .upTo60Minutes: self.init(preset: .aboutAnHour)
            case .upTo240Minutes: self.init(preset: .aFewHours)
            case .upTo480Minutes: self.init(preset: .mostOfTheDay)
            case .upTo10Minutes: self.init(customMinutes: 10)
            case .upTo120Minutes: self.init(customMinutes: 120)
            case .notSure: self = .notSure
            }
            return
        }
        if storageValue == "not_sure" { self = .notSure; return }
        let parts = storageValue.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        if parts[0] == "preset", let preset = DrawPresentationPreset(rawValue: parts[1]) {
            self.init(preset: preset)
        } else if parts[0] == "custom", let minutes = Int(parts[1]) {
            self.init(customMinutes: minutes)
        } else {
            return nil
        }
        guard isValid else { return nil }
    }
}

public struct DrawSession: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let startedAt: Date
    public var endedAt: Date?
    public let context: DrawContext
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
        guard let context = DrawContext(storageValue: availableTimeRaw) else {
            preconditionFailure("Invalid Draw context")
        }
        self.context = context
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
        switch context.mode {
        case .preset:
            guard let preset = context.presentationPreset else { return nil }
            switch preset {
            case .fewMinutes: return .upTo30Minutes
            case .aboutAnHour: return .upTo60Minutes
            case .aFewHours: return .upTo240Minutes
            case .mostOfTheDay: return .upTo480Minutes
            }
        case .custom:
            guard let minutes = context.maximumMinutes else { return nil }
            return AvailableTime(rawValue: "up_to_\(minutes)_minutes")
        case .notSure:
            return .notSure
        }
    }

    public var availableTimeRaw: String { context.storageValue }

    public init(id: UUID = UUID(), startedAt: Date, endedAt: Date? = nil, context: DrawContext, policyVersion: String = DrawSelectionPolicy.version) {
        precondition(context.isValid)
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.context = context
        self.policyVersion = policyVersion
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

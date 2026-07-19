import Foundation

public enum SwiftDataMappingError: Error, Equatable, Sendable {
    case unsupportedLifecycle(rawValue: String, itemID: UUID)
    case unsupportedAvailableTime(rawValue: String, sessionID: UUID)
    case unsupportedAttemptOutcome(rawValue: String, attemptID: UUID)
}

extension SomedayBoxSchemaV1.ItemRecord {
    public convenience init(domain: BoxItem) {
        self.init(
            id: domain.id,
            title: domain.title,
            note: domain.note,
            durationBucketRaw: domain.durationBucketRaw,
            lifecycleRaw: domain.lifecycleRaw,
            createdAt: domain.createdAt,
            updatedAt: domain.updatedAt,
            completedAt: domain.completedAt,
            lastShownAt: domain.lastShownAt
        )
    }

    public func domainValue() throws -> BoxItem {
        guard let lifecycle = PaperLifecycle(rawValue: lifecycleRaw) else {
            throw SwiftDataMappingError.unsupportedLifecycle(rawValue: lifecycleRaw, itemID: id)
        }
        return BoxItem(
            id: id,
            title: title,
            note: note,
            durationBucketRaw: durationBucketRaw,
            lifecycle: lifecycle,
            createdAt: createdAt,
            updatedAt: updatedAt,
            completedAt: completedAt,
            lastShownAt: lastShownAt
        )
    }
}

extension SomedayBoxSchemaV1.CurrentPickRecord {
    public convenience init(domain: CurrentPick) {
        self.init(itemID: domain.itemID, acceptedAt: domain.acceptedAt)
    }

    public func domainValue() -> CurrentPick {
        CurrentPick(itemID: itemID, acceptedAt: acceptedAt)
    }
}

extension SomedayBoxSchemaV1.SessionRecord {
    public convenience init(domain: DrawSession) {
        self.init(
            id: domain.id,
            startedAt: domain.startedAt,
            endedAt: domain.endedAt,
            availableTimeRaw: domain.availableTimeRaw,
            policyVersion: domain.policyVersion
        )
    }

    public func domainValue() throws -> DrawSession {
        guard AvailableTime(rawValue: availableTimeRaw) != nil else {
            throw SwiftDataMappingError.unsupportedAvailableTime(rawValue: availableTimeRaw, sessionID: id)
        }
        return DrawSession(
            id: id,
            startedAt: startedAt,
            endedAt: endedAt,
            availableTimeRaw: availableTimeRaw,
            policyVersion: policyVersion
        )
    }
}

extension SomedayBoxSchemaV1.AttemptRecord {
    public convenience init(domain: DrawAttempt) {
        self.init(
            id: domain.id,
            sessionID: domain.sessionID,
            sequence: domain.sequence,
            itemID: domain.itemID,
            eligibleCount: domain.eligibleCount,
            policyVersion: domain.policyVersion,
            shownAt: domain.shownAt,
            outcomeRaw: domain.outcomeRaw,
            resolvedAt: domain.resolvedAt
        )
    }

    public func domainValue() throws -> DrawAttempt {
        guard DrawAttemptOutcome(rawValue: outcomeRaw) != nil else {
            throw SwiftDataMappingError.unsupportedAttemptOutcome(rawValue: outcomeRaw, attemptID: id)
        }
        return DrawAttempt(
            id: id,
            sessionID: sessionID,
            sequence: sequence,
            itemID: itemID,
            eligibleCount: eligibleCount,
            policyVersion: policyVersion,
            shownAt: shownAt,
            outcomeRaw: outcomeRaw,
            resolvedAt: resolvedAt
        )
    }
}

extension SomedayBoxSchemaV1.MemoryRecord {
    public convenience init(domain: CompletionMemory) {
        self.init(
            id: domain.id,
            sourceItemID: domain.sourceItemID,
            titleSnapshot: domain.titleSnapshot,
            noteSnapshot: domain.noteSnapshot,
            durationSnapshotRaw: domain.durationSnapshotRaw,
            completedAt: domain.completedAt
        )
    }

    public func domainValue() -> CompletionMemory {
        CompletionMemory(
            id: id,
            sourceItemID: sourceItemID,
            titleSnapshot: titleSnapshot,
            noteSnapshot: noteSnapshot,
            durationSnapshotRaw: durationSnapshotRaw,
            completedAt: completedAt
        )
    }
}

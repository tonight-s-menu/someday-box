import Foundation
import SwiftData

public enum SomedayBoxSchemaV1: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [ItemRecord.self, CurrentPickRecord.self, SessionRecord.self, AttemptRecord.self, MemoryRecord.self]
    }

    @Model
    public final class ItemRecord {
        @Attribute(.unique) public var id: UUID
        public var title: String
        public var note: String?
        public var durationBucketRaw: String
        public var lifecycleRaw: String
        public var createdAt: Date
        public var updatedAt: Date
        public var completedAt: Date?
        public var lastShownAt: Date?

        public init(
            id: UUID,
            title: String,
            note: String?,
            durationBucketRaw: String,
            lifecycleRaw: String,
            createdAt: Date,
            updatedAt: Date,
            completedAt: Date?,
            lastShownAt: Date?
        ) {
            self.id = id
            self.title = title
            self.note = note
            self.durationBucketRaw = durationBucketRaw
            self.lifecycleRaw = lifecycleRaw
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.completedAt = completedAt
            self.lastShownAt = lastShownAt
        }
    }

    @Model
    public final class CurrentPickRecord {
        @Attribute(.unique) public var itemID: UUID
        public var acceptedAt: Date

        public init(itemID: UUID, acceptedAt: Date) {
            self.itemID = itemID
            self.acceptedAt = acceptedAt
        }
    }

    @Model
    public final class SessionRecord {
        @Attribute(.unique) public var id: UUID
        public var startedAt: Date
        public var endedAt: Date?
        public var availableTimeRaw: String
        public var policyVersion: String

        public init(
            id: UUID,
            startedAt: Date,
            endedAt: Date?,
            availableTimeRaw: String,
            policyVersion: String
        ) {
            self.id = id
            self.startedAt = startedAt
            self.endedAt = endedAt
            self.availableTimeRaw = availableTimeRaw
            self.policyVersion = policyVersion
        }
    }

    @Model
    public final class AttemptRecord {
        @Attribute(.unique) public var id: UUID
        public var sessionID: UUID
        public var sequence: Int
        public var itemID: UUID
        public var eligibleCount: Int
        public var policyVersion: String
        public var shownAt: Date
        public var outcomeRaw: String
        public var resolvedAt: Date?

        public init(
            id: UUID,
            sessionID: UUID,
            sequence: Int,
            itemID: UUID,
            eligibleCount: Int,
            policyVersion: String,
            shownAt: Date,
            outcomeRaw: String,
            resolvedAt: Date?
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
    }

    @Model
    public final class MemoryRecord {
        @Attribute(.unique) public var id: UUID
        public var sourceItemID: UUID
        public var titleSnapshot: String
        public var noteSnapshot: String?
        public var durationSnapshotRaw: String
        public var completedAt: Date

        public init(
            id: UUID,
            sourceItemID: UUID,
            titleSnapshot: String,
            noteSnapshot: String?,
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
}

public enum SomedayBoxSchemaV2: VersionedSchema {
    public static let versionIdentifier = Schema.Version(2, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [ItemRecord.self, CurrentPickRecord.self, SessionRecord.self, AttemptRecord.self, MemoryRecord.self, SourceRecord.self]
    }

    @Model
    public final class ItemRecord {
        @Attribute(.unique) public var id: UUID
        public var title: String
        public var note: String?
        public var durationBucketRaw: String
        public var lifecycleRaw: String
        public var createdAt: Date
        public var updatedAt: Date
        public var completedAt: Date?
        public var lastShownAt: Date?

        public init(id: UUID, title: String, note: String?, durationBucketRaw: String, lifecycleRaw: String, createdAt: Date, updatedAt: Date, completedAt: Date?, lastShownAt: Date?) {
            self.id = id
            self.title = title
            self.note = note
            self.durationBucketRaw = durationBucketRaw
            self.lifecycleRaw = lifecycleRaw
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.completedAt = completedAt
            self.lastShownAt = lastShownAt
        }
    }

    @Model
    public final class CurrentPickRecord {
        @Attribute(.unique) public var itemID: UUID
        public var acceptedAt: Date
        public init(itemID: UUID, acceptedAt: Date) { self.itemID = itemID; self.acceptedAt = acceptedAt }
    }

    @Model
    public final class SessionRecord {
        @Attribute(.unique) public var id: UUID
        public var startedAt: Date
        public var endedAt: Date?
        public var availableTimeRaw: String
        public var policyVersion: String
        public init(id: UUID, startedAt: Date, endedAt: Date?, availableTimeRaw: String, policyVersion: String) {
            self.id = id; self.startedAt = startedAt; self.endedAt = endedAt; self.availableTimeRaw = availableTimeRaw; self.policyVersion = policyVersion
        }
    }

    @Model
    public final class AttemptRecord {
        @Attribute(.unique) public var id: UUID
        public var sessionID: UUID
        public var sequence: Int
        public var itemID: UUID
        public var eligibleCount: Int
        public var policyVersion: String
        public var shownAt: Date
        public var outcomeRaw: String
        public var resolvedAt: Date?
        public init(id: UUID, sessionID: UUID, sequence: Int, itemID: UUID, eligibleCount: Int, policyVersion: String, shownAt: Date, outcomeRaw: String, resolvedAt: Date?) {
            self.id = id; self.sessionID = sessionID; self.sequence = sequence; self.itemID = itemID; self.eligibleCount = eligibleCount; self.policyVersion = policyVersion; self.shownAt = shownAt; self.outcomeRaw = outcomeRaw; self.resolvedAt = resolvedAt
        }
    }

    @Model
    public final class MemoryRecord {
        @Attribute(.unique) public var id: UUID
        public var sourceItemID: UUID
        public var titleSnapshot: String
        public var noteSnapshot: String?
        public var durationSnapshotRaw: String
        public var completedAt: Date
        public init(id: UUID, sourceItemID: UUID, titleSnapshot: String, noteSnapshot: String?, durationSnapshotRaw: String, completedAt: Date) {
            self.id = id; self.sourceItemID = sourceItemID; self.titleSnapshot = titleSnapshot; self.noteSnapshot = noteSnapshot; self.durationSnapshotRaw = durationSnapshotRaw; self.completedAt = completedAt
        }
    }

    @Model
    public final class SourceRecord {
        @Attribute(.unique) public var id: UUID
        @Attribute(.unique) public var importEnvelopeID: UUID
        public var itemID: UUID
        public var acceptedURLString: String?
        public var sourceKindRaw: String
        public var capturedAt: Date
        public init(id: UUID, itemID: UUID, importEnvelopeID: UUID, acceptedURLString: String?, sourceKindRaw: String, capturedAt: Date) {
            self.id = id; self.itemID = itemID; self.importEnvelopeID = importEnvelopeID; self.acceptedURLString = acceptedURLString; self.sourceKindRaw = sourceKindRaw; self.capturedAt = capturedAt
        }
    }
}

public enum SomedayBoxSchemaMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [SomedayBoxSchemaV1.self, SomedayBoxSchemaV2.self]
    }

    public static var stages: [MigrationStage] {
        [.lightweight(fromVersion: SomedayBoxSchemaV1.self, toVersion: SomedayBoxSchemaV2.self)]
    }
}

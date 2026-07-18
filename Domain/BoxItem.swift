import Foundation

public enum PaperLifecycle: String, Codable, CaseIterable, Sendable {
    case active
    case completed
    case archived
}

public enum DurationBucket: String, Codable, CaseIterable, Sendable {
    case upTo10Minutes = "up_to_10_minutes"
    case upTo30Minutes = "up_to_30_minutes"
    case upTo60Minutes = "up_to_60_minutes"
    case upTo120Minutes = "up_to_120_minutes"
    case upTo240Minutes = "up_to_240_minutes"
    case upTo480Minutes = "up_to_480_minutes"

    public var maximumMinutes: Int {
        switch self {
        case .upTo10Minutes: 10
        case .upTo30Minutes: 30
        case .upTo60Minutes: 60
        case .upTo120Minutes: 120
        case .upTo240Minutes: 240
        case .upTo480Minutes: 480
        }
    }
}

public enum AvailableTime: String, Codable, CaseIterable, Sendable {
    case upTo10Minutes = "up_to_10_minutes"
    case upTo30Minutes = "up_to_30_minutes"
    case upTo60Minutes = "up_to_60_minutes"
    case upTo120Minutes = "up_to_120_minutes"
    case upTo240Minutes = "up_to_240_minutes"
    case upTo480Minutes = "up_to_480_minutes"
    case notSure = "not_sure"

    public var maximumMinutes: Int? {
        DurationBucket(rawValue: rawValue)?.maximumMinutes
    }
}

public struct BoxItem: Equatable, Identifiable, Sendable {
    public let id: UUID
    public var title: String
    public var note: String?
    public var durationBucketRaw: String
    public var lifecycle: PaperLifecycle
    public let createdAt: Date
    public var updatedAt: Date
    public var completedAt: Date?
    public var lastShownAt: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        note: String? = nil,
        durationBucketRaw: String,
        lifecycle: PaperLifecycle = .active,
        createdAt: Date,
        updatedAt: Date,
        completedAt: Date? = nil,
        lastShownAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.note = note
        self.durationBucketRaw = durationBucketRaw
        self.lifecycle = lifecycle
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
        self.lastShownAt = lastShownAt
    }

    public var supportedDuration: DurationBucket? {
        DurationBucket(rawValue: durationBucketRaw)
    }
}

public struct CurrentPick: Equatable, Sendable {
    public let itemID: UUID
    public let acceptedAt: Date
}

import Foundation
import SomedayBoxDomain

/// Runs deterministic domain checks without depending on the iOS application target.
@main
struct DomainVerification {
    static func main() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let short = item(duration: .upTo30Minutes, now: now)
        let long = item(duration: .upTo120Minutes, now: now)
        let result = CandidatePoolBuilder().build(
            items: [short, long],
            availableTime: .upTo60Minutes,
            currentPick: nil,
            reservedItemID: nil,
            shownItemIDs: []
        )
        precondition(result == .candidates([short]), "Timed draw admitted an oversized paper.")

        let unsupported = item(durationRaw: "future_duration", now: now)
        let unsupportedResult = CandidatePoolBuilder().build(
            items: [unsupported],
            availableTime: .notSure,
            currentPick: nil,
            reservedItemID: nil,
            shownItemIDs: []
        )
        precondition(unsupportedResult == .empty(.unsupportedDurations), "Unknown duration became drawable.")

        let tenMinutes = item(duration: .upTo10Minutes, now: now)
        let timeFitWeight = DrawSelectionPolicy().weight(
            for: tenMinutes,
            availableTime: .upTo30Minutes,
            eligibleCount: 1,
            now: now
        )
        precondition(timeFitWeight == 1.275, "Time fit did not use discrete duration buckets.")

        var generator = FixedGenerator(value: 0.99)
        let second = item(duration: .upTo30Minutes, now: now)
        let selected = DrawSelectionPolicy().select(
            from: [short, second],
            availableTime: .upTo30Minutes,
            now: now,
            using: &generator
        )
        precondition(selected?.id == second.id, "Injected random source did not produce deterministic selection.")

        let content = try! PaperContentValidator().validate(title: "  A quiet walk  ", note: "line one\nline two")
        precondition(content.title == "A quiet walk", "Title normalization changed unexpectedly.")

        let session = DrawSession(startedAt: now, availableTime: .upTo30Minutes)
        let attempt = DrawAttempt(
            sessionID: session.id,
            sequence: 1,
            itemID: short.id,
            eligibleCount: 1,
            shownAt: now,
            outcome: .unresolved
        )
        var reservedItem = short
        reservedItem.lastShownAt = now
        let state = PersistedProductState(items: [reservedItem], sessions: [session], attempts: [attempt])
        try! PersistedStateValidator().validate(state)

        verifyStoreCountCapacityBoundaries()
        print("Domain verification passed.")
    }

    private static func verifyStoreCountCapacityBoundaries() {
        let policy = StoreCountCapacityPolicy()
        let expectedLimits: [(StoreCapacityResource, Int)] = [
            (.boxItems, 5_000),
            (.completionMemories, 5_000),
            (.drawSessions, 10_000),
            (.drawAttempts, 50_000),
        ]
        for (resource, expectedLimit) in expectedLimits {
            precondition(resource.countLimit == expectedLimit, "A format-v1 count limit drifted.")
            try! policy.requireCapacity(
                for: resource,
                currentCount: expectedLimit - 1,
                adding: 1
            )
            do {
                try policy.requireCapacity(for: resource, currentCount: expectedLimit, adding: 1)
                preconditionFailure("A growing mutation exceeded a format-v1 count limit.")
            } catch let violation as StoreCountCapacityViolation {
                precondition(violation.resource == resource)
                precondition(violation.limit == expectedLimit)
                precondition(violation.projectedCount == expectedLimit + 1)
            } catch {
                preconditionFailure("Count capacity returned an unexpected error.")
            }
        }
    }

    private static func item(duration: DurationBucket, now: Date) -> BoxItem {
        item(durationRaw: duration.rawValue, now: now)
    }

    private static func item(durationRaw: String, now: Date) -> BoxItem {
        BoxItem(title: "Paper", durationBucketRaw: durationRaw, createdAt: now, updatedAt: now)
    }
}

private struct FixedGenerator: RandomNumberGenerating {
    let value: Double

    mutating func nextUnitInterval() -> Double { value }
}

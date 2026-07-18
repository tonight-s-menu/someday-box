import Foundation
import SomedayBoxDomain

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

        var generator = FixedGenerator(value: 0.99)
        let second = item(duration: .upTo30Minutes, now: now)
        let selected = DrawSelectionPolicy().select(
            from: [short, second],
            availableTime: .upTo30Minutes,
            now: now,
            using: &generator
        )
        precondition(selected?.id == second.id, "Injected random source did not produce deterministic selection.")
        print("Domain verification passed.")
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

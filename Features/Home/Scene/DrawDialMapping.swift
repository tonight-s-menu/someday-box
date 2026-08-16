import Foundation

/// `draw-dial-v1`: the presentation mapping from the time dial onto the unchanged raw
/// duration identifiers (specification §7.3, acceptance DIAL-01/02/05).
///
/// This mapping is presentation only. `CandidatePoolBuilder`, `DrawSelectionPolicy`,
/// weights, and `mvp-v1` are untouched, and no new persisted context value exists: every
/// selection resolves to an `AvailableTime` the product already stores.
enum DrawDialMapping {
    static let version = "draw-dial-v1"

    /// The Custom minutes wheel: 10…480 in steps of 5 (§7.3).
    static let customMinutesRange = 10...480
    static let customMinutesStep = 5

    /// The four physical detents. `up_to_30_minutes` and `up_to_120_minutes` deliberately
    /// have no detent; they stay first-class through Custom (DIAL-05).
    enum Detent: String, CaseIterable, Equatable, Sendable {
        case aFewMinutes
        case aboutAnHour
        case aFewHours
        case mostOfTheDay

        var availableTime: AvailableTime {
            switch self {
            case .aFewMinutes: .upTo10Minutes
            case .aboutAnHour: .upTo60Minutes
            case .aFewHours: .upTo240Minutes
            case .mostOfTheDay: .upTo480Minutes
            }
        }
    }

    /// What the user chose on the dial. Every draw session's context comes from one of
    /// these, always through an explicit action that names the time (DIAL-04).
    enum Selection: Equatable, Sendable {
        case detent(Detent)
        case custom(minutes: Int)
        case notSure
    }

    /// The persisted context for a selection. This is the only value that reaches the
    /// draw use cases.
    static func availableTime(for selection: Selection) -> AvailableTime {
        switch selection {
        case let .detent(detent):
            detent.availableTime
        case let .custom(minutes):
            AvailableTime(rawValue: snap(minutes: minutes).rawValue) ?? .notSure
        case .notSure:
            .notSure
        }
    }

    /// `snap(m)` = the largest supported bucket whose maximum is at most `m` (§7.3).
    ///
    /// Floor-snapping is what preserves hard time safety: the snapped bucket is always
    /// true for the entered minutes, so a fit chip stating the bucket cannot overpromise.
    static func snap(minutes: Int) -> DurationBucket {
        let bounded = normalizedCustomMinutes(minutes)
        var snapped = DurationBucket.upTo10Minutes
        for bucket in DurationBucket.allCases where bucket.maximumMinutes <= bounded {
            if bucket.maximumMinutes > snapped.maximumMinutes { snapped = bucket }
        }
        return snapped
    }

    /// Clamps to the wheel's range and floors onto its 5-minute step, so an out-of-range
    /// or off-step value can never widen the user's stated time.
    static func normalizedCustomMinutes(_ minutes: Int) -> Int {
        let clamped = min(max(minutes, customMinutesRange.lowerBound), customMinutesRange.upperBound)
        return clamped - (clamped % customMinutesStep)
    }
}

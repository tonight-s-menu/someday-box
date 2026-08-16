import Foundation

/// The §9.1 time-of-day light rig: a pure function of wall-clock components, so the same
/// local time always produces the same rig and the whole thing is fixture-testable.
///
/// The four §9.1 bands each own an anchor at their centre — night 00:30, dawn 06:30,
/// day 12:30, dusk 18:30 — and the rig interpolates linearly between the two anchors
/// surrounding the current minute, wrapping across midnight. `band` reports the §9.1 label
/// for that minute, which is a classification, not the interpolation input.
///
/// The anchor values below are presentation tuning, not part of `box-scene-v1`: that
/// identifier versions the derivation rules in §6.2–§6.4, §8, and §10. WP-03 and WP-04 may
/// retune them against the rendered result without a version bump.
enum TimeOfDayLightDriver {
    private struct Anchor {
        let minuteOfDay: Int
        let elevationDegrees: Float
        let azimuthDegrees: Float
        let colorTemperatureKelvin: Float
        let relativeIntensity: Float
        let shadowSoftness: Float
    }

    private static let anchors = [
        Anchor(
            minuteOfDay: 30,
            elevationDegrees: 38,
            azimuthDegrees: 15,
            colorTemperatureKelvin: 2_700,
            relativeIntensity: 0.28,
            shadowSoftness: 0.90
        ),
        Anchor(
            minuteOfDay: 390,
            elevationDegrees: 12,
            azimuthDegrees: -35,
            colorTemperatureKelvin: 2_900,
            relativeIntensity: 0.55,
            shadowSoftness: 0.70
        ),
        Anchor(
            minuteOfDay: 750,
            elevationDegrees: 62,
            azimuthDegrees: 0,
            colorTemperatureKelvin: 6_500,
            relativeIntensity: 1.00,
            shadowSoftness: 0.25
        ),
        Anchor(
            minuteOfDay: 1_110,
            elevationDegrees: 10,
            azimuthDegrees: 35,
            colorTemperatureKelvin: 3_200,
            relativeIntensity: 0.60,
            shadowSoftness: 0.75
        ),
    ]

    /// The anchor the environment holds when clock variation is switched off (§16.2).
    private static var dayAnchor: Anchor { anchors[2] }

    private static let minutesPerDay = 1_440

    /// The rig for an instant. `followsClock` is the §16.2 环境随时间变化 preference: when it
    /// is off the environment stops varying entirely and holds the day anchor.
    static func rig(at date: Date, timeZone: TimeZone, followsClock: Bool = true) -> LightRig {
        guard followsClock else { return rig(from: dayAnchor, band: .day) }
        let minute = minuteOfDay(for: date, timeZone: timeZone)
        return rig(atMinuteOfDay: minute)
    }

    static func rig(atMinuteOfDay minute: Int) -> LightRig {
        let minute = ((minute % minutesPerDay) + minutesPerDay) % minutesPerDay
        let (start, end) = surroundingAnchors(of: minute)
        let span = Float(forwardDistance(from: start.minuteOfDay, to: end.minuteOfDay))
        let travelled = Float(forwardDistance(from: start.minuteOfDay, to: minute))
        let progress = span == 0 ? 0 : travelled / span

        return LightRig(
            band: band(atMinuteOfDay: minute),
            elevationRadians: radians(
                interpolate(start.elevationDegrees, end.elevationDegrees, progress)
            ),
            azimuthRadians: radians(
                interpolate(start.azimuthDegrees, end.azimuthDegrees, progress)
            ),
            colorTemperatureKelvin: interpolate(
                start.colorTemperatureKelvin,
                end.colorTemperatureKelvin,
                progress
            ),
            relativeIntensity: interpolate(start.relativeIntensity, end.relativeIntensity, progress),
            shadowSoftness: interpolate(start.shadowSoftness, end.shadowSoftness, progress)
        )
    }

    /// The §9.1 band boundaries: dawn 05:00–08:00, day 08:00–17:00, dusk 17:00–20:00,
    /// night 20:00–05:00.
    static func band(atMinuteOfDay minute: Int) -> TimeOfDayBand {
        switch minute {
        case 300..<480: .dawn
        case 480..<1_020: .day
        case 1_020..<1_200: .dusk
        default: .night
        }
    }

    static func minuteOfDay(for date: Date, timeZone: TimeZone) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private static func rig(from anchor: Anchor, band: TimeOfDayBand) -> LightRig {
        LightRig(
            band: band,
            elevationRadians: radians(anchor.elevationDegrees),
            azimuthRadians: radians(anchor.azimuthDegrees),
            colorTemperatureKelvin: anchor.colorTemperatureKelvin,
            relativeIntensity: anchor.relativeIntensity,
            shadowSoftness: anchor.shadowSoftness
        )
    }

    private static func surroundingAnchors(of minute: Int) -> (Anchor, Anchor) {
        for index in anchors.indices {
            let start = anchors[index]
            let end = anchors[(index + 1) % anchors.count]
            if forwardDistance(from: start.minuteOfDay, to: minute)
                < forwardDistance(from: start.minuteOfDay, to: end.minuteOfDay) {
                return (start, end)
            }
        }
        // The segments tile the whole day, so this is unreachable; returning the wrapping
        // segment keeps the function total without introducing a crash path.
        return (anchors[anchors.count - 1], anchors[0])
    }

    private static func forwardDistance(from start: Int, to end: Int) -> Int {
        ((end - start) % minutesPerDay + minutesPerDay) % minutesPerDay
    }

    private static func interpolate(_ start: Float, _ end: Float, _ progress: Float) -> Float {
        start + (end - start) * progress
    }

    private static func radians(_ degrees: Float) -> Float {
        degrees * .pi / 180
    }
}

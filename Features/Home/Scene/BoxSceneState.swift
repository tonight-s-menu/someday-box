import Foundation

/// Value types the box scene may render. Everything here is derived, never authoritative:
/// `BoxSceneStateReducer` builds a snapshot from the persisted product state plus an
/// injected clock, and the RealityKit layer diff-applies it (specification §6.1).
///
/// This file imports Foundation only. Nothing in the derivation core may reach for
/// RealityKit, SwiftUI, or any renderer type.
enum BoxSceneDerivation {
    /// Versions the rules in specification §6.2–§6.4, §8, and §10. Changing a band,
    /// threshold, or mapping requires `box-scene-v2` plus updated fixtures.
    static let version = "box-scene-v1"
}

/// Where a paper came from — an explicit persisted fact, never inferred (§8, LB-D06).
enum PaperOrigin: String, Equatable, Sendable {
    case manualCapture
    case shareImported
}

/// Paper weight, derived from the persisted duration bucket alone (§8).
enum PaperForm: String, Equatable, Sendable {
    /// `up_to_10_minutes`, `up_to_30_minutes`.
    case smallSlip
    /// `up_to_60_minutes`, `up_to_120_minutes`.
    case standardFold
    /// `up_to_240_minutes`, `up_to_480_minutes`.
    case doubleFold
    /// A duration raw value this build does not support: neutral slip, still visible in
    /// peek and management, still excluded from every draw (DRW-14, PAPR-04).
    case unknownDuration
}

/// Age expression tiers (§8). Thresholds are exact and clock-injected (PAPR-03).
enum PaperAgeTier: String, Equatable, Sendable {
    case fresh
    case settled
    case aged
    case longKept
}

/// A paper's resting place in the stack, seeded from its UUID so the same record set
/// always arranges identically (§6.3, SCN-03).
///
/// Offsets are metres in the box's local space; `stackIndex` counts from the bottom of the
/// visible stack upwards.
struct PaperRestingTransform: Equatable, Sendable {
    var lateralOffset: Float
    var depthOffset: Float
    var yawRadians: Float
    var bend: Float
    var stackIndex: Int
}

/// One visible paper instance. It carries no title, note, or URL: the scene never renders
/// readable content, and peek is impressions only (PEEK-03, PAPR-01).
struct BoxScenePaper: Equatable, Sendable, Identifiable {
    let id: UUID
    var origin: PaperOrigin
    var form: PaperForm
    var ageTier: PaperAgeTier
    var transform: PaperRestingTransform
}

/// The existing product gates, re-skinned rather than re-implemented (§6.4).
enum BoxSceneGate: Equatable, Sendable {
    /// Ordinary interactive scene.
    case open
    /// An exclusive data operation (restore, erase) holds the arbiter: the box is closed
    /// and quiet, and every scene-initiated mutation affordance is disabled (SCN-07).
    case exclusiveDataOperation
    /// The global resumption gate: the scene opens in reveal focus on this paper before
    /// root tabs (SCN-08, baseline 7.7).
    case unresolvedAttempt(itemID: UUID)
}

/// The four §9.1 anchor bands of the day.
enum TimeOfDayBand: String, Equatable, Sendable {
    case dawn
    case day
    case dusk
    case night
}

/// Light rig parameters produced by `TimeOfDayLightDriver`. Angles are radians, intensity
/// and softness are normalised 0…1, and the renderer maps them onto its own units.
struct LightRig: Equatable, Sendable {
    var band: TimeOfDayBand
    var elevationRadians: Float
    var azimuthRadians: Float
    var colorTemperatureKelvin: Float
    var relativeIntensity: Float
    var shadowSoftness: Float
}

/// Everything the scene is allowed to show at one instant.
struct BoxSceneSnapshot: Equatable, Sendable {
    /// The persisted drawable count (BOX-01). It stays the authority; the stack is an
    /// impression of it (SCN-02).
    var drawableCount: Int
    /// The visible stack, bottom-first, already reduced to the §6.2 band count.
    var visiblePapers: [BoxScenePaper]
    /// Above 200 drawable papers the stack reads as pressed full rather than growing.
    var isStackPressedFull: Bool
    /// The accepted paper clipped at the lid, when one exists.
    var currentPick: BoxScenePaper?
    /// Completion memories behind the seam; the seam predicate itself arrives in WP-16.
    var memoryCount: Int
    var gate: BoxSceneGate
    var light: LightRig
}

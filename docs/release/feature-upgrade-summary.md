# Feature Upgrade Summary

> Repository delivery view, updated for the current candidate. This is not a signed-release claim; use the candidate manifest and acceptance checklist for release evidence.

## Product foundation

| Capability | Current delivery |
| --- | --- |
| Local-first product boundary | All product data remains on device. No account, backend, analytics, CloudKit, ads, or remote configuration is introduced. |
| Capture and Box management | Create, edit, archive, restore, permanently delete, browse, and complete Papers through the existing mutation gate. |
| Draw and Current Pick | Deterministic eligibility, persisted attempts, redraw, accept, dismiss, completion, and relaunch recovery remain authoritative product behavior. |
| Memories | Completed snapshots remain available in the native Memories surface. |

## Share to Box

| Upgrade | Current delivery |
| --- | --- |
| System Share Extension | Text and HTTP(S) URLs are written as atomic App Group envelopes. |
| Main-app materialization | Only the main app writes SwiftData, through the normal product mutation gate. |
| Idempotency and concurrency | Fresh-versus-existing status is decided in the serialized transaction; a concurrent loser reports `alreadyImported`. |
| User feedback | Only committed and refetched imports may animate into the Box. Feedback is bounded, aggregate, ephemeral, and discarded in the background. |
| Failure handling | Invalid, future-version, or quarantined envelopes route to Shared Capture Recovery rather than presenting a false success. |

## Core Box living experience

| Upgrade | Current delivery |
| --- | --- |
| Presentation architecture | `RealityView` presents a bundled USD scene using an explicit virtual camera. It is non-AR and requests no camera permission. |
| Renderer tiers | Full 3D, Lite 3D, and equivalent SwiftUI 2D paths preserve the same product actions. |
| Interaction | Versioned presentation state handles lid/peek, ribbon pull, draw threshold, interruption, stale commands, and fallback reasons. |
| Asset contract | Required named entities, local-only provenance, scene budgets, bundled manifest, and runtime SHA-256 verification are enforced before 3D use. |
| Motion preferences | Normal, quick, and reduced motion are supported alongside independent sound, haptic, and ambience preferences. |
| Automatic degradation | Low Power Mode, memory pressure, asset failure, and unsupported rendering move safely to a lower tier without blocking Capture, Draw, or Recovery. |
| Accessibility | Semantic controls, native action equivalents, accessibility actions, Dynamic Type layout, and automated accessibility audit coverage are present. |

## Durable-data and recovery upgrades

| Upgrade | Current delivery |
| --- | --- |
| Time context v2 | Draw sessions use a canonical context union for the four presets and Custom; legacy raw storage is not dual-written. |
| Schema v3 migration | A journaled independent-generation migration converts supported v2 stores and validates before activation. |
| Backup v3 | Canonical backup v3 and generation digest v3 preserve the full draw context while readers retain v1–v3 import support. |
| Store Recovery | Store-open failure offers retry, validated independent backup recovery, and deliberately confirmed erase. Recovery never depends on the 3D scene. |
| Preference lifecycle | Presentation preferences live in `core-box-presentation-v1`, stay outside product backups, and are reset by Erase All Data. |

## Release and evidence status

| Gate | Status |
| --- | --- |
| Source, configuration, asset, and release audits | Pass |
| Deterministic domain and full simulator/UI test suite | Pass |
| Physical-device performance | Not run |
| Manual VoiceOver, Voice Control, and Switch Control | Not run |
| Runtime network/privacy evidence | Not run |
| Signed packaged candidate | Not run |

The candidate is therefore `shipped-in-candidate-release-blocked`. The remaining gates are intentionally not inferred from simulator or source evidence.

## Deferred scope

P1 starts only after P0 interaction and performance evidence is stable. It may add an openable memory drawer, bounded decorative ambience, age-derived visual treatments, and refined aggregate Share feedback. P2 candidates (for example double-tap draw, device shake, date clip, hidden old-paper layer, and Box-within-the-Box) require their own approved product, data, accessibility, migration, and release contracts before implementation.

## Source of truth

- [Core Box living-experience contract](../core-box-living-experience-upgrade.md)
- [RealityKit architecture decision](../adr/0004-realitykit-core-box-presentation.md)
- [Candidate release manifest](core-box-candidate-manifest.json)
- [Acceptance checklist](acceptance-checklist.md)

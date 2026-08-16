# Lived-in Box readiness

Status date: 2026-08-16 (Australia/Melbourne)

This ledger separates source completion from release acceptance for the [Lived-in Box feature](../features/lived-in-box.md). It is not a candidate manifest and does not authorize shipping. Update the relevant row in the same change as the work it describes; never claim an evidence level the artifacts do not support (simulator evidence is not device evidence; unsigned builds are not packaged evidence).

| Milestone | Source status | Evidence available now | Evidence still required |
| --- | --- | --- | --- |
| B0 — Contract freeze | **Accepted** (2026-08-16) | Feature specification, ADR 0004, development plan, this ledger, baseline/README synchronization; the full decision ledger LB-D01…D20 is owner-approved as of 2026-08-16 — LB-D01/D02/D07 approved as specified, LB-D19 sole-3D-surface, LB-D04/D05/D06 future-roadmap deferrals, and the spec §4.4 pre-release persistence posture | — B0 exit is complete; B1 may begin per the development plan |
| B1 — Tangible core | In progress (WP-01 complete) | `RealityView` hosting proven in the simulator with the existing MVP suites still green (`make ci-check`); scene module scaffolding builds for arm64 device; static audits green | All B1 acceptance rows (SCN/LID/PULL/DIAL/PEEK/MOT/SND/FST/DGR/PRF/AXS), MVP + Share ingestion regression at Q0 and forced Q2, Instruments runs on both reference devices with the oldest-device tier gate met, quality-tier behavior matrix, gesture-equivalence audit, owner experience sign-off |
| B2 — States and traces | Not started | — | PAPR and B2 TRC rows, deletion/restore re-derivation matrices, device pass for completion and import sequences, bilingual copy review, owner sign-off |
| B3 — Growth and echoes | Not started | — | Remaining TRC rows, night selection regression, anniversary and discovery once-only proofs, final accessibility and performance re-runs, release-manifest integration, owner sign-off |

## Work-package status

| WP | Phase | Status | Evidence |
| --- | --- | --- | --- |
| WP-01 — Rendering spike and scaffolding | B1 | **Complete** (2026-08-16) | Source: `Features/Home/Scene/` module behind the Debug-only `SOMEDAYBOX_SCENE_SPIKE` flag, zero shipped behaviour change. Static: `make audit` (now including `scripts/audit-scene-layering.sh`) green. Simulator: `make ci-check` green on iPhone 17 Pro / iOS 26.5 — 52 unit tests and 5 UI tests, no regression against the pre-scene baseline. Build: `xcodebuild build -destination 'generic/platform=iOS'` succeeds for arm64 device (unsigned). Rendering: the placeholder box, lid, and ground render in the simulator, confirmed through a temporary, uncommitted harness and reverted; screenshot held outside the repository. API findings and the answered camera/backdrop/shadow questions are in development plan §6. **Not produced:** physical-device rendering, frame-rate/thermal/memory measurements, signed package — none are WP-01's scope |
| WP-02…WP-14 | B1 | Not started | — |
| WP-15…WP-20 | B2 | Not started | — |
| WP-21…WP-24 | B3 | Not started | — |

## Standing notes

- Share to Box S6 packaged acceptance remains tracked separately in [share-to-box-readiness.md](share-to-box-readiness.md); neither ledger substitutes for the other.
- The feature as specified needs no schema, backup, or policy change. The project is pre-release, so persistence may evolve when genuinely needed — but only docs-first with versioned identifiers (plan §0.2), never silently inside a work package.
- **Toolchain (2026-08-16):** the development machine's missing iOS platform component was installed the same day, restoring simulator and device destinations; `make ci-check` runs again. Simulator evidence in this ledger is still not device evidence — RealityKit material, frame-rate, thermal, and haptic truth stay open until the WP-13 device runs.
- By owner decision (LB-D19, 2026-08-16) there is no 2D product mode: degradation evidence concerns the in-scene quality-tier ladder and the data-safety recovery surface only. No work package may introduce a parallel Home surface.

# Lived-in Box development plan

| Field | Decision |
| --- | --- |
| Document status | Living execution plan for code agents; archived when B3 exits |
| Governing contract | [Lived-in Box feature specification](../features/lived-in-box.md) — on any conflict, the specification wins and this plan must be corrected |
| Architecture decision | [ADR 0004](../adr/0004-realitykit-scene-presentation.md) |
| Status tracking | [Lived-in Box readiness ledger](../release/lived-in-box-readiness.md) — implementation status lives there, never here |
| Last reviewed | 2026-08-16 |

This plan decomposes the feature into work packages (WP) sized for one focused agent session each. It names files, steps, tests, and exit criteria. It contains no implementation code.

---

## 0. Execution rules for every agent

Read before any WP. These rules are binding for every session that implements this plan.

### 0.1 Read-first list

1. [Feature specification](../features/lived-in-box.md) — at minimum §3 (guardrails), §5 (decision ledger), the sections named by your WP, and §18 acceptance IDs your WP cites.
2. [ADR 0004](../adr/0004-realitykit-scene-presentation.md) — authority boundaries.
3. [Product baseline](../product-requirements-and-technical-foundation.md) §9–§10 if your WP touches anything near draw, lifecycle, or persistence semantics.
4. The current [readiness ledger](../release/lived-in-box-readiness.md) row for your WP's phase.

### 0.2 Invariants no WP may break

- **Docs-first:** if implementation reveals the spec is wrong or incomplete, stop, update the spec (and its decision ledger) in the same change, and say so. Never silently diverge.
- **Persistence discipline:** the feature as specified needs no new persisted records; schema v2, backup v2, and `mvp-v1` stay unchanged by design, not prohibition. The project is pre-release, so if implementation genuinely needs a persisted change, stop, update the spec and version the identifier first (docs-first), then implement — never change persistence silently or ride it through an unrelated WP.
- **Layering:** `Domain/` stays Foundation-only. Nothing in `Domain/` or `Application/` imports RealityKit, SwiftUI, AVFAudio, or CoreHaptics. Scene code lives in `Features/Home/Scene/`.
- **Truth before animation:** every mutation commits through existing use cases before its presentation plays. Never reorder.
- **Accessible equivalence, one surface:** any flow you attach to a gesture must remain reachable through a visible, accessible control in the same WP. There is no 2D product mode and no mode switch (spec LB-D19) — never build one, even as scaffolding you intend to ship behind; degradation work targets the in-scene quality tiers only.
- **No content in diagnostics:** no `print`/`Logger` additions that could carry titles, notes, URLs, or UUIDs; the audit greps for logging surfaces and must stay green.
- **No new dependencies, capabilities, or entitlements.** RealityKit, AVFAudio, and CoreHaptics are Apple frameworks and are pre-approved by ADR 0004 for Features-layer use only. Networked or LLM-backed work is future-roadmap scope (spec §4.4) and sits outside this plan entirely.
- **Bilingual copy:** every user-visible string lands in the String Catalog with zh-Hans and en values from spec §17. No hard-coded display strings.
- **Swift 6 strict concurrency:** entity mutation on the main actor; reducers are pure and `Sendable` where applicable.

### 0.3 Verification gate for every WP

Run and keep green before claiming completion:

```text
make audit
make test
make check        (runs iOS tests when full Xcode is selected)
```

A WP that adds acceptance-relevant behavior must add or extend automated tests in the same change. State plainly which spec acceptance IDs your change satisfies and which remain open. Never mark a readiness-ledger row beyond the evidence you actually produced (simulator evidence is not device evidence).

### 0.4 Change hygiene

- One WP per branch/PR-sized change; commit messages follow the existing `feat:` / `fix:` / `docs:` style.
- Update the readiness ledger row for your WP in the same change.
- If you touch copy, update spec §17 if the wording changed during implementation review.
- Human review gates (marked ⚑ in WPs) require the owner to look at screenshots/recordings you attach; do not self-approve aesthetics.

---

## 1. Work-package graph

```text
B1  WP-01 ─► WP-02 ─► WP-03 ─► WP-04 ─┬─► WP-05 (dial UI)
    (spike)  (reducer) (host)  (box)  ├─► WP-06 (lid capture)
                                      ├─► WP-07 (strap draw)
                                      └─► WP-08 (peek)
    WP-09 (audio+haptics) after WP-04; parallel with WP-05..08
    WP-10 (fast paths & settings) after WP-05..08
    WP-11 (quality tiers & recovery surface) after WP-03; parallel with WP-05..09
    WP-12 (a11y closure) after WP-05..08, WP-11
    WP-13 (perf gates) after WP-07, WP-11
    WP-14 (B1 regression & evidence) last in B1

B2  WP-15 (forms/ages) ─► WP-16 (memory seam & completion)
    WP-17 (letter slot & import visuals) parallel with WP-15
    WP-18 (traces v1) after WP-15
    WP-19 (waited-days echo) after WP-15
    WP-20 (B2 evidence) last in B2

B3  WP-21 (compartment & filter) ─► WP-24
    WP-22 (night + anniversary) parallel
    WP-23 (hidden gestures + mementos) parallel
    WP-24 (B3 evidence & manifest) last
```

Parallel lanes assume separate agents; coordinate through the readiness ledger to avoid double-claiming a WP.

---

## 2. Phase B1 — Tangible core

### WP-01 — Rendering spike and scaffolding

- **Goal:** prove `RealityView` hosting inside the existing app shell and create the scene module skeleton, without changing any user-visible behavior.
- **Spec contracts:** ADR 0004 layering; spec §15.1–§15.3.
- **Files:** create `Features/Home/Scene/` (e.g. `BoxSceneView.swift`, `BoxSceneRealityLayer.swift` placeholders); no changes to existing views yet.
- **Steps:** minimal `RealityView` with a placeholder primitive behind an internal compile-time flag not reachable in the shipped UI; confirm simulator rendering in CI destination and on-device build; confirm `make audit` remains green (no new logging, no capability drift).
- **Tests/evidence:** build passes both `xcode-test` destinations; a short findings note in the WP commit (API quirks discovered) — this note feeds WP-03.
- **Done when:** skeleton merges with zero behavior change and audits green.

### WP-02 — `BoxSceneStateReducer` and presentation derivations (`box-scene-v1`, `draw-dial-v1`)

- **Goal:** the pure derivation core: product snapshot + clock/calendar → `BoxSceneSnapshot`.
- **Spec contracts:** §6.2 density bands, §6.3 seeded layout, §6.4 lock/gate states, §8 forms and age tiers, §7.3 dial mapping and snap function, §9.1 light-driver function; acceptance SCN-01/02/03, DIAL-01/02, PAPR-01/03 (derivation halves), PRF-02 (budget).
- **Files:** create `Features/Home/Scene/BoxSceneState.swift`, `BoxSceneStateReducer.swift`, `DrawDialMapping.swift`, `TimeOfDayLightDriver.swift`; create tests `SomedayBoxTests/BoxSceneDerivationTests.swift`, `SomedayBoxTests/DrawDialMappingTests.swift`.
- **Steps:** define snapshot value types (visible stack entries with seeded transforms, seam/slot/lock flags, camera-relevant state); implement band table, UUID-hash seeding, age tiers, dial mapping + snap; implement the light driver as a pure function of wall-clock components.
- **Tests/evidence:** boundary fixtures per spec §19.1 (bands at 12/13/48/49/200/201; snap at 10/29/30/45/90/119/120/300/480; tiers at 7/90/180 days; identical-input layout stability); measure the reducer against the `performance-v1` fixture and record the timing.
- **Done when:** all fixtures pass; reducer ≤ 50 ms on the fixture; no RealityKit import anywhere in this WP.

### WP-03 — `RealityView` host, camera rig, environment

- **Goal:** the living stage: hosting view, camera states, light rig driven by WP-02, abstract backdrop, async load with placeholder, pause rules.
- **Spec contracts:** §9.1–§9.4 ambience, §15.2–§15.3, §15.5 idle/background pause; acceptance FST-01, PRF-03, DGR-04 (containment skeleton).
- **Files:** extend `Features/Home/Scene/`; add `CameraRig.swift`, `EnvironmentRig.swift`; wire `BoxSceneView` in as the Home content of `Features/Home/HomeView.swift` (the legacy Home layout remains only as unshipped scaffolding until WP-14 removes it; it is not a product mode).
- **Steps:** async scene construction with a calm placeholder so overlay controls stay interactive ≤ 400 ms; camera state enum with transition durations and Reduce Motion cross-fades; ambient pause after 10 s idle and full pause on background; catch scene-construction failure and route to the recovery-surface placeholder (completed in WP-11).
- **Tests/evidence:** UI test asserting overlay controls respond before scene readiness; light-driver rig values already unit-tested in WP-02; manual simulator recording attached.
- **Done when:** Home shows the (still boxless) stage with overlay controls fully functional and zero data-path regression.

### WP-04 — Procedural box, materials, paper stack ⚑

- **Goal:** the box itself: body, lid pivot, strap mesh, seams/slot placeholders (hidden until their predicates hold), instanced paper stack from WP-02 snapshots.
- **Spec contracts:** §6.2/§6.3 rendering halves, §15.4 procedural-first, concept-derived material families (spec §15.4); acceptance SCN-02/03 (render side), TRC-08 (hidden-by-default structures).
- **Files:** `BoxGeometry.swift`, `BoxMaterials.swift`, `PaperStackLayer.swift` in the scene module.
- **Steps:** parametric rounded box with warm matte materials; lid as a pivoting child; strap as a small tube/ribbon mesh at rest; paper instances applying seeded transforms; diff application when snapshots change (enter/leave animations minimal for now).
- **Tests/evidence:** snapshot-to-entity mapping unit-testable where extractable; screen recordings in light/dark at four time bands. **⚑ Owner review of look and warmth before B1 proceeds** — this is the art-direction gate; expect iteration.
- **Done when:** density bands render honestly, layout is stable across relaunch, and the owner has reviewed the direction.

### WP-05 — Time dial and Custom minutes

- **Goal:** the `draw-dial-v1` control surface: four detents + Custom + Not sure, prefill, snap statement.
- **Spec contracts:** §7.3; acceptance DIAL-01…06; copy §17.
- **Files:** `Features/Home/Scene/DialControl.swift` (SwiftUI overlay/attachment); integrate with the existing draw-context flow currently presented from `Features/Home/HomeView.swift` / `App/RootTabView.swift`; reuse WP-02 `DrawDialMapping`.
- **Steps:** detent control with light haptic ticks; Custom minutes wheel (10–480, step 5) with the snap statement line; Not sure as the quiet adjacent option; persist last selection to presentation preferences; the dial overlay is the single context surface — the legacy draw-context sheet retires with the legacy Home in WP-14.
- **Tests/evidence:** UI test that each detent/Custom path creates a session with the exact expected `availableTimeRaw`; accessibility adjustable-control pass; DIAL-04 test that prefill cannot auto-commit.
- **Done when:** every context path produces exactly the expected persisted sessions.

### WP-06 — Capture through the lid

- **Goal:** lid-tap capture with rise/fold/drop sequences and all failure states; fast path.
- **Spec contracts:** §7.1, §11.2 capture tiers; acceptance LID-01…06 (LID-05 lands in WP-17), FST-02/04.
- **Files:** `LidCaptureCoordinator.swift` in the scene module; touch `Features/Home/HomeView.swift` only to route; the capture sheet itself is unchanged.
- **Steps:** lid tap and long-press recognizers on the lid entity plus the existing visible capture button; play open/rise, present the existing capture sheet, then fold/drop/close on success or hover-and-hold on failure; tier logic (first-3 full, ≤ 30 s repeat minimal) reading the shared tier engine (small utility, also used by WP-07/16).
- **Tests/evidence:** existing CAP UI tests re-run through both entries; forced-failure test keeps the hovering draft; timing assertions for tier budgets where measurable in UI tests.
- **Done when:** capture via lid, button, and long-press all satisfy CAP-01…08 with the new presentation.

### WP-07 — Strap draw and reveal

- **Goal:** the signature interaction: strap state machine → existing draw use cases → persisted-then-revealed paper with actions.
- **Spec contracts:** §7.2, §7.5, §6.4 gates; acceptance PULL-01…07, SCN-07/08, MOT-02.
- **Files:** `StrapInteraction.swift`, `RevealPresenter.swift` in the scene module; integration with `Application/DrawUseCases.swift` exactly as the current UI calls it (no use-case changes).
- **Steps:** drag recognizer with slack/tension/threshold and cancel spring-back; threshold haptic; on commit, disable input, call the draw use case, and only on persisted success play slide-out and unfold with the SwiftUI attachment result card (title/note/duration/fit chips per DIAL-03); wire 就做这个 / 换一张 / dismiss to existing resolutions; empty-pool soft shake + existing reasons sheet; Current-Pick stowed strap; unresolved-attempt resumption presented in the scene before tabs.
- **Tests/evidence:** extend the forced-termination persist-before-reveal test through this entry point; UI tests for cancel-below-threshold (no session created), single-candidate, exhausted-session, and empty-pool paths; VoiceOver announcement timing per AXS-04.
- **Done when:** every DRW acceptance rule in the baseline passes through the strap flow, and the visible draw button drives the identical path.

### WP-08 — Peek inside

- **Goal:** top-down peek with impressions, read-only surface, and explicit exits to management.
- **Spec contracts:** §7.4; acceptance PEEK-01…06 (PEEK-07 arrives in WP-21).
- **Files:** `PeekPresenter.swift`, impression rendering in `PaperStackLayer.swift`; a small entry from `Features/Box/BoxView.swift` navigation for the pre-filtered long-press path.
- **Steps:** camera transition (≤ 0.8 s, RM cross-fade); ≤ 48 impressions with forms/age visible and no readable text; 整理盒子 button → Box tab; long-press impression → Box with the matching derived filter; accessibility summary line for the peek state.
- **Tests/evidence:** UI test that no title/note string from fixtures is present in the peek accessibility tree; navigation tests for both exits; RM path test.
- **Done when:** peek is demonstrably impression-only and both exits work.

### WP-09 — Sound and haptics registry

- **Goal:** the §12 registries wired to scene events, with toggles and honest audio-session behavior.
- **Spec contracts:** §12.1–§12.2; acceptance SND-01…03, HAP rows in §18.8.
- **Files:** `Features/Home/Scene/SceneAudio.swift`, `SceneHaptics.swift`; audio assets under `Resources/Audio/` with an asset-manifest table appended to this plan (§5 below); Settings toggle work lands in WP-10.
- **Steps:** generate/author the six short samples (self-authored; procedural synthesis acceptable for B1 placeholders), convert to `.caf`, total ≤ 1.5 MB; ambient mix-with-others session that never interrupts playback; map events per registry; respect silent switch; haptics through the existing toggle path.
- **Tests/evidence:** unit test that every registry event maps to a bundled asset; bundle-size assertion; manual device check for silent-switch behavior. **⚑ Sound character review by owner** (placeholder vs final).
- **Done when:** registries are complete, bounded, and silenceable; extension target provably links no audio.

### WP-10 — Fast paths, tiers, and Settings additions

- **Goal:** the efficiency contract: tier engine everywhere, labeled repeat-draw control, new Settings rows.
- **Spec contracts:** §13, §16.2; acceptance FST-01…05 (FST-05 finalized in WP-17), MOT-01.
- **Files:** shared `AnimationTierEngine.swift`; Settings additions in the existing settings view (音效 / 环境随时间变化 / 快速动画); repeat-draw control on the Home overlay.
- **Steps:** implement tier selection (first-3 / standard / burst / forced-minimal); repeat control labeled with the last context (DIAL-04-compliant); preference keys exactly per spec §16.2; confirm zero new confirmation steps by walking every flow.
- **Tests/evidence:** tier-selection unit tests; UI test for the repeat control creating a session with the labeled context; launch-interactive timing test (FST-01).
- **Done when:** fast paths measurably meet budgets and Settings exposes exactly the three new rows, bilingual.

### WP-11 — Quality tiers and the recovery surface

- **Goal:** the §14.2 in-scene degradation ladder (Q0/Q1/Q2) and the catastrophic-failure recovery surface. There is no mode work here — no parallel Home may exist (spec LB-D19).
- **Spec contracts:** §14.2, §15.5–§15.6; acceptance DGR-01…05.
- **Files:** `Features/Home/Scene/SceneQualityController.swift`; a plain SwiftUI recovery view (explanation, retry, full Settings access); tier hooks in `EnvironmentRig.swift` and `PaperStackLayer.swift`; the tier behavior matrix as `docs/release/lived-in-box-tier-matrix.md` (created by this WP from spec §14.2/DGR).
- **Steps:** tier definitions (effects, materials, instance caps per tier); automatic transitions (one frame-floor breach → Q1, a further breach at Q1 → Q2; thermal `.serious` → Q1, `.critical` → Q2; Low Power Mode → Q1); lossless, unannounced, reversible switches; recovery surface on init/asset failure wired from WP-03's placeholder, with retry and working data controls.
- **Tests/evidence:** tier-transition unit tests; scripted full journey at forced Q2; fault-injection init failure → recovery surface with a working export path; the written tier matrix attached to the ledger.
- **Done when:** DGR rules pass and the tier matrix is complete and true.

### WP-12 — Accessibility closure for B1

- **Goal:** the §14.1 contract on every B1 surface.
- **Spec contracts:** acceptance AXS-01…05; baseline accessibility rules.
- **Files:** scene accessibility element + custom actions; audit doc `docs/release/lived-in-box-gesture-equivalence.md` (created by this WP).
- **Steps:** summary element with counts; custom actions (放进一张 / 抽一张 / 看看盒内 / 打开当前纸条); Voice Control names; scrim/contrast pass over animated backdrops; extend the automated accessibility audit UI tests to scene Home, peek, reveal, and the recovery surface.
- **Tests/evidence:** automated audits green in both languages/appearances; manual VoiceOver + Voice Control journey recordings; the gesture-equivalence audit document.
- **Done when:** AXS-01…05 have retained evidence at the correct levels.

### WP-13 — Performance instrumentation and gates

- **Goal:** measure and enforce §15.5.
- **Spec contracts:** acceptance PRF-01…05.
- **Files:** content-free signposts in the scene module; a repeatable Instruments procedure appended to this plan; thermal-ladder handling in `EnvironmentRig.swift`/`SceneQualityController.swift`.
- **Steps:** signpost scene build, reducer pass, first frame; run the `performance-v1` fixture scenario; execute Instruments passes on both reference devices; implement `.serious`/`.critical` ladder behavior; verify idle/background pause.
- **Tests/evidence:** recorded Instruments traces for both devices; fixture timing in CI where runnable; thermal behavior demonstrated (simulated where hardware cannot be forced, and labeled as such).
- **Done when:** every PRF gate has evidence or a truthfully-labeled blocker row in the ledger.

### WP-14 — B1 regression and evidence closure

- **Goal:** close phase B1 per spec §20.
- **Steps:** remove the legacy Home scaffolding so the scene is the only Home surface in the shipped target; run the full existing MVP + Share ingestion regression suites at Q0 and forced Q2; assemble the evidence bundle (test results, recordings, Instruments traces including the oldest-device tier gate, tier matrix + equivalence audits); update every B1 ledger row with links; request the owner's §1.1 experience sign-off.
- **Done when:** the ledger's B1 rows are green with immutable evidence and the owner has signed the phase exit. No B2 WP starts before this.

---

## 3. Phase B2 — States and traces

### WP-15 — Paper forms and age visuals

- **Spec contracts:** §8; acceptance PAPR-01…04 (render side; derivations exist from WP-02).
- **Files:** `PaperForms.swift` in the scene module; peek impression upgrades.
- **Steps:** form meshes/materials per the §8 table (note strip, clipping + corner mark, slip/standard/double-fold weights, neutral unknown-duration slip); age-tier expression (lift/curl/fade/sink); verify no code path reads title/note for any visual decision (PAPR-01 audit grep).
- **Tests/evidence:** derivation-to-form mapping tests; screenshot review in peek and stack; PAPR-01 static audit note.

### WP-16 — Memory seam and completion sequence ⚑

- **Spec contracts:** §7.5, §10.1 seam row, §10.2 stub stamps; acceptance PAPR-05/06/07, TRC-08 (seam), MOT-01.
- **Files:** `MemorySeamLayer.swift`, completion sequence in `RevealPresenter.swift`/scene.
- **Steps:** Current-Pick clip under the lid; stamp-and-slide completion presentation of the already-atomic LIFE-04 transaction; seam appears when memories ≥ 1 with the once-only discovery line; seam opens Memories; archive refold/fade with the §17 line; put-back drop to seeded spot.
- **Tests/evidence:** interruption test mid-animation (nothing lost); seam predicate tests incl. erase → seam disappears; discovery-flag once-only test. **⚑ Owner review of the completion moment** — it is the emotional core.

### WP-17 — Letter slot and import visuals

- **Spec contracts:** §7.1 import path, §10.1 slot row; acceptance LID-05, FST-05, TRC-08 (slot).
- **Files:** `LetterSlotLayer.swift`; integration where the app currently ingests on foreground (see `App/SomedayBoxApp.swift` shared-capture import path).
- **Steps:** slot visibility predicate (any live item with `SourceReference`, or first ingestion in progress); per-envelope slide-in ≤ 0.25 s with `+N` coalescing chip; no success dialog; ingestion logic untouched.
- **Tests/evidence:** multi-envelope mailbox fixture UI test; predicate tests incl. restore re-derivation; regression on the existing ingestion tests.

### WP-18 — Traces v1 (wear, stamps, postmark)

- **Spec contracts:** §10.2, §10.5; acceptance TRC-01/02, SCN-04/06.
- **Files:** `TraceDerivations.swift` (pure, beside WP-02 reducer), `TraceLayer.swift` (render).
- **Steps:** implement `traces-v1` predicates (first-completion stamp, wear tiers 5/20/50, import postmark, stub stamps with completion-truth copy); render as subtle material/decal changes; nothing numeric anywhere.
- **Tests/evidence:** predicate boundary tests (4/5, 19/20, 49/50); deletion-closure test: delete the only qualifying records → trace gone same snapshot; restore re-derivation test; a grep-level check that no trace view formats a count into UI text.

### WP-19 — Waited-days echo

- **Spec contracts:** §10.3; acceptance TRC-03, AXS-04.
- **Files:** echo line in `RevealPresenter.swift`; derivation beside WP-18.
- **Steps:** compute `shownAt − createdAt` at reveal from the persisted attempt and item; show the line only at ≥ 180 days with the exact floor of days; VoiceOver ordering after stable content.
- **Tests/evidence:** boundary tests (179/180/181 days, clock-skew clamp); localization check for day-count pluralization in both languages.

### WP-20 — B2 evidence closure

- As WP-14, scoped to B2 rows: PAPR/TRC(B2)/LID-05/FST-05 evidence, deletion/restore matrices, device pass for completion and import sequences, bilingual copy review, ledger update, owner sign-off.

---

## 4. Phase B3 — Growth and echoes

### WP-21 — Long-kept compartment and Box filter

- **Spec contracts:** §10.1 compartment, §16.3; acceptance PEEK-07, TRC-08/09.
- **Files:** compartment seam in `PeekPresenter.swift`; **很久以前 / Long kept** filter in `Features/Box/BoxView.swift` (presentation filter only).
- **Steps:** long-kept predicate from WP-02; seam in peek when non-empty; once-only discovery line; tap → Box pre-filtered; verify zero effect on eligibility/weights (existing policy tests as oracle).
- **Tests/evidence:** predicate boundaries (180 d / 90 d rules); filter derivation test per BOX-03; TRC-09 no-op-on-policy test.

### WP-22 — Night quietness and anniversary echo

- **Spec contracts:** §9.3, §10.3 anniversary; acceptance TRC-04/05.
- **Files:** night parameters in `TimeOfDayLightDriver.swift` consumers; `AnniversaryEcho.swift`; `echo.lastAnniversaryDay` preference.
- **Steps:** 22:00–05:59 presentation set (dimmer rig, +0.2 s unfold unless fast/RM, softer samples, moon-knot strap detail); anniversary derivation (month-day match, ≥ 1 year, oldest pick, once per day) with the surface animation and line; no announcements.
- **Tests/evidence:** the seeded night regression proving identical pool/weights at 03:00 vs 15:00 (TRC-05 — the most important test in this WP); once-per-day preference test; calendar-edge tests (Feb 29, timezone change day).

### WP-23 — Hidden gestures and micro-mementos

- **Spec contracts:** §10.4, §10.2 mementos; acceptance TRC-06/07/10, FST-03.
- **Files:** gesture recognizers in the scene module; `MementoLayer.swift`; discovery flags per §16.2.
- **Steps:** double-tap box and long-press strap → the labeled repeat-draw path; swipe-down lid with Current Pick → put back with existing confirmation; one-time hint lines; memento derivations (first memory, first imported-source memory, first night completion, memories ≥ 10) rendered at ≤ 4 fixed anchors with no labels.
- **Tests/evidence:** gesture-to-equivalent tests; hint once-only tests; memento predicate + deletion-closure tests; a11y pass confirming gestures never became the only path.

### WP-24 — B3 evidence closure and release-manifest integration

- **Steps:** full-suite regression at Q0 and forced Q2; re-run performance and accessibility matrices; complete all remaining ledger rows; add the Lived-in Box rows (quality-tier matrix reference, asset manifest hash, gesture audit reference) to the [release manifest template](../release/release-manifest-template.md) in the same change; owner phase sign-off; archive this plan to `docs/plans/archive/` per the [documentation operations guide](../README.md).
- **Done when:** the readiness ledger shows B1–B3 accepted with immutable evidence, and packaged-candidate rows remain truthfully open until a signed candidate exists.

---

## 5. Asset manifest

Maintained by WPs that add or replace bundled scene/audio assets. Self-authored only (spec LB-D20).

| Asset | Type | Added by | Size | SHA-256 | Provenance |
| --- | --- | --- | --- | --- | --- |
| _none yet — B0_ | | | | | |

Budgets: audio total ≤ 1.5 MB; B1 total new bundle weight ≤ 10 MB; authored USDZ later ≤ 8 MB (spec §15.4).

---

## 6. Standing risks for agents

- **Do not "improve" draw, lifecycle, or persistence logic while passing through.** If you find a defect there, record it in the ledger and raise it; fixing it is a separate, owner-approved change.
- **Simulator lies about feel.** Frame rate, haptics, materials, and thermal behavior need device evidence; label simulator-only evidence as such in the ledger, always.
- **RealityKit API drift.** The iOS `RealityView` surface is new; when an API behaves differently than documented, write the finding into WP-01's notes section (append below) rather than working around it silently.

### WP-01 findings log

_Empty — populated by the first rendering spike._

# Lived-in Box

## Product requirements, functional translation, and development contract

| Field | Decision |
| --- | --- |
| Document status | Development contract for the second selected post-MVP expansion; implementation status lives only in the [readiness ledger](../release/lived-in-box-readiness.md) |
| Feature name | `Lived-in Box` in English; `有空箱·盒子生活感` in Simplified Chinese |
| Source concept | 「有空箱」核心盒子生活感设计说明, provided by the product owner on 2026-08-16; translated and bounded by this document |
| Parent baseline | [Product requirements and technical foundation](../product-requirements-and-technical-foundation.md) — every MVP contract remains in force unless this document names an explicit, bounded exception |
| Sibling contract | [Share to Box](share-to-box.md) — unchanged by this feature; its S6 packaged acceptance remains independent |
| Rendering decision | [ADR 0004 — RealityKit `RealityView` presentation layer](../adr/0004-realitykit-scene-presentation.md) |
| Execution plan | [Lived-in Box development plan](../plans/lived-in-box-development-plan.md) |
| Readiness ledger | [Lived-in Box readiness](../release/lived-in-box-readiness.md) |
| Runtime model | This release is fully on-device — no account, server, sync, analytics, ads, or LLM; RealityKit renders locally. LLM and networked capabilities are future-roadmap scope (§4.4), never part of B1–B3 |
| Persistence impact | This release needs **no new authoritative records**: schema v2, backup v2, and `mvp-v1` are unchanged by design, not by prohibition — the project is pre-release and persistence may evolve when a feature genuinely needs it (§4.4, §16.1) |
| New versioned identifiers | `box-scene-v1` (scene derivation), `draw-dial-v1` (context presentation mapping), `traces-v1` (trace/echo derivation) |
| Last reviewed | 2026-08-16 |

This document translates the lived-in-box concept brief into a bounded product specification and development contract. Ambiguities in the brief are resolved in the [decision ledger](#5-decision-ledger); nothing in the brief silently overrides an existing product guardrail. It does not contain implementation code.

---

## 1. Executive decision

The MVP proved the loop: capture a paper, draw a paper, keep a memory. This release upgrades **how that loop feels**, not what it does. Home becomes a small, tangible 3D box — a toy-grade digital object (数字玩偶) with volume, a lid, a soft pull strap, paper inside, and traces of use — rendered locally with RealityKit `RealityView` inside SwiftUI. The 3D box is the **sole Home surface and the sole development target**: no parallel 2D product mode exists or will be built (LB-D19).

The release validates one hypothesis:

> When the box behaves like a private object that slowly fills with the user's own life — instead of a static illustration above two buttons — capturing feels lighter, drawing feels more inviting, and returning feels voluntary.

The product loop, draw policy, lifecycle rules, persistence, backup, privacy, and localization contracts are unchanged. Every visible state of the box is **derived from already-persisted product truth**; the scene never becomes a second store, a growth system, or a reward machine.

### 1.1 Release quality bar

The shipped result must simultaneously remain:

- **simple** — one box, one lid, one strap, one dial; no mode lists or growth panels;
- **complete** — every MVP and Share-to-Box function stays reachable and unchanged in meaning;
- **zero-threshold** — a first-time user understands put-in and draw-out without instruction;
- **playful and tactile** — interactions have weight, sound, and haptics, all restrained;
- **fully local in this release** — no network, no LLM, no telemetry; networked/LLM capabilities live on the future roadmap (§4.4) and never enter B1–B3 sideways;
- **never slower** — every lived-in flourish has a fast path; efficiency contracts are acceptance rules, not intentions.

### 1.2 The experience promise

- The environment is abstract; the box and its mechanisms are concrete.
- The box is product structure, not a decorative model: lid = capture, strap = draw, opening = peek, seam = memories.
- The first day is plain. Details, seams, and traces appear only after the user's own actions create them.
- Long-term feedback arrives as quiet traces and echoes, never as achievements, levels, streaks, or progress.
- Nothing sits between the user and a ten-second capture or a two-second draw.
- The 3D box is the only Home surface; degradation happens inside the scene, never beside it.

---

## 2. User problem and jobs

The MVP interface is honest but administrative: an illustration, two buttons, a list. It communicates *function* and not *accumulation*. Users who save thirty papers see the same Home as users who saved one; a paper kept for a year returns with no sense of time; completing something changes a list somewhere else.

Jobs this release serves:

- When I open the app, I want to *see* that my box holds real possibilities, so that drawing feels like reaching into something rather than querying a database.
- When I put an idea in, I want the box to physically receive it, so that capture feels finished without a confirmation dialog.
- When something I saved long ago comes back, I want the moment to acknowledge the time that passed, so the app feels like it kept something for me.
- When I have used the app for months, I want the box to quietly show wear and keepsakes from my own history, so that it feels mine — without ever being scored.

---

## 3. Guardrails

### 3.1 Inherited contracts that remain binding

Every guardrail in baseline sections 3, 5, 9, 10, and 12 continues to apply verbatim. The ones this feature most often risks, restated:

- No deadline, streak, completion rate, score, badge, level, collection meter, or backlog pressure (baseline 3.1).
- No LLM, classifier, semantic parsing, automatic tagging, or inferred context anywhere in this release. By owner decision these moved from permanent non-goals to future-roadmap scope (§4.4); they arrive only through their own replacement contracts, never as a silent enhancement inside this feature.
- Rules decide eligibility; randomness chooses within it; nothing is silently relaxed (baseline 3.3).
- User-visible truth: every label, chip, trace, and echo must be backed by persisted metadata (baseline 3.4).
- Selection is completed and persisted before any reveal animation begins; animation never decides or delays truth (baseline 6.4, 11.2).
- The global Unresolved-attempt resumption gate and the MutationArbiter serialization are untouched (baseline 6.5, 7.7).
- No product network request, account, CloudKit, analytics, or new sensitive capability in this release; the only App Group remains the reviewed Share-to-Box mailbox (baseline 12.1). The networked future scope is bounded by §4.4.
- Titles, notes, URLs, and record UUIDs never appear in logs — including render, audio, gesture, and performance diagnostics (baseline 12.2).

### 3.2 New guardrails introduced by this feature

- **Presentation derives; it never owns.** Every scene state is a pure function of (persisted product records, injected clock/calendar, presentation preferences). The scene layer holds no product truth, writes no product records directly, and introduces no record type.
- **One surface, accessible equivalence.** The 3D scene is the only Home surface (owner decision LB-D19); no parallel 2D product mode exists or may be built. Every product action reachable through a 3D gesture is equally reachable through a visible, accessible control hosted on that same surface. Degradation happens inside the scene as quality tiers (§14.2); catastrophic scene failure exposes only the minimal data-safety recovery surface (§15.6), never a parallel product UI.
- **Traces tell the truth and honor deletion.** Traces, echoes, mementos, and seams derive only from records that still exist. Permanent deletion (baseline LIFE-08) therefore erases every derived trace of the deleted records with no extra bookkeeping.
- **Growth is discovered, not administered.** No unlock announcements, progress toward thresholds, achievement pages, or collection UI. A new seam or memento simply exists the next time the user looks.
- **Immersion never taxes speed.** Animation tiers, fast paths, and skip affordances are acceptance-tested; a lived-in build that is slower than the MVP at capture or draw fails acceptance.
- **The extension stays lean.** The Share Extension gains no RealityKit, audio, or scene code; its contract in [Share to Box §7](share-to-box.md) is unchanged.

---

## 4. Release scope

### 4.1 P0 by phase

| Phase | Scope | Ships only with |
| --- | --- | --- |
| **B1 — Tangible core** | RealityKit Home scene (box, lid, strap, paper stack, abstract backdrop); capture through the lid; draw through the strap; time dial (`draw-dial-v1`, four detents + Custom + Not sure); peek-inside camera; result presentation on the drawn paper; in-scene quality-tier ladder and data-safety recovery surface; sound/haptic core; animation tiers and fast paths; accessibility closure; performance gates | Full MVP + Share ingestion regression evidence |
| **B2 — States and traces** | Paper forms and age tiers; Current Pick clipped at the lid; completion stamp-and-slide into the memory seam; first-completion seam discovery; letter-slot visuals for share ingestion with burst coalescing; wear/stamp traces (`traces-v1`); waited-days line on reveal | B1 accepted |
| **B3 — Growth and echoes** | Bottom long-kept compartment and "Long kept" Box filter; night quietness; anniversary echo; hidden quick gestures with one-time discovery hints; micro-mementos | B2 accepted |

The core hypothesis can be evaluated internally after B1. B2 and B3 are only worth building if B1 evidence shows the box is treated as the primary interaction surface rather than bypassed through buttons.

### 4.2 Outside this release (B1–B3)

**Deferred to the future roadmap (§4.4) — not rejected:**

- LLM capabilities of any kind, including natural-language time parsing and assisted classification.
- Networked capabilities of any kind, including real-weather ambience (WeatherKit) and any second-person/friend content path.
- Content-type paper forms (menu, ticket, postcard…) — B1–B3 derives forms from explicit facts only (§8, LB-D06).
- New capture fields, including event dates, places, energy, or a user-chosen paper skin (§4.3).
- Widgets, App Intents, Apple Watch, iPad-specific layout; physical shake stays a gated experiment (baseline 4.2).

**Rejected on product principle — not phase-dependent:**

- Multiple draw modes (three-choice, destiny, surprise slider, adventure, night *mode* as a switch).
- Achievements, levels, points, collection albums, progress meters, unlock roadmaps, or any visible counter toward a threshold.
- Fake ambience presented as real facts — e.g. decorative "weather" the device cannot actually know (baseline 3.4).
- A parallel 2D product mode, fallback Home, or user-facing mode switch of any kind — the 3D scene is the sole Home surface (LB-D19).

This release also needs no new authoritative records, schema fields, backup changes, or selection-policy changes — a design fact, not a migration constraint (§16.1).

### 4.3 Follow-up candidates

| Candidate | Earliest phase | Required evidence before work begins |
| --- | --- | --- |
| Dated papers + date clip (event/reservation dates) | Own future spec | Users repeatedly capture dated events and miss them; a reviewed spec resolves the deadline-adjacency question and expiry semantics |
| Box-in-box (future-dated / wish papers) | Own future spec | Same as above: needs new content semantics and open/lock rules |
| User-chosen decorative paper form at capture | Post-B2 | Users ask to distinguish papers and accept one optional capture control without hurting the ten-second promise |
| Home-screen widget quick capture | Own future spec | Capture friction evidence; requires a reviewed capability/App-Group change to baseline 12.1 |
| Physical shake to reshuffle an exhausted session | B3 experiment at the earliest | Baseline 4.2 evidence rule: the explicit draw loop shows repeat use and the gesture passes accessibility review |
| Real-weather ambience (WeatherKit or similar) | Future roadmap (§4.4) | The networked scope opens with its own product/privacy contract; ambience claims stay truthful |
| Content-type paper forms via assisted classification | Future roadmap (§4.4) | The LLM scope opens with its own contract; suggested forms stay user-confirmable, never silently applied |
| Natural-language time input | Future roadmap (§4.4) | Same LLM-scope contract; explicit duration truth at save time (baseline 3.4) is preserved |
| Authored USDZ art replacing procedural geometry | Post-B1 | B1 procedural box is functionally accepted; assets are self-authored, license-clean, within the §15.4 budgets |

### 4.4 Future-roadmap boundary (owner decision 2026-08-16)

The project is pre-release and under active development. Two standing consequences, decided by the owner:

- **Data-migration risk is not a design constraint.** Schema, backup format, and policy identifiers may evolve freely when a feature genuinely needs it — through the normal docs-first, versioned-identifier discipline, never through silent drift. Released-data compatibility machinery (shipped-version fixtures, translation adapters) becomes mandatory only once a public build exists.
- **LLM and networked capabilities move from permanent non-goals to future roadmap scope.** Candidates include natural-language time input, assisted content classification for paper forms, real-weather ambience, and eventually second-person content paths. None of it ships inside B1–B3, and none of it may appear as a silent enhancement or fallback: each arrival requires its own product, privacy, and architecture contract that truthfully replaces the local-only claims it touches (baseline §4.3), because the shipped privacy posture must change honestly, not incrementally.

---

## 5. Decision ledger

Every material idea in the source concept brief, with its binding resolution. Implementation follows this table, not the brief, wherever they differ.

| # | Concept-brief idea | Resolution | Rationale |
| --- | --- | --- | --- |
| LB-D01 | Product is called 「有空箱」 | **Adopted as the Simplified Chinese product name for this generation** (English stays `someday-box`). Shipping the rename (App Store listing, marketing) is a separate release decision recorded in the manifest | The brief uses the name throughout; it extends the existing copy 在有空的时候抽一张. Historical MVP documents keep 改天盲盒 as the name under which MVP acceptance was claimed |
| LB-D02 | Four time options + Custom | **Adopted as presentation mapping `draw-dial-v1`** over the unchanged six raw duration identifiers + `not_sure`; Custom minutes floor-snap to a bucket (§7.3) | Papers store bucket durations, so bucket-level filtering loses nothing and floor-snapping preserves hard time-safety; released identifiers are never repurposed (baseline 5.2). A future context revision may persist exact minutes if papers ever gain finer durations — migration cost is not a blocker pre-release (§4.4) |
| LB-D03 | "Not sure" absent from the brief's dial | **Retained** as a quiet option beside the dial | DRW-01 and the existing context contract require it; removing it would change draw semantics for no experience gain |
| LB-D04 | LLM natural-language time input "after LLM is added" | **Deferred to the future roadmap (§4.4); not in B1–B3** | Owner decision 2026-08-16 re-scoped LLM from permanent non-goal to future scope; it arrives only through its own product/privacy contract and never rides along inside this feature |
| LB-D05 | Weather ambience (rain lines, rain audio, weather reflections) | **Deferred to the future roadmap (§4.4).** In B1–B3, ambience derives only from the device clock and calendar: time-of-day light and restrained season accents | Real weather needs networked data (e.g. WeatherKit), which belongs to the future scope's own contract; fake weather presented as weather stays rejected under user-visible truth (3.4) |
| LB-D06 | Paper forms by content type (menu, ticket, postcard, tutorial…) | **Phase-scoped, not rejected.** In B1–B3, forms derive only from explicit persisted facts — origin (manual vs share-imported), duration weight, age tier, lifecycle (§8). Content-type forms return later: first as an explicit user-chosen form (§4.3), then possibly via assisted classification when the LLM future scope (§4.4) opens | This release has no classifier and must not guess (baseline 3.2); deferral keeps forms truthful today without closing the door |
| LB-D07 | Friend letters / papers shared by friends | **Outside this release** — the current generation has no accounts or user-to-user path. The letter-slot visual is the home of Share-to-Box ingestion: system-share imports arrive through the slot | Share to Box already provides the honest external-inflow story today; a real friend-letter path belongs to the networked future roadmap (§4.4) with its own contract, and the slot is ready to receive it |
| LB-D08 | Date clip for dated events | **Deferred to its own spec** (candidate table) | Deferred for product-scope focus and the deadline-adjacency question; schema evolution itself is not a blocker pre-release (§4.4) |
| LB-D09 | Box-in-box for future letters | **Deferred to its own spec** | Same class of change as LB-D08 |
| LB-D10 | Desktop widget quick add | **Follow-up candidate**, not in this feature | Widgets are excluded by baseline 4.2 and touch the capability allowlist |
| LB-D11 | Shake device to remix papers | **Deferred experiment** exactly per baseline 4.2/4.3; if ever adopted, it maps only to the existing explicit reshuffle of an exhausted session | Accessibility and discoverability review required first |
| LB-D12 | Night draws favor "quieter, low-energy papers" | **Rejected.** Night changes presentation only (light, pace, sound); selection stays `mvp-v1` and is test-proven identical at night | Energy-aware selection needs metadata that does not exist and inference that is prohibited |
| LB-D13 | Transparent viewing window | **Superseded by peek** (the brief itself replaces it); no transparent wall ships |
| LB-D14 | Achievements/collection framing for mementos | **Rejected permanently.** Traces and mementos have no gallery, names, counts, or completion state | Baseline 3.1 |
| LB-D15 | Physics simulation for papers | **Adapted:** deterministic animation (springs/keyframes) that *reads* as physics; no gameplay physics engine in any correctness path | Determinism, testability, battery; animation never decides results (baseline 11.2) |
| LB-D16 | Multiple draw modes list | **Rejected for this release**; single draw flow only | Baseline 4.2 |
| LB-D17 | "Visited in real life" stamp copy | **Adapted to completion truth**: stamps say completed-with-date; the app cannot know a place was visited | User-visible truth (3.4) |
| LB-D18 | Root navigation | **Three root tabs remain.** The scene replaces Home's content only; Box and Memories stay reachable as today | IA stability; peek and seams link into the existing tabs |
| LB-D19 | Concept §18 proposed a 2D simplified/low-performance mode | **Rejected by owner decision (2026-08-16): the 3D box is the sole development target and the sole Home surface.** Degradation is an in-scene quality-tier ladder (§14.2); catastrophic scene failure exposes only a minimal data-safety recovery surface (§15.6). Accessibility — Reduce Motion, VoiceOver, Voice Control, Dynamic Type — is served inside the 3D-hosted experience | A maintained parallel mode would split the experience, double every acceptance surface, and invite regression to the administrative look this release replaces. Accepted consequences: the oldest supported device must hold the frame floor at the lowest tier (hard B1 gate), and a scene-layer failure leaves data safety but no product surface |
| LB-D20 | Asset sourcing unstated | **Procedural-first, self-authored only.** No third-party 3D/audio assets without an explicit license review recorded in the release manifest | Extends the zero-third-party-dependency ethos to content |
| LB-D21 | Season accents (spring sprout, summer light, autumn slip, winter pool) | **Removed from this generation by owner decision (2026-08-16).** A season derived from the calendar month asserts a hemisphere, which is a location fact the device does not hold; §9.4 forbids the environment claiming such facts. Ambience in B1–B3 therefore derives from the clock alone (§9.1). A season or hemisphere accent may return only through the future-roadmap contract that also governs weather (LB-D05, §4.4) | Discovered while implementing WP-02: for a southern-hemisphere user, month-derived seasons are simply inverted, and guessing the hemisphere from a time zone is an inference this release does not make. Dropping the accent costs one background flourish and removes an untruth |

---

## 6. Scene presentation contract

### 6.1 Authority

| Concern | Authority |
| --- | --- |
| Papers, lifecycle, Current Pick, sessions/attempts, memories | App-owned SwiftData active generation (unchanged) |
| What the scene may show | `BoxSceneSnapshot`, a pure derivation from the product snapshot plus injected clock/calendar — versioned `box-scene-v1` |
| Scene interaction outcomes | Existing application use cases through MutationArbiter; the scene forwards intents and renders persisted results |
| Presentation preferences (mode, sound, ambience, fast animations, discovery flags) | `UserDefaults`, non-authoritative, excluded from backup (baseline 9.7) |
| Assets (geometry, materials, audio) | App bundle; versioned asset manifest in the development plan |

`box-scene-v1` names the exact derivation rules in §6.2–§6.4, §8, and §10. Changing any band, threshold, or mapping requires `box-scene-v2` (or `traces-v2`) plus updated fixtures — the same discipline as the draw policy.

### 6.2 Density honesty

The visible paper stack derives from the persisted drawable count (BOX-01 definition). Bands, `n` = drawable count:

| Drawable count `n` | Visible stack instances |
| --- | --- |
| 0 | 0 (empty box; capture prompt emphasized) |
| 1–12 | exactly `n` |
| 13–48 | `12 + ⌈(n − 12) / 4⌉` (13–21) |
| 49–200 | `21 + ⌈(n − 48) / 16⌉` (22–31) |
| > 200 | 32, with a visibly pressed-full stack |

The numeric drawable count remains displayed in the Home overlay and the accessibility summary; the stack is an honest impression, never the authority.

When the drawable count exceeds the band's instance count, the visible set is an even stride across the ordered stack (§6.3) with both ends included — never its top slice. A box that is mostly long-kept therefore looks mostly sunk, and the newest paper still has a place.

### 6.3 Stable seeded layout

Each visible paper's resting transform (position jitter, rotation, slight bend) derives from a deterministic 64-bit hash of its item UUID. The same record set therefore produces the same arrangement across relaunches; membership changes move only entering/leaving papers. No unseeded randomness appears in layout, so scene derivation is unit-testable. The hash is a fixed function written for this purpose — never the standard library's per-process hasher, which would rearrange the box on every launch.

Stack order is derived too, never stored. From the bottom up: age tier first (long-kept deepest, then aged, settled, fresh on top, per §8), then `createdAt` ascending so the older paper lies deeper, with UUID byte order breaking exact ties. The order is total, and independent of the order records happen to arrive in.

### 6.4 Locked and gated states

- **Exclusive data operation in progress** (restore, erase): the scene shows a quiet closed box with a short status line; every scene-initiated mutation affordance is disabled. This visualizes the existing arbiter gate; it adds no new gating logic.
- **Unresolved Draw Attempt on activation**: the scene opens directly in the reveal focus state with the persisted paper, before root tabs — the existing global resumption gate (baseline 7.7), re-skinned. Only Accept, supported-policy Redraw, and Dismiss are offered.
- **Generation switch** (after restore/erase): the scene discards all derived state and rebuilds `BoxSceneSnapshot` from the newly active generation only.

---

## 7. Box interactions

### 7.1 Put in a paper — the lid

Trigger: tap the lid, tap the visible **放进一张 / Put in an idea** control, or long-press either for the fast path.

Normal sequence:

1. Lid opens; a blank paper rises from the box.
2. The existing capture sheet contract runs (CAP-01…CAP-08 unchanged): title focused, duration chips, optional note, inline validation.
3. On success: the paper folds, drops in with a soft landing, the lid closes. No success dialog — the box's behavior is the confirmation.
4. On failure or capacity: the paper stays hovering, the draft stays intact, the existing recoverable error/capacity copy shows (CAP-05, CAP-08). The lid never "swallows" an unsaved paper.

Fast paths: long-press opens the sheet with no lid animation; animation tiers per §13.

Share ingestion (foreground import of mailbox envelopes) plays through the **letter slot**, not the lid: the paper slides in through the slot with the source corner mark; multiple envelopes coalesce into one short sequence with a `+N` chip. Ingestion logic, idempotency, and error handling are exactly the existing Share-to-Box pipeline.

### 7.2 Draw a paper — the soft strap

The strap is the single explicit draw mechanism (concept §7.5 adopted): a short fabric pull-tab at the box's lower front, visible but small.

State machine:

```text
Idle → Grabbed (touch down on strap)
Grabbed → Tension (drag beyond slack; papers inside gather toward the mouth)
Tension → Cancelled (release below threshold; strap springs back; no product effect)
Tension → Committed (release at/after threshold cue)
Committed → SelectionPersisted (exactly one draw use case call; UI input locked)
SelectionPersisted → Revealing (paper slides out and unfolds; existing reveal contract)
```

- The threshold is communicated by a visible stretch stop plus one medium haptic; releasing earlier is always a free cancel.
- One committed pull produces exactly one selection; repeat pulls while a call is in flight are ignored.
- Persist-before-reveal (DRW-08) is untouched: the slide-out starts only after the Attempt and `lastShownAt` are persisted.
- Strap availability mirrors existing rules: with a Current Pick, the strap is stowed with the existing resolve-first explanation (DRW-11); with an Unresolved Attempt, the resumption gate owns the screen (DRW-13).
- An empty pool produces a soft, restrained box shake and the existing structured reason sheet (DRW-09, baseline 10.4 copy); the selected time is never silently relaxed.
- Exhausted session, one-candidate, unsupported-policy, and capacity-edge reveals keep their existing behavior (DRW-12/16/17); the scene only re-skins them.

A visible **抽一张 / Draw a paper** control remains on the Home overlay at all times and triggers the identical flow (§3.2 accessible equivalence).

### 7.3 Time context — the dial (`draw-dial-v1`)

The dial sits at the box's base as a small physical control with four detents plus Custom; **不确定 / Not sure** remains available as a quiet adjacent choice.

| Dial label (zh / en) | Persisted `availableTimeRaw` |
| --- | --- |
| 几分钟 / A few minutes | `up_to_10_minutes` |
| 一小时左右 / About an hour | `up_to_60_minutes` |
| 几个小时 / A few hours | `up_to_240_minutes` |
| 大半天 / Most of the day | `up_to_480_minutes` |
| 自定义 / Custom → minutes wheel | floor-snapped bucket (below) |
| 不确定 / Not sure | `not_sure` |

Custom: a minutes wheel, 10–480 in steps of 5. The snap function is `snap(m) = the largest supported bucket whose maximum ≤ m` (45 → `up_to_30_minutes`, 90 → `up_to_60_minutes`, 120 → `up_to_120_minutes`, 300 → `up_to_240_minutes`). Before drawing, the UI states the snapped truth: **将按「30 分钟内」为你筛选 / Matching papers that fit within 30 minutes.** The persisted Draw Session stores only the snapped raw value; the entered minutes are kept solely as a presentation preference for prefill.

Truth rules:

- Fit chips on a result always display the snapped bucket ("适合 30 分钟内"), which is necessarily also true for the entered minutes. A secondary line may restate the user's own input ("你大约有 45 分钟") because it restates input, not inference.
- Every Draw Session's context comes from an explicit user action that names the time: a dial tap, a Custom confirmation, or the labeled repeat control (§13). The last selection may appear pre-highlighted but never auto-commits.
- The two buckets without detents (`up_to_30_minutes`, `up_to_120_minutes`) remain first-class: reachable through Custom, unchanged in capture, storage, and weighting. If usability evidence shows frequent Custom entries clustering at 30 or 120 minutes, the detent set may change as `draw-dial-v2` without touching any persisted identifier.

The dial changes presentation only. `CandidatePoolBuilder`, `DrawSelectionPolicy`, weights, and `mvp-v1` are byte-for-byte unchanged.

### 7.4 Peek inside

Trigger: an explicit action only — the lid-open gesture on the box body, or the visible **看看盒内 / Peek inside** control.

Sequence: the lid opens, the camera rises and tilts to a top-down view (≤ 0.8 s; Reduce Motion: cross-fade). The user sees impressions, never readable content:

- quantity and stacking of papers (up to 48 impression instances; fuller sets read as a fuller stack);
- forms and origin marks (§8) and age tiers (fresh papers on top, long-kept papers sunk);
- the Current Pick clipped inside the lid when one exists;
- seams and slots that have appeared (§10).

Peek is **read-only**: no mutation is reachable from the peek surface itself. Two explicit exits lead onward:

- **整理盒子 / Tidy the Box** button → the existing Box tab (management, search, filters, full text).
- Long-press a paper impression → Box tab pre-filtered to the matching derived filter (e.g. its duration bucket or "Long kept"). Titles are never shown in peek itself.

Closing the lid returns the camera to the front idle state. Emotional peek and functional management remain two distinct layers by contract.

### 7.5 Result, lifecycle, and memories in the scene

- The drawn paper unfolds facing the camera; title, note, duration, and the fit explanation render in a SwiftUI result card above the scene (§15.3; Dynamic Type applies). Actions are the existing three: **就做这个 / Do this**, **换一张 / Draw another**, dismiss.
- Accept clips the paper under the lid's inner edge — the visible home of the Current Pick. Home overlay keeps the existing **Done / Put back** actions.
- Complete plays stamp-then-slide: a date stamp presses onto the paper, and it slides into the memory seam. The underlying transaction is the existing atomic completion (LIFE-04); the animation is presentation of a persisted result.
- Put back drops the paper back into the stack (its seeded resting place).
- Archive refolds the paper and fades it into the archive layer with the supportive line 也许现在的你已经不想做这件事了 (§17). Permanent delete keeps the existing explicit cascade confirmation (LIFE-08) with no scene shortcut.
- Memories remain the existing tab; the seam is a doorway to it, not a replacement.

### 7.6 First launch

Unchanged contract (baseline 7.1) with new skin: a clean box on an abstract backdrop, one short 放进去，抽出来 introduction, no permissions, no sample data. The first capture uses the full lid sequence once; the strap shows a one-time 拉一下，抽一张 hint after the first paper exists.

---

## 8. Paper forms and states

Forms derive **only from explicit persisted facts**. No content analysis of titles or notes ever occurs (LB-D06).

| Fact (source of truth) | Visible form |
| --- | --- |
| Origin: manual capture | Folded note strip |
| Origin: share-imported (`SourceReference` exists) | Clipping with a source corner mark; the existing deterministic host label appears in detail, unchanged |
| Duration `up_to_10/30` | Small slip |
| Duration `up_to_60/120` | Standard folded paper |
| Duration `up_to_240/480` | Double-fold, visibly weightier paper |
| Unknown duration raw (migrated data) | Neutral gray slip; excluded from every draw (DRW-14); still visible in peek and management with the existing **Duration needs updating** state |

Age tiers, derived from `createdAt` and `lastShownAt` with the injected clock:

| Tier | Rule | Expression |
| --- | --- | --- |
| Fresh | `createdAt` < 7 days | Upper stack, slight lift, crisp color |
| Settled | 7–90 days | Mid-stack, neutral |
| Aged | > 90 days | Light curl, slightly muted tone |
| Long-kept | `createdAt` ≥ 180 days AND (never shown OR `lastShownAt` ≥ 90 days) | Sunk to the bottom; feeds the B3 compartment (§10.4) |

Lifecycle expression: Active papers live in the stack; the Current Pick is clipped at the lid; Completed papers exist as stamped stubs behind the memory seam; Archived papers rest in a faded archive layer reachable through management. **None of these tiers or forms changes eligibility, weighting, or lifecycle** — `mvp-v1` remains the only selection authority, and long-kept papers keep their normal (indeed maximal-freshness) draw weight.

---

## 9. Ambient environment

The backdrop is deliberately abstract: a soft ground plane, a gently graded space boundary, and one light rig. It never becomes a room, desk, or scene to decorate.

### 9.1 Time of day

A deterministic function of the device clock drives the light rig: four anchor bands — dawn 05:00–08:00, day 08:00–17:00, dusk 17:00–20:00, night 20:00–05:00 — with smooth interpolation of direction, color temperature (≈ 2700 K–6500 K), intensity, and shadow softness. The same wall-clock time always produces the same rig (unit-testable).

Each band's anchor sits at its centre — 00:30, 06:30, 12:30, 18:30 — and the rig interpolates linearly between the two anchors surrounding the current minute, wrapping across midnight so no seam appears at any hour. The anchor values themselves are presentation tuning and sit outside `box-scene-v1`, which versions the derivation rules in §6.2–§6.4, §8, and §10; retuning the light needs no version bump, changing a band boundary does.

### 9.2 Season accents — removed from this generation

Season accents are **not part of B1–B3** (LB-D21, owner decision 2026-08-16). Deriving a season from the calendar month asserts which hemisphere the user is in, and the device holds no such fact; presenting an inverted season to a southern-hemisphere user is exactly the kind of untruth §9.4 exists to prevent. Ambience in this generation derives from the clock alone (§9.1). Nothing in the scene, the preferences, or the quality tiers refers to a season.

### 9.3 Night quietness (B3)

Between 22:00 and 05:59 local time: dimmer rig, slightly slower unfold (+0.2 s, suppressed by fast mode and Reduce Motion), softer sound variants, and the strap's small moon-knot flourish. **No announcement, no mode label, and no selection change** — a seeded regression test proves the candidate pool and weights are identical at night (LB-D12).

### 9.4 Appearance and truth

- System light/dark appearance sets the base palette; the clock rig modulates within it. Both appearances × four time bands are acceptance-checked.
- In this release the environment never claims weather, location, or any fact the device does not hold locally; real-weather ambience waits for the networked future scope (LB-D05, §4.4). The 环境随时间变化 toggle (§16.2) disables clock/season variation entirely.

---

## 10. Traces, echoes, and growth (`traces-v1`)

All items below are **derived on demand from live records** plus, where noted, one presentation preference. Restore re-derives everything; permanent deletion erases every derived trace of the deleted records automatically. Nothing here displays a count, a percentage, or a next threshold.

### 10.1 Structural growth

| Structure | Appears when (derivation) | Behavior |
| --- | --- | --- |
| Memory seam (side) | ≥ 1 Completion Memory exists | First appearance is a quiet discovery: the seam simply exists; opening it shows the line 完成的纸条会收进这里 once. It opens the Memories surface |
| Letter slot | ≥ 1 live item with a `SourceReference`, or during the first foreground ingestion | Share-imported papers animate in through it (§7.1); it is the visual home of the existing mailbox, never a user-managed inbox |
| Bottom compartment (B3) | The long-kept set (§8) is non-empty | A faint seam appears in peek; first non-empty transition shows 盒底好像压着一些很久以前的纸条 once. Tapping opens the Box tab pre-filtered to **很久以前 / Long kept**. The compartment is a lens: papers in it remain fully eligible and unchanged |

### 10.2 Wear and keepsake traces

| Trace | Derivation | Expression |
| --- | --- | --- |
| First-completion stamp | Memories ≥ 1 | A small dateless stamp mark inside the lid |
| Wear tiers | Memories ≥ 5 / ≥ 20 / ≥ 50 | Edge softening, faint pressed marks, a subtle color settle — three fixed tiers, no numbers anywhere |
| Import postmark | ≥ 1 Memory whose source item has a `SourceReference` | A tiny postmark near the letter slot |
| Completion stub stamps | Each Memory | Its stub in the seam carries the completion date stamp and, for imported sources, the source label — completion-truth copy only (LB-D17) |
| Micro-mementos (B3) | First Memory; first imported-source Memory; first Memory whose `completedAt` falls 22:00–05:59 in the current device calendar; Memories ≥ 10 | At most 4 tiny abstract objects at fixed anchor points near the box; no labels, gallery, or list (LB-D14) |

### 10.3 Time echoes

| Echo | Derivation | Expression |
| --- | --- | --- |
| Waited-days line (B2) | On reveal, `shownAt − createdAt` ≥ 180 days | One line under the unfolded paper: 它在盒子里等了你 N 天 (exact floor of days). VoiceOver reads it after the result is stable |
| Anniversary surface (B3) | A live paper's `createdAt` matches today's month-day in the device calendar and is ≥ 1 year old | At most once per calendar day (last-shown day stored as a presentation preference), the oldest qualifying paper briefly surfaces in the idle scene with 一年前的今天，你把这件事放进了盒子. Non-blocking; tap opens its ordinary detail; it does not alter eligibility or weights |

### 10.4 Hidden quick gestures (B3)

Each gesture duplicates an existing visible control, appears without any tutorial, and shows a one-line hint the first time it is triggered (one presentation flag each):

| Gesture | Effect | Visible equivalent |
| --- | --- | --- |
| Double-tap the box | Draw immediately using the labeled last-time context | The repeat-draw control (§13) |
| Long-press the strap | Same as above | Same |
| Swipe down on the lid while a Current Pick exists | Put back (with the existing confirmation) | The Put back button |

Discovery hints are single, quiet lines (e.g. 原来双击盒子也可以抽一张); they are never tasks, checklists, or badges. Shake remains deferred (LB-D11).

### 10.5 Honesty rules

- A trace or echo is shown only when its derivation predicate is currently true against live records (user-visible truth).
- Trace derivations read the same repository snapshot as the scene; they never maintain private tallies, so deleted history cannot leave ghosts (SCN-04).
- Timezone: month-day and night-window derivations use the current device calendar; a timezone change may shift which day an echo appears but never alters any persisted instant (baseline 12.3).

---

## 11. Motion contract

### 11.1 Physical consistency

One rule set applies everywhere: papers respond to the lid opening; the strap's tension gathers papers toward the mouth; dropped papers land with soft gravity and settle into their seeded spots; drawn papers slide with slight inertia; put-back papers refold before dropping. Consistency is the quality bar — no one-off flourishes that break the material logic.

### 11.2 Duration tiers

| Sequence | Full (first-time) | Standard | Minimal (burst / fast mode) |
| --- | --- | --- | --- |
| Capture drop | ≤ 1.2 s | ≤ 0.5 s | ≤ 0.25 s, coalesced with a count chip |
| Reveal (unchanged baseline 6.4) | 0.6–1.0 s | 0.6–1.0 s | ≤ 0.35 s cross-fade |
| Peek camera | ≤ 0.8 s | ≤ 0.8 s | cross-fade |
| Complete stamp-and-slide | ≤ 1.2 s | ≤ 0.7 s | ≤ 0.3 s |

Tier selection is automatic: the first 3 occurrences of a sequence ever play full; a repeat within 30 seconds plays minimal; 快速动画 forces minimal everywhere. A tap anywhere skips any presentation-only remainder instantly.

### 11.3 Hard rules

- Animation never selects, delays persistence of, or blocks resolution of any result (baseline 11.2 verbatim).
- Reduce Motion replaces every camera move, parallax, spring bounce, and stack shuffle with cross-fades or static states; finger-driven strap drag remains (user-controlled motion), with a non-drag alternative always visible. No flashing, no 3D-dependence for meaning.
- No confetti, coins, fireworks, celebration bursts, or screen-filling effects — completion feedback is the object's own behavior plus at most one quiet line.

---

## 12. Sound and haptics

### 12.1 Sound registry

Bundled, self-authored short samples only (LB-D20); total audio assets ≤ 1.5 MB.

| Event | Sample character |
| --- | --- |
| Lid open / close | Soft wooden tick |
| Paper drop-in | Muted paper tap |
| Strap stretch / release | Fabric slide, soft snap |
| Paper slide-out | Paper friction |
| Stamp press | Soft felt stamp |
| Seam / slot first discovery | Single warm tone |

Rules: effects respect the hardware silent switch, use a mix-with-others ambient audio session, and never interrupt or duck other audio. No rain, weather, mechanical-gear, coin, or slot-machine sounds exist in the bundle (LB-D05, baseline 11.1). Master 音效 toggle in Settings, default on. The Share Extension ships no audio.

### 12.2 Haptics registry

All behind the existing haptics toggle; each haptic pairs with a visible change and never carries meaning alone (baseline 11.3):

| Event | Feedback |
| --- | --- |
| Dial detent change | Light selection tick |
| Strap threshold reached | One medium impact |
| Strap release / paper out | Light impact (the existing reveal haptic) |
| Capture drop landing | Soft tap |
| Completion | Existing success feedback |
| First discovery of a seam/slot | A gentle, distinct double-tap pattern |

---

## 13. Efficiency and fast paths

Lived-in must never mean slower. Contracts:

- Home overlay controls (capture, draw, peek, settings) are interactive ≤ 400 ms after launch; the 3D scene loads asynchronously behind a calm placeholder and attaches when ready.
- Long-press lid or capture control → capture sheet with zero preamble animation.
- **再抽一张（上次：一小时左右）/ Draw again (last time: about an hour)** — a visible repeat control whose label names the reused context, satisfying the explicit-context rule while removing the dial round-trip. The hidden gestures in §10.4 map to this same control.
- Animation tiers (§11.2) engage automatically; 快速动画 forces minimal tiers globally.
- Share-import bursts coalesce: per-item visual ≤ 0.25 s and a single `+N` chip for N envelopes in one ingestion pass.
- The scene adds **zero** new confirmation steps to any existing flow.
- The slow path stays available by choice: with time on their hands, the user gets the full lid, strap, and peek experience.

---

## 14. Accessibility and in-scene degradation

### 14.1 Accessibility contracts

- The 3D scene is exposed to assistive technologies as one summary element — "盒子里有 12 张可抽的纸条…" including drawable count, Current Pick presence, and memory count — plus custom actions: 放进一张、抽一张、看看盒内、打开当前纸条.
- Every 3D gesture has a visible control equivalent (§3.2); Voice Control names cover all of them.
- Essential text is never rendered only as 3D content; titles, notes, chips, echoes, and errors live in SwiftUI overlays above the scene (§15.3) with full Dynamic Type up to accessibility sizes, with scrims guaranteeing contrast over the animated backdrop.
- VoiceOver announces a draw result only after content is stable (unchanged); peek announces the impression summary, never paper text.
- Automated accessibility audits extend to the scene Home, peek, reveal, and the recovery surface.

### 14.2 In-scene quality tiers and the recovery surface

No 2D product mode exists (LB-D19). The scene degrades within itself along a fixed, automatic ladder; every tier renders the same box, the same interactions, and the same truth — a tier never removes a function or a control.

| Tier | Presentation | Entered when |
| --- | --- | --- |
| Q0 — Full | All effects: soft shadows, full instance caps | Default on capable devices |
| Q1 — Reduced | Soft shadows off; simplified materials; instance caps halved | One frame-floor breach; thermal `.serious`; Low Power Mode |
| Q2 — Minimal | Flat lighting, static camera between states, instance cap 12, motion reduced to functional transitions | A further breach while at Q1; thermal `.critical`; the oldest-device default when B1 evidence requires it |

Tier changes are automatic, lossless, reversible, and unannounced; no user-facing mode switch exists. Reduce Motion applies orthogonally at every tier (§11.3).

**Recovery surface:** if RealityKit initialization or a required asset fails outright, the app presents a minimal recovery screen — a plain explanation, a retry action, and full access to Settings (status, export, restore, erase). It is a data-safety surface, not a product surface: capture and draw wait for the scene. This accepted consequence of the single-surface decision is recorded in LB-D19.

---

## 15. Rendering technical foundation

### 15.1 Stack

RealityKit `RealityView` hosted in SwiftUI (iOS 18 API surface), per [ADR 0004](../adr/0004-realitykit-scene-presentation.md). No third-party engine, no SceneKit, no custom Metal pipeline for v1. The Share Extension links none of this.

### 15.2 Entity architecture

```text
BoxSceneRoot
├── Environment      (light rig: one directional + image-based light,
│                     ground plane, graded backdrop)
├── Box              (Body, LidPivot → Lid, StrapAnchor → Strap,
│                     MemorySeam, LetterSlot, BottomSeam)
├── PaperStack       (≤32 idle / ≤48 peek instanced paper entities,
│                     seeded transforms per §6.3)
├── FocusPaper       (reveal/unfold rig; its result card is a SwiftUI
│                     overlay above the scene, not an in-scene attachment)
└── CameraRig        (FrontIdle | CaptureLid | Peek | RevealFocus | SlotFocus)
```

Data flow is one-directional: product snapshot → pure `BoxSceneStateReducer` (`box-scene-v1`) → `BoxSceneSnapshot` → RealityKit applies diffs; gestures → intents → existing use cases → new persisted snapshot. The reducer is plain Swift with injected clock/calendar and is unit-tested against fixtures, including the frozen `performance-v1` dataset.

### 15.3 Interaction plumbing

- Strap, lid, dial, and peek gestures are SwiftUI/RealityKit gesture recognizers resolving to entity hits; thresholds and cancels per §7.2.
- Text-bearing UI (capture sheet, result card, reason sheets) is SwiftUI composited **above** the `RealityView` in the same container, so localization, Dynamic Type, and accessibility behave exactly as today. **Platform constraint (WP-01 spike, 2026-08-16):** iOS has no `RealityView` attachment API — `attachments:` and `ViewAttachmentComponent` are visionOS-only in the iOS 26.5 SDK and absent at the iOS 18.0 floor — so scene-anchored text is not an option and every earlier reference to "attachments" in this document means an overlay. A card that must track a moving entity projects the entity's position into view space and positions the overlay itself.
- All entity mutation happens on the main actor; the reducer's derivation pass is O(n) over the product snapshot with a measured budget (§15.5).

### 15.4 Assets

- **B1 is procedural:** parametric rounded-box geometry, simple strap/seam meshes, PBR materials (soft wood/ceramic/fabric families per concept §4.2 — warm, matte, no exposed machinery). No binary assets beyond audio.
- Authored USDZ/Reality Composer Pro content may replace procedural parts later (candidate table): self-authored only, ≤ 8 MB total, listed with SHA-256 in the plan's asset manifest, license-reviewed in the release manifest.
- Audio per §12.1. Total new bundle weight for B1 ≤ 10 MB.

### 15.5 Performance envelope

Reference devices: newest iPhone and the oldest iPhone that runs iOS 18 (A12 class).

| Gate | Budget |
| --- | --- |
| Overlay interactive after cold launch | ≤ 400 ms (scene loads async) |
| Scene first frame | ≤ 1.5 s (newest) / ≤ 2.5 s (oldest reference) |
| Sustained frame rate | 60 fps target (ProMotion devices may render higher); ≥ 30 fps floor on the oldest reference device at its assigned quality tier — a hard B1 exit gate |
| `BoxSceneStateReducer` full pass on `performance-v1` (5,000 items) | ≤ 50 ms |
| Scene incremental memory | ≤ 150 MB over the pre-scene MVP app baseline |
| Idle behavior | Ambient animation pauses after 10 s without interaction; fully paused in background |
| Thermal ladder | `.serious`: drop to Q1; `.critical`: drop to Q2 for the session (§14.2) |
| Cold launch to interactive | ≤ MVP baseline + 10 % |

Evidence comes from Instruments runs on both reference devices, recorded per the release checklist. Signposts and render diagnostics carry codes and durations only — never titles, notes, or UUIDs (DAT-05).

### 15.6 Failure containment

Any RealityKit initialization or asset failure is caught at the scene boundary and presents the §14.2 recovery surface: retry plus full data-safety controls (status, export, restore, erase). Product data paths have no dependency on the scene layer, so a scene failure can never corrupt, hide, or trap data — but by owner decision there is no parallel product UI behind it; capture and draw wait for the scene. Runtime frame or thermal pressure never reaches this surface: it is absorbed by the in-scene tier ladder.

---

## 16. Data, preferences, and compatibility

### 16.1 Persistence posture

The feature, as specified, needs none of the following to change. Pre-release, this is a design fact rather than a compatibility constraint (§4.4): when a feature genuinely needs persisted changes, identifiers version forward through the normal docs-first discipline instead of silent drift.

| Contract | Status for this release |
| --- | --- |
| SwiftData schema | v2 — this feature needs no new record type or field |
| Backup format | v2 — scene/trace state is never exported because none exists |
| Selection policy | `mvp-v1` — byte-identical filtering and weighting |
| Draw journal retention | `draw-journal-v1`, unchanged |
| Share mailbox, envelopes, ingestion | Unchanged ([Share to Box](share-to-box.md)) |
| Restore / erase | Unchanged generation-switch semantics; the scene rebuilds from the newly active generation (§6.4) |
| Deletion closure | Unchanged and automatically extended to all derived presentation (§10.5) |

### 16.2 New presentation preferences

`UserDefaults`, non-authoritative, excluded from backup/restore (baseline 9.7). Loss on reinstall means discovery hints may show once more — accepted.

| Key | Type / default | Meaning |
| --- | --- | --- |
| `presentation.soundEffectsEnabled` | Bool, `true` | §12.1 |
| `presentation.ambientChangesEnabled` | Bool, `true` | §9.1 clock variation |
| `presentation.fastAnimations` | Bool, `false` | §11.2 minimal tiers |
| `animation.<sequence>.completedCount` / `animation.<sequence>.lastCompletedAt` | Int / Date? | Non-authoritative §11.2 first-three and 30-second repeat history; `<sequence>` is a stable presentation identifier such as `capture-drop` |
| `draw.lastDialDetent` / `draw.lastCustomMinutes` | raw string / Int? | Prefill and the labeled repeat control (§13) |
| `discovery.<trace-id>` | Bool flags | One-time hint bookkeeping (§10) |
| `echo.lastAnniversaryDay` | `yyyy-MM-dd` string | At-most-daily anniversary echo (§10.3) |

Settings additions: 音效, 环境随时间变化, 快速动画. There is no scene-mode setting (LB-D19); quality tiers are automatic. The existing haptics toggle, data controls, and app-status panel are unchanged; no debug switches ship (baseline 6.7).

### 16.3 New derived Box filter

**很久以前 / Long kept** — a presentation filter over persisted fields per the §8 long-kept rule, consistent with BOX-03 (filters derive from persisted fields). It changes browsing only, never eligibility.

---

## 17. Localization and copy

All new strings ship in Simplified Chinese and English through the existing String Catalog. Tone rules from baseline 11.4 apply; the avoid-list extends with: 解锁, 成就, 等级, 积分, 收集进度, 里程碑, and any "X more to go" construction.

| Concept | Simplified Chinese | English |
| --- | --- | --- |
| Dial detents | 几分钟 / 一小时左右 / 几个小时 / 大半天 | A few minutes / About an hour / A few hours / Most of the day |
| Custom entry | 自定义 · 你大约有多少分钟？ | Custom · About how many minutes do you have? |
| Snap statement | 将按「30 分钟内」为你筛选 | Matching papers that fit within 30 minutes |
| Strap hint (once) | 拉一下，抽一张 | Pull to draw a paper |
| Peek | 看看盒内 | Peek inside |
| Tidy entry | 整理盒子 | Tidy the Box |
| Repeat draw | 再抽一张（上次：一小时左右） | Draw again (last: about an hour) |
| Memory seam discovery | 完成的纸条会收进这里 | Finished papers rest here |
| Compartment discovery | 盒底好像压着一些很久以前的纸条。 | Some papers have been resting at the bottom for a while. |
| Long-kept filter | 很久以前 | Long kept |
| Waited-days line | 它在盒子里等了你 N 天。 | It waited N days for you. |
| Anniversary line | 一年前的今天，你把这件事放进了盒子。 | A year ago today, you put this into the box. |
| Archive line | 也许现在的你已经不想做这件事了。收进存档，随时可以拿回来。 | Maybe this isn't you anymore. It will rest in the archive — bring it back anytime. |
| Gesture hint (example) | 原来双击盒子也可以抽一张。 | So a double tap draws a paper, too. |
| Settings | 音效 / 环境随时间变化 / 快速动画 | Sound effects / Ambient changes over time / Quick animations |
| Data-operation lock | 正在整理数据… | Tidying data… |

The waited-days and anniversary lines render a computed number/date from persisted timestamps; they are shown only when the derivation predicate holds (§10.5).

---

## 18. Functional requirements and acceptance rules

### 18.1 Scene truth and derivation

| ID | Requirement | Acceptance rule |
| --- | --- | --- |
| SCN-01 | Scene state derives from persisted truth | `BoxSceneSnapshot` is built only from repository state, injected clock/calendar, and §16.2 preferences; the scene layer stores no product fact |
| SCN-02 | Density honesty | The visible stack follows the §6.2 band table exactly; the numeric drawable count remains displayed and authoritative |
| SCN-03 | Stable layout | An identical record set produces identical paper transforms across relaunches (seeded per §6.3) |
| SCN-04 | Deletion closure extends to presentation | After permanent deletion, no trace, memento, echo, stub, or compartment entry derived from the deleted records can appear |
| SCN-05 | Generation rebuild | After restore or erase, the scene renders only from the newly active generation |
| SCN-06 | No second history store | Traces and echoes are computed on demand; no new authoritative record or tally exists anywhere |
| SCN-07 | Operation lock visual | During an exclusive data operation, the scene shows the locked state and every scene-initiated mutation affordance is disabled |
| SCN-08 | Resumption gate unchanged | An Unresolved Attempt presents the reveal focus before root tabs; only Accept, supported-policy Redraw, and Dismiss are offered |

### 18.2 Lid and capture

| ID | Requirement | Acceptance rule |
| --- | --- | --- |
| LID-01 | Lid opens capture | Lid tap and the visible capture control open the identical capture sheet; CAP-01…CAP-08 pass unchanged through both entries |
| LID-02 | Focus preserved | The rising paper presents the title field already focused |
| LID-03 | Failure keeps the draft | A persistence/validation/capacity failure leaves the paper hovering and the draft intact with existing recoverable copy |
| LID-04 | Fast path | Long-press opens the sheet with no preamble animation |
| LID-05 | Import through the slot | Foreground ingestion animates via the letter slot; N envelopes coalesce to one sequence with a `+N` chip; no success dialog |
| LID-06 | No swallow | The lid never closes over an unsaved draft |

### 18.3 Strap and draw

| ID | Requirement | Acceptance rule |
| --- | --- | --- |
| PULL-01 | Cancellable tension | Release below the threshold cancels with zero product effect; the threshold has a visible stop and one haptic |
| PULL-02 | Exactly one selection | A committed pull issues exactly one draw use case call; further input is ignored until the persisted outcome returns |
| PULL-03 | Persist before reveal | The slide-out begins only after the Attempt and `lastShownAt` are persisted (DRW-08); forced termination during the animation resumes the same result |
| PULL-04 | Empty pool honesty | An empty pool produces the soft shake plus the existing structured reasons; the selected time is never silently relaxed |
| PULL-05 | Availability mirrors rules | Current Pick stows the strap with the resolve-first explanation; an Unresolved Attempt yields to the resumption gate |
| PULL-06 | Existing outcomes | Accept, redraw, dismiss, exhausted-session, single-candidate, unsupported-policy, and capacity-edge behaviors are the existing use cases re-skinned; all DRW rules pass unchanged |
| PULL-07 | One draw mode | No alternative draw mode is reachable anywhere in the build |

### 18.4 Dial and time context

| ID | Requirement | Acceptance rule |
| --- | --- | --- |
| DIAL-01 | Exact mapping | The four detents, Custom, and Not sure map to existing raw identifiers exactly per §7.3; no new persisted context value exists |
| DIAL-02 | Custom snap | Minutes 10–480 step 5; snap = largest bucket ≤ minutes; the snapped bucket is stated before the draw |
| DIAL-03 | Chip truth | Fit chips display the snapped bucket; any minutes line restates user input only |
| DIAL-04 | Explicit context per session | Every Draw Session's context comes from a user action that names the time (detent tap, Custom confirm, or the labeled repeat control); prefill never auto-commits |
| DIAL-05 | Buckets remain first-class | `up_to_30_minutes` and `up_to_120_minutes` stay reachable via Custom and unchanged in capture, storage, and weighting |
| DIAL-06 | Accessible control | The dial is an adjustable accessibility element with spoken values; detent haptics are light |

### 18.5 Peek

| ID | Requirement | Acceptance rule |
| --- | --- | --- |
| PEEK-01 | Explicit entry | Peek starts only from a user action; nothing auto-opens the lid |
| PEEK-02 | Camera contract | Top-down move ≤ 0.8 s; Reduce Motion uses a cross-fade; closing returns to the front state |
| PEEK-03 | Impressions only | No readable title or note text renders in peek; forms, ages, origins, and density are the only information |
| PEEK-04 | Bounded impressions | ≤ 48 instances; overflow reads as a fuller stack; the accessibility summary speaks the real counts |
| PEEK-05 | Explicit management entry | 整理盒子 opens the Box tab; long-press an impression opens Box pre-filtered; neither is hidden-only |
| PEEK-06 | Read-only surface | No mutation is reachable from peek itself |

### 18.6 Paper forms and lifecycle presentation

| ID | Requirement | Acceptance rule |
| --- | --- | --- |
| PAPR-01 | Explicit-fact forms | Form and tint derive only from origin, duration bucket, age tier, and lifecycle; no title/note analysis code path exists |
| PAPR-02 | Source marks | Imported papers show the corner mark and reuse the existing deterministic host label |
| PAPR-03 | Age tiers exact | 7/90/180-day thresholds per §8 with the injected clock; a future `createdAt` clamps to fresh |
| PAPR-04 | Unsupported duration visible | Unknown-duration papers render as neutral slips, appear in peek/management, and stay excluded from every draw |
| PAPR-05 | Current Pick at the lid | The accepted paper is clipped at the lid; Done/Put back/Archive/Delete resolve it exactly as today |
| PAPR-06 | Completion sequence | Stamp-and-slide presents the already-committed atomic completion (LIFE-04); interruption mid-animation loses nothing |
| PAPR-07 | Gentle archive | Archive refolds and fades with the §17 line; permanent delete keeps the full cascade confirmation with no scene shortcut |

### 18.7 Traces, echoes, and growth

| ID | Requirement | Acceptance rule |
| --- | --- | --- |
| TRC-01 | Derived, restorable, deletable | Every §10 item derives from live records (`traces-v1`); restore re-derives all of them; SCN-04 holds for each |
| TRC-02 | No progress framing | No trace surface shows counts, percentages, thresholds, or remaining-N language anywhere |
| TRC-03 | Waited-days truth | The line appears only when `shownAt − createdAt` ≥ 180 days and shows the exact floor of days |
| TRC-04 | Anniversary bounds | Same month-day ≥ 1 year, at most once per calendar day, deterministic oldest pick, non-blocking, no eligibility change |
| TRC-05 | Night is presentation-only | Between 22:00–05:59 the pool and weights are proven identical by a seeded regression test |
| TRC-06 | Quiet discovery | Each discovery hint is one line, shown once per preference flag; re-showing after reinstall is acceptable; hints are never tasks |
| TRC-07 | No collection surface | Mementos have no gallery, names, or completion state; at most 4 render at fixed anchors |
| TRC-08 | Structural growth honesty | Seam, slot, and compartment appear exactly when their §10.1 predicates hold and disappear if the predicate becomes false |
| TRC-09 | Compartment is a lens | Long-kept papers keep their normal eligibility and weights; the filter changes browsing only |
| TRC-10 | Hidden gestures duplicate controls | Every §10.4 gesture has the named visible equivalent, and that equivalent remains functional at every quality tier |

### 18.8 Motion, sound, and haptics

| ID | Requirement | Acceptance rule |
| --- | --- | --- |
| MOT-01 | Tier budgets | Every §11.2 sequence meets its tier budget; tiers switch automatically per the stated rules |
| MOT-02 | Animation subordinate to truth | No animation selects, delays persistence of, or blocks resolution of a result; a tap skips any presentation-only remainder |
| MOT-03 | Reduce Motion complete | With Reduce Motion, no camera dolly, parallax, spring bounce, or auto stack shuffle plays; cross-fade equivalents preserve every state truth |
| MOT-04 | No celebration inflation | No confetti, coins, badges, or screen-filling effects exist in the build |
| SND-01 | Bounded, honest audio | Only the §12.1 registry ships; ≤ 1.5 MB; no weather, gear, or slot-machine sounds; silent switch and mix-with-others respected |
| SND-02 | Toggles | 音效 and haptics toggles silence their channels completely; no haptic or sound carries meaning alone |
| SND-03 | Extension silence | The Share Extension bundles no audio and links no scene code |

### 18.9 Efficiency

| ID | Requirement | Acceptance rule |
| --- | --- | --- |
| FST-01 | Instant controls | Overlay controls are interactive ≤ 400 ms after cold launch while the scene loads asynchronously |
| FST-02 | Fast capture | Long-press capture path reaches a focused title field with no preamble; capture add-to-visible-count meets the MVP timing envelope |
| FST-03 | Labeled repeat draw | The repeat control names the reused context and satisfies DIAL-04 |
| FST-04 | Zero new confirmations | No flow gains a confirmation step relative to the MVP |
| FST-05 | Burst coalescing | N imports in one pass render ≤ 0.25 s per item with a single `+N` chip |

### 18.10 In-scene degradation

| ID | Requirement | Acceptance rule |
| --- | --- | --- |
| DGR-01 | Tier ladder honesty | Q0/Q1/Q2 render the same box, interactions, controls, and truth; no tier removes a function, a control, or a state expression |
| DGR-02 | Automatic tiers | Frame-floor breaches, thermal `.serious`/`.critical`, and Low Power Mode move tiers exactly per §14.2, automatically and reversibly; no user-facing mode switch exists in the build |
| DGR-03 | Oldest-device gate | The oldest reference device completes the full journey at ≥ 30 fps on its assigned tier — a hard B1 exit blocker |
| DGR-04 | Recovery surface | Scene init/asset failure presents the recovery surface with retry and full Settings data controls; data access is never blocked, and no parallel product UI exists (§15.6) |
| DGR-05 | Lossless adaptation | Tier changes and recovery retries finish any in-flight transaction and lose no state |

### 18.11 Performance

| ID | Requirement | Acceptance rule |
| --- | --- | --- |
| PRF-01 | Frame budgets | §15.5 frame-rate targets hold on both reference devices in Instruments evidence |
| PRF-02 | Fixture derivation budget | Reducer full pass ≤ 50 ms on `performance-v1`; memory delta ≤ 150 MB |
| PRF-03 | Idle and background quiet | Ambient pauses after 10 s idle; background rendering is fully paused |
| PRF-04 | Thermal ladder | `.serious` and `.critical` behaviors observable and reversible |
| PRF-05 | Launch protection | Cold launch to interactive stays within MVP baseline + 10 % |

### 18.12 Accessibility

| ID | Requirement | Acceptance rule |
| --- | --- | --- |
| AXS-01 | Scene summary element | One element summarizes box state and exposes the §14.1 custom actions |
| AXS-02 | Control equivalence audit | A written audit maps every 3D gesture to its visible control; all pass VoiceOver and Voice Control journeys |
| AXS-03 | Text never 3D-only | All essential text renders in SwiftUI with Dynamic Type through accessibility sizes; contrast holds over the animated backdrop via scrims |
| AXS-04 | Stable announcements | Reveal, echo lines, and discovery hints are announced only after content is stable |
| AXS-05 | Audited screens | Automated accessibility audits cover scene Home, peek, reveal, and the recovery surface in both languages and appearances |

---

## 19. Test and evidence strategy

Evidence levels stay separated exactly as in the baseline and Share to Box: source/test proof never claims runtime, device, or packaged truth.

### 19.1 Pure and application tests

- `BoxSceneStateReducer` fixtures: density bands (§6.2 boundary values), seeded layout stability, age tiers at 7/90/180-day boundaries, long-kept set, trace/echo predicates (including deletion and restore re-derivation), lock and resumption states.
- `draw-dial-v1`: detent mapping totality, snap-function boundaries (10, 29/30, 45, 90, 119/120, 300, 480), chip truth strings.
- Night regression: identical seeded pool and weights at 03:00 and 15:00 (TRC-05).
- Time-of-day light driver: fixed clock inputs → exact rig parameters.
- Existing domain/application suites run unchanged — any diff in their results is a defect of this feature.

### 19.2 Integration and UI tests

- Persist-before-reveal under forced termination with the strap flow (existing DRW-08 test extended to the new entry point).
- Capture failure/capacity keeps the hovering draft (LID-03/06).
- Import coalescing with a multi-envelope mailbox fixture (LID-05, FST-05).
- Single-surface journey: the scripted MVP journey (capture → relaunch → draw → accept → complete → memories) passes in the scene at Q0 and at forced Q2, in both languages, light/dark, and with Reduce Motion.
- Recovery surface: an injected scene-initialization failure presents the recovery surface with a working export path.
- Automated accessibility audits per AXS-05; overlay-interactive launch timing per FST-01.

### 19.3 Device and manual evidence

- Instruments frame/memory/thermal runs on both reference devices (PRF gates).
- Manual VoiceOver, Voice Control, largest Dynamic Type, and Reduce Motion journeys through lid, strap, dial, peek, and seams.
- Airplane-mode full journey (scene assets are bundled; nothing degrades offline).
- Photosensitivity and motion-comfort review of all camera moves.

### 19.4 Honesty audits

- A static audit greps the scene/audio/diagnostics code paths for content logging (extends the existing content-log audit).
- The quality-tier behavior matrix (DGR-01/02/03) and gesture-equivalence audit (AXS-02) are written artifacts attached to the readiness ledger.

---

## 20. Delivery plan

Milestone details, work packages, and agent execution rules live in the [development plan](../plans/lived-in-box-development-plan.md). Status is tracked only in the [readiness ledger](../release/lived-in-box-readiness.md).

### B0 — Contract freeze

Deliver: this specification; ADR 0004; the development plan; the readiness ledger; baseline and README updates. Exit: **complete — the full decision ledger (LB-D01…D20) is owner-approved as of 2026-08-16**, including LB-D01 (naming), LB-D02 (dial mapping), LB-D07 (letter slot), LB-D19 (sole 3D surface), the LB-D04/D05/D06 future-roadmap deferrals, and the §4.4 pre-release persistence posture. No implementation claim; B1 may begin per the development plan.

### B1 — Tangible core

Deliver §4.1 B1 scope. Exit evidence: all SCN/LID/PULL/DIAL/PEEK (v1)/MOT/SND/FST/DGR/PRF/AXS rules for B1 surfaces green; full MVP + Share ingestion regression; Instruments runs on both reference devices with the oldest-device tier gate met; tier matrix and gesture audits attached; owner experience review of feel and art direction (procedural box).

### B2 — States and traces

Deliver §4.1 B2 scope. Exit evidence: PAPR and TRC (B2 subset) rules green; deletion/restore re-derivation tests; completion and import sequences verified on device; copy review in both languages.

### B3 — Growth and echoes

Deliver §4.1 B3 scope. Exit evidence: remaining TRC/GRW rules green; night regression; anniversary once-per-day proof; discovery-hint one-time proof; final accessibility and performance re-runs; release-manifest integration.

Each phase lands behind the previous phase's acceptance; no phase ships partial acceptance rows as implied truth.

---

## 21. Risks and mitigations

| Risk | Mitigation |
| --- | --- |
| Oldest-device performance (A12) misses the frame floor | Instanced papers with hard caps; procedural low-poly assets; the Q0→Q2 tier ladder is shipped and tested; if Q2 still cannot hold the floor, the device-support decision returns to the owner explicitly — never a hidden fallback mode |
| Procedural art fails the warmth bar | Owner review gates at B1; authored self-made USDZ is a planned, budgeted upgrade path (candidate table) |
| 3D novelty decays into friction | Fast paths and animation-tier automation are acceptance rules (FST); the slow experience is always optional, never mandatory |
| Scope creep toward gamification | §3.2 guardrails plus TRC-02/07 and MOT-04 are hard acceptance rules; the decision ledger records the permanent rejections |
| Gesture semantics collide (lid open vs peek vs capture) | Distinct zones and directions specified in §7; usability check at B1 exit; visible controls always disambiguate |
| RealityKit-on-iOS API surprises (new `RealityView` surface) | B1 starts with a rendering spike work package; §15.6 keeps data safe under any scene failure |
| Single-surface decision concentrates availability risk in the scene layer | Accepted in LB-D19: the recovery surface guarantees data safety; the WP-01 spike and the hard oldest-device gate front-load the risk before B2/B3 invest further |
| Motion discomfort | Conservative camera moves, short durations, Reduce Motion completeness (MOT-03), comfort review (§19.3) |
| Battery/thermal cost | Idle pause, background pause, thermal ladder, and Instruments gates (PRF-03/04) |
| Asset licensing drift | LB-D20: self-authored only; manifest lists every asset with hash and provenance |

---

## 22. Definition of Done

Lived-in Box is done for a given phase only when:

1. Every acceptance rule scoped to that phase passes with retained evidence at the correct level (source, simulator, device), and no existing MVP or Share-to-Box rule regressed.
2. The scene renders only derived truth: the SCN and TRC honesty rules pass, including deletion-closure and restore re-derivation tests.
3. The quality-tier ladder passes its behavior matrix (DGR-01/02/03), the recovery surface proves data safety under injected failure, and every 3D gesture's visible equivalent passes VoiceOver and Voice Control journeys.
4. Performance gates hold on both reference devices with retained Instruments evidence.
5. `make audit`, `make test`, and `make ci-check` pass; the content-log audit covers scene, audio, and diagnostics code.
6. All new copy ships in both languages, reviewed against the tone rules and avoid-list.
7. The readiness ledger rows for the phase cite immutable evidence; no row claims device or packaged truth from simulator runs.
8. The owner has reviewed the experience against §1.1 and signed the phase exit in the readiness ledger.

---

## 23. Apple platform references

Recorded 2026-08-16; verify against current documentation before each phase begins.

- RealityView (RealityKit, SwiftUI hosting on iOS 18+): <https://developer.apple.com/documentation/realitykit/realityview>
- RealityKit: <https://developer.apple.com/documentation/realitykit>
- RealityView attachments (**visionOS only** — unavailable on iOS, see §15.3): <https://developer.apple.com/documentation/realitykit/realityviewattachments>
- Reality Composer Pro packages: <https://developer.apple.com/documentation/realitycomposerpro>
- Core Haptics: <https://developer.apple.com/documentation/corehaptics>
- AVFAudio session categories (ambient, mix with others): <https://developer.apple.com/documentation/avfaudio/avaudiosession>
- Accessibility for SwiftUI (custom actions, Dynamic Type): <https://developer.apple.com/documentation/swiftui/accessibility-fundamentals>
- Reduce Motion guidance (HIG — Motion): <https://developer.apple.com/design/human-interface-guidelines/motion>
- ProcessInfo thermal state: <https://developer.apple.com/documentation/foundation/processinfo/thermalstate>

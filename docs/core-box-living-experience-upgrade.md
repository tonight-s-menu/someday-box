# Core Box Living Experience Upgrade

## Product requirements, functional translation, RealityKit scene contract, and delivery plan

| Field | Decision |
| --- | --- |
| Document status | vNext product and engineering contract; documentation complete, implementation and release evidence not claimed |
| Product | `someday-box` / `改天盲盒` |
| Concept-name note | `有空箱` is the name of the supplied design concept, not an approved product rename |
| Parent product contract | [MVP product requirements and technical foundation](product-requirements-and-technical-foundation.md) |
| Related feature contract | [Share to Box](features/share-to-box.md) |
| Architecture decision | [ADR 0004: RealityKit core-box presentation](adr/0004-realitykit-core-box-presentation.md) |
| Primary platform | iPhone, portrait-first, iOS 18.0 or later |
| Primary presentation | SwiftUI semantic interface with an inline RealityKit `RealityView` using a virtual camera |
| Supported presentation | Full 3D, Lite 3D, and SwiftUI 2D renderer tiers; Normal, Quick, and Reduce Motion variants preserve functional parity |
| Runtime boundary | Fully on-device; no account, server, CloudKit, analytics, ads, remote asset, weather service, or LLM |
| Languages | Simplified Chinese and English |
| Last reviewed | 2026-07-19 |

This document translates the supplied “core box with a lived-in feeling” concept into a bounded development contract for the existing, functional iOS app. It does not replace the product’s domain, persistence, privacy, recovery, or release-safety foundation. It replaces and expands the vNext presentation and interaction direction for Home, Capture, Draw, Reveal, Current Pick, and the emotional entry points into Box and Memories.

The document contains no implementation code. A model, animation, screen, feature flag, or migration described here is not considered implemented until the corresponding source, test, runtime, and packaged evidence exists.

### Authority and override map

| Area | Authority after this document | Rule |
| --- | --- | --- |
| Product promise and low-pressure guardrails | Parent product contract | Unchanged |
| Paper lifecycle, Current Pick, Draw Attempt, Memory, deletion, and mutation gates | Parent product contract | Unchanged unless this document explicitly defines a versioned extension |
| Draw selection truth | Parent contract plus the time-context v2 extension in Section 10 | The old policy is never silently reinterpreted |
| Home, Capture, Draw, Reveal, and Peek presentation | This document | Supersedes the corresponding MVP presentation direction for vNext |
| RealityKit, 3D assets, renderer degradation, scene state, motion, sound, and haptics | This document and ADR 0004 | New vNext contract |
| Share Extension publication and main-app ingestion | Share to Box contract and ADR 0003 | Unchanged; this document owns only post-commit visual feedback |
| Persistence generations, backup, restore, erase, and Recovery | Parent contract and ADR 0002 | Unchanged, with versioned additions required for new durable fields |
| Current implementation and release evidence | README and candidate-specific release records | A requirement document is never runtime proof |

---

## 1. Executive decision

The next major product release upgrades the Box from a decorative illustration into the emotional and interactive center of the app.

The intended feeling is:

> This is a small private digital object that is gradually being filled by my life.

The upgrade is not a 3D reskin. The Box becomes the visible structure through which the existing product loop is understood:

1. Open it to put in a Paper.
2. Pull its soft ribbon to draw a Paper.
3. Lift the lid to peek at the accumulated contents.
4. Keep the Current Pick visibly close to the Box.
5. Let completed experiences settle into a quiet memory layer.

The app continues to use familiar native surfaces when clarity matters. Text entry, exact time selection, errors, recovery, destructive confirmation, search, detailed management, backup, restore, and accessibility controls remain SwiftUI interfaces. RealityKit gives the Box volume, material, lighting, motion, and touch response; it does not replace semantic UI or product truth.

### 1.1 Core architectural rule

> Domain selects and commits; the scene only reveals and responds.

- A captured Paper is committed before it falls into the Box.
- A Draw Attempt is committed before a matching Paper leaves the Box.
- Accept is committed before the Paper becomes the Current Pick.
- Completion and its Memory are committed before the stamp and memory-seam feedback.
- An interrupted animation may be skipped or rebuilt from current truth. It may never be replayed as a second business mutation.

### 1.2 What this release must improve

- First-time understanding of “put in” and “draw out.”
- The sense that the Box has volume, a lid, an interior, weight, and a consistent physical logic.
- Emotional continuity between Capture, Draw, Current Pick, completion, and Memories.
- Long-term visual variation that reflects real product facts without becoming a score or achievement system.
- A slow, enjoyable path and a fast, efficient path that reach the same result.
- Accessibility and low-performance paths that are equal product experiences, not emergency screens.

### 1.3 What this release must not become

- A room simulator, dollhouse, or decorative 3D demo.
- A task manager with urgency, deadlines, priorities, overdue states, or pressure.
- A gacha, casino, slot machine, reward ladder, or collection checklist.
- An inferred recommendation product.
- A networked weather, social, account, or collaboration product.
- A renderer whose failure blocks Capture, Draw, Recovery, or data access.

---

## 2. Existing implementation baseline

The app already has a complete local business loop. This release is a migration of the experience layer around that loop, not permission to rebuild proven rules casually.

| Existing capability | Current product truth | vNext translation |
| --- | --- | --- |
| First launch | Permission-free introduction before the root tabs | Introduce the Box and two visible verbs without a 3D tutorial or an unverified empty-state claim |
| Manual Capture | Title, required duration bucket, optional note, atomic local save | The Box opens and a blank Paper becomes the input metaphor; SwiftUI still owns the actual form and validation |
| Draw context | Six fixed time choices plus Not sure | Four high-frequency presets plus Custom/Not sure, backed by a versioned exact-minute context contract |
| Draw | Eligibility first, weighted random selection second | A soft ribbon starts the same use case; selection remains outside RealityKit |
| Unresolved result | Globally persisted and resumed before the root tabs | Relaunch reveals the exact persisted Paper without replaying selection |
| Current Pick | One accepted Active Paper | The Paper rests on or inside the lid, with native Done and Put back controls |
| Box management | Search, filter, edit, archive, restore, delete | Remains a native management surface reached from the Box tab or explicit Organize action |
| Memories | Immutable completion snapshots grouped by month | P0 adds a memory seam/route; an openable drawer is P1, and the full Memories tab remains authoritative |
| Share to Box | App Group envelope, main-app-only SwiftData materialization | A Paper may visually enter the Box only after main-app commit and refetch |
| Backup/recovery | Versioned backup and generation-safe restore/erase | Renderer and appearance additions must participate in the same evidence and rollback discipline |

### 2.1 Root-state priority and implementation truth

The current source has a fail-closed load-failure surface with **Try again**; it does not yet implement every independent Store Recovery capability required by the parent contract. Complete generation Recovery is a prerequisite workstream, not an existing baseline claim.

Product bootstrap may validate and materialize successful Share envelopes before any root surface appears. User-visible root priority remains:

```text
Loading
  → Store-open failure: Retry now; full Store Recovery when its prerequisite closes
  → Persisted unresolved Draw reveal
  → Shared Capture Recovery
  → First-launch introduction
  → Root tabs and Core Box Home
```

This order does not demote the introduction. On a first installation, no Home or Box snapshot appears before the introduction; the first snapshot after it already includes every successfully materialized Share. A corrupt, future-version, or otherwise blocked Share remains a higher integrity gate and may show Shared Capture Recovery first. The 3D scene must never cover, delay, or bypass any load/recovery gate. If the app launches with an unresolved Draw Attempt, the exact result is the first ordinary product interaction even if the scene asset has not loaded.

### 2.2 Current UI becomes a valuable fallback foundation

The existing SwiftUI illustration, buttons, forms, lists, result cards, and lifecycle controls are not obsolete scaffolding. Their semantic structure should inform the 2D renderer and accessibility representation. The migration may restyle and reorganize them, but it must preserve native controls for every core action.

---

## 3. Permanent product guardrails

| ID | Guardrail |
| --- | --- |
| `CB-G-01` | The Box is the primary product structure; lists remain management and history surfaces. |
| `CB-G-02` | The app remains local-only, no-account, no-LLM, no-analytics, no-CloudKit, and Apple-framework-only at runtime. |
| `CB-G-03` | No deadline, priority, overdue state, streak, level, score, progress bar, or pressure notification is introduced. |
| `CB-G-04` | Every core action has a visible native control; a 3D gesture or hidden shortcut is never the only path. |
| `CB-G-05` | Full 3D, Lite 3D, and 2D call the same application use cases and display the same persisted truth under Normal, Quick, and Reduce Motion variants. |
| `CB-G-06` | Animation, physics, entity order, and visible Paper position never select or rank a Paper. |
| `CB-G-07` | A failed mutation preserves the draft or prior committed product state and gives a recoverable explanation. |
| `CB-G-08` | Immersion never delays quick Capture, Share to Box, unresolved-result recovery, or data Recovery. |
| `CB-G-09` | Living traces respond to facts that already happened; no unlock condition or “how many remain” is shown. |
| `CB-G-10` | Visual semantics must be backed by stored or explicitly derived facts. The app does not pretend to know a category, friend, weather condition, energy level, or date it does not have. |
| `CB-G-11` | Sound, haptics, environment motion, full animation, and renderer quality can be reduced or disabled independently. |
| `CB-G-12` | A scene or asset failure immediately preserves a complete 2D product path and changes no product data. |

---

## 4. Scope and requirement hierarchy

### 4.1 P0: first living-experience release

P0 is one releasable vertical experience. It includes:

- A restrained abstract Home stage with a bundled 3D Box.
- A fixed virtual camera; no AR, camera passthrough, room scanning, or camera permission.
- Box body, lid, soft ribbon, Paper pile, current-Paper anchor, memory seam, ground plane, lighting, and shadows.
- Visible Put in and Draw controls alongside direct Box interactions.
- Capture opening, commit-gated folding, Paper deposit, and fast-repeat variants.
- Four high-frequency Draw time presets, exact local Custom time, and a secondary Not sure option.
- Soft-ribbon pull with threshold feedback, cancel-before-threshold behavior, and a visible button alternative.
- Commit-gated Paper shuffle, exit, unfold, and result handoff.
- Lid-open Peek with a higher camera view, unreadable Paper contents, aggregate information, and an explicit Organize action.
- Current Pick presentation beside or inside the lid, with Done and Put back.
- Commit-gated completion stamp and memory-seam feedback.
- Post-materialization Share to Box feedback, including an aggregate path for multiple imports.
- Bundled sound, optional haptics, time-of-day lighting, and restrained environmental accents.
- Full 3D, Lite 3D, and functional SwiftUI 2D renderer tiers with Normal, Quick, and Reduce Motion variants.
- Complete accessibility, performance, background, interruption, local-only, migration, rollback, and packaged-device evidence.

### 4.2 P1: state and trace expansion

P1 begins only after P0 interaction and performance evidence is stable:

- More stable non-semantic Paper silhouettes and folds.
- New/old curl, fold wear, and depth placement derived from existing timestamps.
- Source-reference clipping or a small imported-corner mark.
- A naturally visible, openable memory drawer when at least one Memory exists; P0 ships only the truthful seam and route.
- A bounded set of surface wear, stamps, and small abstract objects backed by an approved appearance-data contract.
- Morning, day, evening, and night light refinement.
- Decorative local calendar palettes that never claim actual weather or an unverified physical season.
- More refined aggregate feedback for consecutive Share imports.

### 4.3 P2: independently contracted growth candidates

These ideas require new product and data contracts. They are not silently authorized by the 3D scene:

- Date-aware Paper and a date clip.
- A hidden old-Paper compartment.
- Always-optional double-tap, long-press, and device-motion shortcuts.
- A future-letter Paper or a Box-within-the-Box.
- Durable keepsakes and long-lived patina that survive source-record deletion.
- Optional manually selected semantic Paper types.
- Optional place, energy, company, or other context metadata and a new selection policy.
- A Widget or App Intent capture mailbox.

### 4.4 Explicit non-goals for this upgrade

- Real weather, WeatherKit, location permission, or weather-derived recommendations.
- A realistic room, desk, window, or outdoor scene.
- User-selectable room decoration or a decoration store.
- Remote assets, seasonal downloads, or an online content catalog.
- Automatic category detection from titles, notes, URLs, screenshots, or webpages.
- Friend identity, a remote inbox, peer-to-peer delivery, or account-based sharing.
- Night-time changes to Draw eligibility or weighting without explicit Paper metadata.
- A visible achievement page, unlock tree, collection index, or completion counter.
- Full cloth simulation for the ribbon or full rigid-body simulation for every Paper.
- Rendering one 3D entity for every stored Paper.

### 4.5 Concept decision ledger

| Concept idea | Decision | Translation |
| --- | --- | --- |
| Central 3D Box | P0 | Primary Home object and interaction surface |
| Complete room or desk | Rejected | Abstract plane, boundary, light, and shadow only |
| Soft ribbon | P0 | Default visible draw mechanism, deterministic deformation rather than cloth simulation |
| Mechanical crank | Rejected | Conflicts with the warm, soft object language |
| Tap or lift lid to Capture | P0 with resolved semantics | Visible Put in action starts Capture; a plain lid tap opens Peek |
| Tap lid to Peek | P0 | Unique direct-tap meaning; never overloaded with Capture |
| Double-tap Box to draw | P2 shortcut | Always optional; first successful accidental use may show one hint |
| Shake device | P2 experiment | Never required and disabled when motion access is inappropriate |
| Four time choices plus Custom | P0 | Requires time-context v2, schema v3, backup v3, and a new selection-policy version |
| Optional current state | Deferred | No energy/state Paper metadata exists; no fake filter ships |
| Semantic Paper forms | Deferred | P0 uses non-semantic stable variants and known source state only |
| Transparent preview window | Rejected | Replaced by an intentional lid-open Peek |
| Memory drawer | P0 seam / P1 detail | P0 derives a non-opening seam and Memories route from existing Memories; an openable drawer and durable decorations wait for P1 |
| Date clip | P2 | Requires date semantics that preserve the low-pressure contract |
| Friend letter slot | Rejected as stated | The local Share Extension cannot prove friend identity; P0 may show an external-import slot only |
| Old-Paper hidden layer | P2 | Requires interaction and deletion semantics beyond a visual trick |
| Real weather atmosphere | Rejected | Decorative ambience must not claim real conditions |
| Time-of-day atmosphere | P0 | Derived from the local clock and never affects selection |
| Seasonal atmosphere | P1 bounded | Local decorative palette only; no location or false hemisphere claim |
| Surface wear and souvenirs | P1 | No scores; durable traces require backup/delete semantics |
| Anniversary and long-wait copy | P1 | Derived from existing timestamps and shown only at a natural encounter |
| Box within the Box | P2 | Separate future-letter lifecycle and backup contract |

---

## 5. Target information architecture

The three root tabs remain available because they provide simple, discoverable access to core truth:

| Surface | Emotional role | Functional role |
| --- | --- | --- |
| Home | Live with and operate the Box | Put in, choose time, pull to draw, Peek, resolve Current Pick |
| Box | Organize clearly | Search, filter, edit, archive, restore, delete, inspect sources |
| Memories | Revisit lived moments | Browse immutable completion snapshots and put ideas back |

Home becomes object-led, not button-led, but native actions remain visible. Box and Memories remain list-led because management and historical reading benefit from clarity more than theatrical motion.

### 5.1 Home composition

From top to bottom, Home contains:

1. A compact navigation/header layer with Settings.
2. The abstract Box stage, occupying the primary visual area.
3. A short state sentence, never a productivity metric.
4. A compact time selector when no Current Pick or unresolved result exists.
5. A visible Draw action paired with the ribbon interaction.
6. A visible Put in action paired with the lid-opening Capture sequence.
7. A native Current Pick card when one exists.
8. A quiet route to recent Memories only when useful.

The exact vertical layout adapts to Dynamic Type. Native actions may move below the scene or into a stacked layout; they may not be hidden behind the 3D model.

### 5.2 Slow and fast paths

Both paths call the same use cases.

| Intent | Slow path | Fast path |
| --- | --- | --- |
| Capture | Open Box, show blank Paper, enter text, fold, deposit | Long-press the visible Put in action or use Share to Box; short deposit feedback |
| Draw | Choose time, pull ribbon, watch short shuffle and reveal | Reuse last context from a visible shortcut and use a shortened reveal |
| Peek | Open lid and move to overview | Enter Box management directly from the tab |
| Resolve Current Pick | Observe Paper near the Box, then act | Use native Done or Put back without waiting for scene motion |

No preference is inferred from frequency. A person can select a presentation preference explicitly, and the system may shorten only repeated animations within the current session as defined in Section 14.3.

### 5.3 Peek and Organize remain different layers

**Peek** is spatial, aggregate, and intentionally unreadable. It answers “what does my Box feel like now?”

**Organize** is explicit, textual, and manageable. It answers “which exact Papers are here, and what do I want to change?”

Peek never grows into a hidden list browser. Organize never pretends to be a physical pile.

---

## 6. Core scene and visual language

### 6.1 Abstract environment

The scene occupies a believable but deliberately undefined space between a display plinth, a quiet table, and a small stage.

Required elements:

- One shallow ground plane or shadow receiver.
- A restrained background color field or abstract boundary.
- One primary light and an optional low-cost fill.
- One stable camera and one Peek camera transform.
- A small number of ambient accents with no functional meaning.

Prohibited elements:

- A complete room, window, furniture set, or outdoor environment.
- Remote environment maps.
- Camera passthrough or a claim that the Box is in the user’s real room.
- Continuous particle noise that competes with reading or drains power.

### 6.2 Box form

The Box should sit between a warm storage box, a music box, a letter keeper, and a soft collectible object without copying one literal product.

Form requirements:

- Clear single silhouette at small sizes.
- Soft corners and a visible lid relationship.
- A broad, stable body rather than exposed machinery.
- One subtle Paper exit and one small ribbon anchor.
- A side seam that can truthfully represent Memories.
- Space for later bounded attachments without designing empty fake mechanisms.

Material direction:

- Low metallic response.
- Medium-to-high roughness.
- Warm wood-pulp, matte ceramic, coated paper, fabric, or soft-plastic character.
- Fine normal detail rather than high geometric noise.
- Light wear that remains gentle and clean.

Avoid exposed gears, bolts, industrial steel, photorealistic decay, excessive scratches, steam-punk ornament, and toy-plastic gloss.

### 6.3 Paper pile and count semantics

The scene never mirrors the database one-to-one. It presents a bounded aggregate projection.

`inBoxCount` is the physical-content authority: Active Papers excluding the Current Pick and the Paper reserved by an Unresolved Draw Attempt. It includes a migrated Paper whose duration is unsupported because that Paper is still visibly and manageably in the Box. `drawableCount` is the subset with a supported stored duration and is used for general Draw availability/summary. A selected time context produces a separate candidate/`eligibleCount`; it must not be mislabeled as either Box quantity.

| `inBoxCount` | Visual density |
| ---: | --- |
| 0 | Empty interior with one clear starter cue |
| 1–2 | Individually readable silhouettes |
| 3–7 | Small loose pile |
| 8–19 | Medium layered pile |
| 20–49 | Full but breathable pile |
| 50+ | Capped full pile plus deeper aggregate geometry |

At most 24 individual Paper entities may be visible in the full renderer. Additional quantity is represented through aggregate pile meshes, depth, and density—not more collision bodies.

Visible Paper selection is a stable presentation sample from the `inBoxCount` population and is derived from item identity. It is not the Draw candidate pool, does not imply likelihood, and cannot expose exact titles. Peek may truthfully summarize both values, for example “18 Papers in the Box; 15 ready to draw,” but it never calls an unsupported-duration Paper drawable.

### 6.4 Honest Paper variation

P0 supports only variation backed by known facts:

- Stable non-semantic fold, size, angle, and subtle color variation derived from a versioned digest of the item UUID bytes.
- External-source corner treatment derived from `SourceReference`.
- Current-Pick placement derived from `CurrentPick`.
- Completion stamp derived from `CompletionMemory.completedAt`.

P1 may add newness, age, curl, and recent-movement treatments derived from `createdAt` and `lastShownAt` after those visual semantics pass comprehension review.

The stable digest is a rendering seed, not a classifier. Use a documented, versioned digest such as SHA-256 over canonical UUID bytes; never use Swift’s process-randomized `hashValue`. A ticket-shaped Paper must not imply “movie,” and a postcard-shaped Paper must not imply “travel” unless a future explicit Paper-type contract exists.

### 6.5 Time-of-day environment

P0 uses the device’s local clock only for appearance:

| Period | Approximate local interval | Direction |
| --- | --- | --- |
| Morning | 05:00–10:59 | Cooler-soft light, longer gentle shadow |
| Day | 11:00–16:59 | Neutral-bright light, clearer shape |
| Evening | 17:00–20:59 | Warmer light, slightly deeper background |
| Night | 21:00–04:59 | Focused warm light, quieter ambient motion |

These periods are presentation values and never change Draw eligibility or weights. A clock change updates the next stable scene snapshot; it does not interrupt an active gesture or animation.

### 6.6 Weather and season truth

The app has no weather service and requests no location. It therefore cannot say that current rain, sun, or temperature is being represented.

P0 has no real-weather state. P1 may include a decorative ambience rotation such as faint lines, a moving light patch, or one leaf-like shape, but:

- it is labeled nowhere as current weather;
- it is optional and can be disabled;
- it uses no network, location, or downloaded asset;
- it does not affect selection;
- it avoids hemisphere-specific seasonal claims unless the person explicitly chooses a local presentation preference.

---

## 7. Detailed user journeys

### 7.1 First launch

1. The app resolves store, migration, unresolved-result, and Share Recovery gates.
2. A short introduction presents the Box and two plain-language verbs: Put in and Draw out. It is explanatory, not a product-count snapshot, and never claims the Box is empty when a prelaunch Share has already materialized.
3. Both actions are visible native controls; the ribbon and lid also look interactive.
4. No camera, notification, location, microphone, or tracking permission is requested.
5. The first Capture is available even if the 3D asset is still loading; the 2D Box placeholder handles the same intent.
6. After the first successful save, the Paper deposit feedback plays and the Home count/scene snapshot refreshes from persisted truth.

Acceptance intent: a first-time participant can point to how to add and how to draw without being told where to tap.

### 7.2 Manual Capture

1. The person taps **Put in an idea**. Long-press may request the quick variant but is never required.
2. The lid opens for Capture. A blank Paper rises only as a presentation cue.
3. A SwiftUI Capture surface owns the title, six Paper-duration buckets, optional note, validation, keyboard, and accessibility.
4. Cancel closes the lid and writes nothing.
5. Save calls the Capture use case through the structured outcome boundary in Section 11.2.
6. On `notCommitted`, the draft remains visible, the Paper does not fall, and the Box stays open or returns to a stable error pose.
7. On `committed(outcome, snapshot)`, the real item ID becomes the presentation command correlation. The Paper folds, falls into the Box, and the lid closes.
8. On `committedButProjectionUnavailable`, the app states that the idea was saved, removes the ability to submit the stale draft, drops the deposit animation, and enters read-only reconcile/loading.
9. If the process ends after commit but before animation completes, next launch shows the correct stored density without replaying a mutation.

### 7.3 Share to Box Capture

1. The Share Extension receives system-provided text and/or an HTTP(S) URL.
2. The person confirms title and one of the existing six Paper-duration buckets.
3. The extension atomically publishes a local envelope. Its success language describes that transport fact only.
4. The main app later ingests the envelope through the global mutation gate. The same serialized transaction that creates or observes the Source Reference distinguishes a freshly imported result from `alreadyImported`; a preflight snapshot cannot decide this under concurrency.
5. Only a freshly imported result, after commit and verified refetch, may enqueue a shared-import deposit presentation. `alreadyImported` and commit-with-refetch-failure perform cleanup/reconciliation without replaying success motion.
6. One to three freshly imported Papers may receive individual short deposits. Four or more use one aggregate motion and a truthful count.
7. A failed or quarantined envelope goes to Shared Capture Recovery and never plays an “in the Box” animation. Losing a post-commit presentation event is acceptable and does not make the idempotent import eligible for replay.

### 7.4 First Draw

1. The person selects a visible time preset or Custom context.
2. The ribbon becomes armed and a native **Draw a paper** action remains visible.
3. Pulling below threshold only stretches the ribbon and lightly stirs the visible pile.
4. Releasing below threshold returns to idle and writes no Draw Session.
5. Releasing at or beyond threshold sends one Draw intent.
6. The application use case filters, selects, and persists the Session, Attempt, and `lastShownAt` before returning success.
7. The scene shuffles and releases only the Paper associated with that persisted Attempt.
8. The result becomes a stable SwiftUI semantic surface with title, note, duration, fit explanation, and actions.
9. VoiceOver moves focus or announces only after the content is stable.

### 7.5 Accept, redraw, and dismiss

- **Do this:** commit the Attempt resolution and Current Pick first, then attach the Paper to the lid/side anchor.
- **Draw another:** commit the old outcome and next persisted Attempt first, then return the old Paper and reveal the new one. The scene never produces an intermediate uncommitted result.
- **Dismiss:** commit dismissal first, then fold and return the Paper.
- **Exhausted:** show the truthful exhausted-round state with Change time or Reshuffle. Do not visually repeat a Paper as if it were a new result.
- **Interrupted:** next launch resumes the exact unresolved Attempt. It may use a shortened static reveal; it never starts a second session.

### 7.6 Current Pick

1. A Current Pick appears at `CurrentPaperAnchor`, visually close to the Box rather than buried in it.
2. A native card always exposes the exact title, duration, **Done**, and **Put back**.
3. A new Draw remains unavailable until the Current Pick is completed, put back, archived, or deleted under the parent contract.
4. The visual Paper may be touched for detail, but it is not the only route.
5. If the scene fails, the Current Pick card remains fully functional.

### 7.7 Complete and remember

1. The person chooses **Done**.
2. The application use case atomically changes lifecycle, creates the Memory, and clears Current Pick when applicable.
3. On failure, the Current Pick remains in place and the prior product truth is shown.
4. On success, the Paper receives a restrained date-stamp sound/visual and slides toward the memory seam.
5. The memory seam becomes visible whenever at least one persisted Memory exists. This is a derived feature, not an announced unlock.
6. Opening the seam routes to or previews Memories without creating a second history store.

### 7.8 Peek and Organize

1. A plain tap on the lid, or the visible **Peek inside** action, starts Peek. This gesture never starts Capture.
2. The lid opens and the camera transitions to a slightly elevated view.
3. Paper text remains unreadable. P0 shows density, source marks, and stable non-semantic physical variation; P1 may add age/recent-movement treatment.
4. P0 may briefly highlight a freshly committed import only while its ephemeral presentation event is valid. Persistent “newest” or “recently moved” bias belongs to P1 and never reveals a title.
5. A visible **Organize the Box** action exits the scene transition cleanly and opens the native Box surface.
6. Closing Peek restores the default camera and lid.
7. Backgrounding during the transition restores a stable default or overview snapshot on foreground; it never leaves an intermediate camera state as truth.

### 7.9 Fast repeat use

- Repeated manual Captures in one session use the short lid-open/deposit sequence.
- Repeated Share imports use aggregate feedback.
- A visible **Use last time** action may reuse the most recent non-authoritative Draw context preference; it never starts a Draw without confirmation.
- The first full animation, normal repeat animation, and rapid variant produce identical stored results.

### 7.10 2D and reduced-motion journeys

The 2D renderer uses layered SwiftUI shapes or bundled images to show the same closed, open, pulling, revealed, current, and memory states. Reduce Motion replaces camera travel, Paper flight, elasticity, particle drift, and depth transitions with short fades and immediate stable states. All actions, errors, and recovery paths remain present.

---

## 8. Direct interaction contract

### 8.1 Lid semantics

The supplied concept uses the lid both for Capture and Peek. P0 resolves the ambiguity:

| Input | Meaning |
| --- | --- |
| Tap lid | Peek inside |
| Visible Put in action | Start Capture and open lid for Capture |
| Long-press visible Put in action | Request the shortened Capture presentation |
| Accessibility action “Put in an idea” | Start Capture |
| Accessibility action “Peek inside” | Start Peek |

No direction-sensitive lid gesture is required. A two-axis gesture such as “up opens, sideways draws” is too difficult to discover, localize, and operate reliably.

### 8.2 Ribbon geometry and gesture

The ribbon is a visible, soft pull tab. Its target must project to at least 44 × 44 points in every supported layout; world-space collision dimensions alone cannot prove this. If the mesh projection is smaller or unstable, an aligned transparent SwiftUI interaction overlay provides the 44-point target and forwards the same intent.

Initial interaction values, to be tuned through the device prototype but frozen before implementation exit:

| Value | Initial contract |
| --- | --- |
| Pull direction | Predominantly outward/downward from the Box anchor |
| Normalized progress | `0.0...1.0` derived from clamped projected drag distance |
| Armed threshold | `0.72` |
| Hysteresis | Once threshold feedback fires, it does not repeat until progress falls below `0.55` |
| Cancel | Release below `0.72`; no Draw use case call |
| Trigger | Release at or above `0.72`; exactly one Draw intent |
| Locked state | From intent dispatch until success/failure returns |

The mesh deformation follows gesture progress. Visible Paper stirring may begin before threshold, but it is presentation-only. Haptic threshold feedback occurs at most once per pull. A second finger, repeated release, or view update cannot submit a second intent.

### 8.3 Visible Draw alternative

The native **Draw a paper** button:

- is always present when a Draw is permitted;
- uses the same selected context and application use case;
- triggers the short ribbon/reveal presentation after commit;
- remains reachable with VoiceOver, Voice Control, Switch Control, and large Dynamic Type;
- is the primary path when targeted 3D input is unavailable.

### 8.4 Hidden shortcuts

Double-tap, long-pull reuse, swipe-to-return, and device motion are P2 shortcuts only. If implemented later:

- they are available as shortcuts, not earned capabilities;
- the app never shows unlock progress;
- the first successful use may show one calm hint;
- every shortcut maps to an existing visible action;
- destructive actions remain confirmed and never occur from an undisclosed gesture.

---

## 9. Interaction and presentation state machines

The implementation should use one top-level interaction owner plus focused sub-state machines. A single giant enum containing every visual permutation would be difficult to reason about and recover.

### 9.1 Orthogonal state model

Root gates, interaction, rendering, motion, lifecycle, and durable product projection are separate axes. They must not be collapsed into one enum.

```text
RootGate (before scene construction)
  loading | loadFailure | storeRecovery | unresolvedReveal | sharedCaptureRecovery | introduction | clear

InteractionMode (mutually exclusive while RootGate = clear)
  idle | capturing | drawing | peeking | completing

RendererTier
  full3D | lite3D | swiftUI2D

MotionMode
  normal | quick | reduced

SceneLifecycle
  foreground | suspended

ProductProjection (read-only facts that may coexist with interaction)
  currentPick: absent | present(itemID)
  unresolvedAttempt: absent | present(attemptID, itemID, policyVersion)
  inBoxCount | drawableCount | memoryCount | snapshotVersion
```

Only `InteractionMode` owns direct scene interaction. A Current Pick can coexist with Capture, Peek, Organize, and Memories; it blocks only a new Draw under the parent product contract. Reduce Motion modifies any renderer tier and is not a fourth renderer. `swiftUI2D` is a renderer tier, not an interaction or failure state. Loading, load failure, and Recovery resolve before the scene coordinator exists.

### 9.2 Lid state

```text
closed
  → opening(capture | peek | deposit | memoryFeedback)
  → open(capture | peek | deposit | memoryFeedback)
  → closing(capture | peek | deposit | memoryFeedback)
  → closed
```

Capture and Peek cannot own the lid concurrently. A new command first settles or cancels a presentation-only transition; it never cancels a committed product mutation.

### 9.3 Capture state

```text
idleClosed
  → openingCapture
  → editingDraft
  → committing
      ├─ failure → editingDraftWithError
      └─ success(itemID) → folding → depositing → closing → idleClosed
```

### 9.4 Draw state

A normal new Draw is available only when the root gate is clear, Current Pick is absent, and no Unresolved Attempt exists:

```text
idle
  → selectingContext
  → armed
  → pulling(progress)
      ├─ releaseBelowThreshold → returning → armed
      └─ releaseAtThreshold → committingSelection
          ├─ notCommitted(error | empty) → returning → explanation
          ├─ committedButProjectionUnavailable(outcome) → reconcileGate
          └─ committed(outcome, snapshot) → shuffling → ejecting → resultVisible
```

Launch with an existing Unresolved Attempt bypasses context selection, ribbon arming, pull, and randomness:

```text
RootGate.unresolvedReveal(attemptID, itemID, policyVersion)
  → resultVisible(persistedAttempt)
```

This root-owned `resultVisible` reuses the Draw-result transition model but does not construct the Home scene or claim `InteractionMode.drawing`. The result may use an immediate stable pose or shortened reveal, but its semantic surface is never withheld for animation. If `policyVersion` is not executable by the current build, **Do this** and **Dismiss** remain enabled while **Draw another** is disabled with the existing unsupported-policy explanation.

Result resolution:

```text
resultVisible
  ├─ accept committed → attachingCurrentPick → idle + CurrentPick.present
  ├─ redraw notCommitted → resultVisibleWithError
  ├─ redraw committed(nextAttempt) → returningOld → revealingNew → resultVisible
  ├─ redraw committed(exhausted) → returningOld → deferredShareRefresh
  │     ├─ recovery required → RootGate.sharedCaptureRecovery
  │     └─ clear → exhausted
  └─ dismiss committed → returningPaper → idle
```

`exhausted` means the prior Attempt is resolved, the prior Session is ended, and no new Attempt exists. It offers **Change time** and **Reshuffle**. **Reshuffle** is explicit: after deferred Share ingestion/recovery has cleared, it starts a new Session with the same persisted context; it never reopens or appends to the ended Session. **Change time** returns to context selection. Neither action may bypass a newly discovered Shared Capture Recovery condition.

### 9.5 Peek state

```text
idleClosed
  → openingPeek
  → cameraToOverview
  → overview
      ├─ organize → cameraReset/close → Box management
      └─ close → cameraReset → lidClosing → idleClosed
```

### 9.6 Completion state

```text
currentPick(itemID)
  → committingCompletion
      ├─ failure → currentPick(itemID)
      └─ success(memoryID) → stamping → movingToMemorySeam → settled
```

### 9.7 Command correlation and interruption

Every transient scene command carries:

- a monotonically increasing presentation sequence;
- a command kind;
- the applicable item, attempt, session, or memory identifier when one exists;
- a source snapshot version;
- a Normal/Quick/Reduced Motion variant.

The renderer ignores a completion callback whose sequence is older than the current scene projection. Identifiers are never written to logs. They exist only in memory to prevent a stale animation from overriding a newer state.

When the app enters the background:

1. Stop accepting scene gestures.
2. Stop audio, particles, active physics, and per-frame work.
3. Allow an already-started product mutation to finish according to its application contract.
4. Discard presentation-only intermediate progress.
5. On foreground, build a stable scene from the latest persisted snapshot.

The app does not attempt to serialize a half-open lid or a Paper halfway through the air.

---

## 10. Time-context v2

The design concept’s four presets plus Custom conflicts with the current persisted six-bucket Draw Session contract. P0 adopts the new experience only through an explicit schema, backup, and policy migration.

### 10.1 Paper duration remains explicit and bucketed

Manual Capture and Share to Box continue to require one of the six existing Paper-duration buckets:

```text
10, 30, 60, 120, 240, or 480 minutes
```

This preserves fast Capture, existing data, and a truthful maximum duration for eligibility. The app does not infer a Paper’s duration.

### 10.2 Draw presets

| Visible choice | Stored maximum | Supporting text |
| --- | ---: | --- |
| A few minutes / 几分钟 | 30 minutes | Up to 30 min / 最多 30 分钟 |
| About an hour / 一小时左右 | 60 minutes | Up to 1 hour / 最多 1 小时 |
| A few hours / 几个小时 | 240 minutes | Up to 4 hours / 最多 4 小时 |
| Most of the day / 大半天 | 480 minutes | Up to 8 hours / 最多 8 小时 |
| Custom / 自定义 | 10–480 minutes | 5-minute increments |

The supporting maximum is visible. The product does not hide a precise limit behind a fuzzy phrase.

Not sure remains available inside the Custom sheet as a secondary explicit choice. It preserves a useful existing behavior without adding a fifth primary chip.

### 10.3 Custom input

- Local wheel, stepper, or picker only.
- Minimum 10 minutes, maximum 480 minutes, 5-minute increments.
- Optional “until” display may calculate a local end time from the selected minutes but stores the duration, not a deadline.
- No natural-language input, LLM, parser, or calendar event.
- No remembered Custom value is applied silently; **Use last time** is an explicit action.

### 10.4 Eligibility

For a finite context:

```text
Eligible only when Paper.maximumMinutes <= DrawContext.maximumMinutes
```

For Not sure, every otherwise eligible Paper with a supported stored duration may participate. No unsupported-duration Paper enters any Draw.

### 10.5 Selection policy `time-context-v2`

`time-context-v2` keeps weighted surprise and freezes the existing freshness behavior while extending finite contexts to exact minutes. For an exact Custom value, the effective fit bucket is the greatest supported Paper bucket less than or equal to the selected minutes.

Examples:

| Custom time | Eligible Paper buckets | Effective fit bucket |
| ---: | --- | ---: |
| 15 minutes | 10 | 10 |
| 45 minutes | 10, 30 | 30 |
| 90 minutes | 10, 30, 60 | 60 |
| 180 minutes | 10, 30, 60, 120 | 120 |
| 300 minutes | 10, 30, 60, 120, 240 | 240 |

For a finite context, calculate the Paper bucket's index distance below the effective bucket and apply the complete fit table:

| Index distance | Time-fit multiplier |
| ---: | ---: |
| 0 | 1.00 |
| 1 | 0.85 |
| 2 | 0.70 |
| 3 | 0.55 |
| 4 or more | 0.45 |

Not sure uses a time-fit multiplier of 1.00. Freshness remains 1.50 for a never-shown Paper; otherwise it rises linearly from 1.00 to 1.50 over the first 30 elapsed days, with negative clock movement clamped to zero. Recent repeat remains 0.25 when the Paper was shown less than 24 hours ago and more than one candidate is eligible, otherwise 1.00. Final weight is `timeFit × freshness × recentRepeat`. Candidate construction, no-repeat-within-session behavior, Current Pick exclusion, and weighted random selection remain as defined by the parent contract.

### 10.6 Persisted contract

Draw Session schema v3 replaces the v2 session-time field with one canonical tagged union:

| Field | Meaning |
| --- | --- |
| `contextModeRaw` | `preset`, `custom`, or `not_sure`; closed behavioral enum |
| `maximumMinutes` | Optional integer; required for preset/custom and absent for Not sure |
| `presentationPresetRaw` | Optional closed identifier: `few_minutes`, `about_an_hour`, `a_few_hours`, or `most_of_the_day` |
| `policyVersion` | New exact selection-policy identifier |

`availableTimeRaw` is removed from the active v3 storage model. It remains only in frozen schema-v1/schema-v2 models and backup-v1/backup-v2 DTO adapters. Every old value is converted before a v3 generation is validated; every new and migrated v3 Session uses the same union. There is no optional legacy column, empty-string sentinel, behavioral fallback to the old raw value, or dual write for downgrade.

Persisted invariants:

- `contextModeRaw = preset` requires one exact pair: `few_minutes`/30, `about_an_hour`/60, `a_few_hours`/240, or `most_of_the_day`/480.
- `contextModeRaw = custom` requires `maximumMinutes` in 10...480 and divisible by 5; `presentationPresetRaw` is absent.
- `contextModeRaw = not_sure` requires both `maximumMinutes` and `presentationPresetRaw` to be absent.
- `contextModeRaw` is a closed behavioral enum. An unknown value makes the generation/backup invalid because eligibility cannot be executed safely.
- `presentationPresetRaw` is closed within backup/schema v3. An unknown or mismatched value is invalid; future presets keep an existing stable identifier or require a new readable format/schema adapter.
- New Sessions and Attempts use `policyVersion = time-context-v2`. Historical opaque policy identifiers remain preserved under the parent policy-version rules.

### 10.7 Version and migration rules

- SwiftData schema advances from v2 to v3 through a custom independent-generation migration, not a lightweight in-place migration.
- Backup format advances from v2 to v3 and remains able to read supported v1 and v2 documents.
- Old 30-, 60-, 240-, and 480-minute `availableTimeRaw` values map to their matching preset plus exact maximum. Old 10- and 120-minute values map to Custom plus the same exact maximum; no old value is rounded.
- Old `not_sure` maps to `contextModeRaw = not_sure` and no maximum.
- The adapter rejects an unknown legacy `availableTimeRaw`; it never guesses. After mapping, the normal v3 validator sees no legacy/new-session distinction and applies the same union invariants to every Session.
- Existing ended Sessions retain their exact historical policy version.
- An unresolved result selected under `mvp-v1` resumes the exact persisted item. If the new build no longer executes that policy, Accept and Dismiss remain available and Redraw is disabled with the existing unsupported-policy explanation.
- The new engine never labels an old selection as v2 and never reselects during migration.
- `time-context-v2` is the frozen policy identifier for this contract. Source and fixture evidence are still required before it can be claimed as implemented.
- Forward reading is the compatibility promise: the new build reads supported predecessor stores/backups. An older binary is not expected to open schema v3 or backup v3, and no downgrade dual-write is introduced.

### 10.8 Current state remains out of P0

No place, energy, mood, cost, company, weather, or indoor/outdoor selector appears. Without corresponding explicit Paper metadata, such a selector would either do nothing or create an unsupported inference. A future context field requires its own Capture cost, schema migration, policy version, and usability evidence.

---

## 11. Product truth to scene projection

The renderer consumes a read-only projection. It never reads SwiftData models directly.

| Product truth | Scene projection | Forbidden inference |
| --- | --- | --- |
| `inBoxCount` | Density tier and Peek quantity | Draw eligibility or probability |
| `drawableCount` | General Draw availability and supported-content summary | Physical Box emptiness or context-specific eligibility |
| Box Item ID | Stable visual seed | Content category |
| `createdAt` | Age/curl range | Urgency or neglect |
| `lastShownAt` | Recently moved appearance | User preference |
| `SourceReference` | Imported corner/clip | Source popularity or friend identity |
| Unresolved Attempt | Exact result Paper in reveal | New random selection |
| Current Pick | Paper at current anchor | In-progress backlog count |
| Completion Memory | Date stamp and memory-seam visibility | Score or achievement |
| Local clock | Light and quiet motion | Energy recommendation |
| Haptic/sound preferences | Feedback enabled/disabled | Product outcome |

### 11.1 Scene snapshot

A scene snapshot is an in-memory, immutable, content-minimized view of current product state. It may contain:

- separate `inBoxCount`, `drawableCount`, and density tiers;
- stable visual seeds;
- lifecycle/source appearance flags and P1 age flags only when that scope is shipped;
- Current Pick identity and display-safe presentation state;
- unresolved-result identity when the global gate owns the UI;
- memory-seam visibility;
- local presentation preferences and renderer tier;
- a snapshot version.

It does not contain titles, notes, full URLs, backup paths, or a second mutable copy of product records. Exact text remains in SwiftUI semantic surfaces.

### 11.2 Coordinator-facing committed outcomes

The presentation layer must not flatten a mutation and its subsequent snapshot refresh into one Boolean. Every coordinator-facing call returns exactly one state:

```text
notCommitted(error)
committed(outcome, refreshedSnapshot)
committedButProjectionUnavailable(outcome)
```

- `notCommitted` means the transaction made no product change. A Capture draft or unresolved result remains actionable and may be retried.
- `committed` carries structured identifiers from the authoritative transaction and a refetched snapshot that verifies the new projection.
- `committedButProjectionUnavailable` means the transaction succeeded but the following snapshot could not be loaded. The app says the change was saved, enters a read-only reconcile/load gate, disables resubmission of that mutation, and retries projection loading. It may lose the animation; it must not claim “not changed,” preserve a retryable stale draft, or duplicate the business action.

The structured outcome includes the applicable item, session, attempt, memory, source, or envelope identifiers and discriminates such cases as `redrawn(nextAttempt)` versus `redrawExhausted`, and `sharedImportFresh` versus `alreadyImported`. IDs originate from the transaction result; the coordinator never reconstructs success from count differences, entity positions, or before/after list guesses. These IDs exist only inside the in-process outcome/command correlation path and never enter a health snapshot, log, diagnostic export, candidate artifact, or derived pseudonymous identifier.

Minimum outcome cases:

| Case | Required correlation |
| --- | --- |
| `captureCommitted` | Item ID |
| `drawSelected` | Session, Attempt, and Item IDs |
| `drawAccepted` / `drawDismissed` | Attempt and Item IDs |
| `redrawNext` | Prior Attempt, next Attempt, and next Item IDs |
| `redrawExhausted` | Ended Session ID and its canonical context |
| `completionCommitted` | Item and Memory IDs |
| `sharedImportFresh` | Envelope, Item, and Source Reference IDs |
| `alreadyImported` | Envelope plus existing Item and Source Reference IDs |

For Share ingestion, fresh-versus-existing must be decided inside the same serialized transaction that creates or observes the `SourceReference`. A pre-transaction snapshot check is insufficient because a concurrent ingestion can win before commit. The transaction outcome is then verified by refetch. If refetch fails, no Share-deposit event plays; later envelope reconciliation returns `alreadyImported` and still does not replay one.

### 11.3 Ephemeral presentation events

Only `committed(outcome, refreshedSnapshot)` may create a presentation event:

```text
captureCommitted(itemID)
drawCommitted(sessionID, attemptID, itemID)
attemptAccepted(attemptID, itemID)
attemptRedrawn(previousAttemptID, nextAttemptID, itemID)
drawExhausted(sessionID)
attemptDismissed(attemptID, itemID)
completionCommitted(memoryID, itemID)
sharedImportFreshlyMaterialized(count, boundedItemIDs)
sceneReset(snapshotVersion)
```

These events are not persisted event sourcing and are not required to reconstruct product truth. Losing one event means losing an animation, not losing a Paper. `sharedImportFreshlyMaterialized` is emitted only from the fresh-import outcome; an idempotent `alreadyImported` result caused by an interrupted envelope cleanup never recreates it.

Shared-import scheduling is bounded and non-durable:

- Keep at most one pending aggregate batch, a truthful total count, and at most three item IDs; never retain an unbounded ID list.
- Coalesce fresh imports while Capture, Draw, Peek, Complete, introduction, or another root gate owns the surface.
- Play at the next stable idle Home only when it occurs within 30 seconds of the verified refetch. After that time, drop the event and show the correct snapshot without delayed theatre.
- Entering the background drops the pending batch immediately. Foreground reconstruction shows density only and never invents a deposit replay.
- One to three IDs may use short individual deposits; four or more use one aggregate response. The batch never blocks navigation or another product mutation.
- A dropped, superseded, or interrupted event is never persisted, retried, or reconstructed from a count delta.

---

## 12. RealityKit and SwiftUI architecture

### 12.1 Selected presentation stack

- SwiftUI app lifecycle and root navigation remain unchanged.
- `RealityView` embeds RealityKit content inside Home on iOS 18 or later.
- The `RealityView` content closure explicitly assigns `content.camera = .virtual`; relying on the iOS default would select the AR camera path.
- Bundled Reality or USD-family assets validated against the pinned production toolchain supply the scene; Reality Composer Pro is an optional authoring tool only after compatibility is proven.
- RealityKit entities render the Box, lid, ribbon, Papers, decorations, lights, shadow receiver, and authored motion.
- SwiftUI overlays own controls, text, forms, errors, result semantics, navigation, settings, and accessibility representation.

The app requests no camera access. Camera passthrough, world tracking, anchors to a physical room, and scene reconstruction are out of scope.

### 12.2 Dependency direction

```text
SwiftUI semantic controls / targeted 3D gestures
                    ↓ UserIntent
CoreBoxInteractionCoordinator
                    ↓
Existing or versioned Application Use Cases
                    ↓
Persisted Product Truth
                    ↓ structured committed outcome + verified refetch
SceneSnapshot + PresentationCommand
             ↙                    ↘
RealityKit Renderer          SwiftUI 2D Renderer
```

Rules:

- RealityKit imports remain in the App/presentation layer.
- Domain, Application, Data, and the Share Extension do not depend on RealityKit.
- The renderer owns entities but not repositories, contexts, random generators, or lifecycle transitions.
- A targeted gesture emits an intent; it does not mutate an entity and assume the product followed.
- Renderer switching produces no product-store write.

### 12.3 Interaction targets

Interactive entities use explicit simplified collision proxies and input-target components. The production scene has separate hit entities for lid, ribbon, Box body, and memory seam. Decorative entities do not receive input.

RealityKit targeting is an enhancement. Every action has a SwiftUI button or accessibility action. A missing collision component therefore degrades one input path rather than disabling the product.

### 12.4 Asset loading and failure

1. The native Home structure and actions become available from product data without waiting for the 3D asset.
2. `RealityView` loads the bundled scene asynchronously with a 2D placeholder.
3. The runtime asset validator checks the bundled manifest version/digest plus required entities, unique names, transforms, and anchors.
4. A valid scene cross-fades in without changing product state.
5. A missing, corrupt, incompatible, digest-mismatched, or structurally invalid scene selects functional 2D for the current launch and records a content-free in-memory reason code.
6. The app never loops asset retries, downloads a replacement, or blocks Recovery.

### 12.5 Animation approach

P0 prefers authored transforms, animation resources, deterministic paths, and short state-driven interpolation.

- Lid motion rotates around a fixed hinge pivot.
- Ribbon motion is a rigged/segmented or blend-shaped deformation driven by normalized drag progress.
- Paper movement uses authored anchors and paths.
- Paper pile stirring uses bounded transforms on a small pooled set.
- Completion stamping and memory-seam response use deterministic animation.
- Physics may add small presentation-only settling, but it never determines a product outcome.
- Continuous full cloth simulation and hundreds of rigid-body Paper collisions are prohibited.

The iOS 18 implementation must use APIs available at the deployment target. Newer implicit-animation convenience APIs may be adopted only behind availability checks and cannot be required for the baseline renderer.

Triangle, material, texture, audio, provenance, and package-size ceilings are build/archive audit facts recorded in the signed asset manifest. Runtime does not recount expensive asset internals to guess whether a scene is over budget. It verifies the manifest identity and reacts to actual load, memory, thermal, or sustained performance failure. A candidate whose build-time audit exceeds a ceiling cannot ship that asset version.

### 12.6 Scene coordinator responsibilities

- Serialize top-level interaction modes.
- Translate SwiftUI and targeted-entity inputs into `UserIntent`.
- Call application use cases and handle the three structured commit/projection outcomes in Section 11.2.
- Build content-minimized scene snapshots.
- Emit correlated presentation commands.
- Cancel or settle obsolete animations.
- Pause work during background, thermal pressure, and renderer changes.
- Route asset or renderer failure to 2D.

It does not choose Draw candidates, infer commits from snapshot deltas, validate backup files, own SwiftData transactions, or duplicate the mutation gate.

---

## 13. 3D asset production contract

### 13.1 Source and packaging

- C1 freezes one version-controlled source path that the pinned production toolchain can build: a reviewed USD/USDA/USDZ source tree, compatible Reality assets, or a compatible Reality Composer Pro project plus deterministic exported interchange artifacts.
- Compiled Reality/asset bundles are produced by the parent contract's pinned production Xcode and CI host. A 3D authoring tool may use a separately recorded host only when its exports remain reproducible and buildable on that production line.
- Every model, texture, normal map, environment texture, and sound ships in the app bundle.
- No runtime URL, CDN, asset catalog service, or remote feature pack exists.
- Every externally authored asset has a provenance/license record and a replaceable source.
- Generative or assistant features in an authoring tool are not a runtime product dependency and are not required by this pipeline.

Reality Composer Pro is optional rather than a P0 prerequisite. At this review, Apple's current Reality Composer Pro overview lists macOS Tahoe 26.5 or later, while the parent contract's production/CI floor is macOS 26.2; the authoring host therefore cannot be assumed to be the CI host. Project-linking requirements must be checked against the pinned Xcode/macOS pair during C1, and this document does not silently upgrade the production toolchain to adopt a newer authoring workflow. The source-of-truth format, authoring-host version when applicable, export command, and production compile command are frozen before C1 exits.

### 13.2 Coordinate and scale contract

- Unit: meters.
- Up axis: `+Y`.
- The scene root has identity transform.
- Default Box center is near the origin.
- Approximate Box body envelope: 0.30 m wide × 0.18 m high × 0.22 m deep.
- Paper visible envelope: approximately 0.09 m × 0.06 m, with visual thickness sufficient to avoid z-fighting.
- Camera, object, and animation paths are authored relative to stable anchors, not mesh bounds discovered at runtime.

Values may be tuned during the spike, but the final dimensions and transforms become a versioned asset contract.

### 13.3 Required entity names

```text
BoxRoot
BoxBody
LidPivot
LidMesh
RibbonRoot
RibbonTip
PaperSpawn
PaperExit
PaperDeposit
PaperRest_00 ... PaperRest_N
CurrentPaperAnchor
MemorySeam
DecorationRoot
Camera_Default
Camera_Peek
Light_Key
Light_Fill
ShadowReceiver
Hit_Lid
Hit_Ribbon
Hit_Box
Hit_MemorySeam
```

Requirements:

- Names are unique and stable across compatible asset versions.
- `LidMesh` rotates through `LidPivot`; its own mesh origin is not used as the hinge contract.
- Paper spawn, exit, deposit, and current anchors are empty transform entities.
- Hit entities use simple box, capsule, or convex proxies and are not visible.
- Optional decorations live under `DecorationRoot` and cannot become required interaction anchors.
- A missing required entity rejects the whole 3D scene and selects 2D. The app does not expose a partially interactive Box.

### 13.4 Ribbon model

The ribbon must look soft without requiring nondeterministic cloth physics.

Acceptable techniques:

- A small joint chain with bounded authored deformation.
- Blend shapes for relaxed, stretched, and threshold poses.
- Segmented child transforms interpolated from pull progress.

The visible tip returns to exactly the same rest pose after cancel, failure, interruption, or renderer reset. Deformation must not intersect the Box under any supported progress value.

### 13.5 Paper pool

- Full renderer: at most 24 active/visible individual Paper entities.
- Lite renderer: at most 10.
- Only the currently animated Paper receives a temporary detailed path or collision proxy.
- Remaining quantity is represented by pooled instances and aggregate pile geometry.
- Mesh, material, and texture resources are shared; the renderer does not rebuild identical resources per Paper.
- Stable item seeds map to visible slots deterministically for a snapshot, but the selected Draw item can be represented by a pooled reveal Paper after commit. It need not have occupied a literal visible slot.

### 13.6 Initial scene budgets

These are pre-implementation ceilings to validate and tighten on the oldest supported reference iPhone:

| Resource | Full 3D ceiling | Lite 3D ceiling |
| --- | ---: | ---: |
| Visible triangles | 60,000 | 25,000 |
| Visible renderable entities | 80 | 36 |
| Individual Paper entities | 24 | 10 |
| Real-time shadow-casting lights | 1 | 0 |
| Total dynamic lights | 2 | 1 |
| Texture dimension | 2,048 × 2,048 maximum | 1,024 × 1,024 preferred |
| Resident texture target | 32 MiB | 16 MiB |
| Added bundled 3D/audio size | 20 MiB target | Same bundle; lower-runtime variant |

The full scene should use a texture atlas where practical, minimize transparent overdraw, merge meshes that share material when programmatic access is unnecessary, and keep collision shapes simple. Raising a ceiling requires measured evidence and a reviewed manifest change.

### 13.7 Asset validation evidence

Every asset version records:

- source commit and asset version;
- compiled bundle digest;
- required-entity inventory;
- default transforms and bounds;
- triangle, entity, material, texture, and audio counts;
- license/provenance manifest;
- full and Lite screenshots in light/dark appearance;
- load success on minimum and current OS;
- 2D parity screenshot;
- performance measurement on reference devices.

---

## 14. Motion, sound, and haptics

### 14.1 Physical rules

The scene establishes a small consistent world:

- Papers move downward when deposited.
- Opening the lid lightly shifts the visible pile.
- Pulling the ribbon tensions it and draws the pile toward the exit.
- A released Paper has brief inertia and settles.
- Returning a Paper folds it before it re-enters.
- The Current Pick remains outside the drawable pile.
- Completion moves the Paper toward Memories only after Memory commit.

The rules are more important than spectacle. They remain consistent across full and short variants.

### 14.2 Initial timing contract

| Motion | First/slow variant | Normal variant | Rapid variant | Reduce Motion |
| --- | ---: | ---: | ---: | --- |
| Lid open or close | 350–450 ms | 240–320 ms | 120–180 ms | State swap + 120 ms fade |
| Capture fold and deposit | 650–900 ms | 380–560 ms | 180–260 ms | 150 ms fade/scale |
| Ribbon return below threshold | Gesture-tracked + 220 ms | Same | Same | Immediate + light fade |
| Post-commit shuffle and exit | 700–1,000 ms | 500–750 ms | 260–420 ms | 150–220 ms cross-fade |
| Peek camera transition | 450–650 ms | 350–500 ms | 180–260 ms | No camera travel; content fade |
| Completion stamp and settle | 600–900 ms | 400–650 ms | 220–350 ms | Immediate state + short fade |

No core action waits for an animation-completion callback before committing. The semantic result surface enters the accessibility tree only in the stable `resultVisible` state. Under VoiceOver or Reduce Motion that state is immediate or uses only the short fade; a result is never focusable midway through flight, and its announcement fires once after stable insertion.

### 14.3 Automatic shortening

- First successful occurrence in the current installation may use the full instructional variant.
- Later occurrences use normal timing.
- Three or more same-kind actions within 60 seconds use the rapid variant for the rest of that burst.
- The preference **Quick animations** always selects rapid timing.
- Reduce Motion overrides every timing tier.
- Automatic shortening is presentation-only and need not be backed up.

No animation is lengthened because a person has not opened the app recently.

### 14.4 Sound

Bundled, restrained sound cues may include:

- Paper fold and friction.
- Soft lid contact.
- Fabric tension/release.
- Small wood/pulp contact.
- Quiet slide.
- Soft stamp.

Avoid gears, factory machinery, slot-machine effects, bright reward tones, applause, or confetti-like audio.

Sound rules:

- Sound can be disabled independently from haptics.
- Short cues use the nonexclusive `AVAudioSession` ambient category: respect the Ring/Silent switch, mix with other audio, never duck or interrupt the person's music, and request no background-audio capability.
- No microphone permission or recording exists.
- No looping ambience in P0.
- No more than the minimum active audio sources needed for the current action.
- A route change, interruption, or background transition stops and discards the current cue. It does not resume or replay after the route/lifecycle returns and has no product-state effect.

### 14.5 Haptics

| Event | Feedback |
| --- | --- |
| Time preset change | Light selection |
| Ribbon first crosses threshold | One clear light/medium impact |
| Paper exits | Short light impact |
| Paper deposits | Soft light impact |
| Completion commit | Success feedback |
| Hidden-compartment candidate in a future release | Distinct but gentle pattern, never the only cue |

Haptics pair with visible state and can be disabled. They never communicate eligibility, failure, or completion alone.

---

## 15. Accessibility and renderer parity

### 15.1 Equal functional paths

| Capability | Full/Lite 3D | SwiftUI 2D | Reduced-motion variant at any tier |
| --- | --- | --- | --- |
| Put in | Lid feedback + native action | Layered Box + native action | Immediate stable state + native action |
| Select time | Native controls | Same | Same |
| Draw | Ribbon + native action | 2D ribbon + native action | Native action + fade |
| Peek | Lid/camera overview | 2D top-down illustration | Static aggregate summary |
| Organize | Visible action to Box | Same | Same |
| Current Pick | 3D anchor + native card | 2D Paper + native card | Native card |
| Done / Put back | Native controls | Same | Same |
| Errors and Recovery | SwiftUI | Same | Same |

2D is not an error message and does not omit Peek, Current Pick, or recovery.

### 15.2 VoiceOver and semantic structure

- Treat the Box stage as one semantic group rather than exposing every decoration.
- Provide actions: Put in an idea, Draw a paper, Peek inside, Organize the Box, and Open Memories when valid.
- Expose a concise value such as “18 Papers in the Box; 15 ready to draw; one current Paper” without reading hidden titles.
- Hide decorative particles, lights, ground geometry, and pile Papers from the accessibility tree.
- RealityKit `AccessibilityComponent` may enhance entities, but SwiftUI semantic controls remain the guaranteed path.
- Reveal announces the exact result only after the semantic result surface is stable.
- Peek reports aggregate quantity and state; it does not enumerate Paper text.

### 15.3 Dynamic Type and control layout

- All exact text and controls remain SwiftUI, never baked into 3D textures.
- The scene yields vertical space when large text requires it.
- At accessibility sizes, actions stack vertically and remain at least 44 × 44 points.
- No title, result, error, or destructive confirmation is clipped behind the scene.
- Voice Control names match visible labels.

### 15.4 Accessibility settings

The release verifies:

- VoiceOver.
- Voice Control.
- Switch Control.
- Dynamic Type through the largest accessibility size.
- Increase Contrast.
- Differentiate Without Color.
- Reduce Transparency.
- Reduce Motion.
- Bold Text.
- Light and dark appearance.

Reduce Motion avoids camera travel, z-axis flight, bounce, sustained oscillation, and peripheral particles. A static 3D Box is permitted when comfortable; 2D remains an explicit option.

### 15.5 User settings

Settings adds a clear Experience section:

- Box appearance: Automatic / Full 3D / Simplified 2D.
- Quick animations.
- Background ambience.
- Sound.
- Haptics.

Unsupported Full 3D may be shown as unavailable with an explanation. A preference never bypasses an automatic safety fallback during asset failure or serious resource pressure.

The user-facing **Simplified 2D** value maps exactly to D2 SwiftUI 2D and the stored `swiftUI2D` preference. D1 Lite 3D is an automatic safety tier, not a separate user preference.

---

## 16. Renderer tiers, motion variants, and automatic degradation

| Tier | Presentation | Functional contract |
| --- | --- | --- |
| D0 Full 3D | Dynamic key light, one real-time shadow, full Paper pool, restrained ambience, complete paths | Full |
| D1 Lite 3D | Simplified asset/LOD, no real-time shadow, smaller Paper pool, no particles, shorter paths | Full |
| D2 SwiftUI 2D | Layered Box illustration and short native transitions | Full |

Motion is an independent modifier:

| Mode | Rule |
| --- | --- |
| M0 Normal | Normal authored timing for the selected renderer tier |
| M1 Quick | Rapid timing for the selected renderer tier |
| M2 Reduced | Static states and brief fades; no camera travel, flight, bounce, or peripheral ambient motion |

Every D0/D1/D2 tier must support the applicable M0/M1/M2 variants. Automatic shortening may select M1; the system Reduce Motion setting selects M2. Neither changes product truth or renderer quality by itself.

### 16.1 Automatic fallback conditions

- Bundled asset cannot load.
- Required entity or anchor validation fails.
- Renderer initialization fails.
- Memory pressure makes the current scene unsafe.
- Thermal state becomes serious or critical.
- During active rendering, two consecutive 120-frame windows exceed p95 16.7 ms at D0 or p95 33.3 ms at D1; downgrade occurs at the next stable interaction boundary.
- Low Power Mode selects Lite by reviewed policy; it does not force 2D without evidence.

The renderer never switches midway through a pull or before a product-use-case response. It settles the current presentation, preserves product truth, then rebuilds at the new tier.

### 16.2 Preference versus safety

- User choice selects a preferred maximum tier.
- Automatic policy may choose a lower tier for safety.
- The app does not repeatedly oscillate between tiers in one foreground session.
- A content-free reason code explains a fallback in diagnostics and, when useful, in Settings.
- Renderer choice is a presentation preference and excluded from product-data backup.

---

## 17. Living traces and progressive growth

### 17.1 P0/P1 derived traces

Derived traces avoid a new achievement ledger, but their delivery phase remains explicit:

| Phase | Fact | Trace |
| --- | --- | --- |
| P0 | At least one Memory | Non-opening memory seam and route are visible |
| P0 | Current Pick exists | One Paper rests outside the pile |
| P0 | Source Reference exists | Small imported/source corner treatment |
| P1 | Paper is recently created | Cleaner fold and top-layer bias |
| P1 | Paper is older or recently shown | Slight curl/depth or recent-movement treatment |
| P1 | Paper waited a long time and is drawn | One gentle age sentence on reveal |
| P1 | Memory anniversary matches local date | Optional quiet “one year ago” surface |

No derived trace changes Draw weight beyond the existing documented freshness policy. Visual depth is not a ranking promise.

### 17.2 P1 long-wait copy

When a drawn Paper has waited at least 180 local calendar days, the result may show one line:

> This is something you left here a long time ago.

An optional exact day count uses local calendar-day difference, clamps negative values to zero after clock correction, and is presented as context rather than an achievement. It appears only when the Paper is naturally drawn, never as a pressure notification.

### 17.3 P1 anniversary copy

An existing Memory may surface quietly when its local month/day matches the current date. It:

- does not enter the Draw pool automatically;
- creates no notification or badge;
- requires no response;
- disappears if its Memory/source is permanently deleted;
- handles February 29 with a separately tested display rule;
- does not become a streak.

### 17.4 Durable P1 appearance data

If general wear, stamps, or keepsakes must survive deletion, compaction, and backup/restore, they become user-owned product data rather than UserDefaults decoration.

A later contract may introduce:

- `BoxAppearanceState`: stable appearance seed, first-used date, bounded general patina.
- `BoxTraceRecord`: stable open raw kind, occurrence date, visual variant, and optional source Memory/Paper reference.

Rules:

- No level, experience points, progress, remaining count, or reward rarity.
- A source-specific trace cascades when its source is permanently deleted unless the confirmation explicitly says otherwise.
- General non-semantic patina may remain only if that behavior is explicitly approved.
- Backup, restore, migration, full export, capacity, delete, and Erase All cover the data.
- A trace never affects Draw selection.

### 17.5 Date clip, friend slot, and Box-within-the-Box

These are not P0 decorations because each implies product semantics:

- A date clip requires an explicit date/window model with no overdue or pressure behavior.
- A friend slot requires a truthful sender/transport contract; current Share to Box provides neither identity nor remote receipt.
- A Box-within-the-Box requires future-open conditions, visibility rules, backup behavior, and clock-change handling.

They remain separate future features until those contracts exist.

---

## 18. Data, migration, backup, and deletion impact

### 18.1 Data classification

| Data | Authority | Persistence |
| --- | --- | --- |
| Papers, Current Pick, Draw Sessions/Attempts, Memories, Sources | Product truth | SwiftData + backup |
| Time-context v2 fields | Product truth for Draw history/recovery | SwiftData schema v3 + backup v3 |
| Renderer, Quick animation, sound, haptic, ambience, last-context, and first-animation preferences | Presentation preference | Versioned UserDefaults namespace; excluded from product backup |
| Current animation progress and command queue | Ephemeral presentation | Memory only |
| P0 Paper appearance seed | Deterministically derived from ID | Not separately persisted |
| Future durable patina/keepsakes | User-owned product data if approved | New schema + backup contract |

### 18.2 Presentation-preference lifecycle

P0 owns a versioned `core-box-presentation-v1` preference namespace with these defaults:

| Key | Default | Rule |
| --- | --- | --- |
| Renderer preference | `automatic` | Other valid values are `full3D` and `swiftUI2D`; automatic safety may choose a lower tier |
| Quick animations | `false` | Selects M1; system Reduce Motion still overrides with M2 |
| Background ambience | `true` | Decorative only; Low Power/safety policy may suppress it |
| Sound | `true` | Still respects Ring/Silent and ambient audio-session behavior |
| Haptics | Existing preference, otherwise `true` | Migrates the current local setting without changing product truth |
| Last Draw context | Absent | Stored only after a Draw Session is successfully committed; used only by **Use last time** |
| First full Capture/Draw/Complete animation flags | `false` | Become true only after the corresponding committed outcome reaches stable presentation |

The 60-second burst counter, active command sequence, fallback reason, and pending Share-deposit batch are in-memory session state, not preferences. Unknown preference values fall back to safe defaults without invalidating product data. Product-data restore leaves presentation preferences unchanged. **Erase All Data** resets this entire namespace, last context, first-animation flags, haptics, and introduction/onboarding state as part of the parent contract's app-owned preference cleanup. A normal app update migrates the namespace deterministically; it does not silently copy values into product backup.

### 18.3 Schema v3

Schema v3 adds the time-context fields required by Section 10 and no 3D coordinates. Scene transforms, visible Paper slots, lid state, and animation phase never enter SwiftData.

Migration requirements:

- Freeze the immediate predecessor schema-v2 fixture from current source. If any predecessor binary has actually been distributed, retain and test a fixture from each supported distributed schema build as well.
- Old Draw Session conversion and full invariant validation.
- Existing unresolved result resumes unchanged.
- Existing Box Items, Sources, Current Pick, Attempts, and Memories remain field-for-field domain-equivalent and canonical-fixture equivalent after the deliberate Session-context mapping.
- Schema v3 must use the parent contract's independent-generation migration, fresh-container validation, manifest switch, durable commit boundary, and idempotent cleanup path. This is additional implementation work unless the candidate source proves a migration operation already supports every phase; the current restore/erase generation journal must not be cited as migration evidence by itself.
- The migration is custom because the required v2 `availableTimeRaw` representation is replaced, not merely extended. No in-place lightweight migration or empty legacy sentinel qualifies.
- The generation `productDigest` advances to a canonical v3 payload and schema-v3 metadata that include every new Session context field. A digest still computed through the v2 codec cannot validate a v3 generation.
- Migration is never gated by the 3D feature flag.

### 18.4 Backup v3

Backup v3 adds only the canonical Draw Session context union in Section 10. P1 appearance records are not reserved or appended later; if approved, they require backup v4 or a later explicitly versioned format.

- `BackupDocumentV3` uses `formatVersion = 3` and `canonicalizationVersion = 1`. It replaces `productV1CanonicalData` with `productV3CanonicalData`, whose decoded payload contains export/app/build/schema/policy metadata, Items, Current Pick, Sessions with the new union, Attempts, and Memories. Sources and pending envelopes retain their v2 DTO semantics as outer-document arrays.
- Record order remains UUID-byte ascending within each record type; attempt/session invariants, sorted JSON keys, unescaped slashes, timestamp canonicalization, and checksum encoding remain the existing canonicalization-v1 rules.
- The outer checksum excludes only its own checksum field and covers format/canonicalization versions, the complete canonical v3 product payload, Sources, and pending envelopes. The encoded file limit remains exactly 159,383,552 bytes; the product-graph budget remains 150,994,944 bytes; existing record/text/source/envelope count limits remain unchanged. Exact projected-size and final encoded-size checks include every new context field.
- v1 and v2 remain readable through version-specific deterministic adapters. Their old `availableTimeRaw` values map exactly as Section 10.7 specifies before normal v3 validation.
- Unknown future format is rejected without writes.
- A v3 restore validates old and new policy/context invariants before staging.
- Presentation preferences and active animation state remain excluded.
- The generation `productDigest` uses the canonical backup-v3 store payload with no pending mailbox envelopes and fixed schema-v3 metadata, so loss or reinterpretation of any new context field changes the digest.
- The release manifest records minimum/maximum readable format and exact policy versions.

### 18.5 Delete and erase

- P0 derived appearance disappears naturally when its source Paper, Memory, or Source Reference is deleted.
- Permanent Paper deletion keeps the existing cascade contract.
- Renderer caches contain no durable personal text and can be recreated.
- Erase All removes all future user-owned appearance/trace records as part of the generation operation.
- Exported files, OS backups, and OS diagnostics remain outside app control as already documented.

### 18.6 No 3D state in Recovery truth

Recovery shows native, stable SwiftUI. It never attempts to reconstruct the Box scene before the authoritative generation is known. Once Recovery finishes and product truth is refetched, the renderer starts from a new snapshot.

---

## 19. Privacy, locality, and content safety

### 19.1 Runtime boundary

- No app account or identity.
- No developer server.
- No product network request.
- No CloudKit or remote configuration.
- No analytics, advertising, tracking, or crash SDK.
- No LLM, embedding, classifier, OCR, semantic parsing, or remote asset generation.
- No camera, location, microphone, Photos, Contacts, Calendar, or notification permission for the core experience.
- All 3D, texture, audio, 2D fallback, and environment assets are bundled.

### 19.2 Camera truth

RealityKit is used as a non-AR renderer with a virtual camera. Product copy must not say the Box is placed in the user’s room or environment. The app does not access the camera feed.

### 19.3 Diagnostic boundary

The current repository audit rejects production `Logger`, `os_log`, `print`, and equivalent call surfaces. P0 preserves that rule. It uses external Instruments measurements, test/candidate evidence, and an optional bounded in-memory health snapshot for the current foreground session; it does not add a production event log or persistent gesture timeline. A proposal for durable content-free diagnostics requires a separate reviewed policy plus an explicit audit-script change before implementation.

Allowed in-memory metric dimensions:

- Stable error/reason code.
- Renderer tier.
- Scene/asset/interaction version.
- Duration and count.
- Frame-time bucket.
- Boolean success/failure.

Forbidden fields:

- Title, note, URL, Paper text, or source text.
- Any product/envelope UUID, stable record identifier, or truncated/hashed/otherwise derived form of one; asset/version digests remain allowed because they contain no product identity.
- Texture containing rendered user text.
- Scene screenshot containing user text.
- A durable timeline of every gesture.

Suggested content-free metric keys for tests, Instruments correlation, and the current-session health snapshot:

```text
scene_load
scene_validation
renderer_fallback
interaction_transition
animation_interrupted
frame_budget
audio_lifecycle
```

The snapshot contains counters/latest reason only, stores no identifiers or user content, is discarded on process exit and Erase All, and is excluded from backup. Settings may expose the current fallback reason without turning it into history. Candidate artifacts are reviewed for the same forbidden fields before retention.

### 19.4 Weather and environment

No network or location is introduced for ambience. If a future proposal needs real weather, it is a product-boundary change requiring a separate privacy, capability, copy, failure, and removal decision; it is not a small visual enhancement.

---

## 20. Performance, energy, and resource requirements

### 20.1 Launch and interaction

- The candidate manifest names the oldest and current reference iPhones and exact OS builds. On each, Release-without-debugger measurement records at least 20 cold and 20 warm launches.
- Native Home interactivity is p95 ≤ 1.5 seconds. 3D readiness is p95 ≤ 2.0 seconds under the frozen local fixture, but it is never an interaction prerequisite.
- Capture persistence and Draw selection retain the existing 150 ms targets excluding intentional presentation.
- Asset file I/O and decode run asynchronously. During load/configuration, main-thread stall p95 is < 50 ms with zero stalls ≥ 100 ms; entity insertion and SwiftUI publication occur only through measured bounded main-actor work.
- A 2D placeholder is stable, not a spinner over unavailable actions.

### 20.2 Frame budget

- D0 targets 60 fps. In each frozen 60-second Capture/Peek/Draw interaction recording, frame-time p95 is ≤ 16.7 ms and frames > 33.3 ms are ≤ 1%.
- D1 targets a stable 30 fps minimum. In the same recording, frame-time p95 is ≤ 33.3 ms and frames > 66.7 ms are ≤ 1%.
- Average main- and render-thread work below 12 ms remains an optimization direction, not a substitute for the percentile/hitch release gates.
- The exact runtime downgrade windows are fixed in Section 16.1. A release may tighten them through a reviewed manifest version; it may not relax these acceptance limits without new device evidence and contract review.
- Frame and hitch values are verified with Instruments/RealityKit metrics on physical devices and are never inferred from simulator smoothness.

### 20.3 Memory and thermal

- Full 3D peak resident-memory increase over the same D2 journey targets no more than 120 MiB.
- Textures, meshes, animation resources, and audio are reused and released when the scene is torn down.
- A checked-in 50-cycle Release stress recipe (Capture, Peek, Draw, Dismiss, and stable-idle intervals over seeded local data) must not reach thermal serious or critical.
- Memory warning handling settles the current presentation and may select D1/D2 without changing product data.

### 20.4 Idle and background

- No continuous physics body, particle emitter, oscillation, or audio loop remains active while Home is visually idle.
- Per-frame subscriptions exist only when necessary and return no work in stable states.
- Within one second of background, scene animation, audio, particles, and gesture processing stop.
- Foreground rebuilds from current truth instead of resuming a stale half-animation.
- Low Power Mode uses the reviewed renderer policy and never disables a product action.

### 20.5 Large dataset

The parent contract defines the 5,000-Paper scale requirement, but the current source does not yet provide a frozen performance fixture. C1/C4 must check in a deterministic generator and canonical fixture before any candidate cites large-dataset evidence. That fixture then becomes the candidate authority. The scene always consumes bounded aggregate projections, so increasing the database from 50 to 5,000 Papers does not create thousands of entities, collision shapes, materials, or animations.

---

## 21. Functional requirements and acceptance rules

### 21.1 Home and scene

| ID | Requirement | Acceptance rule |
| --- | --- | --- |
| `CB-HOME-01` | Make the Box the central Home object | In first-use research, participants can identify Put in and Draw without opening another tab |
| `CB-HOME-02` | Preserve visible native actions | Put in, Draw, Peek/Organize, and Current Pick actions remain reachable when RealityKit input is unavailable |
| `CB-HOME-03` | Keep scene truth derived | Changing renderer tier produces zero product-store mutations |
| `CB-HOME-04` | Load without blocking | Capture and Draw controls are usable from 2D placeholder before 3D is ready |
| `CB-HOME-05` | Fail to 2D safely | Missing/corrupt required asset produces a complete 2D Home and content-free error, not a crash or blocked app |
| `CB-HOME-06` | Preserve global gates | Load failure/full Store Recovery, unresolved result, Share Recovery, and first-launch introduction resolve in the documented order before Home scene construction |
| `CB-HOME-07` | Return structured mutation truth | Coordinator receives transaction-derived IDs/outcome plus refreshed snapshot, never a Boolean or count-delta inference |
| `CB-HOME-08` | Separate commit from projection failure | Injected post-commit refetch failure enters read-only reconcile, reports saved truth, and cannot resubmit or duplicate the mutation |

### 21.2 Capture

| ID | Requirement | Acceptance rule |
| --- | --- | --- |
| `CB-CAP-01` | Open Box for Capture | Visible Put in action enters Capture; lid tap alone enters Peek instead |
| `CB-CAP-02` | Keep native input semantics | Title, duration, note, errors, keyboard, Dynamic Type, and accessibility remain SwiftUI |
| `CB-CAP-03` | Commit before deposit | Forced save failure leaves the draft and never plays Paper-fell-into-Box success |
| `CB-CAP-04` | Survive interruption | Termination after save but before deposit animation relaunches with the Paper present exactly once |
| `CB-CAP-05` | Support fast repeat | Rapid presentation reduces time but commits the same records and validation |

### 21.3 Draw and ribbon

| ID | Requirement | Acceptance rule |
| --- | --- | --- |
| `CB-DRW-01` | Require time context | Ribbon/button cannot start Draw without an explicit preset, Custom, or Not sure selection |
| `CB-DRW-02` | Cancel before threshold | Releasing below threshold creates no Session or Attempt |
| `CB-DRW-03` | Trigger once | Any repeated touch/update after threshold creates at most one Draw intent and one unresolved Attempt |
| `CB-DRW-04` | Commit before exit | Revealed item ID always equals the persisted unresolved Attempt item ID |
| `CB-DRW-05` | Preserve empty-pool truth | No-match returns the ribbon and shows a supportive explanation without ejecting a fake Paper |
| `CB-DRW-06` | Resume exact result | Force termination during reveal restores the same Attempt and does not rerun randomness |
| `CB-DRW-07` | Provide button parity | Native Draw button completes the identical journey in every renderer tier |
| `CB-DRW-08` | Keep Current Pick singleton | Scene cannot arm a new Draw while Current Pick exists; Capture, Peek, Organize, and Memories remain available |
| `CB-DRW-09` | Resume before new interaction | Launch with Unresolved Attempt enters its exact stable result without context selection, pull, or reselection; unsupported policy disables Redraw only |
| `CB-DRW-10` | Close exhausted rounds | Exhausted Redraw ends the old Session with no new Attempt, refreshes deferred Share/Recovery work, and Reshuffle starts a distinct Session with the same context only after gates clear |

### 21.4 Time context

| ID | Requirement | Acceptance rule |
| --- | --- | --- |
| `CB-TIME-01` | Show truthful preset limits | Every fuzzy preset visibly states its exact maximum |
| `CB-TIME-02` | Support exact Custom safely | A 45-minute context never admits a 60-minute Paper and admits supported 10/30-minute Papers |
| `CB-TIME-03` | Keep Capture explicit | Every new Paper still requires one supported duration bucket |
| `CB-TIME-04` | Version changed behavior | New Sessions store the new policy/context contract; old history is never relabeled |
| `CB-TIME-05` | Migrate without reselection | An old unresolved Attempt resumes its item after schema/backup upgrade |
| `CB-TIME-06` | Replace the legacy field exactly | Every v3 Session validates the tagged union; no `availableTimeRaw` column, sentinel, fallback, or dual write remains in active v3 storage |
| `CB-TIME-07` | Cover new truth in backup and digest | Backup v3 round trip and generation digest change when any context field changes, while deterministic v1/v2 adapters preserve old meaning |

### 21.5 Peek and management

| ID | Requirement | Acceptance rule |
| --- | --- | --- |
| `CB-PEEK-01` | Open a spatial overview | Lid tap moves to a stable overview in normal motion and a static summary in Reduce Motion |
| `CB-PEEK-02` | Protect blind-box content | No title or note is visually readable or exposed through Peek accessibility order |
| `CB-PEEK-03` | Show only supported aggregates | Density, source, and Current Pick appearance derive from documented fields; age appears only when the P1 trace scope is declared |
| `CB-PEEK-04` | Separate Organize | A visible action enters the full Box management surface; no hidden gesture is required |
| `CB-PEEK-05` | Recover camera state | Background/foreground never leaves the scene in an unrecoverable intermediate view |
| `CB-PEEK-06` | Separate physical and drawable counts | Unsupported-duration Active Papers contribute to `inBoxCount`/density but not `drawableCount`; Peek and VoiceOver state both truthfully |

### 21.6 Current Pick and Memories

| ID | Requirement | Acceptance rule |
| --- | --- | --- |
| `CB-LIFE-01` | Project Current Pick | The scene and native card agree with the persisted singleton after launch and every resolution |
| `CB-LIFE-02` | Commit before attachment | Failed Accept does not leave a Paper presented as Current Pick |
| `CB-LIFE-03` | Commit before stamp | Failed completion creates no stamp, memory-seam response, or Memory |
| `CB-LIFE-04` | Derive memory seam | The seam appears whenever persisted Memories are nonempty, without an unlock message |
| `CB-LIFE-05` | Preserve delete truth | Deleting a source Paper removes its derived source-specific visual traces on the next snapshot |

### 21.7 Share to Box

| ID | Requirement | Acceptance rule |
| --- | --- | --- |
| `CB-SHARE-01` | Keep transport truth separate | Extension publication alone never plays or claims main-Box deposit |
| `CB-SHARE-02` | Animate only a fresh materialization | Deposit event is emitted only for a fresh Box Item + Source Reference commit and refetch; `alreadyImported` reconciliation never replays it |
| `CB-SHARE-03` | Aggregate bursts | Four or more freshly committed imports use one bounded aggregate feedback instead of blocking sequential animations |
| `CB-SHARE-04` | Respect recovery | Quarantined or failed envelopes remain in Recovery and produce no success animation |
| `CB-SHARE-05` | Close concurrent idempotency | Two concurrent ingestions of one envelope produce one Item/Source and exactly one transaction-derived fresh outcome; the loser returns `alreadyImported` |
| `CB-SHARE-06` | Bound presentation scheduling | At most one in-memory batch with three IDs is queued; background or 30-second expiry drops it without replay or product change |

### 21.8 Accessibility and degradation

| ID | Requirement | Acceptance rule |
| --- | --- | --- |
| `CB-A11Y-01` | Never require a 3D gesture | Every direct gesture has a visible native and accessibility action equivalent |
| `CB-A11Y-02` | Keep exact text semantic | Titles, notes, errors, times, and actions remain SwiftUI and scale through largest Dynamic Type |
| `CB-A11Y-03` | Respect Reduce Motion | No camera travel, z-axis flight, sustained bounce, or ambient peripheral motion remains enabled |
| `CB-A11Y-04` | Preserve 2D parity | D2 completes Capture → Draw → Accept → Complete → Memories plus all error/recovery states |
| `CB-A11Y-05` | Provide independent settings | Sound, haptics, ambience, Quick animations, and renderer preference can be changed separately and reset under the documented lifecycle |

### 21.9 Performance and privacy

| ID | Requirement | Acceptance rule |
| --- | --- | --- |
| `CB-NFR-01` | Bound scene scale | 5,000 Papers never create more than the renderer’s fixed Paper/entity ceilings |
| `CB-NFR-02` | Meet launch target | Native Home remains interactive within 1.5 seconds on the oldest supported reference device in Release |
| `CB-NFR-03` | Stop background work | Audio, animation, particles, and gesture processing stop within one second of background |
| `CB-NFR-04` | Bundle every asset | Offline archive inspection finds no remote model, texture, sound, font, or environment dependency |
| `CB-NFR-05` | Request no new sensitive permission | Fresh install and complete journey show no camera, location, microphone, Photos, Contacts, Calendar, or notification prompt |
| `CB-NFR-06` | Keep diagnostics content-free | Production logging calls remain audit-prohibited; in-memory/candidate evidence contains no title, note, URL, product identifier or derivative, full path, or user-text screenshot |
| `CB-NFR-07` | Meet measured frame gates | D0/D1 percentile, hitch, memory, thermal, launch, and background budgets pass the frozen physical-device recipes |

---

## 22. Test and evidence strategy

### 22.1 Domain and policy tests

Add deterministic coverage for:

- Every Custom minute boundary from below minimum through maximum.
- Eligibility at 10/30/60/120/240/480 boundaries and values between them.
- Effective fit-bucket mapping and the complete 0/1/2/3/4+ multiplier table.
- Not sure behavior.
- New policy-version fixtures and non-reinterpretation of old Sessions.
- Custom independent-generation schema v2 → v3 migration, all legacy time mappings, union-invalid cases, and an unresolved `mvp-v1` result.
- Backup v1/v2 → v3 adapters, v3 round trip, canonical ordering/checksum/byte ceilings, and generation-digest sensitivity to every context field.
- Existing candidate filtering, freshness, Current Pick, mutation gate, and capacity behavior remaining unchanged.
- `inBoxCount` including unsupported-duration Papers while `drawableCount` excludes them.

### 22.2 Presentation-state tests

Use a pure transition model with injected clock/commands to verify:

- Lid ownership between Capture and Peek.
- Ribbon cancel and one-shot threshold behavior.
- `notCommitted`, `committed`, and post-commit-refetch-failure paths for every animated mutation, including proof that the latter cannot be resubmitted.
- Stale command rejection by sequence/snapshot version.
- Background settlement and foreground reconstruction.
- D0/D1/D2 under Normal/Quick/Reduced Motion reaching the same stable state.
- Renderer switch only at a stable boundary.
- Share import aggregation.
- Fresh-import versus `alreadyImported` replay after commit succeeds but mailbox cleanup is interrupted.
- Concurrent duplicate-envelope ingestion returning exactly one fresh transaction outcome.
- One-batch/three-ID/30-second Share scheduling, coalescing, expiry, and background drop.
- Startup unresolved-result bypass, unsupported-policy actions, Redraw exhaustion, deferred Share refresh, and new-Session Reshuffle.
- Product restore preserving presentation preferences and Erase All resetting the complete namespace.
- Asset failure routing to D2.

### 22.3 Asset contract tests

- Required entity inventory and unique names.
- Identity root and frozen bounds/transforms.
- Lid/ribbon/Paper anchor presence.
- Collision proxy simplicity.
- Build/archive audit of triangle, entity, material, texture, audio, package-size, and provenance budgets; runtime manifest digest and required-anchor validation are tested separately.
- Full and Lite load on minimum/current SDK/runtime.
- Bundle digest and provenance manifest.
- Missing-anchor fixture proving whole-scene 2D fallback.

### 22.4 UI journeys

Automate stable semantic UI journeys for:

- First launch and first Capture.
- Capture save failure preserving draft.
- Preset and 45-minute Custom Draw.
- Ribbon-equivalent native Draw.
- Empty pool.
- Reveal, Accept, Redraw, Dismiss, Current Pick, Done, Put back.
- Force termination during unresolved reveal.
- Launch into an unsupported-policy unresolved result with Accept/Dismiss available and Redraw unavailable.
- Exhausted Redraw followed by deferred Share Recovery and then explicit same-context Reshuffle as a new Session.
- Peek and Organize.
- Shared import after main-app materialization.
- Concurrent duplicate Share import and post-commit refetch failure without a false deposit event.
- Shared Capture Recovery.
- 3D asset failure and explicit 2D setting.
- Restore/erase Recovery without scene construction.
- Simplified Chinese and English.

Coordinate-driven tests do not replace semantic control tests. Targeted 3D gestures require bounded manual/device evidence because screenshot or coordinate automation alone is fragile.

### 22.5 Visual and motion evidence

- Reference screenshots for default, Peek, Current Pick, empty, full, memory-seam, light/dark, and time-of-day states.
- Short recordings for first/normal/rapid/Reduce Motion Capture and Draw.
- Visual review at smallest and largest supported iPhones.
- No Paper-title texture in scene captures.
- No clipping at all Dynamic Type sizes.
- Motion review for bounce, z-axis travel, peripheral movement, and cancellation.

### 22.6 Accessibility evidence

- Automated accessibility audit for every primary screen and major state, not only Home/Settings.
- Manual VoiceOver journey on a physical device.
- Manual Voice Control and Switch Control actions.
- Largest Dynamic Type and keyboard presentation.
- Increase Contrast, Differentiate Without Color, Reduce Transparency, and Reduce Motion.
- 3D gesture versus native-action result parity.
- VoiceOver focus and the one-time result announcement occur only after stable `resultVisible`; no flying Paper exposes duplicate/intermediate semantics.

### 22.7 Performance and device evidence

On the oldest supported reference iPhone and a current iPhone, using a Release build without debugger:

- Cold/warm launch and 3D readiness.
- Main/render/GPU frame time.
- Peak resident memory versus D2.
- Asset load and validation time.
- 50-cycle interaction thermal test.
- Background stop time.
- Ambient-audio route/interruption/background stop with no cue replay and no interruption of other audio.
- Low Power Mode and memory-warning fallback.
- 5,000-Paper fixture with capped scene entities.
- D0/D1/D2 journeys under Normal and Reduced Motion, plus Quick variants for repeated actions.

### 22.8 Local-only and packaged evidence

- Static dependency, source, capability, entitlement, and privacy-manifest audit.
- Existing production-log prohibition plus review of the bounded in-memory health snapshot/candidate artifacts.
- Archive inventory proving every scene/audio asset is bundled.
- Runtime network inspection and App Privacy Report across the complete journey.
- Airplane-mode cold launch, Capture, Draw, Complete, Share ingestion, export, restore, and relaunch.
- Signed packaged candidate on physical devices.

Simulator smoothness, Swift previews, source presence, and a successful unsigned archive are lower evidence levels and cannot close release acceptance.

---

## 23. Delivery plan

Each milestone is a reversible vertical slice with explicit exit evidence. Schema work is versioned and unconditional; renderer rollout uses signed local build configuration rather than remote flags.

### C0 — Contract and baseline freeze

Deliver:

- This document and ADR 0004.
- Current-flow recordings and current performance/accessibility baseline.
- Final product-name decision: no rename in this work.
- Frozen P0/P1/P2 scope and concept ledger.

Exit evidence:

- Product/design/engineering review.
- No unresolved conflict with parent, Share, or Recovery contracts.
- Documentation-only commit; no implementation claim.

### C1 — Asset and renderer spike

Deliver:

- Box, lid, ribbon, pooled Paper, camera, light, and shadow prototype.
- RealityView virtual-camera integration in an internal path.
- 2D placeholder and required-entity validator.
- Initial full/Lite asset variants and budgets.
- Frozen source/interchange format plus separately recorded authoring and production-build hosts; Reality Composer Pro is used only if compatible with the pinned line.
- Deterministic 5,000-Paper and 50-cycle performance fixtures.

Exit evidence:

- Oldest/current device load, frame, memory, and thermal results.
- No camera permission or network.
- Asset source, digest, provenance, and fallback proof.

The spike may be discarded. It does not change product data or public schema.

### C2 — Scene projection and accessibility foundation

Deliver:

- Content-minimized `SceneSnapshot`.
- Interaction coordinator and command sequencing.
- Structured coordinator-facing commit/projection outcomes, including post-commit refetch reconciliation.
- D0/D1/D2 parity shell with Normal/Quick/Reduced Motion variants.
- SwiftUI semantic Box actions and settings.

Exit evidence:

- Pure transition tests.
- Renderer switches with zero product writes.
- Asset-failure 2D journey.
- Initial accessibility audits.

### C3 — Capture and Peek vertical slice

Deliver:

- Resolved lid semantics.
- Commit-gated manual Capture animation.
- Quick Capture variant.
- Peek overview, unreadable content, and Organize routing.

Exit evidence:

- Save failure/interruption tests.
- Capture under 10-second usability direction.
- Peek versus Organize comprehension.
- D0/D1/D2 parity under Normal and Reduced Motion variants.

### C4 — Time-context v2 migration

Deliver:

- Four visible presets, Custom picker, and secondary Not sure.
- Schema v3, backup v3, adapters, migration fixture, and policy version.
- Canonical backup-v3 payload/checksum/limits and generation-digest v3.
- Independent-generation migration operation/reconciliation when it is not already present in candidate source.
- Old unresolved-result preservation.

Exit evidence:

- Full boundary and fixture suite.
- Generation migration/recovery matrix.
- 45-minute eligibility proof.
- No behavior change to Paper Capture duration truth.

This milestone is independently revertible before public schema release. Once a public v3 exists, removal follows normal data compatibility and forward-fix rules.

### C5 — Ribbon Draw and result lifecycle

Deliver:

- Ribbon deformation, threshold, cancellation, and native alternative.
- Commit-gated reveal, redraw, dismiss, and Current Pick attachment.
- Startup unresolved-result bypass, unsupported-policy controls, exhausted-round closure, and new-Session Reshuffle.
- Completion stamp/memory feedback.

Exit evidence:

- One-shot threshold tests.
- Exact persisted-result recovery.
- Current Pick/memory transaction failure paths.
- End-to-end 3D/2D journey.

### C6 — Share feedback, sound, and environment

Deliver:

- Post-materialization individual/aggregate Share deposit feedback.
- Transaction-derived concurrent idempotency result and bounded/expiring presentation queue.
- Bundled sound and independent setting.
- Haptic mapping.
- Local time-of-day lighting and optional ambience.

Exit evidence:

- Transport versus product-truth tests.
- Burst import test.
- Background audio stop.
- No weather/network/location claim or capability.

### C7 — Hardening and packaged acceptance

Deliver:

- Final assets and budgets.
- Complete localization and accessibility.
- Performance degradation policy.
- Release manifest fields and candidate evidence archive.
- Removal of expired internal renderer paths and flags.
- Closure of the parent contract's independent Store Recovery surface, or an explicit decision that Core Box packaged acceptance remains blocked.

Exit evidence:

- `make ci-check` and all new gates.
- Full physical-device matrix.
- Airplane-mode/privacy proof.
- Signed packaged journey.
- Product review confirming the app still feels simple, low-pressure, and non-gamified.

### C8 — P1 trace decision

P1 is not automatically included in the P0 release. Before work begins, decide which traces remain derived and which become user-owned durable data. Approve deletion, backup, restore, capacity, and rollback semantics first.

---

## 24. Rollout, containment, rollback, and removal

### 24.1 Signed local feature manifest

There is no remote configuration. Candidate builds record:

```text
coreBoxRendererVersion
coreBoxAssetVersion
coreBoxAssetDigest
coreBoxInteractionVersion
coreBoxAnimationTimingVersion
coreBoxRendererDefault
coreBoxFallbackPolicyVersion
drawContextVersion
selectionPolicyVersion
schemaVersion
backupFormatVersion
```

Internal flags have an owner, default, introduction milestone, expiry milestone, on/off tests, and removal plan. Migration never depends on a renderer flag.

`Core Box living experience = shipped` means the complete P0 contract, including time-context v2, schema v3, backup v3, and digest v3. A renderer-only prototype remains internal/unreachable and is recorded as `not shipped`; there is no ambiguous “P0 presentation-only” release state.

### 24.2 Distribution sequence

```text
Internal 2D baseline
  → Internal Full/Lite 3D
  → TestFlight physical-device matrix
  → Phased App Store release
```

With no production analytics, evaluation uses consented usability sessions, direct feedback, candidate crash/OS diagnostics within the existing privacy boundary, and candidate-specific manual evidence. No telemetry SDK is added to support rollout.

### 24.3 Containment matrix

There is no remote kill switch. Before distribution, internal build configuration and candidate defaults may contain a defect. After a public build is installed, the developer can only pause the rollout, rely on already-shipped user preferences or deterministic local safety fallback, and issue a forward fix.

| Failure | In-build/local containment | Distribution response | Product data |
| --- | --- | --- | --- |
| Asset missing/corrupt | Automatic D2 for current launch | Pause rollout; forward-fix asset | Unchanged |
| Frame/thermal defect | Settle then automatic D1/D2 under frozen thresholds | Pause rollout; forward-fix budgets/policy | Unchanged |
| Animation defect | Person may choose Quick, Reduced Motion, or D2; presentation interruption may be dropped | Pause rollout; forward-fix; no remote disable claim | Unchanged |
| Targeted-gesture defect | Native buttons remain; person may select D2 | Pause rollout; forward-fix | Unchanged |
| Sound defect | Person turns Sound off; interruption already drops cues | Pause rollout; forward-fix; no remote mute claim | Unchanged |
| Custom-time policy defect | Preserve exact unresolved result; unsupported policy permits Accept/Dismiss only | Pause rollout; forward-fix under a new policy identifier | Preserved through versioned records |
| Schema/backup defect | Existing load/Recovery gates fail closed; never select an empty store | Pause rollout; forward-fix | Never auto-cleared |
| Share feedback defect | An unpresentable ephemeral event may be dropped; mailbox/materialization remains authoritative | Pause rollout; forward-fix; no remote event switch claim | Unchanged |

### 24.4 Source and distribution rollback

- Presentation-only work can be reverted before release while the native paths remain.
- Once schema v3 or backup v3 is public, binary downgrade is not the recovery plan.
- Pause TestFlight/phased release and ship a forward fix from the stable line.
- The v3 build reads supported v1/v2 predecessors through explicit adapters. It does not dual-write legacy Session fields or promise that an older binary can open v3 data.
- An unresolved old-policy result remains accept/dismiss capable even if redraw is unavailable.

### 24.5 Legacy surface removal

The old Home illustration/presentation path is removed only after:

- D0/D1/D2 parity under required Normal/Quick/Reduced Motion variants is proven.
- The new 2D renderer replaces its accessibility and fallback role.
- Two consecutive packaged candidates complete the core journey without using the obsolete path except intentional D2.
- No migration, Recovery, or Share path references it.

Do not keep indefinite duplicate Home implementations under stale flags.

---

## 25. Product validation plan

No production usage analytics are added. Validation is explicit and consent-based.

| Hypothesis | Method | Directional signal |
| --- | --- | --- |
| The Box makes the core loop immediately understandable | First-use moderated task | At least 80% identify Put in and Draw without instruction |
| The object feels personal rather than mechanical | Interview after repeated seeded use | Participants describe it as a container/object, not a slot machine or task list |
| Ribbon interaction adds satisfaction without hiding the action | Compare ribbon and native button paths | Participants discover the ribbon while still recognizing the button alternative |
| Peek differs meaningfully from Organize | Ask participants to inspect then edit one Paper | They use Peek for aggregate understanding and Organize for exact management |
| Motion adds delight without delay | Compare normal, rapid, and Reduce Motion | Normal feels brief; rapid supports repetition; Reduce Motion loses no clarity |
| Custom time remains trustworthy | Seed 30/60-minute Papers and choose 45 minutes | No 60-minute Paper appears; participants understand the exact limit |
| Life traces feel responsive rather than gamified | Revisit after seeded completion/history | Participants notice changes without asking what they must do to unlock more |

The study records observations and participant consent. App Store production remains free of developer-operated analytics.

---

## 26. Risks and mitigations

| Risk | Consequence | Mitigation |
| --- | --- | --- |
| 3D becomes decorative overhead | Core workflow feels slower | Native actions load first; one central object; bounded stage; quick mode |
| Scene becomes product truth | Relaunch and data diverge | One-way snapshot, commit-gated commands, no renderer repository access |
| Ribbon is undiscoverable | People cannot draw | Visible label/button, 44-point target, first-use affordance, accessibility actions |
| Lid semantics conflict | Tap outcome is unpredictable | Tap = Peek; visible Put in = Capture; no direction-sensitive dual meaning |
| Physics creates nondeterminism | Wrong Paper appears or tests flake | Authored motion, pooled reveal Paper, physics never selects |
| 5,000 Papers overload the scene | Frame and memory failure | Density tiers, aggregate meshes, fixed 24/10 Paper ceilings |
| Custom time is implemented as UI-only | Oversized Paper can appear | Time-context v2 + schema v3 + backup v3 + digest-v3 milestone and exact-minute hard gate |
| Semantic Paper forms fake intelligence | User-visible truth fails | Stable non-semantic seed; explicit source-only marks; manual metadata deferred |
| Real weather sneaks into ambience | Local-only boundary breaks | Clock-only P0; no network/location; decorative P1 language |
| Night visuals secretly alter recommendations | Time-only policy breaks | Environment never enters candidate builder |
| “Friend letter” overstates source | Social capability is falsely implied | Call it external import; no identity claim |
| Living traces become achievements | Low-pressure promise collapses | No progress, conditions, levels, rarity, or reward page |
| Durable decoration escapes deletion | Personal history remains unexpectedly | Separate data contract and explicit cascade/backup rules before P1 |
| Reduce Motion is cosmetic only | Core path remains uncomfortable | No camera/z travel, full 2D option, manual device evidence |
| 3D asset fails in a release | Home becomes unusable | Async validation, D2 fallback, bundled digest, packaged tests |
| New assets increase supply-chain risk | License/removal uncertainty | Versioned source, provenance manifest, no remote runtime dependency |
| Duplicate renderer paths linger | Maintenance and truth drift | Evidence-based removal gate and expired-flag deletion |

---

## 27. Definition of Done

The living-experience upgrade is complete only when all of the following are true.

### 27.1 Contract and source

- This document and ADR 0004 are approved and synchronized with the parent/Share contracts.
- The production scene, source assets, 2D renderer, interaction coordinator, and settings exist in source.
- Required assets are bundled, versioned, licensed, and digest-recorded.
- RealityKit is absent from Domain, Application, Data, and Share Extension boundaries.
- No old duplicate Home production path remains beyond the approved D2 renderer.

### 27.2 Functional truth

- A person can Capture, Draw, Accept, Redraw, Dismiss, Complete, Put back, Peek, Organize, and revisit Memories.
- Every success animation follows a committed mutation.
- A post-commit refetch failure enters reconcile without offering a duplicate mutation or claiming that the commit failed.
- Force termination during reveal resumes the exact result.
- Current Pick remains a singleton, blocks a new Draw, and does not block Capture/Peek/Organize.
- 45-minute Custom eligibility is exact.
- Exhausted Redraw ends its Session, refreshes deferred Share/Recovery work, and Reshuffle creates a new Session.
- Share feedback follows one transaction-derived fresh main-app materialization, not envelope publication, count inference, or `alreadyImported` reconciliation.
- `inBoxCount` and `drawableCount` remain distinct in scene density, Peek, Draw, and accessibility.
- Asset or renderer failure changes no product data.

### 27.3 Experience

- First-time users identify Put in and Draw without instruction at the directional target.
- The Box reads as the product’s core object rather than an icon above two buttons.
- Peek feels different from Organize and never reveals Paper text.
- Normal motion is brief, rapid motion supports bursts, and Reduce Motion loses no information.
- No screen, copy, or trace introduces task pressure, reward progress, or unsupported intelligence.

### 27.4 Accessibility and performance

- D0/D1/D2 under required Normal/Quick/Reduced Motion variants complete the same core and recovery journeys.
- Automated audits plus manual VoiceOver, Voice Control, Switch Control, and largest Dynamic Type evidence pass.
- Launch, frame, memory, thermal, background, and asset budgets pass on oldest/current physical devices.
- The 5,000-Paper fixture stays within fixed scene ceilings.

### 27.5 Data and release

- Schema v2 → v3 and backup v1/v2 → v3 evidence pass.
- Active schema v3 contains only the canonical context union; backup v3 and generation digest cover every new field and freeze no future P1 appearance extension.
- Generation migration/recovery interruption evidence passes.
- Full independent Store Recovery required by the parent contract is present; a Retry-only load failure cannot close packaged acceptance.
- Airplane-mode and runtime network/privacy evidence show no app-initiated connection or new sensitive permission.
- A signed packaged candidate completes the same journey as development.
- Candidate manifest records every scene, asset, interaction, policy, schema, and backup version.

If only the model looks polished, the work is not done. If only the simulator is smooth, the work is not done. If 3D works but 2D, Recovery, or VoiceOver does not, the work is not done.

---

## 28. Apple platform references

The following primary sources support the selected rendering and accessibility boundaries. Availability and performance behavior must be rechecked against the pinned toolchain before implementation and every release.

- [RealityView](https://developer.apple.com/documentation/realitykit/realityview)
- [RealityViewCameraContent](https://developer.apple.com/documentation/realitykit/realityviewcameracontent)
- [RealityView virtual camera](https://developer.apple.com/documentation/realitykit/realityviewcamera/virtual)
- [ModelEntity](https://developer.apple.com/documentation/realitykit/modelentity)
- [Loading entities from a file](https://developer.apple.com/documentation/realitykit/loading-entities-from-a-file)
- [Reality Composer Pro](https://developer.apple.com/documentation/realitycomposerpro)
- [InputTargetComponent](https://developer.apple.com/documentation/realitykit/inputtargetcomponent)
- [Responding to gestures on an entity](https://developer.apple.com/documentation/realitykit/responding-to-gestures-on-an-entity)
- [Entity animations](https://developer.apple.com/documentation/realitykit/game-development-entity-animations)
- [DirectionalLightComponent](https://developer.apple.com/documentation/realitykit/directionallightcomponent)
- [Applying realistic material and lighting effects](https://developer.apple.com/documentation/realitykit/applying-realistic-material-and-lighting-effects-to-entities)
- [Improving RealityKit performance](https://developer.apple.com/documentation/realitykit/improving-the-performance-of-a-realitykit-app)
- [Reducing CPU utilization in RealityKit](https://developer.apple.com/documentation/realitykit/reducing-cpu-utilization-in-your-realitykit-app)
- [Reducing GPU utilization in RealityKit](https://developer.apple.com/documentation/realitykit/reducing-gpu-utilization-in-your-realitykit-app)
- [AccessibilityComponent](https://developer.apple.com/documentation/realitykit/accessibilitycomponent)
- [AVAudioSession](https://developer.apple.com/documentation/avfaudio/avaudiosession)
- [Mix with other audio](https://developer.apple.com/documentation/avfaudio/avaudiosession/categoryoptions-swift.struct/mixwithothers)
- [SwiftUI accessibility fundamentals](https://developer.apple.com/documentation/swiftui/accessibility-fundamentals)
- [SwiftUI Reduce Motion environment value](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion)
- [Human Interface Guidelines: Motion](https://developer.apple.com/design/human-interface-guidelines/motion)
- [Human Interface Guidelines: Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)

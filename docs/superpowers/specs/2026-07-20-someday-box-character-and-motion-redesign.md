# someday-box Character, 3D Asset, and Motion Redesign

- Status: Written design pending final user review
- Date: 2026-07-20
- Product: someday-box / 改天盲盒
- Platform: iPhone, iOS 18 or later
- Parent contracts:
  - [`docs/product-requirements-and-technical-foundation.md`](../../product-requirements-and-technical-foundation.md)
  - [`docs/core-box-living-experience-upgrade.md`](../../core-box-living-experience-upgrade.md)
  - [`docs/adr/0004-realitykit-core-box-presentation.md`](../../adr/0004-realitykit-core-box-presentation.md)

## 1. Summary

The Home Box becomes a deliberately authored character: a curious, warm paper spirit with subtle anthropomorphism, restrained idle behavior, a side-mounted sage-green pull ribbon, and a real Blender-authored 3D asset pipeline.

The redesign replaces the production use of runtime box primitives with a bundled, versioned, validated USDZ character. The app continues to use SwiftUI for semantic controls and RealityKit for presentation only. Product mutations remain authoritative: Capture, Draw, Current Pick, and Memory state must commit before the scene performs their success animations.

The approved character direction is:

- subtle anthropomorphism;
- curious and warm rather than mischievous or sleepy;
- paper-crafted maple body with visible folds and restrained fibers;
- paper-inlay eyes, with no mouth, limbs, electronic face, or pressure-oriented emotion;
- a sage-green segmented ribbon fixed at the character's screen-right edge in the default camera;
- low-frequency, interruptible idle micro-actions;
- character presence on Home and key Capture, Draw, reveal, Peek, and Complete transitions;
- paper-material and motion echoes, but no persistent mascot, in Box and Memories.

## 2. Current-State Findings

The redesign addresses verified weaknesses in the current implementation:

1. `CoreBox.usda` is validated by digest, but the Home scene does not load it for rendering. `HomeView` builds a separate scene from RealityKit primitives.
2. Runtime validation currently occurs before `Camera_Default` and `Light_Key` are added, so the Full/Lite scene fails its required-name check and falls back to SwiftUI 2D.
3. The bundled USDA contains placeholder cubes and transforms rather than production topology, UVs, PBR materials, animation clips, collision proxies, or a character rig.
4. The existing `CoreBoxPresentationStateMachine`, snapshots, and commands are not wired to Home.
5. The current `RealityView` has no update closure, so renderer, Paper, Current Pick, and Memory changes do not reliably update an existing scene.
6. The visible pull control is a SwiftUI capsule; it does not deform the 3D ribbon.
7. Capture, Peek, Draw reveal, Complete stamp, and idle character motion are not implemented in the 3D scene.
8. Several AppModel mutation entry points collapse structured use-case results to `Bool`, which is insufficient for distinguishing a failed commit from a committed mutation followed by a projection failure.

The existing uncommitted edits in `Features/Home/HomeView.swift` and `Resources/Localizable.xcstrings` are user-owned work. Implementation must inspect and preserve their intent rather than overwrite, discard, or accidentally include them in an unrelated commit.

## 3. Goals and Non-Goals

### 3.1 Goals

- Give someday-box one recognizable, production-quality 3D protagonist.
- Make the Box feel present, warm, and responsive without creating pressure or constant motion.
- Improve Home composition, gesture correspondence, material response, lighting, transitions, and feedback.
- Use one reproducible authoring, export, validation, packaging, and rollback pipeline.
- Make the asset loaded by RealityKit exactly the asset identified by the candidate-sealed local manifest.
- Preserve native SwiftUI controls, VoiceOver equivalents, functional 2D fallback, and all existing product truth boundaries.
- Integrate deterministic motion into Capture, Draw, reveal, Peek, Current Pick, and Complete flows.
- Prove the result in the current Simulator and on supported physical devices before release.

### 3.2 Non-goals

- No account, backend, CloudKit, analytics, remote assets, ads, LLM, or third-party runtime renderer.
- No AR camera passthrough, room placement, world tracking, or camera permission.
- No arms, legs, mouth, speech bubble personality, sad empty state, angry error state, streak celebration, or urgency cue.
- No full cloth simulation, large rigid-body Paper pile, perpetual physics, continuous oscillation, looping idle audio, or always-on particles.
- No renderer-owned Draw selection, lifecycle mutation, Memory creation, or persistence access.
- No persistent mascot on Box or Memories.
- No new audio production in this redesign. Existing sound preference hooks may remain, but sound content is separately scoped.

## 4. Character and Visual Design

### 4.1 Silhouette

The character reads as a compact paper-crafted keepsake box rather than a shipping carton or treasure chest.

- Width remains dominant over height, with a softly tapered body and visible folded corners.
- The lid is a separate rounded folded form and acts as the character's head.
- The front remains visually open so both eyes read clearly at Home size.
- The sage-green pull ribbon is mounted near the screen-right outer corner in the default camera. It must not cross the face.
- A limited Paper pool is visible behind the lid from the committed `inBoxCount` projection, regardless of Draw eligibility or supported duration. Current Pick and the unresolved reveal Paper remain outside that pool.
- A thin Memory seam is integrated near the lower front edge. It is quietly visible whenever committed `memoryCount` is nonzero, and a newly committed completion adds one bounded glow pulse before returning to that stable intensity.

The final physical envelope remains compatible with the parent contract: approximately 0.30 m wide, 0.18 m high, and 0.22 m deep before final camera-relative tuning.

### 4.2 Expression Channels

The character has four bounded expression channels:

1. `BoxRoot`: weight shift, restrained compression, and small pitch/roll.
2. `LidPivot`: listening, nodding, looking, opening, and closing.
3. Eye pivots or bounded eye-shape deformation: blink and short gaze changes only.
4. `RibbonRoot` through `RibbonTip`: attention, anticipation, drag progress, and delayed settle.

Paper motion and the Memory seam represent product truth rather than free character emotion.

The emotion vocabulary is limited to calm, curious, and warm. Empty is receptive, not sad. A large Box is abundant, not anxious. Current Pick is acknowledged, not nagged. Failure returns quietly to neutral.

### 4.3 Materials and Lighting

The production asset uses four primary PBR material families:

| Material | Visual contract | Runtime notes |
| --- | --- | --- |
| Maple paper body | Warm pale maple, matte, visible folds, restrained paper fiber | Atlas-based base color, normal, roughness, and AO |
| Sage ribbon | Woven, soft-looking, high roughness, slightly darker edges | Segmented or locally rigged; no nondeterministic cloth |
| Moss-ink eyes | Dark green-black paper inlay, semi-matte, small catchlight | No electronic emission or animated display texture |
| Interior / Memory glow | Warm amber transmitted light | Bounded emission; no full-screen bloom or flashing |

Full 3D uses one restrained real-time key shadow and a fill/environment solution. Lite 3D removes the real-time shadow and uses lower-cost lighting. The stage includes a soft contact shadow so the Box has weight and does not appear to float.

Light and dark appearance require separately reviewed backgrounds and contrast, while the character palette remains stable.

## 5. Blender-to-RealityKit Asset Pipeline

### 5.1 Authorization and Tooling

The user authorized installation of Blender on 2026-07-20 and explicitly requested the installation after reviewing this design. Blender 5.2.0 LTS is the pinned authoring and headless-export version for the first pipeline spike. This tool installation does not by itself approve the remaining implementation plan.

The pinned installation record is:

- version: Blender 5.2.0 LTS, build hash `fbe6228777e7`;
- source: the Homebrew `blender` cask using the official Apple Silicon installer at `https://download.blender.org/release/Blender5.2/blender-5.2.0-macos-arm64.dmg`;
- installer SHA-256: `ed4d8390166dec5ea0a2813a03db6221f206ce016442be7f59f41d760972568a`;
- installed application: `/Applications/Blender.app`;
- headless executable: `/opt/homebrew/bin/blender`;
- source file format: Blender 5.2 `.blend`.

The implementation freezes:

- one Blender version;
- the installation source plus a recorded SHA-256 digest of the downloaded installer or package;
- the `.blend` source format version;
- the headless export command;
- Apple USD tool versions;
- the production Xcode version;
- Simulator and physical-device acceptance destinations.

The verified pre-implementation host state is:

| Tool | Current fact on 2026-07-20 | Pipeline status |
| --- | --- | --- |
| Blender | 5.2.0 LTS (`fbe6228777e7`) installed; official installer digest verified; headless launch, code signature, and notarization checks passed | Pinned for the first pipeline spike; any version change requires a reviewed pin and digest update |
| Apple USD Tools | `usdzip` and `usdchecker` 0.25.2 are available | Approved packaging and compliance tools |
| Xcode | 26.6 (`17F113`) | Current build host; release host is pinned again in candidate evidence |
| Reality Composer Pro | 2.0 (`494.100.6`) inside Xcode | Optional inspection/tuning tool after a compatibility spike |
| Reality Converter | Not installed | Not part of the production pipeline |
| Python `pxr` | Not installed | Not assumed by the production pipeline |
| `realitytool` | Available through `xcrun` as the Reality Composer Pro Assets Compiler | Not a USDZ exporter; `.rkassets` to `.reality` use remains unapproved, and the current duplicate-USDKit-class warnings require a spike before any use |

Reality Composer Pro may be used to inspect or tune RealityKit composition after a minimal compile and runtime compatibility spike. It is not the topology source of truth. `realitytool` is not used to package USDZ.

### 5.2 Version-Controlled Layout

The planned source layout is:

```text
Assets/CoreBoxCharacter/
  CoreBoxCharacter.blend
  textures/
    core-box-basecolor.png
    core-box-normal.png
    core-box-roughness.png
    core-box-ao.png
  scripts/
    export-core-box.py
  export-config.json
  provenance.json
  manifest-schema-v1.json
.build/core-box/
  CoreBoxCharacterFull.usda
  CoreBoxCharacterLite.usda
Resources/CoreBoxCharacterFull.usdz
Resources/CoreBoxCharacterLite.usdz
Resources/CoreBoxAssetManifest.json
Generated/CoreBoxAssetIdentity.generated.swift
```

These paths are the fixed initial contract. `.build/core-box/` is ignored intermediate output and is never a runtime dependency. A later path change requires a reviewed design or ADR update together with audit and release-manifest changes.

The production conversion path is exactly:

```text
pinned Blender headless
  -> deterministic Full/Lite USDA
  -> usdzip --arkitAsset --checkCompliance
  -> usdchecker --arkit -t
  -> bundled USDZ
  -> RealityKit load and runtime inventory proof
```

The initial commands are frozen as:

```sh
blender --background Assets/CoreBoxCharacter/CoreBoxCharacter.blend --python Assets/CoreBoxCharacter/scripts/export-core-box.py -- --config Assets/CoreBoxCharacter/export-config.json --output .build/core-box
usdzip Resources/CoreBoxCharacterFull.usdz --arkitAsset .build/core-box/CoreBoxCharacterFull.usda --checkCompliance
usdzip Resources/CoreBoxCharacterLite.usdz --arkitAsset .build/core-box/CoreBoxCharacterLite.usda --checkCompliance
usdchecker --arkit -t Resources/CoreBoxCharacterFull.usdz
usdchecker --arkit -t Resources/CoreBoxCharacterLite.usdz
```

The first spike must verify the exact Blender exporter behavior before these commands become mergeable production gates. Blender is not assumed to emit USDZ directly.

### 5.3 Required Hierarchy

The final scene extends the parent entity contract without weakening it:

```text
BoxRoot
  BoxBody
  LidPivot
    LidMesh
  EyeLeftPivot
    EyeLeftMesh
  EyeRightPivot
    EyeRightMesh
  RibbonRoot
    RibbonJoint_01 ... RibbonJoint_05
    RibbonTip
  PaperPool
    PaperRest_00 ... PaperRest_09  # Full and Lite
    PaperRest_10 ... PaperRest_23  # Full only
  PaperSpawn
  PaperExit
  PaperDeposit
  PaperReveal
  CurrentPaperAnchor
  MemorySeam
  DecorationRoot
  ShadowReceiver
  Hit_Lid
  Hit_Ribbon
  Hit_Box
  Hit_MemorySeam
  Camera_Default
  Camera_Peek
  Camera_Overview
  Light_Key
  Light_Fill
```

Names are unique and stable. `BoxRoot` has identity transform, units are meters, and `+Y` is up. Mesh origins are not substituted for explicit pivots. Hit proxies are simplified invisible geometry.

Full contains exactly 24 Paper rest anchors and Lite contains exactly 10. The ten Lite names are the shared prefix of the Full inventory. Tier-specific manifests list the exact allowed names; a missing, extra, or out-of-range Paper rest anchor fails the asset audit.

`RibbonRoot` is authored on the character's local side that renders at screen right under `Camera_Default`. The export audit validates this rest transform and verifies that no supported pull pose crosses either eye's projected safe region.

### 5.4 Geometry and Runtime Budgets

The redesign tightens targets beneath the parent release ceilings and adds machine-comparable character ceilings:

| Resource | Full target | Full hard ceiling | Lite target | Lite hard ceiling |
| --- | ---: | ---: | ---: | ---: |
| Visible triangles | 40,000 | 60,000 | 16,000 | 25,000 |
| Visible renderable entities | 60 | 80 | 30 | 36 |
| Individual visible Papers/rest anchors | exactly 24 | 24 | exactly 10 | 10 |
| PBR material slots | 6 | 8 | 4 | 6 |
| Shadow-casting lights | 1 | 1 | 0 | 0 |
| Total dynamic lights | 2 | 2 | 1 | 1 |
| Largest texture dimension | 2,048 square | 2,048 square | 1,024 square | 2,048 square |
| Resident texture acceptance | 32 MiB | 32 MiB | 16 MiB | 16 MiB |
| Discrete animation resources | exactly 13 | 13 | exactly 13 | 13 |
| Parameterized ribbon channels | exactly 1 | 1 | exactly 1 | 1 |
| Added audio resources | 0 | 0 | 0 | 0 |
| Packaged tier asset size | 12 MiB | 16 MiB | 5 MiB | 8 MiB |

The aggregate packaged Full + Lite + manifest addition targets 17 MiB and has a 20 MiB hard ceiling. Lite's 1,024-square texture value remains the preferred target inherited from the parent contract; the explicit 2,048-square hard ceiling prevents an accidental larger asset while allowing a reviewed candidate to miss the preferred target without pretending the parent made 1,024 a hard limit. Resident texture and package values are release acceptance ceilings for this redesign; changing one requires a reviewed manifest and measured device evidence.

The Full and Lite exports share semantic entity names and motion end states. Lite may simplify topology, Paper pool size, texture resolution, lighting, and secondary deformation; it may not remove a product interaction.

### 5.5 Export and Audit

The export task must run without Blender UI and fail closed when:

- the pinned Blender version is unavailable;
- required collections or objects are missing or duplicated;
- a required pivot, anchor, hit proxy, camera, or light is invalid;
- units, axes, scale, or root transform differ from the contract;
- Full or Lite exceeds its budget;
- textures are missing, oversized, or referenced outside the repository;
- unsupported modifiers or unapplied transforms make export nondeterministic;
- USD compliance fails;
- RealityKit cannot load the exported hierarchy or expose the required discrete animation inventory;
- the parameterized ribbon channel lacks its exact rest, threshold, or maximum pose;
- either tier differs from its exact Paper, clip, material, audio, or package inventory;
- two clean-checkout exports from the same pinned inputs and normalized environment do not produce identical normalized USDA and packaged SHA-256 digests.

The production scripts run `usdzip --arkitAsset --checkCompliance` and then `usdchecker --arkit -t` for each tier. A successful package operation alone is insufficient; both commands must exit zero and the packaged file must pass the later archive and Runtime RealityKit checks.

The committed manifest records a canonical authoring-source tree digest, source and packaged digests, byte counts, tool versions, tier-specific entity inventory, discrete animation inventory, parameterized-channel samples, default transforms, bounds, geometry/material/texture/audio counts, provenance, and asset schema version. The candidate commit belongs to the external release manifest to avoid a self-referential Git commit identity.

### 5.6 Candidate-Sealed Asset Identity

`CoreBoxAssetManifest.json` validates against `manifest-schema-v1.json` and has the following required shape:

```json
{
  "schemaVersion": 1,
  "manifestCanonicalizationVersion": "raw-utf8-v1",
  "authoringTreeDigestVersion": "path-sha256-v1",
  "assetVersion": "core-box-character-v1",
  "authoringTreeSHA256": "64 lowercase hex characters",
  "toolchain": {},
  "tiers": {
    "full": {
      "resourceName": "CoreBoxCharacterFull.usdz",
      "sha256": "64 lowercase hex characters",
      "byteCount": 0,
      "paperRestCount": 24,
      "requiredEntities": [],
      "clips": [],
      "parameterizedChannels": [],
      "budgets": {}
    },
    "lite": {
      "resourceName": "CoreBoxCharacterLite.usdz",
      "sha256": "64 lowercase hex characters",
      "byteCount": 0,
      "paperRestCount": 10,
      "requiredEntities": [],
      "clips": [],
      "parameterizedChannels": [],
      "budgets": {}
    }
  },
  "provenance": {}
}
```

The zero and empty container values above illustrate schema shape only. A production manifest must populate positive byte counts, every exact required entity and clip, the `ribbon.pull` samples, measured budgets, and complete provenance; the schema rejects placeholder inventories.

`path-sha256-v1` covers the `.blend`, textures, export script, export config, provenance, and schema inputs. It sorts repository-relative POSIX paths by UTF-8 byte order and hashes the concatenation `path UTF-8 + NUL + raw-file SHA-256 lowercase hex + LF` for every file. Generated USD/manifest/Swift outputs are excluded, so the source digest is not self-referential.

`raw-utf8-v1` means the manifest generator emits UTF-8 without a BOM, LF line endings, lexicographically sorted object keys at every depth, finite JSON numbers, no insignificant trailing whitespace, and exactly one final newline. Identity is SHA-256 over those exact validated file bytes. The generator, Swift runtime, source audit, and archive audit must hash the raw bytes directly; none may parse and reserialize the manifest to derive identity. A canonicalization rule change requires a new `manifestCanonicalizationVersion`, schema review, generated-identity change, and migration/rollback fixtures.

The checked-in manifest does not establish trust by declaring its own asset SHA. The build performs these bindings:

1. clean export and audit produce Full/Lite packaged SHA-256 digests;
2. schema validation and the `raw-utf8-v1` exact-byte rules produce the asset-manifest SHA-256 digest;
3. the authoring export generates `CoreBoxAssetIdentity.generated.swift` with the expected schema version, canonicalization and authoring-tree digest versions, asset version, exact-byte manifest digest, and both packaged tier digests;
4. those constants are compiled into the executable;
5. archive signing seals the executable, both USDZ resources, and the manifest in the same candidate bundle;
6. the external candidate release manifest records the candidate commit, authoring-tree digest, archive SHA-256, application code-signing identity/CDHash, asset-manifest digest, and both tier digests.

At runtime, the signed executable compares its compiled expected identity with the exact bundled manifest bytes, then compares the selected tier's bundled bytes with the tier digest. Only after both checks pass may structural loading begin; a runtime digest, schema, tier, clip, or entity mismatch fails closed to 2D. The archive audit independently recomputes every digest from the signed `.xcarchive`, verifies the resource seal, and matches them to the external candidate manifest. A missing or unsealed resource blocks candidate promotion.

## 6. Motion Language

### 6.1 Shared Grammar

Every character action uses three beats:

```text
anticipate -> act -> settle
```

- The heavy Box body leads.
- Eyes, Papers, and ribbon may follow by 80 to 150 ms.
- Normal root displacement is approximately 1 to 2 mm.
- Normal root scale change is approximately 0.5% to 1.5%.
- Routine lid/root rotation is approximately 2 to 4 degrees.
- Every action has a deterministic stable end pose.
- A higher-priority command may interrupt an action at any time.

### 6.2 Idle Scheduling

Idle is an optional cancellable presentation layer, not a business or interaction state.

- Stable Home schedules an idle opportunity every 12 to 24 seconds using an injected clock and stable seed.
- The scheduler may choose blink, listen, Paper rustle, or Current Pick glance when their preconditions are true.
- An idle micro-action lasts approximately 0.8 to 1.2 seconds.
- Only one idle action runs at a time.
- Direct touch, gesture, sheet presentation, mutation, renderer change, background, or root gate cancels idle immediately.
- Stable idle performs no per-frame work, continuous physics, particle loop, or audio loop.

### 6.3 Authored Animation and Parameter Contract

Full and Lite assets expose the same exact set of 13 non-looping `availableAnimations` resources. The scheduler or coordinator may invoke a resource more than once, but no resource contains an infinite loop.

| Exact resource name | Canonical asset duration | Stable terminal pose |
| --- | ---: | --- |
| `idle.blink` | 340 ms | Neutral closed-Box pose |
| `idle.listen` | 1,000 ms | Neutral closed-Box pose |
| `idle.paperRustle` | 900 ms | Neutral pose with current stable Paper slots |
| `idle.currentGlance` | 820 ms | Neutral pose with Current Pick unchanged |
| `react.touch` | 200 ms | Neutral pose |
| `react.notice.single` | 460 ms | Neutral pose with rebuilt stable Paper density |
| `react.notice.aggregate` | 620 ms | Neutral pose with rebuilt stable Paper density |
| `capture.receive` | 300 ms | Stable `captureOpen` pose |
| `capture.deposit` | 560 ms | Stable closed pose from the verified post-capture snapshot |
| `draw.reveal` | 750 ms | Stable semantic `resultVisible` pose |
| `current.attach` | 420 ms | Stable `currentAttached` pose |
| `paper.return` | 500 ms | Stable closed/armed pose before any next reveal command |
| `memory.stamp` | 650 ms | Stable closed pose with the committed Memory seam state |

The canonical resource duration is the asset sample duration, not a promise that every presentation variant plays at that wall-clock duration. The coordinator applies deterministic speed selection inside the inherited First, Normal, Rapid, and Reduce Motion ranges in Section 6.5. Reduced Motion does not play these depth-motion resources; it applies their stable terminal state immediately with the specified fade.

`draw.pull(progress)` is not a discrete clip and must not be implemented with `playAnimation`. Both tiers expose one manifest-described parameterized channel named `ribbon.pull`, sampled at these exact authored poses:

| Sample | Progress | Meaning |
| --- | ---: | --- |
| Rest | `0.00` | Exact armed rest transforms |
| Threshold | `0.72` | Tension pose used when threshold feedback first latches |
| Maximum | `1.00` | Maximum reviewed pull without face or body intersection |

The channel contains local transforms for `RibbonRoot`, `RibbonJoint_01...05`, `RibbonTip`, and the bounded `BoxRoot` lean. Runtime clamps input to `0...1`, uses smoothstep within the `0...0.72` and `0.72...1.0` segments, linearly interpolates translation/scale, and uses shortest-arc quaternion interpolation for rotation. Release/cancel samples from the current pose back to Rest; a threshold crossing only updates the feedback latch. The Full and Lite sample transforms may differ, but names, progress samples, safe regions, and terminal semantics are identical.

The pipeline spike must load each tier through RealityKit on Simulator and a physical device, compare the unordered `availableAnimations` name set with the exact 13-name manifest inventory, play every resource to its stable terminal pose, and sample `ribbon.pull` at `0`, `0.72`, and `1`. Acceptance records transform tolerances, screenshots, eye-safe-region checks, and the absence of NaN, missing-resource, or hierarchy-detachment failures.

### 6.4 Approved Motion Vocabulary

| Motion | Trigger and truth boundary | Normal presentation |
| --- | --- | --- |
| `idle.blink` | Stable visible Home | One irregular blink, then neutral |
| `idle.listen` | Stable visible Home | Lid raises 2 to 4 degrees, root leans slightly, ribbon follows, then settle |
| `idle.paperRustle` | Committed visible Paper pool is non-empty | One or two pooled Papers move within bounded slots |
| `idle.currentGlance` | A committed Current Pick exists | Short eye/root acknowledgement toward the current Paper, with no urgency |
| `react.touch` | Direct Box touch | 120 to 260 ms weighted compression and restrained rebound |
| `react.notice` | A fresh local Share import batch commits and its projection is verified | One to three arrivals receive bounded individual beats; four or more receive one aggregate notice. Already-imported entries, ordinary refresh, expiry, background drop, and Recovery do not animate |
| `capture.receive` | Capture presentation begins | Lid opens and character makes visual room before the native editor owns focus |
| `capture.deposit` | Capture commit and verified projection succeed | Visual Paper folds, drops, body receives weight, and lid closes within the applicable parent timing range |
| `draw.pull(progress)` | Eligible ribbon drag | Ribbon continuously follows normalized progress; Box leans at most 2 degrees |
| `draw.threshold` | Armed progress first crosses `0.72` | Latch and give one optional haptic only; no Draw intent is emitted until release, and hysteresis prevents repeated feedback |
| `draw.cancel` | Release below threshold or cancellation | Ribbon and pooled Papers settle to exact rest pose |
| `draw.reveal` | Draw Attempt commit and verified projection succeed | Short anticipation, bounded Paper shuffle, and one reveal Paper exit within the applicable parent timing range |
| `current.attach` | Accept commit and verified Current Pick projection succeed | Reveal Paper moves to Current anchor; character gives one small nod |
| `paper.return` | Put back, dismiss, or redraw transition commits and its projection is verified | Paper folds and returns before the next stable or correlated reveal pose |
| `memory.stamp` | Complete commit and Memory projection succeed | Soft stamp, small nod, and one Memory seam glow within the applicable parent timing range |
| `failure.settle` | Mutation did not commit | Code-sampled settle returns prepared parts quietly; no shake, sadness, or false success motion |
| `fallback.settle` | Renderer degrades | Code-sampled settle returns current motion to a stable pose, then presentation cross-fades without product mutation |

### 6.5 Motion Variants and Timing

This redesign adopts, and does not lengthen or replace, the parent contract's timing matrix:

| Motion | First/slow | Normal | Rapid | Reduce Motion |
| --- | ---: | ---: | ---: | --- |
| Lid open or close | 350–450 ms | 240–320 ms | 120–180 ms | State swap + 120 ms fade |
| Capture fold and deposit | 650–900 ms | 380–560 ms | 180–260 ms | 150 ms fade/scale |
| Ribbon return below threshold | Gesture-tracked + 220 ms | Same | Same | Immediate + light fade |
| Post-commit shuffle and exit | 700–1,000 ms | 500–750 ms | 260–420 ms | 150–220 ms cross-fade |
| Peek camera transition | 450–650 ms | 350–500 ms | 180–260 ms | No camera travel; content fade |
| Completion stamp and settle | 600–900 ms | 400–650 ms | 220–350 ms | Immediate state + short fade |

The candidate assigns a new `coreBoxAnimationTimingVersion` because the resource and parameter-channel inventory changes, while retaining these timing ranges unchanged. Any future range change requires an explicit parent-contract update and another timing-version increment.

- Normal includes the approved anticipation, action, and settle timing.
- Quick shortens anticipation and settle but preserves the same stable states and product sequencing.
- Reduced removes camera movement, Paper flight, bounce, idle, and sustained depth motion. It enters the authoritative stable end state with a 120 to 220 ms opacity or material fade and optional semantic haptic.

Reduce Motion is independent of renderer choice. Lite 3D is an automatic safety tier, not a user-facing renderer preference.

The renderer preference contract becomes `Automatic / Full 3D / Simplified 2D`, with `Automatic` as the default. On the one-time preference namespace migration, a stored `.lite3D` value maps to `Automatic`, `.full3D` maps to `Full 3D`, and `.swiftUI2D` maps to `Simplified 2D`. Lite remains an internal automatic tier and is removed from Settings as a selectable value.

### 6.6 Renderer Preference Namespace Migration

The new namespace is exactly `core-box-presentation-v2`. Migration from `core-box-presentation-v1` is deterministic and idempotent:

1. if the v2 `migrationCompleted` marker exists, read only valid v2 values, ignore v1 values, and finish idempotent cleanup of any leftover v1 keys;
2. otherwise read v1 once, map renderer `.lite3D -> Automatic`, `.full3D -> Full 3D`, and `.swiftUI2D -> Simplified 2D`, and copy valid Quick animations, ambience, sound, haptics, last-context, and first-animation flags without changing their meaning;
3. write all v2 values first and write `migrationCompleted` last, so interruption before the marker safely retries the same mapping;
4. after the marker is durable, remove the obsolete v1 keys; a downgrade may reset presentation preferences but never product data;
5. unknown or malformed source values use the documented safe defaults and do not invalidate product data;
6. Erase All removes both v1 and v2 namespaces, the migration marker, last context, and first-animation flags.

`coreBoxPreferenceNamespaceVersion = core-box-presentation-v2` is required in the external candidate manifest. Tests cover every renderer mapping, all copied independent preferences, interruption before each write boundary, repeated migration, malformed values, Erase All, and the rule that presentation preferences never enter product backup.

## 7. Experience Integration

### 7.1 Home

Home makes the Box the primary visual object while preserving native semantic actions.

- The character stage has enough height for readable silhouette, contact shadow, side ribbon, and Paper exit path.
- The primary native actions remain visible and accessible beneath the stage.
- A Box-body touch triggers `react.touch` and then the existing Peek affordance only when the target action is unambiguous.
- The lid has a targeted Peek hit proxy.
- The right-side ribbon has a targeted Draw hit proxy, a minimum 44-point equivalent SwiftUI hit area, and business-state enablement identical to the Draw button.
- Stage summary text remains SwiftUI, not scene texture.
- Current Pick remains a semantic SwiftUI surface; the character visually acknowledges it without replacing its Done and Put Back actions.

### 7.2 Capture

1. Put In emits a presentation intent and begins `capture.receive`.
2. The native Capture editor becomes authoritative for text, duration, validation, cancellation, and errors.
3. Cancel settles the character without a deposit.
4. Save calls the application use case.
5. Only a committed outcome plus verified projection emits `capture.deposit`.
6. Deposit completion returns Home to the new stable Paper projection.

### 7.3 Draw and Reveal

1. Home presents the parent contract's visible time presets plus Custom and Not Sure when no Current Pick or unresolved result exists.
2. Selecting a context arms the ribbon and the native Draw button with the same exact context value.
3. Ribbon input is enabled only when that context is selected and the native Draw action is enabled.
4. Drag progress continuously deforms the 3D ribbon and the equivalent 2D affordance.
5. Crossing `0.72` only latches threshold feedback. It does not open Draw Context, select a Paper, or call a use case.
6. Falling below `0.55` while still dragging resets only the threshold-feedback latch. Releasing below `0.72`, cancellation, a second finger, or view interruption returns to armed state and emits no Draw intent.
7. Releasing at or above `0.72` emits exactly one Draw intent with the already selected context and locks repeated submission until the use case returns.
8. The Draw use case filters, selects, and persists the unresolved attempt.
9. The root unresolved-result gate immediately presents the exact persisted SwiftUI semantic result and remains authoritative.
10. The reveal surface may use the same character asset and coordinator vocabulary for a disposable `draw.reveal` enhancement, but semantic result availability never waits for the applicable 260 to 1,000 ms presentation variant or for a complete Home scene to initialize.
11. VoiceOver and Reduced Motion move immediately to the stable semantic result after truth is projected. A missing, interrupted, or degraded reveal clip cannot delay focus or alter the result.
12. Accept, Redraw, and Dismiss animate only from their own committed-and-projected outcomes.

This section preserves the parent contract's **choose time, then pull** flow. It intentionally replaces the current prototype behavior in which the ribbon opens Draw Context after release. The animation never chooses the Paper and never makes an unresolved Attempt dismissible before the existing gate allows it.

### 7.4 Peek

- Lid tap or the native Peek action emits one intent.
- The lid opens around `LidPivot` and the virtual camera moves to the reviewed overview pose in Normal/Quick modes.
- SwiftUI owns count labels, actions, and accessibility semantics.
- Reduced Motion switches directly to the stable Peek composition with a short fade.
- Closing Peek resets camera and lid before idle can resume.

### 7.5 Complete and Memories

- Done calls the existing Complete use case.
- A committed Completion Memory projection triggers `memory.stamp`.
- Box and Memories adopt matching paper surfaces, warm seam accents, and restrained native transitions.
- The 3D character does not persist as a mascot in those tabs.

### 7.6 Share Arrival

- A Share arrival animation requires a newly committed import batch and its verified projection.
- A batch of one to three Papers may use short sequential notice beats within one bounded presentation.
- A batch of four or more uses one aggregate notice and directly rebuilds the stable Paper density.
- `alreadyImported`, routine snapshot refresh, expired presentation, background drop, and Shared Capture Recovery never replay a success animation.
- Recovery remains a semantic SwiftUI gate and does not load the 3D scene as a prerequisite.

## 8. Presentation Architecture

### 8.1 Components

The implementation introduces or completes these bounded presentation components:

- `CoreBoxPresentationCoordinator`: owns presentation serialization, command priority, cancellation, stable poses, renderer policy, and snapshot correlation.
- `CoreBoxAssetLoader`: asynchronously loads Full/Lite assets and fails closed to 2D.
- `CoreBoxAssetValidator`: validates manifest identity and cheap runtime structural invariants.
- `CoreBoxSceneAdapter`: maps snapshots and commands onto RealityKit entities and animation resources.
- `CoreBox2DAdapter`: maps the same stable states and motion vocabulary onto functional SwiftUI 2D.
- `CoreBoxIdleScheduler`: injected clock and stable seed; no global random source.
- `CoreBoxInteractionSurface`: owns SwiftUI hit regions, native actions, accessibility actions, and normalized targeted gesture progress.

The existing pure Foundation presentation types remain the preferred location for deterministic state transitions. RealityKit types stay in the app presentation layer.

### 8.2 Data Flow

```text
SwiftUI native action or targeted 3D gesture
                    |
                    v
             UserIntent
                    |
                    v
Application use case + MutationArbiter
                    |
                    v
structured commit result + verified projection
                    |
                    v
CoreBoxSceneSnapshot + correlated command
             /             |             \
            v              v              v
       Full/Lite 3D   SwiftUI 2D   Reduced motion
```

The renderer owns no repository, model context, Draw RNG, lifecycle rule, restore state, or mutation lock.

### 8.3 Structured Outcomes

Presentation-triggering AppModel methods must expose enough information to distinguish:

1. not committed;
2. committed and projected;
3. committed but projection refresh failed.

Only outcome 2 plays a correlated transient success animation. Outcome 1 settles and displays the native error. Outcome 3 preserves the committed fact, blocks duplicate mutation, enters read-only projection reconciliation, and permanently drops that occurrence's deposit, reveal, attach, stamp, or notice animation. When projection later succeeds, the scene rebuilds only the current stable pose; it never infers or replays old success motion from a count delta or delayed refetch.

Command acceptance validates both monotonically increasing sequence and source snapshot version. A command produced from stale truth is dropped and rebuilt, not replayed.

### 8.4 RealityView Lifecycle

- The make closure asynchronously loads and validates the bundle asset while SwiftUI presents a stable 2D placeholder and usable actions.
- The update closure applies snapshot and command changes to the loaded hierarchy.
- Per-frame updates exist only during a continuous gesture or actively sampled animation that requires them.
- Scene subscriptions are stored and explicitly cancelled at stable idle, teardown, renderer transition, and background.
- A fresh foreground projection rebuilds stable pose rather than resuming an interrupted animation.

## 9. Priority, Interruption, and Failure

### 9.1 Ownership Priority

Highest to lowest:

1. root Recovery and unresolved-result gates;
2. background, teardown, renderer transition, and reconciliation;
3. committed transaction presentation;
4. direct continuous gesture;
5. one-shot touch or notice reaction;
6. idle micro-action.

Only one owner may control each lid, ribbon, Paper, eye, camera, or root transform channel at a time. An interruption settles from the current sampled pose to a reviewed stable pose; it does not snap through intersecting geometry.

### 9.2 Failure and Degradation

| Trigger | Presentation response | Product response |
| --- | --- | --- |
| Missing/corrupt/digest-mismatched asset | Reject 3D for the launch and cross-fade to 2D | All native product actions remain available |
| Required node, pivot, hit proxy, material, or clip missing | Reject the complete 3D scene; no partial character | Same functional 2D path |
| Low Power Mode | Apply `effectiveTier = min(userPreferredMaximum, lite3D)` at a stable boundary, under the order `swiftUI2D < lite3D < full3D` | No product action is disabled and an explicit 2D preference is never upgraded |
| Sustained frame-budget failure or thermal pressure | Full to Lite, then 2D if required | No data mutation or retry loop |
| Memory warning | Settle and degrade one tier; a repeated warning can select 2D | Preserve current flow and semantic controls |
| App background or covering gate | Cancel gestures, animation, particles, and idle within one second | Rebuild from current truth on return |
| Mutation did not commit | `failure.settle`; no success motion | Native error and retry remain authoritative |
| Commit succeeded but projection failed | Enter reconciliation and permanently drop that occurrence's transient success animation; later rebuild only the stable pose | Preserve committed data and prevent duplicate mutation |

The app never downloads a replacement asset, loops retries, auto-clears data, or blocks Recovery because 3D is unavailable.

Every automatic degradation treats the user's renderer preference as a maximum quality tier. `Automatic` may begin at Full and fall to Lite or 2D; `Full 3D` may fall for safety; `Simplified 2D` always remains 2D, including under Low Power Mode.

For tier calculation, `userPreferredMaximum(Automatic) = full3D`, `userPreferredMaximum(Full 3D) = full3D`, and `userPreferredMaximum(Simplified 2D) = swiftUI2D`.

## 10. Accessibility and Input Parity

- Decorative 3D entities remain hidden from the primary SwiftUI accessibility tree unless a tested RealityKit accessibility enhancement adds value.
- Every lid, ribbon, Box, and Memory seam action has a visible native control or explicit accessibility action.
- Business enablement is shared. Before a context is selected, or whenever the native Draw action is disabled, the ribbon accepts no effective pull, latches no threshold feedback, and emits no Draw intent.
- VoiceOver receives state summaries from committed SwiftUI data, not inferred scene transforms.
- Successful reveal moves accessibility focus to the stable semantic result as soon as presentation truth is projected, independently of whether the optional character clip starts or finishes.
- Largest Dynamic Type must not overlap the stage summary, native actions, or ribbon hit area.
- Voice Control and Switch Control use semantic SwiftUI labels and actions.
- Reduce Motion behavior follows the approved static-state contract.
- New character-layer haptics are limited to threshold latch, committed deposit/reveal, and completion. Existing native time-preset selection feedback remains intact. Every haptic obeys the independent Haptics setting and never compensates for missing visual meaning.

## 11. Testing and Acceptance

### 11.1 Asset Tests

- Headless Blender export from a clean checkout.
- Full and Lite USD compliance.
- Required names are unique with correct parentage, pivots, transforms, bounds, and coordinate system.
- `RibbonRoot` rest location is screen-right in the default camera and all pull samples remain outside the eye safe regions.
- Required animation resources are visible to RealityKit with stable names and reviewed durations.
- The exact 13-resource set and one `ribbon.pull` parameterized channel pass on both tiers.
- Compiled expected identity, `raw-utf8-v1` exact-byte manifest digest, and both exact packaged runtime-asset digests match.
- Geometry, entity, material, texture, animation, audio, package-size, and provenance budgets pass.
- Missing-node, duplicate-node, wrong-digest, oversized-texture, and missing-clip fixtures fail closed.

### 11.2 Logic Tests

- Snapshot truncation and deterministic Paper slot mapping.
- Command sequence and snapshot-version rejection.
- Interaction priority and one-owner-per-channel rules.
- Threshold latch, hysteresis, cancel, and exact ribbon rest pose.
- Seeded idle schedule, preconditions, cancellation, and zero stable-idle work.
- Normal, Quick, and Reduced variants reach identical stable product poses.
- Not-committed, committed-and-projected, and committed-projection-failed outcomes.
- Full to Lite to 2D degradation only at allowed stable boundaries.
- Background and foreground rebuild behavior.

### 11.3 Integration and UI Tests

- Capture cancel versus committed deposit.
- Ribbon enablement equals native Draw enablement.
- Choosing time arms the ribbon; crossing threshold only latches feedback; release below `0.72` cancels and release at or above `0.72` emits exactly one Draw intent without reopening context.
- Persisted unresolved Attempt precedes reveal.
- Accept, Redraw, Dismiss, Put Back, and Complete animate only after authoritative outcomes.
- Asset failure keeps Capture, Draw, Peek, Current Pick, Memories, Settings, and Recovery usable through 2D.
- Fresh Share batches use one-to-three bounded beats or one four-plus aggregate notice; already-imported, refresh, expiry, background-drop, and Recovery paths never replay it.
- Stored `.lite3D` preference migrates once to `Automatic`, while Full 3D and Simplified 2D retain their user meaning.
- Low Power Mode maps Automatic or Full 3D to no higher than Lite and leaves Simplified 2D at 2D.
- VoiceOver, Voice Control, Switch Control, largest Dynamic Type, Reduce Motion, Low Power Mode, light appearance, and dark appearance.
- Stable result focus and no duplicate accessibility announcement.

### 11.4 Runtime Evidence

- Current iPhone Simulator build, unit tests, UI tests, screenshots, and interaction recording.
- Oldest supported and current physical-device asset load and behavior.
- Full 3D 60-second Capture/Peek/Draw trace with frame-time p95 at or below 16.7 ms and frames over 33.3 ms at or below 1%.
- Lite 3D trace with frame-time p95 at or below 33.3 ms and frames over 66.7 ms at or below 1%.
- Full 3D peak resident-memory increase target no more than 120 MiB over the same 2D journey.
- Fifty-cycle stress recipe without thermal serious/critical, scene leaks, duplicated subscriptions, or stale motion.
- Archive inventory proves both assets and manifest are bundled, no remote runtime dependency exists, and no camera entitlement or usage string was added.

Simulator smoothness is visual evidence only; physical-device Instruments evidence is required for release performance claims.

### 11.5 Executable Gates and CI Wiring

Implementation adds `core-box-export`, `core-box-repro-check`, `core-box-asset-audit`, and `core-box-package-audit` Make targets. `core-box-export` is an explicit authoring command that writes reviewed source outputs; it is never called by candidate verification. From an already-clean checkout at the candidate SHA, the local/CI gate is read-only with respect to tracked and untracked source:

```sh
test -z "$(git status --porcelain)"
candidate_sha="$(git rev-parse HEAD)"
make core-box-repro-check CHECKED_OUT_ASSETS="$PWD"
make core-box-asset-audit
make audit
make ci-check SIMULATOR_DESTINATION='platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' RESULT_BUNDLE_PATH="$PWD/.build/test-results/CoreBox-${candidate_sha}.xcresult"
git diff --exit-code
test -z "$(git status --porcelain)"
```

`core-box-repro-check` creates two isolated export directories from the clean candidate checkout with the pinned Blender and Apple USD tools, runs the exact `usdzip`/`usdchecker` commands in Section 5.2, and compares both isolated normalized USDA and packaged SHA-256 digests. It then byte-compares each isolated Full/Lite USDZ, `CoreBoxAssetManifest.json`, and `CoreBoxAssetIdentity.generated.swift` against its committed runtime counterpart. It never writes into the checkout. Any cross-run or committed-artifact difference fails. `core-box-asset-audit` validates the JSON schema; `raw-utf8-v1` bytes and candidate-sealed identity; Full/Lite entity, Paper, clip, and parameter inventories; transforms and bounds; geometry, material, texture, animation, audio, and package budgets; and provenance. `make audit` invokes the non-exporting form of that audit against committed runtime artifacts. `make ci-check` gains `RESULT_BUNDLE_PATH` plumbing so the `.xcresult` filename and metadata identify the exact candidate SHA.

The GitHub macOS 26 workflow pins and checksum-verifies Blender, then runs `make core-box-repro-check` and `make ci-check`. It uploads the candidate-SHA `.xcresult`, normalized export comparison, USD compliance logs, canonical asset manifest, and budget report. A runner lacking the pinned Blender version fails rather than skipping the asset gate.

For a signed candidate archive, the executable package gate is:

```sh
make core-box-package-audit ARCHIVE_PATH=/absolute/path/to/SomedayBox.xcarchive RELEASE_MANIFEST_PATH=/absolute/path/to/candidate-manifest.json
```

That target verifies the archive code signature, bundle identifier/version/build, archive digest, compiled expected identity, sealed asset-manifest digest, Full/Lite resource inventory/digests, `usdzip -l` contents, absence of remote asset dependencies and new audio/camera capabilities, and equality with the external release manifest. Promotion additionally requires installing that exact signed candidate on the named oldest and current reference devices, proving `availableAnimations` and all three `ribbon.pull` samples for both tiers, running the core journeys, and attaching physical-device logs/screenshots/Instruments traces to the same candidate evidence record. Simulator or unsigned archive evidence cannot substitute.

## 12. Release, Rollback, and Operations

The redesign is a hard replacement of the obsolete production 3D path after parity evidence passes.

- The programmatic primitive scene remains only as a deterministic test fixture or explicit development diagnostic, not a silent production fallback.
- Functional SwiftUI 2D remains the production safety renderer.
- The release manifest bumps renderer, asset, interaction, and animation-timing contract versions together when their behavior changes.
- The signed candidate records Blender, USD tool, Xcode, asset, manifest canonicalization, renderer, interaction, animation timing, preference namespace, schema, backup, and Draw-policy versions.
- Candidate promotion remains blocked until asset, logic, UI, device, performance, archive, and rollback evidence is complete.
- A bad 3D candidate is forward-fixed or replaced by a new binary that defaults to 2D. Binary downgrade is not a data recovery mechanism.
- No remote flag, remote asset replacement, or server kill switch is introduced.

Rollback is source- and release-based:

1. Revert the character asset and presentation implementation together to the last signed compatible versions.
2. Keep product schema and personal data forward-compatible and untouched.
3. Default to functional 2D when a compatible 3D asset cannot be proven.
4. Re-run package, migration, recovery, and physical-device acceptance before promotion.

## 13. Implementation Entry Conditions

Implementation may begin only after the user reviews this written specification and a separate implementation plan is approved.

The first implementation slice must prove the pipeline before full character work:

1. install and pin Blender;
2. create a minimal authored character hierarchy with the approved side ribbon;
3. export deterministic Full and Lite USDA from Blender headless, then package and strictly check both USDZ assets with Apple USD Tools;
4. validate named nodes, pivots, digest, and budgets;
5. load the actual asset in `RealityView` with an update closure;
6. prove three motions end to end: `idle.listen`, `capture.deposit`, and `draw.pull(progress)`;
7. prove asset failure selects functional 2D;
8. only then expand the full approved motion vocabulary and page integration.

This spike is an evidence gate, not a parallel prototype path. If a required Blender-to-RealityKit animation feature is unreliable, the approved fallback is high-quality static Blender geometry plus deterministic RealityKit transform animation on named rigid nodes. The app does not return to runtime primitive modeling as the production source.

## 14. Approved Decisions

| Decision | Approval |
| --- | --- |
| Subtle anthropomorphism | User selected option A on 2026-07-20 |
| Curious and warm personality | User selected option A on 2026-07-20 |
| Paper-spirit visual direction | User selected option B on 2026-07-20 |
| Restrained, low-frequency idle | User selected option A on 2026-07-20 |
| Character scope: Home plus key transitions | User selected option A on 2026-07-20 |
| Modular authored asset plus code-coordinated motion | User selected option A on 2026-07-20 |
| Sage ribbon mounted at the side, not center | User requested the change on 2026-07-20 |
| Stronger paper folds and visible restrained fiber | User selected the paper-emphasis option in the visual companion on 2026-07-20 |
| Real Blender 3D authoring pipeline | User authorized Blender installation on 2026-07-20 |
| Asset pipeline design | User explicitly approved on 2026-07-20 |
| Motion language | User selected option A on 2026-07-20 |
| Presentation architecture and safety boundaries | User selected option A in the visual companion on 2026-07-20 |

The product and character design direction has no unresolved choice. Tool compatibility remains deliberately gated by the first pipeline spike: Blender export behavior, RealityKit clip exposure, parameter-sample fidelity, deterministic packaging, and any optional Reality Composer Pro composition must produce the specified evidence before full asset authoring expands beyond the three required proof motions.

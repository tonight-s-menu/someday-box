# Someday Box 3D Character Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and ship a lively, warm, Blender-authored Someday Box protagonist with deterministic Full/Lite USDZ assets, restrained idle motion, truth-correlated interaction animation, a functional SwiftUI 2D fallback, and candidate-sealed release evidence.

**Architecture:** Keep product truth in the existing Application/Domain pipeline and treat RealityKit as a replaceable presentation adapter. A root-owned coordinator consumes monotonic scene snapshots plus structured committed outcomes, then drives either a validated RealityKit hierarchy or a state-equivalent SwiftUI 2D adapter. The Blender source, export scripts, exact-byte manifest, compiled identity, runtime assets, CI evidence, and signed-package audit form one reproducible and rollback-safe asset pipeline.

**Tech Stack:** Blender 5.2.0 LTS, Blender Python 3.13 with `bpy` and `pxr`, Apple USD Tools 0.25.2, USD/USDZ, RealityKit, SwiftUI, Swift 6, Swift Testing/XCTest/XCUITest, Xcode 26.6, Python standard library, Make, GitHub Actions.

---

## 0. Execution contract and verified baseline

This is one ordered implementation plan with three independently gated slices:

1. **Pipeline proof:** strict asset contract, deterministic Blender export, Full/Lite packaging, three-motion RealityKit spike, and functional 2D asset-failure proof.
2. **Presentation truth:** transaction receipts, three-state post-commit projection, snapshot/coordinator/interaction logic, renderer migration, and adapter wiring.
3. **Production character:** final model, all 13 authored motions, complete product journeys, accessibility, performance, archive, and hard replacement of the obsolete primitive path.

Do not start slice 2 until the pipeline gate in Task 5 passes. Do not start final character polish until the structured-outcome and coordinator tests in Tasks 8-13 pass. Each task ends in a green commit; if execution resumes a task whose commit already exists, amend that task commit instead of creating a duplicate task commit.

Current facts verified on 2026-07-20:

- Worktree: clean `main`, HEAD `c5a74a02410c81e08b4fbadac7401f8bb2f1be7b` before this plan commit.
- A user-owned stash exists with label `workspace cleanup before Blender pipeline implementation 2026-07-20`; execution must not pop, drop, or rewrite it without an explicit user request.
- The design spec's statement about uncommitted `HomeView.swift` and String Catalog edits is historical. The actual implementation baseline is the clean worktree plus the untouched stash.
- Blender executable: `/Applications/Blender.app/Contents/MacOS/Blender`, version `5.2.0 LTS`, build hash `fbe6228777e7`, arm64 binary SHA-256 `60ba7a9b6743f7acf101274361fa76409e382ae07cd2007ce07dea30f6b129f2`. `/opt/homebrew/bin/blender` is a Homebrew wrapper script, not the pinned Mach-O binary, and is not an accepted export input.
- Official installer SHA-256: `ed4d8390166dec5ea0a2813a03db6221f206ce016442be7f59f41d760972568a`.
- Xcode: `26.6 (17F113)` on macOS build `25D125`. Apple `usdcat`, `usdzip`, and `usdchecker` each print exactly `Apple USD Tools (0.25.2)` and have SHA-256 values `3a16e9ff866d145669d41de552ce8d64bfd3454570881481a4a12ed48efdd9a4`, `ee1d296ce79bea5897ed6adb568b215235819cc355b82620cb8a2e952a506ac1`, and `333cd7aefbda685fb232d7b4d2d025fa385b4022aa639b92653a5a6476d5b371` respectively.
- Apple USD Tools 0.25.2 has a verified `usdzip --arkitAsset ... --checkCompliance` crash on an asset that passes `usdchecker --arkit --strict`; a direct `subprocess.run(argv, shell=False)` observes `returncode == -signal.SIGBUS` while a shell may translate the same termination to 138. `usdzip --arkitAsset` without that flag succeeds. Task 3 records the direct-process reproduction and amends the design/ADR to the fail-closed pre-package plus post-package strict checker gate before implementation proceeds.
- `make ci-check` currently passes 64 XCTest, 10 Swift Testing, and 5 UI tests: 79 total, zero failures, on iPhone 17 Pro Simulator.
- `Package.swift` compiles only `Domain/`; therefore `make test` is never sufficient proof for Application, App, SwiftUI, RealityKit, or XCUITest work.

Before every task:

```bash
cd /Users/drava/Local/someday-box
test -z "$(git status --porcelain)"
git branch --show-current
git stash list | rg 'workspace cleanup before Blender pipeline implementation 2026-07-20'
```

Expected: clean output from the first command, the intended implementation branch from the second command, and exactly one matching untouched stash entry from the third command.

At execution start, create an isolated worktree using `superpowers:using-git-worktrees`; use a branch name under `feature/`, for example `feature/core-box-3d-character`. Do not implement directly on `main`.

## 1. Frozen contracts used by every task

### 1.1 Asset names and budgets

The single source of configuration truth is `Assets/CoreBoxCharacter/export-config.json`. It must encode these exact constants; Python, Swift, the manifest, and release audit read or generate from this file instead of maintaining independent handwritten lists.

```json
{
  "assetVersion": "core-box-character-v1",
  "animationEncoding": "usdNamedResourcesV1",
  "aoIntegration": "bakedIntoBasecolorLinearMultiplyV1",
  "packagingComplianceMode": "preAndPostUsdcheckerStrictV1",
  "schemaVersion": 1,
  "manifestCanonicalizationVersion": "raw-utf8-v1",
  "authoringTreeDigestVersion": "path-sha256-v1",
  "blender": {
    "version": "5.2.0 LTS",
    "buildHash": "fbe6228777e7",
    "binarySHA256": "60ba7a9b6743f7acf101274361fa76409e382ae07cd2007ce07dea30f6b129f2"
  },
  "appleUSDTools": {
    "macOSBuild": "25D125",
    "versionOutput": "Apple USD Tools (0.25.2)",
    "usdcat": {
      "path": "/usr/bin/usdcat",
      "sha256": "3a16e9ff866d145669d41de552ce8d64bfd3454570881481a4a12ed48efdd9a4"
    },
    "usdchecker": {
      "path": "/usr/bin/usdchecker",
      "sha256": "333cd7aefbda685fb232d7b4d2d025fa385b4022aa639b92653a5a6476d5b371"
    },
    "usdzip": {
      "path": "/usr/bin/usdzip",
      "sha256": "ee1d296ce79bea5897ed6adb568b215235819cc355b82620cb8a2e952a506ac1"
    }
  },
  "coordinateSystem": {
    "metersPerUnit": 1.0,
    "upAxis": "Y",
    "rootEntity": "BoxRoot"
  },
  "requiredEntities": [
    "BoxRoot",
    "BoxBody",
    "LidPivot",
    "LidMesh",
    "EyeLeftPivot",
    "EyeLeftMesh",
    "EyeRightPivot",
    "EyeRightMesh",
    "RibbonRoot",
    "RibbonJoint_01",
    "RibbonJoint_02",
    "RibbonJoint_03",
    "RibbonJoint_04",
    "RibbonJoint_05",
    "RibbonTip",
    "PaperPool",
    "PaperSpawn",
    "PaperExit",
    "PaperDeposit",
    "PaperReveal",
    "CurrentPaperAnchor",
    "MemorySeam",
    "DecorationRoot",
    "ShadowReceiver",
    "Hit_Lid",
    "Hit_Ribbon",
    "Hit_Box",
    "Hit_MemorySeam",
    "Camera_Default",
    "Camera_Peek",
    "Camera_Overview",
    "Light_Key",
    "Light_Fill"
  ],
  "clips": [
    { "name": "idle.blink", "durationMilliseconds": 340, "authoringFrameCount": 21 },
    { "name": "idle.listen", "durationMilliseconds": 1000, "authoringFrameCount": 60 },
    { "name": "idle.paperRustle", "durationMilliseconds": 900, "authoringFrameCount": 54 },
    { "name": "idle.currentGlance", "durationMilliseconds": 820, "authoringFrameCount": 50 },
    { "name": "react.touch", "durationMilliseconds": 200, "authoringFrameCount": 12 },
    { "name": "react.notice.single", "durationMilliseconds": 460, "authoringFrameCount": 28 },
    { "name": "react.notice.aggregate", "durationMilliseconds": 620, "authoringFrameCount": 38 },
    { "name": "capture.receive", "durationMilliseconds": 300, "authoringFrameCount": 18 },
    { "name": "capture.deposit", "durationMilliseconds": 560, "authoringFrameCount": 34 },
    { "name": "draw.reveal", "durationMilliseconds": 750, "authoringFrameCount": 45 },
    { "name": "current.attach", "durationMilliseconds": 420, "authoringFrameCount": 26 },
    { "name": "paper.return", "durationMilliseconds": 500, "authoringFrameCount": 30 },
    { "name": "memory.stamp", "durationMilliseconds": 650, "authoringFrameCount": 39 }
  ],
  "exportProfiles": {
    "pipeline-spike-v1": {
      "artifactKind": "proof",
      "clipSelection": {
        "mode": "named",
        "names": ["idle.listen", "capture.deposit", "draw.reveal"]
      },
      "textureDimensions": {
        "full": { "basecolor": 64, "normal": 64, "roughness": 64 },
        "lite": { "basecolor": 64, "normal": 64, "roughness": 64 }
      }
    },
    "production-v1": {
      "artifactKind": "runtime",
      "clipSelection": {
        "mode": "allConfigured",
        "names": []
      },
      "textureDimensions": {
        "full": { "basecolor": 2048, "normal": 512, "roughness": 512 },
        "lite": { "basecolor": 1024, "normal": 512, "roughness": 512 }
      }
    }
  },
  "parameterizedChannels": [
    {
      "name": "ribbon.pull",
      "samples": [0.0, 0.72, 1.0],
      "entities": [
        "BoxRoot",
        "RibbonRoot",
        "RibbonJoint_01",
        "RibbonJoint_02",
        "RibbonJoint_03",
        "RibbonJoint_04",
        "RibbonJoint_05",
        "RibbonTip"
      ]
    }
  ],
  "tiers": {
    "full": {
      "collection": "EXPORT_FULL",
      "resourceName": "CoreBoxCharacterFull.usdz",
      "paperRestCount": 24,
      "triangleCeiling": 60000,
      "renderableEntityCeiling": 80,
      "materialSlotCeiling": 8,
      "shadowCastingLightCeiling": 1,
      "dynamicLightCeiling": 2,
      "largestTextureDimensionCeiling": 2048,
      "residentTextureByteCeiling": 33554432,
      "packageByteCeiling": 16777216
    },
    "lite": {
      "collection": "EXPORT_LITE",
      "resourceName": "CoreBoxCharacterLite.usdz",
      "paperRestCount": 10,
      "triangleCeiling": 25000,
      "renderableEntityCeiling": 36,
      "materialSlotCeiling": 6,
      "shadowCastingLightCeiling": 0,
      "dynamicLightCeiling": 1,
      "largestTextureDimensionCeiling": 2048,
      "residentTextureByteCeiling": 16777216,
      "packageByteCeiling": 8388608
    }
  },
  "aggregatePackageByteCeiling": 20971520
}
```

`PaperRest_00` through `PaperRest_09` exist in both tiers. `PaperRest_10` through `PaperRest_23` exist only in Full. No other `PaperRest_` name is allowed.

### 1.2 Presentation vocabulary

Application code uses these event names, independent of the selected adapter:

```swift
public enum CoreBoxPresentationEvent: Equatable, Sendable {
    case touch
    case shareArrival(freshItemIDs: [UUID])
    case captureReceive
    case captureDeposit(itemID: UUID)
    case drawReveal(attemptID: UUID, itemID: UUID)
    case currentAttach(attemptID: UUID, itemID: UUID)
    case paperReturn(itemID: UUID)
    case memoryStamp(itemID: UUID, memoryID: UUID)
    case failureSettle
    case fallbackSettle(CoreBoxFallbackReason)
}
```

The event-to-motion mapping is exact:

| Event | Motion resource or sampled channel |
| --- | --- |
| `touch` | `react.touch` |
| fresh Share count 1...3 | `react.notice.single`, sequential but one bounded presentation |
| fresh Share count 4 or more | `react.notice.aggregate`, once |
| `captureReceive` | `capture.receive` |
| `captureDeposit` | `capture.deposit` |
| `drawReveal` | `draw.reveal` |
| `currentAttach` | `current.attach` |
| `paperReturn` | `paper.return` |
| `memoryStamp` | `memory.stamp` |
| `failureSettle` | code-sampled settle to stable pose |
| `fallbackSettle` | code-sampled settle then adapter cross-fade |
| eligible drag | `ribbon.pull` at clamped progress `0...1` |

### 1.3 Truth boundary

Every mutation that may trigger character motion returns exactly one of:

```swift
public enum AppMutationProjection<Outcome: Equatable & Sendable>: Equatable, Sendable {
    case notCommitted(failure: AppMutationFailure)
    case committed(outcome: Outcome, snapshot: CoreBoxSceneSnapshot)
    case committedButProjectionUnavailable(outcome: Outcome)
}
```

Only `.committed(outcome:snapshot:)` may emit a transient success event. `.committedButProjectionUnavailable` enters read-only reconciliation, prevents replay of the mutation, permanently drops that event occurrence, and later restores only a stable snapshot.

### 1.4 Directory evidence identity

Use `xcarchive-tree-sha256-v1` for archives and the identical framing named `xcresult-tree-sha256-v1` for result bundles. Enumerate every descendant by repository-style relative POSIX path sorted by UTF-8 bytes and reject devices/sockets. Frame a regular file as `path + NUL + file + NUL + four-digit lowercase octal mode + NUL + decimal size + NUL + raw-file lowercase SHA-256 + LF`; frame a symlink as `path + NUL + symlink + NUL + mode + NUL + UTF-8 link target + LF` without following it; frame a directory as `path + NUL + directory + NUL + mode + LF`. Do not include mtimes, owner IDs, or the root entry. Hash the concatenated bytes with SHA-256. Every evidence producer and consumer recomputes this framing rather than hashing a directory name or trusting a supplied digest.

## 2. File responsibility map

### Blender, validation, and packaging

| Path | Responsibility |
| --- | --- |
| `Assets/CoreBoxCharacter/CoreBoxCharacter.blend` | Authoritative Full/Lite model, pivots, cameras, lights, actions, materials, and authored ribbon samples. |
| `Assets/CoreBoxCharacter/export-config.json` | Exact names, clips, samples, budgets, coordinate system, and tool pins. |
| `Assets/CoreBoxCharacter/provenance.json` | Installer, cask, binary, signing, Xcode, USD tool, and license provenance. |
| `Assets/CoreBoxCharacter/manifest-schema-v1.json` | Strict manifest schema with closed objects and non-empty production inventories. |
| `Assets/CoreBoxCharacter/textures/*.png` | Checked-in PBR atlas inputs; no absolute or external file references. |
| `Assets/CoreBoxCharacter/scripts/build-core-box-spike.py` | Deterministically creates the minimal proof `.blend`; not used after final hand-authored source replaces the spike. |
| `Assets/CoreBoxCharacter/scripts/preflight-core-box.py` | Runs inside Blender to reject hierarchy, transform, collection, UV, material, action, and budget drift at the authoring source. |
| `Assets/CoreBoxCharacter/scripts/export-core-box.py` | Preflights the `.blend`, exports base/tier/clip layers, records measured inventory, and exits nonzero on contract drift. |
| `Assets/CoreBoxCharacter/scripts/compose-core-box-clips.py` | Uses Blender's bundled `pxr` to compose named clip layers and ribbon sample data into tier USDA. |
| `Assets/CoreBoxCharacter/scripts/core_box_png.py` | Performs deterministic PNG decode, Lanczos-3 staging, color/normal handling, and canonical encoding. |
| `Assets/CoreBoxCharacter/scripts/validate-core-box-export-request.py` | Validates the pinned binary, profile, roots, and write scope before Blender opens the source file. |
| `Assets/CoreBoxCharacter/scripts/inspect-core-box-usd.py` | Traverses real USDA/USDZ with Blender `pxr` and emits canonical measured inventory. |
| `Assets/CoreBoxCharacter/scripts/promote-core-box-output.py` | Promotes proof and runtime artifact sets transactionally with journal, backup, and rollback. |
| `Assets/CoreBoxCharacter/scripts/generate-core-box-proof.py` | Seals the three-motion test proof report and generated Swift identity from audited package bytes. |
| `scripts/core-box-export.sh` | Explicit, checkout-writing authoring command; never called by candidate verification. |
| `scripts/core-box-repro-check.sh` | Creates two isolated exports, compares them and the committed artifacts, and never writes to the checkout. |
| `scripts/json_schema_subset.py` | Dependency-free validator for the exact JSON Schema keywords used by the asset schema. |
| `scripts/core_box_tree_digest.py` | Shared Section 1.4 archive/result-bundle traversal, framing, hashing, and CLI. |
| `scripts/core_box_asset_audit.py` | Validates canonical bytes, source tree, manifests, USD inventory, budgets, and negative fixtures. |
| `scripts/core_box_toolchain.py` | Single config-driven verifier for provenance equality and live Xcode, Blender, macOS, and Apple USD identities. |
| `scripts/run-core-box-blender.sh` | The only Blender-Python launcher; validates pins and executes Blender under an empty, explicit environment allowlist. |
| `scripts/audit-core-box-assets.sh` | Thin shell entry point for the Python/Blender audit. |
| `scripts/audit-core-box-proof.sh` | Re-inspects both verification-only proof packages and validates their canonical report/identity. |
| `scripts/audit-core-box-package.sh` | Validates the signed archive against the external candidate manifest. |
| `scripts/tests/test_core_box_manifest.py` | Canonicalization, source digest, identity, schema, and budget unit tests. |
| `scripts/tests/test_core_box_fixtures.py` | Missing/duplicate node, wrong digest, oversized texture, and missing clip fail-closed tests. |
| `scripts/tests/core_box_fixture_factory.py` | Deterministically materializes positive and five negative audit fixtures in isolated temporary directories. |
| `SomedayBoxTests/Fixtures/CoreBoxProofFull.usdz` | Verification-only Full spike package; used by tests/compatibility host, never the production app Resources phase. |
| `SomedayBoxTests/Fixtures/CoreBoxProofLite.usdz` | Verification-only Lite spike package; used by tests/compatibility host, never the production app Resources phase. |
| `SomedayBoxTests/Fixtures/CoreBoxProofReport.json` | Canonical three-motion compatibility evidence; not the production asset manifest. |
| `Resources/CoreBoxCharacterFull.usdz` | Sealed production Full runtime asset created only after all 13 motions pass. |
| `Resources/CoreBoxCharacterLite.usdz` | Sealed production Lite runtime asset created only after all 13 motions pass. |
| `Resources/CoreBoxAssetManifest.json` | Canonical exact-byte runtime manifest. |
| `Generated/CoreBoxAssetIdentity.generated.swift` | Compiled manifest and tier digests generated only from audited bytes. |

### Application truth and presentation

| Path | Responsibility |
| --- | --- |
| `Application/ProductRepository.swift` | Generic atomic transaction result and committed state. |
| `Application/MutationArbiter.swift` | Mutation policy plus generic transaction receipt forwarding. |
| `Application/DrawUseCases.swift` | Exact Attempt/Session/Item receipts for start, redraw, accept, and dismiss. |
| `Application/PaperUseCases.swift` | Capture and Share receipts without post-commit inference. |
| `Application/LifecycleUseCases.swift` | Complete/Put Back receipts including Memory identity. |
| `Application/CoreBoxMutationOutcome.swift` | Three-state mutation/projection result and reconciliation failure values. |
| `Application/CoreBoxProjection.swift` | Stable, deterministic `CoreBoxSceneSnapshot` construction. |
| `Application/CoreBoxPresentation.swift` | Pure presentation state, renderer preference v2, command/event values, and no RealityKit imports. |
| `Application/CoreBoxPresentationCoordinator.swift` | Sequence/snapshot correlation, priority, channel ownership, interruption, stable poses, and event queue. |
| `Application/CoreBoxIdleScheduler.swift` | Seeded 12...24 second idle opportunities with injected clock and cancellation. |
| `Application/CoreBoxRendererHealthPolicy.swift` | Pure Low Power, memory, thermal, active-frame-window, cooldown, and no-upgrade degradation reducer. |
| `Application/CoreBoxMotionRecipe.swift` | Created only if the compatibility gate activates `runtimeTransformRecipesV1`; stores the exact 13 deterministic named rigid-node recipes. |
| `App/SomedayBoxApp.swift` | AppModel projection revision, structured mutation APIs, and reconciliation gate. |
| `App/CoreBoxRendererHealthMonitor.swift` | Live system-signal adapter that feeds the pure health policy and coordinator without owning renderer truth. |
| `App/RootTabView.swift` | Root-owned coordinator, authoritative root gates, and no old Draw-mutation sheet. |
| `App/UITestLaunchConfiguration.swift` | Debug-only isolated store, fixed fixtures, and one-shot failure injection. |

### SwiftUI and RealityKit adapters

| Path | Responsibility |
| --- | --- |
| `Features/Home/CoreBox/CoreBoxStage.swift` | Stable stage composition and adapter selection. |
| `Features/Home/CoreBox/CoreBoxRealityStage.swift` | `RealityView` make/update lifecycle only. |
| `Features/Home/CoreBox/CoreBoxInteractionSurface.swift` | Shared hit regions, Draw enablement, native actions, and normalized ribbon gesture. |
| `Features/Home/CoreBox/CoreBoxAssetLoader.swift` | Async exact-byte load that returns only a structurally attested tier asset. |
| `Features/Home/CoreBox/CoreBoxAssetValidator.swift` | Cheap runtime hierarchy, animation, and sample checks. |
| `Features/Home/CoreBox/CoreBoxSceneAdapter.swift` | Snapshot/event application to named RealityKit entities. |
| `Features/Home/CoreBox/CoreBox2DAdapter.swift` | Functional state-equivalent SwiftUI fallback. |
| `Features/Home/CoreBox/CoreBoxPeekView.swift` | Peek semantic surface and stable open/close coordination. |
| `Features/Draw/DrawContextPicker.swift` | Context selection only; never mutates Draw. |
| `Features/Draw/DrawRevealGate.swift` | Immediate semantic reveal, focus, and committed result actions. |
| `Features/Capture/CaptureView.swift` | Native editor with receive/deposit/cancel contract. |
| `Features/Settings/SettingsView.swift` | Automatic/Full 3D/Simplified 2D preferences only. |
| `Features/Home/HomeView.swift` | Page composition; no asset digesting or production primitive construction. |

### Compatibility verification host

| Path | Responsibility |
| --- | --- |
| `CompatibilityHost/CoreBoxCompatibilityHostApp.swift` | Verification-only iOS host with proof resources and no product store or production target membership. |
| `CompatibilityHost/CoreBoxCompatibilityProbeView.swift` | Actual RealityView make/update, playback-terminal, ribbon-sample, and pre-install failure proof. |
| `CoreBoxCompatibilityUITests/CoreBoxCompatibilityProbeUITests.swift` | Simulator and physical-device proof for both tiers plus functional 2D rejection path. |
| `docs/design/core-box-compatibility-decision.md` | Selected animation encoding and exact proof/result-bundle identities. |

### Tests and release wiring

Every new Swift source, test, fixture resource, USDZ, JSON manifest, and generated Swift file must be added explicitly to `SomedayBox.xcodeproj/project.pbxproj`, because this project uses traditional PBX groups rather than folder-synchronized groups.

| Path | Coverage |
| --- | --- |
| `SomedayBoxTests/CoreBoxTransactionReceiptTests.swift` | Generic transactions and exact use-case identities. |
| `SomedayBoxTests/AppModelPresentationTests.swift` | Three-state projection and reconciliation. |
| `SomedayBoxTests/CoreBoxPreferenceMigrationTests.swift` | v1-to-v2 migration, interruption, malformed values, and reset. |
| `SomedayBoxTests/CoreBoxProjectionTests.swift` | Counts, exclusion, truncation, stable seed, and versions. |
| `SomedayBoxTests/CoreBoxPresentationCoordinatorTests.swift` | Priority, correlation, ownership, interruption, and degradation. |
| `SomedayBoxTests/CoreBoxRibbonInteractionTests.swift` | 0.72 threshold, 0.55 hysteresis, cancel, and exactly-one intent. |
| `SomedayBoxTests/CoreBoxIdleSchedulerTests.swift` | Seed, preconditions, cancellation, and zero stable-idle work. |
| `SomedayBoxTests/CoreBoxRendererHealthPolicyTests.swift` | Signal thresholds, frame windows, cooldown, coalescing, and no-upgrade behavior. |
| `SomedayBoxTests/CoreBoxStageLifecycleTests.swift` | RealityView make/update, stale-load rejection, replacement, teardown, and stable-idle subscription rules. |
| `SomedayBoxTests/CoreBoxProofIdentityTests.swift` | Verification-only three-motion package/report/compiled-identity equality. |
| `SomedayBoxTests/CoreBoxAssetIdentityTests.swift` | Compiled identity versus bundle bytes. |
| `SomedayBoxTests/CoreBoxRealityKitAssetTests.swift` | Both tiers, hierarchy, exact animation names, and ribbon samples. |
| `SomedayBoxTests/CoreBoxMotionTerminalTests.swift` | Duration, terminal transform, finite sample, and stable-pose tolerances for all motions. |
| `SomedayBoxTests/CoreBoxContactShadowTests.swift` | Full/Lite contact-shadow mesh/material/input and shadow-light count contract. |
| `SomedayBoxTests/CoreBox2DParityTests.swift` | Same stable terminal states across adapters. |
| `SomedayBoxUITests/CoreBoxHomeUITests.swift` | Home context-first Draw, ribbon, native action, and Peek parity. |
| `SomedayBoxUITests/CoreBoxMutationJourneyUITests.swift` | Capture, Share, reveal, current, return, complete, and failure journeys. |
| `SomedayBoxUITests/CoreBoxFallbackAccessibilityUITests.swift` | Forced 2D, Reduce Motion, Dynamic Type, and accessibility. |
| `Makefile` | Explicit export plus read-only test/audit/repro/package gates. |
| `.github/workflows/ci.yml` | Pinned Blender and candidate-SHA evidence artifacts. |
| `scripts/audit-core-box-release.sh` | Audits source/resource removal, release-only test-hook absence, privacy, and candidate-version contracts. |
| `scripts/generate-core-box-candidate-manifest.py` | Binds exact source, signed archive, reproducibility, asset-audit, and xcresult evidence outside the checkout. |
| `docs/release/core-box-candidate-manifest.schema.json` | Closed schema for external candidate commit, evidence, and signed archive identity. |
| `docs/release/release-manifest-template.md` | Human-readable field guide for the generated external candidate manifest. |
| `docs/release/acceptance-checklist.md` | Simulator, device, performance, accessibility, archive, and rollback evidence. |
| `docs/release/feature-upgrade-summary.md` | Operator-facing renderer, asset, fallback, migration, and rollback summary. |

## Slice A — Deterministic Blender pipeline and RealityKit proof

### Task 1: Define the strict source, manifest, and negative-fixture contract

**Files:**

- Create: `Assets/CoreBoxCharacter/export-config.json`
- Create: `Assets/CoreBoxCharacter/provenance.json`
- Create: `Assets/CoreBoxCharacter/manifest-schema-v1.json`
- Create: `scripts/json_schema_subset.py`
- Create: `scripts/core_box_tree_digest.py`
- Create: `scripts/core_box_asset_audit.py`
- Create: `scripts/core_box_toolchain.py`
- Create: `scripts/run-core-box-blender.sh`
- Create: `scripts/tests/test_core_box_manifest.py`
- Create: `scripts/tests/test_core_box_fixtures.py`
- Create: `scripts/tests/test_core_box_toolchain.py`
- Create: `scripts/tests/core_box_fixture_factory.py`
- Modify: `Makefile`

- [ ] **Step 1: Write canonicalization and failure-fixture tests first**

Use the exact configured constants from Section 1. The canonical-byte test must prove sorted keys, UTF-8, LF, and one final newline; the authoring-tree test must prove UTF-8 byte-order sorting and `path + NUL + file-digest + LF` framing. Separate directory-evidence tests cover file/directory/symlink frames, mode changes, symlink non-following, forbidden special files, and identical `xcarchive`/`xcresult` framing apart from the version label.

```python
class ManifestContractTests(unittest.TestCase):
    def test_raw_utf8_v1_is_exact(self) -> None:
        value = {"z": 2, "a": {"β": 1, "a": 0}}
        self.assertEqual(
            canonical_json_bytes(value),
            b'{"a":{"a":0,"\xce\xb2":1},"z":2}\n',
        )

    def test_path_sha256_v1_is_path_sensitive(self) -> None:
        first = [("b.bin", b"B"), ("a.bin", b"A")]
        second = [("a.bin", b"A"), ("c.bin", b"B")]
        self.assertNotEqual(authoring_tree_digest(first), authoring_tree_digest(second))

    def test_evidence_tree_digest_binds_mode_and_symlink_target(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "nested").mkdir()
            (root / "nested/data.bin").write_bytes(b"data")
            (root / "alias").symlink_to("nested/data.bin")
            first = evidence_tree_digest(root, version="xcresult-tree-sha256-v1")
            (root / "nested/data.bin").chmod(0o600)
            second = evidence_tree_digest(root, version="xcresult-tree-sha256-v1")
            self.assertNotEqual(first, second)
            self.assertEqual((root / "alias").readlink().as_posix(), "nested/data.bin")

    def test_negative_fixtures_fail_with_stable_codes(self) -> None:
        expected = {
            "missing-node": "missing_required_entity",
            "duplicate-name": "duplicate_entity_name",
            "wrong-digest": "tier_digest_mismatch",
            "oversized-texture": "texture_dimension_exceeded",
            "missing-clip": "clip_inventory_mismatch",
        }
        for name, code in expected.items():
            with self.subTest(name=name):
                with tempfile.TemporaryDirectory() as directory:
                    root = Path(directory)
                    write_core_box_fixture(root, mutation=name)
                    with self.assertRaisesRegex(AssetAuditError, f"^{code}:"):
                        audit_fixture(root)


class ToolchainContractTests(unittest.TestCase):
    def test_config_is_the_single_pin_source_and_provenance_must_match(self) -> None:
        contract = load_toolchain_contract(CONFIG_PATH, PROVENANCE_PATH)
        self.assertEqual(contract.apple_usd, apple_usd_from_provenance(PROVENANCE_PATH))

    def test_any_provenance_or_consumer_drift_fails_closed(self) -> None:
        for mutation in (
            "provenance-macos-build",
            "provenance-version-output",
            "provenance-tool-path",
            "provenance-tool-sha",
            "consumer-expected-sha",
        ):
            with self.subTest(mutation=mutation):
                self.assertToolchainContractFails(mutation, code="toolchain_contract_drift")
```

- [ ] **Step 2: Run the tests and confirm the red state**

Run:

```bash
/usr/bin/python3 -B -m unittest discover -s scripts/tests -p 'test_core_box_*.py' -v
```

Expected: import failure for `scripts.core_box_asset_audit` or undefined `canonical_json_bytes`; no fixture is allowed to pass accidentally.

- [ ] **Step 3: Implement a dependency-free closed-schema validator and audit core**

`scripts/json_schema_subset.py` must implement only these schema keywords and reject every other keyword: `$ref`, `$defs`, `type`, `const`, `enum`, `required`, `properties`, `additionalProperties`, `items`, `minItems`, `maxItems`, `uniqueItems`, `minimum`, `maximum`, `minLength`, and `pattern`. It resolves only local references beginning with `#/$defs/`.

The public audit API is exact:

```python
class AssetAuditError(RuntimeError):
    def __init__(self, code: str, detail: str) -> None:
        super().__init__(f"{code}: {detail}")
        self.code = code
        self.detail = detail


def canonical_json_bytes(value: object) -> bytes:
    text = json.dumps(
        value,
        ensure_ascii=False,
        allow_nan=False,
        sort_keys=True,
        separators=(",", ":"),
    )
    return (text + "\n").encode("utf-8")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def authoring_tree_digest(entries: Iterable[tuple[str, bytes]]) -> str:
    framed = bytearray()
    for path, raw in sorted(entries, key=lambda item: item[0].encode("utf-8")):
        framed.extend(path.encode("utf-8"))
        framed.append(0)
        framed.extend(sha256_bytes(raw).encode("ascii"))
        framed.extend(b"\n")
    return sha256_bytes(bytes(framed))


def validate_manifest(manifest_path: Path, schema_path: Path) -> dict[str, object]:
    raw = manifest_path.read_bytes()
    value = json.loads(raw)
    if raw != canonical_json_bytes(value):
        raise AssetAuditError("manifest_not_canonical", str(manifest_path))
    validate_json_schema(value, json.loads(schema_path.read_text(encoding="utf-8")))
    return value


def audit_fixture(root: Path) -> None:
    schema = REPOSITORY_ROOT / "Assets/CoreBoxCharacter/manifest-schema-v1.json"
    manifest = validate_manifest(root / "manifest.json", schema)
    inventory = json.loads((root / "inventory.json").read_text(encoding="utf-8"))
    validate_inventory(inventory, manifest)
    validate_digests(root, manifest)
    validate_budgets(root, manifest)
```

`scripts/core_box_tree_digest.py` implements Section 1.4 once and exposes `evidence_tree_digest(root: Path, version: str) -> str`. Its CLI is `/usr/bin/python3 -B scripts/core_box_tree_digest.py --version xcresult-tree-sha256-v1 --root PATH`; it prints exactly one lowercase 64-character digest plus LF and exits 64 for unknown version/arguments or non-directory roots. Candidate generation and package audit import this function instead of copying traversal code.

`scripts/core_box_toolchain.py` is the only executable authority for tool pins. It reads the closed `appleUSDTools` object from `export-config.json`, requires exact deep equality with the same object in provenance, and then measures live tools. Its public CLI is `/usr/bin/python3 -B scripts/core_box_toolchain.py --source-root PATH --scope apple-usd|host|full [--blender PATH]`; unknown options or caller-supplied expected versions/hashes exit 64, config/provenance drift exits 65, and live identity drift exits 66. `apple-usd` verifies macOS build plus all three absolute paths/version outputs/hashes; `host` adds exact Xcode output; `full` adds Blender resolved Mach-O path/version/build/hash. Make, export/proof/package wrappers, and CI call this CLI; none repeats a literal expected tool value.

`scripts/run-core-box-blender.sh` is the only permitted launcher for a Blender process that executes Python. It starts with `set -eu`, resolves the repository and Blender paths, calls the `full` toolchain scope with host `/usr/bin/python3 -B` under its own `env -i` allowlist, then executes Blender via a second `env -i` with only `TZ=UTC`, `LC_ALL=C`, `LANG=C`, `SOURCE_DATE_EPOCH=946684800`, `PYTHONDONTWRITEBYTECODE=1`, `PYTHONHASHSEED=0`, `PYTHONNOUSERSITE=1`, and present-but-empty `PYTHONPATH`, `PYTHONHOME`, and `PYTHONUSERBASE`. An optional caller `DEVELOPER_DIR` is copied only into the toolchain-check process, where exact Xcode output is still verified; it never reaches Blender. No caller `PATH`, `HOME`, `TMPDIR`, or other `PYTHON*` value reaches either Python runtime; every executable and script path passed to it is absolute. The in-Blender bootstrap rejects project-module import until its measured flag contract passes and uses explicit exceptions, never Python `assert`, for production gates.

This Task 1 API is the dependency-free contract-unit layer: `inventory.json` is deliberately injected test input, not accepted production evidence. Task 3 adds the pinned-Blender `pxr` inspector that derives inventory from real USDA/USDZ and requires byte equality with any generated report before the production audit can pass.

`write_core_box_fixture` always creates canonical `manifest.json`, measured `inventory.json`, deterministic `full.bin`, deterministic `lite.bin`, and a valid standard-library-encoded PNG. The valid fixture has all 13 clip names and exact required nodes. Each named mutation changes exactly one dimension: delete `LidPivot`; duplicate `RibbonRoot`; replace the Full digest with 64 zeroes; replace the texture with a valid 4096×1 PNG while leaving reported metadata untouched; or remove `memory.stamp`. The audit reads and validates the real PNG signature/IHDR dimensions rather than trusting inventory width. This keeps each failure classification unambiguous and makes fixture bytes reproducible without checking generated binaries into source.

The schema must set `additionalProperties: false` at every object level. Source validation requires each `authoringFrameCount` to equal `ceil(durationMilliseconds * 60 / 1000)` and every duration/name to be unique. It requires `aoIntegration=bakedIntoBasecolorLinearMultiplyV1` and `packagingComplianceMode=preAndPostUsdcheckerStrictV1`, records the checked-in AO source digest, and permits exactly three runtime texture entries named basecolor/normal/roughness; standalone AO is invalid. It also requires the closed `appleUSDTools` tuple from Section 1.1: exact macOS build, exact complete version output, and one lowercase SHA-256 for each absolute tool path. A version-only configuration is invalid. Production tier inventories require exactly 13 unique clip names, exactly one `ribbon.pull` channel with samples `[0.0, 0.72, 1.0]`, positive `byteCount`, 64-character lowercase SHA-256 strings, and the exact tier budgets from Section 1.1.

The source audit also validates the two export profiles exactly. `pipeline-spike-v1` may name only the three compatibility clips and emits verification-only proof artifacts; `production-v1` must resolve `allConfigured` to the 13 entries in `clips` and emits runtime artifacts. The shell-request validator rejects unknown profile names, an empty effective selection, profile/output-path disagreement, or texture dimensions that differ from the frozen profile before Blender opens the source; the Blender exporter repeats all config/profile checks after load and fails on any disagreement.

The production authoring tree is the sorted set of `CoreBoxCharacter.blend`, all four source textures, every `.py` file under `Assets/CoreBoxCharacter/scripts/`, `scripts/core-box-export.sh`, `scripts/run-core-box-blender.sh`, `scripts/core_box_toolchain.py`, `export-config.json`, `provenance.json`, and `manifest-schema-v1.json`. Generated USDA/USDZ/report/manifest/Swift files, verification-only wrappers, and `.build/` are excluded. Adding, deleting, or changing any output-affecting authoring or packaging script therefore changes `authoringTreeSHA256` and requires an atomic regenerated identity commit.

- [ ] **Step 4: Add provenance with verified local facts**

`provenance.json` contains these immutable inputs:

```json
{
  "blender": {
    "applicationIdentifier": "org.blenderfoundation.blender",
    "binaryPath": "/Applications/Blender.app/Contents/MacOS/Blender",
    "binarySHA256": "60ba7a9b6743f7acf101274361fa76409e382ae07cd2007ce07dea30f6b129f2",
    "buildHash": "fbe6228777e7",
    "installerSHA256": "ed4d8390166dec5ea0a2813a03db6221f206ce016442be7f59f41d760972568a",
    "installerURL": "https://download.blender.org/release/Blender5.2/blender-5.2.0-macos-arm64.dmg",
    "version": "5.2.0 LTS"
  },
  "homebrew": {
    "caskSourceSHA256": "b47d0595fcfa7d7bd8b05c777d7aaede4da2befdd8b0fca2d74e2019f23f995c",
    "tapCommit": "a61ec1d1ae76cff8cf10f792b617f5b4f7a49a84"
  },
  "appleUSDTools": {
    "macOSBuild": "25D125",
    "versionOutput": "Apple USD Tools (0.25.2)",
    "usdcat": {
      "path": "/usr/bin/usdcat",
      "sha256": "3a16e9ff866d145669d41de552ce8d64bfd3454570881481a4a12ed48efdd9a4"
    },
    "usdchecker": {
      "path": "/usr/bin/usdchecker",
      "sha256": "333cd7aefbda685fb232d7b4d2d025fa385b4022aa639b92653a5a6476d5b371"
    },
    "usdzip": {
      "path": "/usr/bin/usdzip",
      "sha256": "ee1d296ce79bea5897ed6adb568b215235819cc355b82620cb8a2e952a506ac1"
    }
  },
  "xcode": "26.6 (17F113)"
}
```

- [ ] **Step 5: Add the pipeline-test Make target and run green**

```make
BLENDER_BIN ?= /Applications/Blender.app/Contents/MacOS/Blender
DEVELOPER_DIR ?= $(shell /usr/bin/xcode-select -p)

.PHONY: core-box-toolchain-audit core-box-pipeline-tests

core-box-toolchain-audit:
	env -i DEVELOPER_DIR="$(DEVELOPER_DIR)" TZ=UTC LC_ALL=C LANG=C PYTHONDONTWRITEBYTECODE=1 /usr/bin/python3 -B scripts/core_box_toolchain.py --source-root "$(CURDIR)" --scope full --blender "$(BLENDER_BIN)"

core-box-pipeline-tests:
	PYTHONDONTWRITEBYTECODE=1 /usr/bin/python3 -B -m unittest discover -s scripts/tests -p 'test_core_box_*.py' -v
```

Run:

```bash
make core-box-pipeline-tests
```

Expected: all canonicalization, schema, digest, positive fixture, and five negative fixture tests pass; each negative fixture fails internally with its exact stable error code.

- [ ] **Step 6: Commit the contract**

```bash
git add Assets/CoreBoxCharacter/export-config.json Assets/CoreBoxCharacter/provenance.json Assets/CoreBoxCharacter/manifest-schema-v1.json scripts/json_schema_subset.py scripts/core_box_tree_digest.py scripts/core_box_asset_audit.py scripts/core_box_toolchain.py scripts/run-core-box-blender.sh scripts/tests Makefile
git commit -m "test: define strict Core Box asset contract" -m " - Add canonical manifest and source-tree identity rules
 - Prove required negative fixtures fail closed"
```

### Task 2: Create the minimal Blender-authored proof character

**Files:**

- Create: `Assets/CoreBoxCharacter/CoreBoxCharacter.blend`
- Create: `Assets/CoreBoxCharacter/scripts/build-core-box-spike.py`
- Create: `Assets/CoreBoxCharacter/scripts/preflight-core-box.py`
- Create: `Assets/CoreBoxCharacter/textures/core-box-basecolor.png`
- Create: `Assets/CoreBoxCharacter/textures/core-box-normal.png`
- Create: `Assets/CoreBoxCharacter/textures/core-box-roughness.png`
- Create: `Assets/CoreBoxCharacter/textures/core-box-ao.png`
- Create: `scripts/tests/test_core_box_blend_source.py`

- [ ] **Step 1: Write the Blender source preflight test**

The test launches Blender in background, opens the checked-in `.blend`, and calls a source-only validation mode. It asserts:

```python
EXPECTED_COLLECTIONS = {"SOURCE_SHARED", "EXPORT_FULL", "EXPORT_LITE"}
EXPECTED_ACTIONS = {"idle.listen", "capture.deposit", "draw.reveal"}
EXPECTED_RIBBON_X = 0.132
EXPECTED_ROOT_SCALE = (1.0, 1.0, 1.0)

class BlendSourceTests(unittest.TestCase):
    def test_spike_source_has_side_ribbon_and_three_proof_actions(self) -> None:
        report = run_blender_preflight()
        self.assertEqual(set(report["collections"]), EXPECTED_COLLECTIONS)
        self.assertEqual(set(report["actions"]), EXPECTED_ACTIONS)
        self.assertEqual(tuple(report["boxRootScale"]), EXPECTED_ROOT_SCALE)
        self.assertAlmostEqual(report["ribbonRootTranslation"][0], EXPECTED_RIBBON_X, places=4)
        self.assertGreater(report["ribbonRootScreenX"], report["rightEyeSafeMaxX"])
```

- [ ] **Step 2: Run the focused test and confirm it fails**

```bash
/usr/bin/python3 -B -m unittest scripts.tests.test_core_box_blend_source -v
```

Expected: failure because `CoreBoxCharacter.blend` and `build-core-box-spike.py` do not exist.

- [ ] **Step 3: Build the exact proof hierarchy in Blender**

`build-core-box-spike.py` resets the factory scene, sets metric units with scale `1.0`, authors object and vertex coordinates directly in the runtime convention (`+Y` up, `+Z` toward the viewer), creates `BoxRoot` at identity, and creates the required hierarchy from Section 1.1. Blender's UI convention is not exported as a transform; cameras, lights, pivots, and meshes all use this explicit target convention. Use these proof dimensions and positions in meters:

```python
SPIKE_GEOMETRY = {
    "BoxBody": {"size": (0.30, 0.16, 0.22), "location": (0.0, 0.08, 0.0), "bevel": 0.012},
    "LidPivot": {"location": (0.0, 0.155, -0.095)},
    "LidMesh": {"size": (0.306, 0.034, 0.226), "location": (0.0, 0.017, 0.095), "bevel": 0.010},
    "EyeLeftPivot": {"location": (-0.052, 0.118, 0.111)},
    "EyeRightPivot": {"location": (0.052, 0.118, 0.111)},
    "RibbonRoot": {"location": (0.132, 0.102, 0.086)},
    "RibbonTip": {"location": (0.055, -0.030, 0.0)},
    "MemorySeam": {"size": (0.18, 0.003, 0.004), "location": (0.0, 0.045, 0.111)}
}

RIBBON_JOINT_OFFSETS = [
    (0.011, -0.003, 0.0),
    (0.011, -0.006, 0.0),
    (0.011, -0.009, 0.0),
    (0.011, -0.012, 0.0),
    (0.011, -0.015, 0.0),
]

CONTACT_SHADOW = {
    "segments": 32,
    "size": (0.240, 0.105),
    "location": (0.0, 0.001, 0.012),
    "centerAlpha": 0.14,
    "edgeAlpha": 0.0,
}
```

Create `EXPORT_FULL` and `EXPORT_LITE` as top-level source collections, and link the single `SOURCE_SHARED` collection as a child of both. Objects identical across tiers live only in `SOURCE_SHARED`; Full-only objects live directly under `EXPORT_FULL`, and Lite-only objects live directly under `EXPORT_LITE`. Preflight asserts `set(EXPORT_FULL.all_objects) & set(EXPORT_LITE.all_objects) == set(SOURCE_SHARED.all_objects)` and rejects any tier-only object reachable from the opposite scope. The ribbon is on local `+X`, which appears at screen right under `Camera_Default`; it never crosses the face. Create 24 Full Paper anchors and the shared first 10 Lite anchors. Author `ShadowReceiver` from `CONTACT_SHADOW` as a visible horizontal ellipse with no collision/input and the radial-alpha atlas patch. Author `FullSource__Light_Key` with one shadow and `LiteSource__Light_Key` with shadows disabled, both mapped to public `Light_Key`; `Light_Fill` is non-shadowing. Create simplified invisible hit geometry parented to `Hit_Lid`, `Hit_Ribbon`, `Hit_Box`, and `Hit_MemorySeam`.

The proof uses five atlas-backed material families named exactly `MAT_MaplePaper`, `MAT_SageRibbon`, `MAT_MossInk`, `MAT_InteriorMemory`, and `MAT_ContactShadow`. The four source PNG inputs are 64×64 deterministic proof textures created by Blender Python; AO is baked into runtime basecolor, so only basecolor/normal/roughness are exported. Their replacement in Task 15 keeps the same source paths and material names.

- [ ] **Step 4: Author three proof actions with stable terminal poses**

Create non-looping actions at 60 fps:

```python
PROOF_ACTIONS = {
    "idle.listen": {"frames": (0, 60), "terminal": "neutral"},
    "capture.deposit": {"frames": (0, 34), "terminal": "closedFromSnapshot"},
    "draw.reveal": {"frames": (0, 45), "terminal": "resultVisible"}
}
```

`idle.listen` raises `LidPivot` by 3°, leans `BoxRoot` 1.5°, delays the ribbon by 6 frames, and returns every channel to the exact rest transform at frame 60. `capture.deposit` samples `PaperDeposit`, applies at most 1.2% root compression, and ends closed at frame 34. `draw.reveal` moves one visual Paper from `PaperSpawn` through `PaperExit` to `PaperReveal` while the product Paper remains SwiftUI-owned and ends at frame 45. Every proof and production action starts at frame 0; preflight rejects any other `action.frame_range`.

Create a custom property group `core_box_ribbon_pull` on `BoxRoot` containing exact transforms for progress `0.0`, `0.72`, and `1.0`. At progress `1.0`, root lean is no more than 2° and the projected ribbon bounding box remains right of both eye safe regions.

- [ ] **Step 5: Save with deterministic cleanup and preflight it**

The builder removes orphan data, packs no external paths, makes all texture paths repository-relative, sorts collections and view layers by name, sets the active scene and frame to 0, then saves to the explicit argument after `--`. `preflight-core-box.py` is read-only, shares validation functions later imported by the exporter, writes only the explicit report path, and never changes or saves the opened `.blend`.

```bash
BLENDER_BIN=/Applications/Blender.app/Contents/MacOS/Blender \
scripts/run-core-box-blender.sh \
  --background \
  --factory-startup \
  --disable-autoexec \
  --offline-mode \
  --python-use-system-env \
  --python-exit-code 1 \
  --python "$PWD/Assets/CoreBoxCharacter/scripts/build-core-box-spike.py" \
  -- \
  --output "$PWD/Assets/CoreBoxCharacter/CoreBoxCharacter.blend"

BLENDER_BIN=/Applications/Blender.app/Contents/MacOS/Blender \
scripts/run-core-box-blender.sh \
  --background \
  --factory-startup \
  --disable-autoexec \
  --offline-mode \
  --python-use-system-env \
  --python-exit-code 1 \
  "$PWD/Assets/CoreBoxCharacter/CoreBoxCharacter.blend" \
  --python "$PWD/Assets/CoreBoxCharacter/scripts/preflight-core-box.py" \
  -- \
  --config "$PWD/Assets/CoreBoxCharacter/export-config.json" \
  --report "$PWD/.build/core-box/source-preflight.json"
```

Both Blender scripts raise an explicit startup error before importing project modules unless `__debug__` is true and the measured flag tuple is exactly: `ignore_environment=0`, `isolated=0`, `dont_write_bytecode=1`, `hash_randomization=0`, `no_user_site=1`, `optimize=0`, `inspect=0`, `interactive=0`, `debug=0`, `dev_mode=false`, `safe_path=false`, `verbose=0`, `bytes_warning=0`, `quiet=0`, `warn_default_encoding=0`, and `utf8_mode=1`. They also require `PYTHONPATH`, `PYTHONHOME`, and `PYTHONUSERBASE` to be present and empty and reject any other environment key beginning with `PYTHON`. Expected: Blender exits 0; the report contains those measured interpreter flags, identity root transform, local `+X` ribbon root at `0.132`, exact shared hierarchy, 24/10 Paper anchors, five material families, three proof actions, and no absolute texture path or newly created `__pycache__`.

- [ ] **Step 6: Run the pipeline test suite and commit**

```bash
make core-box-pipeline-tests
git add Assets/CoreBoxCharacter scripts/tests/test_core_box_blend_source.py
git commit -m "build: create the Blender Core Box proof source" -m " - Add the side-ribbon character hierarchy and proof materials
 - Author three deterministic motion samples for export validation"
```

### Task 3: Export, compose, package, and reproduce Full/Lite proof assets

**Files:**

- Create: `Assets/CoreBoxCharacter/scripts/export-core-box.py`
- Create: `Assets/CoreBoxCharacter/scripts/compose-core-box-clips.py`
- Create: `Assets/CoreBoxCharacter/scripts/core_box_png.py`
- Create: `Assets/CoreBoxCharacter/scripts/validate-core-box-export-request.py`
- Create: `Assets/CoreBoxCharacter/scripts/inspect-core-box-usd.py`
- Create: `Assets/CoreBoxCharacter/scripts/promote-core-box-output.py`
- Create: `scripts/core-box-export.sh`
- Create: `scripts/core-box-repro-check.sh`
- Create: `scripts/tests/test_core_box_export_contract.py`
- Modify: `Assets/CoreBoxCharacter/provenance.json`
- Modify: `docs/superpowers/specs/2026-07-20-someday-box-character-and-motion-redesign.md`
- Modify: `docs/adr/0004-realitykit-core-box-presentation.md`
- Modify: `.gitignore`
- Modify: `Makefile`

- [ ] **Step 1: Test exporter arguments, tool pins, normalized packaging, and checkout isolation**

```python
class ExportContractTests(unittest.TestCase):
    def test_blender_command_is_fail_closed_and_offline(self) -> None:
        command = blender_export_command(Path("/repo"), Path("/stage"))
        self.assertEqual(command[0], "/repo/scripts/run-core-box-blender.sh")
        self.assertIn("--python-exit-code", command)
        self.assertIn("1", command)
        self.assertIn("--disable-autoexec", command)
        self.assertIn("--offline-mode", command)
        self.assertIn("--python-use-system-env", command)

    def test_export_environment_and_tier_scope_are_frozen(self) -> None:
        environment = blender_export_environment()
        self.assertEqual(
            environment,
            {
                "LANG": "C",
                "LC_ALL": "C",
                "PYTHONDONTWRITEBYTECODE": "1",
                "PYTHONHASHSEED": "0",
                "PYTHONHOME": "",
                "PYTHONNOUSERSITE": "1",
                "PYTHONPATH": "",
                "PYTHONUSERBASE": "",
                "SOURCE_DATE_EPOCH": "946684800",
                "TZ": "UTC",
            },
        )
        full = usd_export_arguments("full", Path("/stage/full"))
        lite = usd_export_arguments("lite", Path("/stage/lite"))
        self.assertEqual(full["collection"], "EXPORT_FULL")
        self.assertEqual(lite["collection"], "EXPORT_LITE")
        self.assertEqual(full["export_textures_mode"], "NEW")
        self.assertEqual(lite["export_textures_mode"], "NEW")
        self.assertTrue(full["overwrite_textures"])
        self.assertTrue(lite["overwrite_textures"])

    def test_real_blender_uses_the_same_flags_under_a_poisoned_parent_environment(self) -> None:
        clean = run_pinned_blender_python_flag_probe(parent_environment={})
        measured = run_pinned_blender_python_flag_probe(
            parent_environment={
                "PYTHONOPTIMIZE": "2",
                "PYTHONWARNINGS": "error",
                "PYTHONPYCACHEPREFIX": "/tmp/core-box-poison-cache",
                "PYTHONINSPECT": "1",
                "PYTHONSAFEPATH": "1",
                "PYTHONUTF8": "0",
            }
        )
        self.assertEqual(measured, clean)
        self.assertEqual(
            measured,
            {
                "PYTHONHOME": "",
                "PYTHONPATH": "",
                "PYTHONUSERBASE": "",
                "__debug__": True,
                "bytes_warning": 0,
                "debug": 0,
                "dev_mode": False,
                "dont_write_bytecode": 1,
                "hash_randomization": 0,
                "ignore_environment": 0,
                "inspect": 0,
                "interactive": 0,
                "isolated": 0,
                "no_user_site": 1,
                "optimize": 0,
                "quiet": 0,
                "safe_path": False,
                "unexpected_python_environment": [],
                "utf8_mode": 1,
                "verbose": 0,
                "warn_default_encoding": 0,
            },
        )

    def test_apple_usd_toolchain_uses_only_the_config_driven_verifier(self) -> None:
        completed = run_toolchain_cli(scope="apple-usd")
        self.assertEqual(completed.returncode, 0, completed.stderr)

    def test_packaging_uses_strict_checker_before_and_after_zip(self) -> None:
        commands = apple_packaging_commands(Path("/stage/tier.usda"), Path("/out/tier.usdz"))
        self.assertEqual(commands[0][0], "/usr/bin/usdcat")
        self.assertEqual(commands[1][:3], ["/usr/bin/usdchecker", "--arkit", "--strict"])
        self.assertEqual(commands[2][:2], ["/usr/bin/usdzip", "/out/tier.usdz"])
        self.assertNotIn("--checkCompliance", commands[2])
        self.assertEqual(commands[3][:3], ["/usr/bin/usdchecker", "--arkit", "--strict"])
        self.assertEqual(commands[4][-2:], ["--list", "-"])

    def test_check_compliance_regression_is_direct_sigbus(self) -> None:
        fixture = write_minimal_arkit_fixture()
        completed = subprocess.run(
            [
                "/usr/bin/usdzip",
                str(fixture.with_suffix(".usdz")),
                "--arkitAsset",
                str(fixture),
                "--checkCompliance",
            ],
            shell=False,
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        self.assertEqual(completed.returncode, -signal.SIGBUS)

    def test_package_dependency_closure_is_exact(self) -> None:
        for encoding, expected_action_layer_count in (
            ("usdNamedResourcesV1", 3),
            ("runtimeTransformRecipesV1", 0),
        ):
            with self.subTest(encoding=encoding):
                package = export_and_package_fixture(animation_encoding=encoding)
                closure = inspect_package_closure_with_pinned_blender(package)
                self.assertEqual(closure.actual_members, closure.root_reachable_members)
                self.assertEqual(closure.runtime_texture_roles, {"basecolor", "normal", "roughness"})
                self.assertEqual(closure.root_layer_count, 1)
                self.assertEqual(closure.root_layer_suffix, ".usdc")
                self.assertEqual(closure.action_layer_count, expected_action_layer_count)

    def test_package_dependency_closure_rejects_missing_extra_and_external_members(self) -> None:
        expected = {
            "missing-reachable-member": "package_dependency_missing",
            "extra-unreachable-member": "package_member_unreachable",
            "external-asset-path": "package_dependency_external",
            "case-fold-collision": "package_member_collision",
            "wrong-localized-path": "package_localization_mismatch",
            "recipe-action-layer-extra": "package_member_unreachable",
        }
        for mutation, code in expected.items():
            with self.subTest(mutation=mutation):
                self.assertPackageClosureFails(mutation=mutation, code=code)

    def test_composed_stage_is_y_up_with_identity_root(self) -> None:
        stage = open_with_blender_bundled_pxr(export_proof_stage("full"))
        self.assertEqual([prim.GetPath().pathString for prim in stage.GetPseudoRoot().GetChildren()], ["/BoxRoot"])
        self.assertFalse(stage.GetPrimAtPath("/_materials").IsValid())
        self.assertTrue(stage.GetPrimAtPath("/BoxRoot/Materials").IsValid())
        self.assertTrue(all_material_bindings_resolve_below(stage, "/BoxRoot/Materials"))
        self.assertEqual(stage.GetMetadata("upAxis"), "Y")
        self.assertEqual(stage.GetMetadata("metersPerUnit"), 1.0)
        self.assertMatrixAlmostEqual(
            local_transform(stage, "/BoxRoot", time="default"),
            identity_matrix(),
            places=9,
        )

    def test_repro_check_rejects_checkout_writes(self) -> None:
        before = git_status_bytes()
        run_repro_check()
        self.assertEqual(git_status_bytes(), before)

    def test_three_motion_spike_is_exact(self) -> None:
        report = export_to_temporary_directory()
        self.assertEqual(
            set(report["exportedClips"]),
            {"idle.listen", "capture.deposit", "draw.reveal"},
        )

    def test_pinned_png_golden_and_budget_formula(self) -> None:
        png = encode_uniform_map(width=2, height=2, rgba=(229, 201, 159, 255))
        self.assertEqual(len(png), 74)
        self.assertEqual(
            hashlib.sha256(png).hexdigest(),
            "f821b5090dce15d4ecf9464ba0f3373f590f8d82201540f6fe00a4db9dde9118",
        )
        self.assertEqual(resident_texture_bytes("full"), 25_165_820)
        self.assertEqual(resident_texture_bytes("lite"), 8_388_604)

    def test_real_usd_negative_fixtures_fail_through_blender_pxr(self) -> None:
        for mutation, code in REAL_USD_NEGATIVE_CASES.items():
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as directory:
                package = write_real_usd_fixture(Path(directory), mutation=mutation)
                self.assertInspectorFails(package, code=code)
```

- [ ] **Step 2: Run focused tests and confirm they fail**

```bash
/usr/bin/python3 -B -m unittest scripts.tests.test_core_box_export_contract -v
```

Expected: failure because the export and reproducibility wrappers do not exist.

- [ ] **Step 3: Implement fail-closed Blender export**

`export-core-box.py` parses only arguments after `--`, validates the exact Blender version/build/binary digest before reading scene data, resolves the tier's collection from `export-config.json`, and calls once per tier:

```python
bpy.ops.wm.usd_export(
    filepath=str(output_usda),
    allow_unicode=False,
    author_blender_name=False,
    check_existing=False,
    collection=collection_name,
    evaluation_mode="RENDER",
    export_animation=export_animation,
    export_armatures=True,
    export_cameras=True,
    export_curves=False,
    export_custom_properties=True,
    export_hair=False,
    export_lights=True,
    export_materials=not export_animation,
    export_mesh_colors=False,
    export_meshes=True,
    export_normals=True,
    export_points=False,
    export_shapekeys=True,
    export_subdivision="TESSELLATE",
    export_uvmaps=True,
    export_volumes=False,
    export_textures_mode="NEW",
    overwrite_textures=True,
    generate_preview_surface=True,
    generate_materialx_network=False,
    convert_world_material=False,
    convert_orientation=False,
    convert_scene_units="METERS",
    custom_properties_namespace="userProperties",
    incremental_frames=0,
    merge_parent_xform=False,
    meters_per_unit=1.0,
    ngon_method="BEAUTY",
    only_deform_bones=False,
    quad_method="SHORTEST_DIAGONAL",
    relative_paths=True,
    rename_uvmaps=False,
    root_prim_path="",
    selected_objects_only=False,
    triangulate_meshes=True,
    use_instancing=False,
    xform_op_mode="TRS",
)
```

`collection_name` must be exactly `EXPORT_FULL` or `EXPORT_LITE`; exporting the whole scene or selected UI objects is prohibited. Objects linked into both export collections are permitted only when they are also members of `SOURCE_SHARED` and their geometry, material, transform, custom properties, and animation bindings must be byte-equivalent in both measured inventories. A tier-specific source object belongs to exactly one export collection, uses the authoring name `FullSource__Name` or `LiteSource__Name`, and stores its exact runtime name in `coreBoxPublicName`. Immediately before export, the script renames only the active tier's variant objects in memory, validates one unique complete public hierarchy, exports, and restores every authoring name in a `finally` block without saving the `.blend`. This supports materially different Full/Lite meshes and lights without leaking source prefixes or the other tier into USD.

`convert_orientation=False` is also intentional: the source is already authored in the target `+Y`-up convention, while Blender's orientation conversion would add a non-identity rotation to `/BoxRoot`. An empty `root_prim_path` is intentional because the authored top-level object already exports as `/BoxRoot`; using `/BoxRoot` here would create the invalid duplicate path `/BoxRoot/BoxRoot`. Blender 5.2 emits a raw sibling `/_materials` whenever the static base uses `export_materials=True`; this raw stage is therefore not yet the runtime contract. Source preflight asserts one authored object root, and the composer performs the deterministic material normalization below before the final USD audit requires exactly one top-level `/BoxRoot`, identity within `1e-9`, no source-name prefix, and no opposite-tier entity.

For each tier, materialize the four checked-in source PNGs at `$OUTPUT_ROOT/source-textures/full/` or `$OUTPUT_ROOT/source-textures/lite/` under the exact checked-in basenames before opening them in Blender. The AO source is resampled to the basecolor dimensions and multiplied into linear basecolor with `rgbOut = rgbLinear * aoLinear`; it is an authoring input, never a standalone USD Preview Surface dependency. Use the three runtime-map dimensions in the selected profile: proof is 64 for basecolor/normal/roughness; production Full is 2048 basecolor plus 512 normal/roughness; production Lite is 1024 basecolor plus 512 normal/roughness. Point the in-memory material graphs at the staged basecolor-with-AO, normal, and roughness copies, disconnect/remove every AO image node and AO image datablock, and never save the `.blend`. Blender 5.2 `export_textures_mode="NEW"` must create exactly `textures/core-box-basecolor.png`, `textures/core-box-normal.png`, and `textures/core-box-roughness.png` as relative references beside the tier USDA. An exported `core-box-ao.png`, a fourth runtime texture, or an AO asset relationship fails the audit.

`core_box_png.py` implements the staging conversion without `Image.scale()`: decode non-interlaced 8-bit RGB/RGBA/grayscale PNG scanlines and all five PNG filters; clamp borders; use a fixed radius-3 Lanczos kernel; decode basecolor with the IEC 61966-2-1 sRGB transfer function before filtering; resample AO as a linear scalar to the same dimensions; multiply every linear RGB channel by AO; then encode basecolor back to sRGB. Filter roughness as a linear scalar; decode normal RGB to `[-1,1]`, filter, renormalize with `(0,0,1)` for a zero vector, and re-encode; quantize with `floor(clamp(value,0,1) * 255 + 0.5)`. Encode filter-zero rows with Blender Python's pinned zlib 1.3.1 at level 9 and only IHDR/IDAT/IEND chunks. A 2×2 RGBA maple input with uniform AO 1.0 remains exactly 74 bytes with SHA-256 `f821b5090dce15d4ecf9464ba0f3373f590f8d82201540f6fe00a4db9dde9118`; separate nonuniform raw-pixel goldens cover kernel, edge clamp, sRGB, AO multiplication, and normal renormalization. The export audit also requires each material's active render UV map to be named `st`, since `rename_uvmaps=False` is frozen.

For budget accounting, conservatively treat each of the three staged runtime maps as RGBA8 with a complete mip chain: `sum(4 * max(1,width >> level) * max(1,height >> level))` through 1×1. This is 25,165,820 bytes for Full and 8,388,604 bytes for Lite, below 32/16 MiB without assuming driver compression. The proof total is 65,532 bytes per tier. Device evidence still records measured resident-memory delta. The audit rejects absolute paths, `..`, `source-textures/` references, external files, a standalone AO dependency, missing/extra runtime texture files, a profile/map dimension mismatch, invalid PNG structure, resident estimate overflow, or a texture digest that differs across two isolated runs.

For each tier, export one static base USDA with `export_materials=True`, then one USDA per selected action with `export_materials=False`, beneath `$OUTPUT_ROOT/stage/full/` or `$OUTPUT_ROOT/stage/lite/`. Before each action export, clear all NLA tracks, set only that action active, require its `frame_range` to be exactly `0...authoringFrameCount`, sample that inclusive integer domain at 60 fps, and reset every object to its rest pose. `authoringFrameCount` is frozen in config because many approved millisecond durations are not an integer number of 60 Hz intervals. Export measured inventory to `export-report.json`.

- [ ] **Step 4: Compose named animation layers with Blender's bundled `pxr`**

`compose-core-box-clips.py` opens the base stage, calls `UsdGeom.SetStageUpAxis(stage, UsdGeom.Tokens.y)` and `UsdGeom.SetStageMetersPerUnit(stage, 1.0)` without transforming any prim. It creates `/BoxRoot/Materials` as a `UsdGeom.Scope`, copies every spec below raw `/_materials` there, rewrites every `material:binding*` relationship target by replacing the exact `/_materials` prefix with `/BoxRoot/Materials`, verifies every rewritten target resolves to a `UsdShade.Material`, and removes the old raw scope with one checked `Sdf.BatchNamespaceEdit`. It fails if any non-material relationship targets that scope, any old target remains, the copy count differs, or the pseudo-root children are not then exactly `[/BoxRoot]`. Only after that normalization does it verify `/BoxRoot` remains identity at default time. Each action layer is audited to contain no material scope or texture dependency; if Blender writes a static `material:binding*` relationship despite `export_materials=False`, the composer first proves it equals the normalized base binding and then removes that redundant property from the action layer, otherwise it fails. The composer sets `timeCodesPerSecond=1000` and `framesPerSecond=60`; for every action layer it remaps the integer source sample domain `0...authoringFrameCount` onto `0...durationMilliseconds`. The final sample is therefore exact even when intermediate sample times are fractional milliseconds. The audit rejects a missing source endpoint, non-monotonic remap, dangling material binding, or final duration error greater than 1 ms.

The `usdNamedResourcesV1` compatibility candidate uses standard `Usd.ClipsAPI` metadata on `/BoxRoot`: one sanitized clip-set token per public action, relative action-layer asset paths, the exact `/BoxRoot` clip prim path, active/times mappings, and `customData["coreBoxAnimationNames"]` mapping tokens back to public dotted names. It never creates a second top-level prim or copies rigid transform specs beneath a fake animation hierarchy. The action USDA files are package dependencies inside the single tier USDZ, not separate runtime resources. RealityKit support for exposing those clip sets as named `AnimationResource` values is deliberately untrusted until Task 5. If the probe fails only that exposure gate, `runtimeTransformRecipesV1` keeps the static authored hierarchy and stores the same retimed rigid-node samples in the proof report/production manifest; the intermediate action layers remain build evidence, not runtime claims. `ribbon.pull` remains manifest sample data, not a looping clip.

The first spike deliberately tests this encoding rather than assuming RealityKit support. The only accepted outputs are one Full USDZ and one Lite USDZ; separate runtime USDZ files per action are prohibited.

`inspect-core-box-usd.py` runs only through the pinned Blender binary and its bundled `pxr`. It opens the real USDA or USDZ, traverses every prim, resolves `coreBoxPublicName`, parentage, local/default transforms, bounds, mesh triangles, material bindings, active `st` primvars, lights/shadows, cameras, `Usd.ClipsAPI` metadata or recipe inventory, time samples, terminal transforms, and all asset dependencies. It reads real PNG IHDR/channel data and rejects a dependency outside the package. It emits canonical inventory JSON; exporter reports and later manifests must embed the identical derived inventory digest. The Task 3 negative test factory writes minimal real USDA/USDZ packages for missing entity, duplicate public name, missing clip metadata, and oversized valid PNG, while the wrong-digest case mutates the real package digest. No production gate trusts a handwritten inventory file.

- [ ] **Step 5: Normalize staging and package with Apple USD tools**

`scripts/core-box-export.sh` validates explicit `SOURCE_ROOT` and `OUTPUT_ROOT`, requires exactly one of `EXPORT_PROFILE` or comma-separated `EXPORT_PROFILES`, copies no output into the checkout unless `--write-reviewed-output` is passed, and starts with `set -eu`. Before staging, it invokes `scripts/core_box_toolchain.py --scope full`; this is the sole macOS/Xcode/Blender/Apple-USD pin check, and no expected tool literal is duplicated in the wrapper. Before passing the `.blend` path to Blender, it runs `validate-core-box-export-request.py` with host `/usr/bin/python3 -B` under an `env -i` host allowlist; that dependency-free request check validates config/profile/clip/texture rules and confirms output/write destinations. Every host Python subprocess uses the same empty environment plus `-B`, and every Apple tool subprocess receives only fixed locale/time values. Only then does it call the sole Blender launcher with this frozen command:

```bash
BLENDER_BIN="$BLENDER_BIN" \
"$SOURCE_ROOT/scripts/run-core-box-blender.sh" \
  --background \
  --factory-startup \
  --disable-autoexec \
  --offline-mode \
  --python-use-system-env \
  --python-exit-code 1 \
  "$SOURCE_ROOT/Assets/CoreBoxCharacter/CoreBoxCharacter.blend" \
  --python "$SOURCE_ROOT/Assets/CoreBoxCharacter/scripts/export-core-box.py" \
  -- \
  --config "$SOURCE_ROOT/Assets/CoreBoxCharacter/export-config.json" \
  --output "$OUTPUT_ROOT"
```

The launcher defaults `BLENDER_BIN` to `/Applications/Blender.app/Contents/MacOS/Blender`; a caller override is accepted only through the config-driven verifier. Its real-Blender flag probe runs before source load and requires the exact clean/poisoned-parent interpreter values from the Step 1 test. Set all staged file mtimes to `946684800` (2000-01-01T00:00:00Z) with Python `os.utime` before packaging. For each tier run against its isolated stage root:

```bash
/usr/bin/usdcat --loadOnly "$OUTPUT_ROOT/stage/full/CoreBoxCharacterFull.usda"
/usr/bin/usdchecker --arkit --strict "$OUTPUT_ROOT/stage/full/CoreBoxCharacterFull.usda"
/usr/bin/usdzip "$OUTPUT_ROOT/CoreBoxCharacterFull.usdz" \
  --arkitAsset "$OUTPUT_ROOT/stage/full/CoreBoxCharacterFull.usda"
/usr/bin/usdchecker --arkit --strict "$OUTPUT_ROOT/CoreBoxCharacterFull.usdz"
/usr/bin/usdzip "$OUTPUT_ROOT/CoreBoxCharacterFull.usdz" --list -
```

Run the same five commands for Lite. Pinned `usdzip --arkitAsset` converts the source root USDA to exactly one packaged root `.usdc` member and localizes dependencies under relative package paths such as `0/...`; the audit never assumes the source `.usda` name survives. Parse list output as normalized relative POSIX package paths and reject absolute paths, `..`, duplicates, case-fold collisions, and non-UTF-8 names. Next invoke `inspect-core-box-usd.py` through `run-core-box-blender.sh` on the newly written USDZ. Starting from the stage's actual packaged root layer, it recursively follows every packaged `Sdf.AssetPath`/clip dependency, records the source-to-localized path map, and requires every authored reference to resolve to that map rather than the source-stage path.

The exact closure branches on `animationEncoding`. For `usdNamedResourcesV1`, the root-reachable set is one root `.usdc`, all and only selected localized action USD layers, and exactly the three localized runtime textures with roles basecolor/normal/roughness. For `runtimeTransformRecipesV1`, deterministic recipes live in root custom data plus the canonical report/manifest; intermediate action USDA layers remain build evidence outside the package, so the package set is exactly one root `.usdc` plus the three localized runtime textures and zero action layers. In both branches, the actual `usdzip --list` set, the inspector's opened/resolved member set, and the encoding-specific reachable set must be byte-for-byte equal. Missing, external, unresolved, wrongly localized, or extra members fail before `promote-core-box-output.py` may run.

Before changing the frozen spec, `test_core_box_export_contract.py` reproduces and records the pinned-tool behavior against one minimal valid fixture. It invokes `subprocess.run([...], shell=False)` directly and requires: pre-package `usdchecker` return code 0, the `usdzip --checkCompliance` process return code exactly `-signal.SIGBUS`, plain `usdzip --arkitAsset` return code 0, and post-package `usdchecker` return code 0. The test never asserts shell status 138. The spec and ADR then replace only the crashing redundant flag with `preAndPostUsdcheckerStrictV1`; weakening either strict check, changing the macOS-build/version/hash tuple silently, or treating a nonzero checker as advisory is prohibited. Treat each `usdchecker` exit status as authoritative; known USDKit duplicate-registration diagnostics on stderr are captured in the report but do not override a zero exit status.

`--write-reviewed-output` never copies files one by one directly from a live export. `promote-core-box-output.py` first stages and audits the complete requested profile set, acquires an exact `.build/core-box/promotion.lock`, and writes a canonical promotion journal listing every target, prior existence/digest, staged digest, and phase. It fsyncs sibling temporary files, moves prior targets into a digest-verified backup, renames every staged file into place, verifies the whole target set, marks committed, and removes the journal/backup. On any exception or next-start recovery, it restores the complete prior set and verifies every prior digest before releasing the lock; an incomplete recovery fails closed for manual intervention. A single-profile promotion is allowed before production exists. Once Task 16 changes the 13-action authoring tree, proof and production profiles must be requested together so no successful command can leave new proof evidence beside old runtime identity.

- [ ] **Step 6: Prove two isolated exports are identical**

```bash
make core-box-repro-check BLENDER_BIN=/Applications/Blender.app/Contents/MacOS/Blender CHECKED_OUT_ASSETS="$PWD" EXPORT_PROFILE=pipeline-spike-v1
```

`core-box-repro-check` uses two `mktemp -d` roots and an explicit profile. In Task 3, `pipeline-spike-v1` compares normalized base/action/final USDA, texture trees, Full/Lite proof USDZ bytes, and `export-report.json` across the two isolated runs only; proof descriptor/identity generation does not exist yet and must not be referenced. Task 4 extends the same wrapper to compare its canonical proof report and generated identity across runs and against the test-target files. Under `production-v1`, enabled in Task 16, it compares the production manifest, generated identity, and both runtime USDZ files. It installs an exit trap that removes only the two resolved temporary directories. It records no timestamp, random UUID, absolute path, hostname, username, or Git commit inside generated asset bytes.

Expected: identical SHA-256 values across both isolated exports and unchanged `git status`. If `usdzip` remains byte-nondeterministic after normalized inputs, stop this task, retain the comparison report, and revise the packaging design before any later task; do not weaken the digest requirement.

- [ ] **Step 7: Add Make targets and commit the exporter**

```make
.PHONY: core-box-export core-box-repro-check

core-box-export:
	./scripts/core-box-export.sh --write-reviewed-output

core-box-repro-check:
	./scripts/core-box-repro-check.sh
```

```bash
make core-box-pipeline-tests
status_before="$(git status --porcelain=v1)"
make core-box-repro-check BLENDER_BIN=/Applications/Blender.app/Contents/MacOS/Blender CHECKED_OUT_ASSETS="$PWD" EXPORT_PROFILE=pipeline-spike-v1
test "$status_before" = "$(git status --porcelain=v1)"
git add Assets/CoreBoxCharacter/scripts Assets/CoreBoxCharacter/provenance.json scripts/core-box-export.sh scripts/core-box-repro-check.sh scripts/tests/test_core_box_export_contract.py docs/superpowers/specs/2026-07-20-someday-box-character-and-motion-redesign.md docs/adr/0004-realitykit-core-box-presentation.md .gitignore Makefile
git commit -m "build: add deterministic Core Box asset export" -m " - Export isolated Full and Lite USD stages with strict tool pins
 - Prove normalized packages reproduce without checkout writes"
```

### Task 4: Seal the three-motion proof in the unit-test bundle

**Files:**

- Create: `SomedayBoxTests/Fixtures/CoreBoxProofFull.usdz`
- Create: `SomedayBoxTests/Fixtures/CoreBoxProofLite.usdz`
- Create: `SomedayBoxTests/Fixtures/CoreBoxProofReport.json`
- Create: `SomedayBoxTests/Generated/CoreBoxProofIdentity.generated.swift`
- Create: `SomedayBoxTests/CoreBoxProofIdentityTests.swift`
- Create: `Assets/CoreBoxCharacter/scripts/generate-core-box-proof.py`
- Modify: `scripts/core-box-export.sh`
- Modify: `scripts/core-box-repro-check.sh`
- Modify: `SomedayBox.xcodeproj/project.pbxproj`
- Create: `scripts/audit-core-box-proof.sh`
- Modify: `Makefile`

- [ ] **Step 1: Write exact-byte identity tests before generating output**

```swift
import CryptoKit
import Foundation
import Testing
@testable import SomedayBox

private final class CoreBoxProofBundleMarker {}

@Suite("Core Box proof identity")
struct CoreBoxProofIdentityTests {
    @Test func compiledIdentityMatchesBundledBytes() throws {
        let bundle = Bundle(for: CoreBoxProofBundleMarker.self)
        let reportURL = try #require(bundle.url(forResource: "CoreBoxProofReport", withExtension: "json"))
        let fullURL = try #require(bundle.url(forResource: "CoreBoxProofFull", withExtension: "usdz"))
        let liteURL = try #require(bundle.url(forResource: "CoreBoxProofLite", withExtension: "usdz"))

        #expect(Self.digest(try Data(contentsOf: reportURL)) == CoreBoxProofIdentity.reportSHA256)
        #expect(Self.digest(try Data(contentsOf: fullURL)) == CoreBoxProofIdentity.fullTierSHA256)
        #expect(Self.digest(try Data(contentsOf: liteURL)) == CoreBoxProofIdentity.liteTierSHA256)
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
```

- [ ] **Step 2: Add file references without adding generated output yet and confirm red**

Run:

```bash
xcodebuild test \
  -project SomedayBox.xcodeproj \
  -scheme SomedayBox \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:SomedayBoxTests/CoreBoxProofIdentityTests
```

Expected: build or test failure because the test-only report, packages, and generated identity do not exist.

- [ ] **Step 3: Generate a canonical spike report, not a production manifest**

`generate-core-box-proof.py` is added in this task, and the spike export performs this strict order:

1. export and audit both tiers;
2. compute source-tree and tier digests;
3. emit canonical `CoreBoxProofReport.json` with profile `pipeline-spike-v1`, exact clip list `idle.listen/capture.deposit/draw.reveal`, ribbon samples, hierarchy, inventory, and both package digests;
4. hash those exact report bytes;
5. emit `CoreBoxProofIdentity.generated.swift` from the report digest and both tier digests;
6. copy the reviewed spike outputs only into `SomedayBoxTests/Fixtures/` and `SomedayBoxTests/Generated/`.

The proof report is deliberately not named `CoreBoxAssetManifest.json`, does not validate as the 13-clip production schema, and never enters the app Resources phase. The production manifest and identity are created only in Task 16.

Generate Swift with this exact function so no unresolved marker can enter source:

```python
def swift_proof_identity_source(report_digest: str, full_digest: str, lite_digest: str) -> bytes:
    digest_pattern = re.compile(r"^[0-9a-f]{64}$")
    for digest in (report_digest, full_digest, lite_digest):
        if digest_pattern.fullmatch(digest) is None:
            raise AssetAuditError("invalid_generated_digest", digest)
    source = f'''import Foundation

enum CoreBoxProofIdentity {
    static let profile = "pipeline-spike-v1"
    static let reportSHA256 = "{report_digest}"
    static let fullTierSHA256 = "{full_digest}"
    static let liteTierSHA256 = "{lite_digest}"
}}
'''
    return source.encode("utf-8")
```

- [ ] **Step 4: Wire proof resources into the unit-test bundle**

Add both proof USDZ files and the proof report to a `SomedayBoxTests` Resources phase. Add `CoreBoxProofIdentity.generated.swift` and the proof identity test to the test Sources phase. Task 5 later reuses the same source bytes in its separate compatibility-host bundle. Assert in the project audit that none of the three proof resources appears in the production `SomedayBox` Resources phase.

- [ ] **Step 5: Add the verification-only proof audit**

```bash
#!/bin/sh
set -eu
export PYTHONDONTWRITEBYTECODE=1
export PYTHONHASHSEED=0
export PYTHONNOUSERSITE=1
export PYTHONPATH=
export PYTHONHOME=
export PYTHONUSERBASE=

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
blender_bin="${BLENDER_BIN:-/Applications/Blender.app/Contents/MacOS/Blender}"
blender_launcher="$repo_root/scripts/run-core-box-blender.sh"
audit_root="$(mktemp -d /tmp/core-box-proof-audit.XXXXXX)"
case "$audit_root" in
  /tmp/core-box-proof-audit.*) ;;
  *) printf 'Unexpected audit directory: %s\n' "$audit_root" >&2; exit 70 ;;
esac
trap 'rm -rf -- "$audit_root"' EXIT HUP INT TERM

BLENDER_BIN="$blender_bin" "$blender_launcher" --background --factory-startup --disable-autoexec --offline-mode \
  --python-use-system-env --python-exit-code 1 \
  --python "$repo_root/Assets/CoreBoxCharacter/scripts/inspect-core-box-usd.py" -- \
  --asset "$repo_root/SomedayBoxTests/Fixtures/CoreBoxProofFull.usdz" \
  --output "$audit_root/full-inventory.json"
BLENDER_BIN="$blender_bin" "$blender_launcher" --background --factory-startup --disable-autoexec --offline-mode \
  --python-use-system-env --python-exit-code 1 \
  --python "$repo_root/Assets/CoreBoxCharacter/scripts/inspect-core-box-usd.py" -- \
  --asset "$repo_root/SomedayBoxTests/Fixtures/CoreBoxProofLite.usdz" \
  --output "$audit_root/lite-inventory.json"

env -i TZ=UTC LC_ALL=C LANG=C PYTHONDONTWRITEBYTECODE=1 \
  /usr/bin/python3 -B "$repo_root/scripts/core_box_asset_audit.py" \
  --source-root "$repo_root" \
  --profile pipeline-spike-v1 \
  --report "$repo_root/SomedayBoxTests/Fixtures/CoreBoxProofReport.json" \
  --full "$repo_root/SomedayBoxTests/Fixtures/CoreBoxProofFull.usdz" \
  --lite "$repo_root/SomedayBoxTests/Fixtures/CoreBoxProofLite.usdz" \
  --full-inventory "$audit_root/full-inventory.json" \
  --lite-inventory "$audit_root/lite-inventory.json" \
  --generated "$repo_root/SomedayBoxTests/Generated/CoreBoxProofIdentity.generated.swift"
```

The wrapper never fabricates inventory on the host: both reports must come from traversal by the pinned Blender `pxr` runtime, and the host audit only validates those reports against canonical proof bytes and schema.

- [ ] **Step 6: Run identity and audit gates**

```bash
make core-box-export BLENDER_BIN=/Applications/Blender.app/Contents/MacOS/Blender EXPORT_PROFILE=pipeline-spike-v1
make core-box-repro-check BLENDER_BIN=/Applications/Blender.app/Contents/MacOS/Blender CHECKED_OUT_ASSETS="$PWD" EXPORT_PROFILE=pipeline-spike-v1
make core-box-proof-audit
xcodebuild test \
  -project SomedayBox.xcodeproj \
  -scheme SomedayBox \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:SomedayBoxTests/CoreBoxProofIdentityTests
```

Expected: canonical report bytes, source digest, both packaged digests, test-bundle bytes, and generated proof identity match; the production `SomedayBox` app bundle contains no proof resource.

- [ ] **Step 7: Commit reviewed proof artifacts atomically**

```bash
git add Assets/CoreBoxCharacter/scripts/generate-core-box-proof.py scripts/core-box-export.sh scripts/core-box-repro-check.sh SomedayBoxTests/Fixtures/CoreBoxProofFull.usdz SomedayBoxTests/Fixtures/CoreBoxProofLite.usdz SomedayBoxTests/Fixtures/CoreBoxProofReport.json SomedayBoxTests/Generated/CoreBoxProofIdentity.generated.swift SomedayBoxTests/CoreBoxProofIdentityTests.swift SomedayBox.xcodeproj/project.pbxproj scripts/audit-core-box-proof.sh Makefile
git commit -m "build: seal the verification-only Core Box proof" -m " - Bind three-motion Full and Lite packages to exact-byte evidence
 - Keep compatibility spike resources outside the production app bundle"
```

### Task 5: Prove RealityKit animation exposure and the functional fallback gate

**Files:**

- Modify: `Assets/CoreBoxCharacter/export-config.json`
- Modify: `Application/CoreBoxPresentation.swift`
- Create: `Features/Home/CoreBox/CoreBoxAssetLoader.swift`
- Create: `Features/Home/CoreBox/CoreBoxAssetValidator.swift`
- Create: `Features/Home/CoreBox/CoreBoxSceneAdapter.swift`
- Create: `Features/Home/CoreBox/CoreBox2DAdapter.swift`
- Create: `CompatibilityHost/CoreBoxCompatibilityHostApp.swift`
- Create: `CompatibilityHost/CoreBoxCompatibilityProbeView.swift`
- Create: `CoreBoxCompatibilityUITests/CoreBoxCompatibilityProbeUITests.swift`
- Create: `SomedayBox.xcodeproj/xcshareddata/xcschemes/CoreBoxCompatibilityHost.xcscheme`
- Create: `docs/design/core-box-compatibility-decision.md`
- Modify: `docs/superpowers/specs/2026-07-20-someday-box-character-and-motion-redesign.md`
- Create if fallback is selected: `Application/CoreBoxMotionRecipe.swift`
- Modify if fallback is selected: `docs/adr/0004-realitykit-core-box-presentation.md`
- Create: `SomedayBoxTests/Fixtures/CoreBoxProofAssetSource.swift`
- Replace: `SomedayBoxTests/Fixtures/CoreBoxProofFull.usdz`
- Replace: `SomedayBoxTests/Fixtures/CoreBoxProofLite.usdz`
- Replace: `SomedayBoxTests/Fixtures/CoreBoxProofReport.json`
- Replace: `SomedayBoxTests/Generated/CoreBoxProofIdentity.generated.swift`
- Create: `SomedayBoxTests/CoreBoxRealityKitAssetTests.swift`
- Create: `SomedayBoxTests/CoreBox2DParityTests.swift`
- Modify: `SomedayBox.xcodeproj/project.pbxproj`

- [ ] **Step 1: Freeze the staged compatibility gate and write real bundle-load tests**

First revise the design spec's pipeline-spike acceptance wording unconditionally: Task 5 is the physical-device compatibility gate for the three representative motions `idle.listen`, `capture.deposit`, and `draw.reveal`; Task 16 is the later physical-device production gate for all 13 public motions. This changes only gate sequencing, never the final 13-motion scope, and removes any claim that Slice A already proves the complete vocabulary. For the proof asset, require the three exported names on both tiers and require all configured hierarchy names plus the exact Paper anchor counts. The full 13-name production assertion is enabled in Task 16.

```swift
@MainActor
@Suite("RealityKit Core Box proof")
struct CoreBoxRealityKitAssetTests {
    @Test(arguments: [CoreBoxRendererTier.full3D, .lite3D])
    func loadsProofTierWithNamedMotions(_ tier: CoreBoxRendererTier) async throws {
        let bundle = Bundle(for: CoreBoxProofBundleToken.self)
        let loader = CoreBoxAssetLoader(source: CoreBoxProofAssetSource.source(bundle: bundle))
        let loaded = try await loader.load(tier: tier)
        let inventory = loaded.validatedInventory
        let expected = Set(["idle.listen", "capture.deposit", "draw.reveal"])
        #expect(Set(inventory.publicMotionNames) == expected)
        switch inventory.animationEncoding {
        case .usdNamedResourcesV1:
            #expect(Set(inventory.realityKitAnimationNames) == expected)
        case .runtimeTransformRecipesV1:
            #expect(Set(inventory.runtimeRecipeNames) == expected)
        }
        #expect(inventory.paperRestCount == tier.maximumVisiblePapers)
        #expect(inventory.ribbonSampleProgress == [0.0, 0.72, 1.0])
    }
}
```

- [ ] **Step 2: Confirm the tests fail against the unimplemented loader**

```bash
xcodebuild test \
  -project SomedayBox.xcodeproj \
  -scheme SomedayBox \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:SomedayBoxTests/CoreBoxRealityKitAssetTests \
  -only-testing:SomedayBoxTests/CoreBox2DParityTests
```

Expected: compile failure for missing loader/validator/adapter types or test failure because animation names are not exposed.

- [ ] **Step 3: Implement exact-byte load before structural load**

```swift
import CryptoKit
import Foundation
import RealityKit

struct CoreBoxTierInventory: Decodable, Sendable {
    let resourceName: String
    let resourceSHA256: String
    let byteCount: Int
    let publicEntityNames: [String]
    let parentByEntity: [String: String]
    let publicMotionNames: [String]
    let paperRestCount: Int
    let ribbonSampleProgress: [Double]
}

struct CoreBoxAssetInventory: Decodable, Sendable {
    let schemaVersion: Int
    let profile: String
    let animationEncoding: CoreBoxAnimationEncoding
    let tiers: [String: CoreBoxTierInventory]
}

struct CoreBoxValidatedInventory: Equatable, Sendable {
    let animationEncoding: CoreBoxAnimationEncoding
    let publicMotionNames: [String]
    let realityKitAnimationNames: [String]
    let runtimeRecipeNames: [String]
    let paperRestCount: Int
    let ribbonSampleProgress: [Double]
}

enum CoreBoxAnimationEncoding: String, Decodable, Equatable, Sendable {
    case usdNamedResourcesV1
    case runtimeTransformRecipesV1
}

enum CoreBoxAssetValidationError: Error, Equatable {
    case noAssetFor2D
    case digestMismatch(expected: String, actual: String)
    case descriptorDecodeFailed
    case tierMissing(String)
    case invalidInventory(String)
}

struct CoreBoxExpectedAssetIdentity: Sendable {
    let descriptorSHA256: String
    let fullTierSHA256: String
    let liteTierSHA256: String

    func digest(for tier: CoreBoxRendererTier) throws -> String {
        switch tier {
        case .full3D: fullTierSHA256
        case .lite3D: liteTierSHA256
        case .swiftUI2D: throw CoreBoxAssetValidationError.noAssetFor2D
        }
    }
}

struct CoreBoxAssetSource: Sendable {
    let descriptorData: @Sendable () throws -> Data
    let assetData: @Sendable (CoreBoxRendererTier) throws -> Data
    let assetURL: @Sendable (CoreBoxRendererTier) throws -> URL
    let loadEntity: @MainActor @Sendable (URL) async throws -> Entity
    let identity: CoreBoxExpectedAssetIdentity
}

struct CoreBoxValidationAttestation: Sendable {
    fileprivate init() {}
}

struct CoreBoxLoadedAsset {
    let tier: CoreBoxRendererTier
    let root: Entity
    let validatedInventory: CoreBoxValidatedInventory
    private let attestation: CoreBoxValidationAttestation

    fileprivate init(
        tier: CoreBoxRendererTier,
        root: Entity,
        validatedInventory: CoreBoxValidatedInventory,
        attestation: CoreBoxValidationAttestation
    ) {
        self.tier = tier
        self.root = root
        self.validatedInventory = validatedInventory
        self.attestation = attestation
    }
}

struct CoreBoxAssetLoader: Sendable {
    let source: CoreBoxAssetSource

    @MainActor
    func load(tier: CoreBoxRendererTier) async throws -> CoreBoxLoadedAsset {
        let descriptorData = try source.descriptorData()
        try Self.validateDigest(descriptorData, expected: source.identity.descriptorSHA256)
        let descriptor: CoreBoxAssetInventory
        do {
            descriptor = try JSONDecoder().decode(CoreBoxAssetInventory.self, from: descriptorData)
        } catch {
            throw CoreBoxAssetValidationError.descriptorDecodeFailed
        }
        let assetData = try source.assetData(tier)
        let expectedTierDigest = try source.identity.digest(for: tier)
        try Self.validateDigest(assetData, expected: expectedTierDigest)
        let root = try await source.loadEntity(source.assetURL(tier))
        let validated = try CoreBoxAssetValidator().validate(
            tier: tier,
            expectedTierDigest: expectedTierDigest,
            descriptor: descriptor,
            root: root
        )
        return CoreBoxLoadedAsset(
            tier: tier,
            root: root,
            validatedInventory: validated,
            attestation: CoreBoxValidationAttestation()
        )
    }

    private static func validateDigest(_ data: Data, expected: String) throws {
        let actual = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard actual == expected else {
            throw CoreBoxAssetValidationError.digestMismatch(expected: expected, actual: actual)
        }
    }
}
```

`CoreBoxAssetValidator.validate` chooses only `full` or `lite`, requires schema/profile/tier/resource digest equality, traverses the loaded root, and compares exact public-name uniqueness, parent map, identity root, required entities, Paper anchors, motion/recipe names, ribbon samples, finite transforms, material bindings, contact-shadow contract, and opposite-tier absence. It returns `CoreBoxValidatedInventory`; no public initializer can mint `CoreBoxValidationAttestation`. Therefore the stage can receive only a fully validated `CoreBoxLoadedAsset`, never an entity plus an unchecked descriptor. Under `#if DEBUG`, the same loader file provides the complete `CoreBoxLoadedAsset.fixture(tier:)` factory used by unit tests; Release contains no fixture constructor.

`CoreBoxProofAssetSource.swift` defines `CoreBoxProofBundleToken` and `source(bundle:)`, which resolves the descriptor plus two asset URLs from the explicitly supplied bundle, uses `CoreBoxProofIdentity`, and supplies the live `{ try await Entity(contentsOf: $0) }` closure; unit tests pass `Bundle(for: CoreBoxProofBundleToken.self)` and the compatibility host passes `.main`. Task 16 supplies the production app-bundle source and `CoreBoxAssetIdentity` values with that same live closure. The loader itself has no test/production branch and accepts no unchecked entity because every closure result must pass `CoreBoxAssetValidator` before an attestation is minted. Runtime does not attempt to reserialize canonical JSON: signed/generated identity binds the exact raw descriptor bytes, while build/package audits prove `raw-utf8-v1` canonicalization.

Any schema, exact-byte digest, tier digest, entity, clip, sample, parentage, root transform, or anchor-count mismatch throws one stable validation error and rejects the complete 3D scene for that launch.

- [ ] **Step 4: Implement a state-equivalent proof adapter and forced-failure test**

Before declaring the adapter protocol, add the exact `CoreBoxPresentationEvent` vocabulary from Section 1.2 and the full `CoreBoxSettleReason` enum (`completed`, `cancelled`, `background`, `coveringGate`, `rendererTransition`, `reconciliation`, `validationFailure`) to `Application/CoreBoxPresentation.swift`. These are pure Foundation types and remain the same when Task 10 adds ownership. `CoreBox2DAdapter` consumes the same snapshot and event types as the scene adapter. The proof test uses a forced `.assetValidation` failure and asserts Capture, Draw, Peek, Current Pick, Memories, Settings, and Recovery intents remain available without loading RealityKit.

```swift
@MainActor
protocol CoreBoxPresentationAdapter: AnyObject {
    func apply(snapshot: CoreBoxSceneSnapshot)
    func apply(event: CoreBoxPresentationEvent, sourceSnapshotVersion: UInt64)
    func applyRibbon(progress: Double, latched: Bool)
    func settle(reason: CoreBoxSettleReason)
}
```

- [ ] **Step 5: Mount and play the proof in a verification-only RealityView host**

Add a separate `CoreBoxCompatibilityHost` iOS app target and `CoreBoxCompatibilityUITests` target. Its Sources phase contains only `CoreBoxCompatibilityHostApp.swift`, `CoreBoxCompatibilityProbeView.swift`, `Application/CoreBoxPresentation.swift`, the four CoreBox loader/validator/scene/2D adapter files, the optional recipe file selected in Step 7, `CoreBoxProofAssetSource.swift`, and `CoreBoxProofIdentity.generated.swift`; it links the existing `SomedayBoxDomain` package product for shared value types. Its Resources phase contains the two USDZ files plus proof report. The production `SomedayBox` target still contains none of those proof resources. The host has no product repository, store, network entitlement, or route into the shipping app.

`CoreBoxCompatibilityProbeView` owns one `RealityView`. Its make closure constructs the loader with `CoreBoxProofAssetSource.source(bundle: .main)`, so structural validation completes before `content.add`; it adds exactly one validated root, sets `.virtual` camera and `Camera_Default`, and records make/root counts. Its update closure mutates that existing root for a second stable pose and records update/root counts without another load. It then plays `idle.listen`, `capture.deposit`, and `draw.reveal` sequentially through the selected encoding, waits for `AnimationEvents.PlaybackCompleted` or the recipe terminal callback, and compares every controlled entity with the proof report terminal transform: translation tolerance `0.0005 m`, rotation `0.25°`, scale `0.001`, duration error at most `1 ms`, and no NaN/infinity. It samples ribbon progress `0`, `0.72`, and `1`, and exposes stable accessibility values only after each check passes. Under verification-host-only `--force-structural-failure`, a wrapped `loadEntity` first performs the live load and then removes `LidPivot`; descriptor and USDZ digest checks still pass, structural validation fails, and `content.add` is never reached. The view routes that error to `CoreBox2DAdapter` and exposes the same Capture, Draw, Peek, Current, Memories, Settings, and Recovery actions.

```swift
final class CoreBoxCompatibilityProbeUITests: XCTestCase {
    func testBothTiersUseOneRealityRootAndReachAllProofTerminals() {
        for tier in ["full3D", "lite3D"] {
            let app = XCUIApplication()
            app.launchArguments = ["--core-box-proof-tier", tier]
            app.launch()
            XCTAssertTrue(app.otherElements["probe.motion.idle.listen.complete"].waitForExistence(timeout: 20))
            XCTAssertTrue(app.otherElements["probe.motion.capture.deposit.complete"].exists)
            XCTAssertTrue(app.otherElements["probe.motion.draw.reveal.complete"].exists)
            XCTAssertEqual(app.otherElements["probe.ribbon.samples"].value as? String, "0,0.72,1")
            app.buttons["probe.advance.stable-pose"].tap()
            XCTAssertEqual(app.otherElements["probe.reality.counts"].value as? String, "make:1,update:1,roots:1")
            app.terminate()
        }
    }

    func testStructuralFailureNeverInstalls3DAndKeeps2DFunctional() {
        let app = XCUIApplication()
        app.launchArguments = ["--core-box-proof-tier", "full3D", "--force-structural-failure"]
        app.launch()
        XCTAssertTrue(app.otherElements["probe.fallback.functional"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.otherElements["probe.reality.counts"].value as? String, "make:1,update:0,roots:0")
        for id in ["capture", "draw", "peek", "current", "memories", "settings", "recovery"] {
            XCTAssertTrue(app.buttons["probe.2d.\(id)"].isHittable)
        }
    }
}
```

- [ ] **Step 6: Run the hard compatibility gate on Simulator and a physical device**

```bash
make core-box-repro-check BLENDER_BIN=/Applications/Blender.app/Contents/MacOS/Blender CHECKED_OUT_ASSETS="$PWD" EXPORT_PROFILE=pipeline-spike-v1
make core-box-proof-audit
mkdir -p "$PWD/.build/core-box/reports"
proof_run_root="$(mktemp -d "$PWD/.build/core-box/reports/compatibility.XXXXXX")"
simulator_result="$proof_run_root/simulator.xcresult"
device_result="$proof_run_root/device.xcresult"
xcodebuild test \
  -project SomedayBox.xcodeproj \
  -scheme SomedayBox \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:SomedayBoxTests/CoreBoxRealityKitAssetTests \
  -only-testing:SomedayBoxTests/CoreBox2DParityTests
xcodebuild test \
  -project SomedayBox.xcodeproj \
  -scheme CoreBoxCompatibilityHost \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -resultBundlePath "$simulator_result" \
  -only-testing:CoreBoxCompatibilityUITests
test -n "${CORE_BOX_PROOF_DEVICE_UDID:-}"
xcodebuild test \
  -project SomedayBox.xcodeproj \
  -scheme CoreBoxCompatibilityHost \
  -destination "platform=iOS,id=$CORE_BOX_PROOF_DEVICE_UDID" \
  -resultBundlePath "$device_result" \
  -only-testing:CoreBoxCompatibilityUITests
test -d "$simulator_result" -a -d "$device_result"
simulator_tree_digest="$(/usr/bin/python3 -B scripts/core_box_tree_digest.py --version xcresult-tree-sha256-v1 --root "$simulator_result")"
device_tree_digest="$(/usr/bin/python3 -B scripts/core_box_tree_digest.py --version xcresult-tree-sha256-v1 --root "$device_result")"
test "${#simulator_tree_digest}" -eq 64 -a "${#device_tree_digest}" -eq 64
case "$simulator_tree_digest$device_tree_digest" in *[!0-9a-f]*) exit 1 ;; esac
```

Expected for the first probe: both tier assets validate before installation; a real `RealityView` make/update keeps one root; all three motions play and reach exact terminals; ribbon samples pass; the forced structural failure installs zero 3D roots and leaves 2D functional on both Simulator and the connected physical device. Under `usdNamedResourcesV1`, a narrowly classified clip-exposure/playback failure may activate Step 7; every digest, hierarchy, transform, terminal, ribbon-safety, make/update, device, or 2D-functional failure blocks the slice.

- [ ] **Step 7: Apply the explicit compatibility decision**

If RealityKit exposes all three exact names and plays them correctly, set `animationEncoding` in `export-config.json` to `usdNamedResourcesV1`, regenerate the proof report/identity, and continue.

If RealityKit does not expose exact names after the composed-layer implementation, stop expansion and activate the already-approved rigid-node fallback: set `animationEncoding` to `runtimeTransformRecipesV1`, add `Application/CoreBoxMotionRecipe.swift` with the same 13 public names and terminal-state contract, store deterministic transform keyframes in the report/manifest, and update the design spec plus ADR before continuing. The fallback tests compare recipe names and sampled transforms rather than `availableAnimations`; all UI/coordinator semantics remain identical. Do not ship 13 separate runtime USDZ files, do not restore production primitives, and do not relax exact naming or truth correlation.

After either decision, regenerate with `make core-box-export BLENDER_BIN=/Applications/Blender.app/Contents/MacOS/Blender EXPORT_PROFILE=pipeline-spike-v1`, run reproducibility and proof audit, then rerun the complete Simulator and physical-device host commands from Step 6. The selected encoding changes an authoring-tree input, so the proof Full/Lite packages, report, and generated proof identity must be regenerated and committed atomically with the config.

- [ ] **Step 8: Record proof evidence and commit only the passing branch**

Store Simulator/device result bundles, probe inventory, terminals, and transforms in `.build/core-box/reports/`; do not commit machine-specific paths. `docs/design/core-box-compatibility-decision.md` records selected encoding, Blender/Xcode/USD tool identities, Full/Lite proof digests, device model/OS, and both `xcresult-tree-sha256-v1` values from Section 1.4. A missing physical-device tree digest leaves Slice A blocked.

```bash
git add -A Features/Home/CoreBox Application CompatibilityHost CoreBoxCompatibilityUITests SomedayBoxTests/Fixtures SomedayBoxTests/Generated/CoreBoxProofIdentity.generated.swift SomedayBoxTests/CoreBoxRealityKitAssetTests.swift SomedayBoxTests/CoreBox2DParityTests.swift SomedayBox.xcodeproj/project.pbxproj SomedayBox.xcodeproj/xcshareddata/xcschemes/CoreBoxCompatibilityHost.xcscheme Assets/CoreBoxCharacter/export-config.json docs/design/core-box-compatibility-decision.md docs/superpowers/specs docs/adr
git commit -m "feat: prove the Core Box RealityKit presentation gate" -m " - Validate authored assets and sampled ribbon poses on both tiers
 - Keep all semantic actions functional through forced 2D fallback"
```

**Slice A exit gate:** Tasks 1-5 are complete, every commit is green, the spec explicitly separates this three-motion compatibility gate from Task 16's complete 13-motion production gate, Full/Lite proof export is reproducible, proof identity is sealed outside the production app bundle, and the verification host proves on Simulator and physical device that a real `RealityView` keeps one root through make/update, all three representative motions reach audited terminals, all ribbon samples work through RealityKit or the explicitly documented rigid-node fallback, and pre-install asset rejection preserves a functional 2D experience.

## Slice B — Product truth, coordinator, and interaction state

### Task 6: Return exact identities from atomic product transactions

**Files:**

- Modify: `Application/ProductRepository.swift`
- Modify: `Application/MutationArbiter.swift`
- Modify: `Application/DrawUseCases.swift`
- Modify: `Application/PaperUseCases.swift`
- Modify: `Application/LifecycleUseCases.swift`
- Modify: `Data/SwiftDataProductRepository.swift`
- Modify: `Data/GenerationProductRepository.swift`
- Modify: `SomedayBoxTests/ApplicationUseCaseTests.swift`
- Modify: `SomedayBoxTests/SwiftDataPersistenceTests.swift`
- Modify: `SomedayBoxTests/GenerationProductRepositoryTests.swift`
- Create: `SomedayBoxTests/CoreBoxTransactionReceiptTests.swift`
- Create: `SomedayBoxTests/Support/CoreBoxTestFixtures.swift`
- Modify: `SomedayBox.xcodeproj/project.pbxproj`

- [ ] **Step 1: Write failing transaction and receipt tests**

The tests must prove that IDs come from the same committed transaction and are never inferred from collection counts or a later snapshot.

```swift
@Suite("Atomic Core Box transaction receipts")
struct CoreBoxTransactionReceiptTests {
    @Test func completeReturnsTheCommittedMemoryIdentity() async throws {
        let itemID = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
        let memoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000201")!
        let repository = CoreBoxTestRepository(state: .coreBoxFixture(activeItemID: itemID))
        let useCase = CompletePaperUseCase(
            arbiter: MutationArbiter(repository: repository),
            clock: CoreBoxFixedClock(date: Date(timeIntervalSince1970: 100)),
            makeID: { memoryID }
        )

        let transaction = try await useCase.execute(itemID: itemID)

        #expect(transaction.outcome == CompletePaperResult(itemID: itemID, memoryID: memoryID))
        #expect(transaction.state.memories.map(\.id) == [memoryID])
    }

    @Test func redrawExhaustionCarriesTheEndedSession() async throws {
        let repository = CoreBoxTestRepository(state: .coreBoxFixtureWithExhaustedUnresolvedAttempt())
        let transaction = try await RedrawUseCase(
            arbiter: MutationArbiter(repository: repository),
            clock: CoreBoxFixedClock(date: Date(timeIntervalSince1970: 200))
        ).execute()

        guard case let .exhausted(previousAttemptID, previousItemID, sessionID, context) = transaction.outcome else {
            Issue.record("Expected exact exhausted receipt")
            return
        }
        #expect(previousAttemptID == PersistedProductState.fixtureAttemptID)
        #expect(previousItemID == PersistedProductState.fixtureItemID)
        #expect(sessionID == PersistedProductState.fixtureSessionID)
        #expect(context == DrawContext(preset: .fewMinutes))
    }
}
```

`SomedayBoxTests/Support/CoreBoxTestFixtures.swift` owns non-private reusable test support: an actor-backed `CoreBoxTestRepository` conforming to the new generic repository protocol, `CoreBoxFixedClock`, deterministic UUID/date constants, and the named `PersistedProductState.coreBoxFixture...` builders used from Tasks 6 onward. It must not rely on file-private helpers from existing XCTest files. Add it to the test target in this task.

- [ ] **Step 2: Run focused tests and verify the red state**

```bash
xcodebuild test \
  -project SomedayBox.xcodeproj \
  -scheme SomedayBox \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:SomedayBoxTests/CoreBoxTransactionReceiptTests \
  -only-testing:SomedayBoxTests/ApplicationUseCaseTests \
  -only-testing:SomedayBoxTests/SwiftDataPersistenceTests \
  -only-testing:SomedayBoxTests/GenerationProductRepositoryTests
```

Expected: compile failures because transactions and the receipt values are not yet generic or returned.

- [ ] **Step 3: Generalize the repository and arbiter transaction**

```swift
public struct ProductTransaction<Outcome: Sendable>: Sendable {
    public let outcome: Outcome
    public let state: PersistedProductState

    public init(outcome: Outcome, state: PersistedProductState) {
        self.outcome = outcome
        self.state = state
    }
}

public protocol ProductRepository: Sendable {
    func snapshot() async throws -> PersistedProductState

    func withTransaction<Outcome: Sendable>(
        _ mutation: @escaping @Sendable (inout PersistedProductState) throws -> Outcome
    ) async throws -> ProductTransaction<Outcome>
}

public struct MutationArbiter: Sendable {
    public func perform<Outcome: Sendable>(
        _ kind: ProductMutationKind,
        mutation: @escaping @Sendable (inout PersistedProductState) throws -> Outcome
    ) async throws -> ProductTransaction<Outcome> {
        try await repository.withTransaction { state in
            try validate(state)
            let hasUnresolvedAttempt = state.attempts.contains { $0.outcome == .unresolved }
            if hasUnresolvedAttempt && !kind.mayResolveUnresolvedDraw {
                throw ApplicationError.drawResolutionRequired
            }
            let outcome = try mutation(&state)
            try validate(state)
            return outcome
        }
    }
}
```

Both repositories must persist the mutated state before returning `ProductTransaction(outcome:state:)`. Their rollback behavior remains unchanged when validation or persistence throws. Add a convenience overload returning `ProductTransaction<Void>` only if an unchanged call site needs it; the generic method remains the single implementation.

- [ ] **Step 4: Return exact use-case receipt values**

```swift
public struct CapturePaperResult: Equatable, Sendable {
    public let itemID: UUID
}

public enum StartDrawResult: Equatable, Sendable {
    case revealed(DrawAttempt)
}

public enum RedrawResult: Equatable, Sendable {
    case revealed(previousAttemptID: UUID, previousItemID: UUID, attempt: DrawAttempt)
    case exhausted(previousAttemptID: UUID, previousItemID: UUID, sessionID: UUID, context: DrawContext)
}

public struct AcceptDrawResult: Equatable, Sendable {
    public let attemptID: UUID
    public let sessionID: UUID
    public let itemID: UUID
}

public struct DismissDrawResult: Equatable, Sendable {
    public let attemptID: UUID
    public let sessionID: UUID
    public let itemID: UUID
}

public struct CompletePaperResult: Equatable, Sendable {
    public let itemID: UUID
    public let memoryID: UUID
}

public struct PutBackPaperResult: Equatable, Sendable {
    public let itemID: UUID
}
```

Use-case `execute` methods return `ProductTransaction<Receipt>`. Construct each receipt inside its mutation closure from the records being changed. Capture returns its generated Item ID; Accept/Dismiss return the unresolved Attempt's exact IDs; Complete returns the generated Memory ID; Put Back returns the input Item ID; Redraw returns the previous Attempt and Item identities in both branches. Preserve `ImportSharedPaperResult.imported/alreadyImported` and return it in the same transaction so Share idempotency remains atomic.

This task does not add SwiftData fields and does not change product schema, backup format, or stored personal data.

- [ ] **Step 5: Run persistence and use-case tests**

```bash
xcodebuild test \
  -project SomedayBox.xcodeproj \
  -scheme SomedayBox \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:SomedayBoxTests/CoreBoxTransactionReceiptTests \
  -only-testing:SomedayBoxTests/ApplicationUseCaseTests \
  -only-testing:SomedayBoxTests/SwiftDataPersistenceTests \
  -only-testing:SomedayBoxTests/GenerationProductRepositoryTests
```

Expected: all receipt, rollback, serialization, idempotency, and persistence tests pass.

- [ ] **Step 6: Commit the atomic receipt boundary**

```bash
git add Application/ProductRepository.swift Application/MutationArbiter.swift Application/DrawUseCases.swift Application/PaperUseCases.swift Application/LifecycleUseCases.swift Data/SwiftDataProductRepository.swift Data/GenerationProductRepository.swift SomedayBoxTests/ApplicationUseCaseTests.swift SomedayBoxTests/SwiftDataPersistenceTests.swift SomedayBoxTests/GenerationProductRepositoryTests.swift SomedayBoxTests/CoreBoxTransactionReceiptTests.swift SomedayBoxTests/Support/CoreBoxTestFixtures.swift SomedayBox.xcodeproj/project.pbxproj
git commit -m "refactor: return atomic Core Box mutation receipts" -m " - Preserve exact transaction identities for presentation correlation
 - Keep repository rollback and persistence semantics unchanged"
```

### Task 7: Add three-state AppModel projection and reconciliation

**Files:**

- Create: `Application/CoreBoxMutationOutcome.swift`
- Create: `Application/CoreBoxProjection.swift`
- Create: `SomedayBoxTests/AppModelPresentationTests.swift`
- Modify: `SomedayBoxTests/Support/CoreBoxTestFixtures.swift`
- Modify: `SomedayBoxTests/CoreBoxPresentationTests.swift`
- Modify: `Application/CoreBoxPresentation.swift`
- Modify: `App/SomedayBoxApp.swift`
- Modify: `App/RootTabView.swift`
- Modify: `SomedayBox.xcodeproj/project.pbxproj`

- [ ] **Step 1: Write all three outcome, reconciliation, and in-flight-gate tests**

```swift
@MainActor
@Suite("AppModel presentation truth")
struct AppModelPresentationTests {
    @Test func failedCommitReturnsNotCommitted() async throws {
        let harness = try await CoreBoxAppModelHarness.make(
            forcedMutationFailure: ApplicationError.capacityExceeded(resource: .boxItems, limit: 1)
        )
        let model = harness.model
        let result = await model.capture(title: "Walk", note: nil, duration: .upTo30Minutes)
        #expect(result.isNotCommitted)
        #expect(model.requiresProjectionReconciliation == false)
    }

    @Test func committedCaptureReturnsReceiptAndMonotonicSnapshot() async throws {
        let harness = try await CoreBoxAppModelHarness.make()
        let model = harness.model
        let result = await model.capture(title: "Walk", note: nil, duration: .upTo30Minutes)
        guard case let .committed(outcome, snapshot) = result else {
            Issue.record("Expected committed projection")
            return
        }
        #expect(outcome.itemID == AppModel.fixtureItemID)
        #expect(snapshot.snapshotVersion == 1)
    }

    @Test func projectionFailureBlocksDuplicateMutationAndReconcilesStableTruth() async throws {
        let harness = try await CoreBoxAppModelHarness.make(projectionFailures: 1)
        let model = harness.model
        let first = await model.capture(title: "Walk", note: nil, duration: .upTo30Minutes)
        let second = await model.capture(title: "Walk", note: nil, duration: .upTo30Minutes)
        #expect(first.isCommittedButProjectionUnavailable)
        #expect(second == .notCommitted(failure: .reconciliationRequired))
        #expect(model.state.items.map(\.title) == ["Walk"])

        await model.retryProjection()

        #expect(model.requiresProjectionReconciliation == false)
        #expect(model.sceneSnapshot?.inBoxCount == 1)
    }

    @Test func failedProjectionAfterDrawStillExposesPersistedUnresolvedResult() async throws {
        let harness = try await CoreBoxAppModelHarness.make(drawReady: true, projectionFailures: 1)
        let model = harness.model
        let result = await model.startDraw(context: DrawContext(preset: .fewMinutes))
        #expect(result.isCommittedButProjectionUnavailable)
        #expect(model.unresolvedAttempt?.id == CoreBoxTestIdentity.attemptID)
        #expect(model.requiresProjectionReconciliation)
    }

    @Test func anInFlightMutationRejectsASecondSubmission() async throws {
        let barrier = CoreBoxMutationBarrier()
        let harness = try await CoreBoxAppModelHarness.make(mutationBarrier: barrier)
        let model = harness.model
        async let first = model.capture(
            title: "Walk",
            note: nil,
            duration: .upTo30Minutes
        )
        await barrier.waitUntilEntered()
        let second = await model.capture(
            title: "Walk again",
            note: nil,
            duration: .upTo30Minutes
        )
        #expect(second == .notCommitted(failure: .operationInProgress))
        await barrier.release()
        _ = await first
        #expect(model.state.items.map(\.title) == ["Walk"])
    }
}
```

- [ ] **Step 2: Confirm the focused tests fail**

```bash
xcodebuild test \
  -project SomedayBox.xcodeproj \
  -scheme SomedayBox \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:SomedayBoxTests/AppModelPresentationTests
```

Expected: compile failure for missing structured outcomes, projection loader, version, and reconciliation API.

- [ ] **Step 3: Define the projection result and injectable loader**

```swift
public enum AppMutationFailure: Error, Equatable, Sendable {
    case application(ApplicationError)
    case persistenceUnavailable
    case reconciliationRequired
    case operationInProgress
}

public enum AppMutationProjection<Outcome: Equatable & Sendable>: Equatable, Sendable {
    case notCommitted(failure: AppMutationFailure)
    case committed(outcome: Outcome, snapshot: CoreBoxSceneSnapshot)
    case committedButProjectionUnavailable(outcome: Outcome)
}

public struct CoreBoxPresetDrawCount: Equatable, Sendable {
    public let preset: DrawPresentationPreset
    public let count: Int
}

public struct CoreBoxDrawAvailability: Equatable, Sendable {
    public let totalSupportedCount: Int
    public let selectedContextEligibleCount: Int
    public let presetCounts: [CoreBoxPresetDrawCount]
}

public struct CoreBoxProjectionLoader: Sendable {
    public var load: @Sendable (
        _ state: PersistedProductState,
        _ snapshotVersion: UInt64,
        _ inputs: CoreBoxProjectionInputs
    ) async throws -> CoreBoxSceneSnapshot

    public static let live = Self { state, snapshotVersion, inputs in
        CoreBoxSceneSnapshotBuilder().build(
            state: state,
            inputs: inputs,
            snapshotVersion: snapshotVersion
        )
    }
}

public struct CoreBoxProjectionInputs: Equatable, Sendable {
    public let rendererTier: CoreBoxRendererTier
    public let motionMode: CoreBoxMotionMode
    public let drawContext: DrawContext?
    public let now: Date

    public init(
        rendererTier: CoreBoxRendererTier,
        motionMode: CoreBoxMotionMode,
        drawContext: DrawContext?,
        now: Date
    ) {
        self.rendererTier = rendererTier
        self.motionMode = motionMode
        self.drawContext = drawContext
        self.now = now
    }
}
```

In this task, update `CoreBoxSceneSnapshot` to replace the old scalar `drawableCount` with `drawAvailability`. Add a first green `CoreBoxSceneSnapshotBuilder` in `CoreBoxProjection.swift`: sort active Papers by `(createdAt, UUID string)`, exclude Current and unresolved Item IDs, compute total/selected/preset counts through `CandidatePoolBuilder`, and publish bounded Paper projections. The Task 7 baseline assigns `visualSeed = UInt64(sortedIndex)` and `ageBand = 0`; Task 9 begins with red tests that replace those exact interim values with the frozen FNV-1a and age-band contract. `CoreBoxProjectionLoader.live` above must be usable by the production App composition at the end of Task 7, so no commit depends on a type created by Task 9.

Add this injectable, production-safe seam to `AppModel`:

```swift
struct AppModelMutationHooks: Sendable {
    var beforeOperation: @Sendable () async throws -> Void
    static let live = Self(beforeOperation: {})
}
```

Extend the existing AppModel initializer with defaulted `projectionLoader: CoreBoxProjectionLoader = .live` and `mutationHooks: AppModelMutationHooks = .live` parameters, assign both stored properties before constructing use cases, and leave all existing production arguments and wiring unchanged. `projectMutation` calls `try await mutationHooks.beforeOperation()` only after acquiring `isMutating` and before invoking the repository operation. Production uses the no-op hook. `CoreBoxAppModelHarness` in the shared test-support file asynchronously opens a real `GenerationProductRepository` under a unique temporary `StoreGenerationConfiguration`, seeds deterministic state, injects a counted projection-failure loader and/or `CoreBoxMutationBarrier`, and returns a MainActor `AppModel`. The harness owns its exact support root and deletes only stale harness roots at the next harness creation; it never reuses private helpers from another test file.

- [ ] **Step 4: Replace the Bool mutation helper with a generic truth-preserving helper**

```swift
@MainActor
private func projectMutation<Outcome: Equatable & Sendable>(
    _ operation: () async throws -> ProductTransaction<Outcome>
) async -> AppMutationProjection<Outcome> {
    guard !requiresProjectionReconciliation else {
        return .notCommitted(failure: .reconciliationRequired)
    }
    guard !isMutating else {
        return .notCommitted(failure: .operationInProgress)
    }
    isMutating = true
    defer { isMutating = false }

    do {
        try await mutationHooks.beforeOperation()
        let transaction = try await operation()
        state = transaction.state
        guard snapshotVersion < UInt64.max else {
            requiresProjectionReconciliation = true
            return .committedButProjectionUnavailable(outcome: transaction.outcome)
        }
        let nextVersion = snapshotVersion + 1
        do {
            let snapshot = try await projectionLoader.load(
                transaction.state,
                nextVersion,
                projectionInputs
            )
            snapshotVersion = nextVersion
            sceneSnapshot = snapshot
            return .committed(outcome: transaction.outcome, snapshot: snapshot)
        } catch {
            requiresProjectionReconciliation = true
            return .committedButProjectionUnavailable(outcome: transaction.outcome)
        }
    } catch let error as ApplicationError {
        return .notCommitted(failure: .application(error))
    } catch {
        return .notCommitted(failure: .persistenceUnavailable)
    }
}
```

All Capture, Start Draw, Redraw, Accept, Dismiss, Put Back, Complete, and Share entry points call this helper and return their typed result. Preserve the existing AppModel `isMutating` property as the publicly readable, privately controlled in-flight gate; every mutation button and gesture shares it in its disabled predicate. They clear any retryable UI draft after both committed cases, because retrying a committed operation would duplicate truth.

- [ ] **Step 5: Implement read-only reconciliation as a root gate**

`state = transaction.state` occurs immediately after every successful transaction and before projection, so semantic Paper/Attempt/Current/Memory truth is never rolled back by presentation failure. `retryProjection()` calls `repository.snapshot()` and builds a fresh stable snapshot with a checked `snapshotVersion + 1`; `UInt64.max` remains fail-closed in reconciliation rather than wrapping. It never recreates an event from count differences, pending receipts, or the earlier transaction.

While reconciliation is active, root priority is:

```text
store load/error
  -> unresolved Draw result with embedded Retry Projection and disabled Accept/Redraw/Dismiss
  -> Shared Capture Recovery with embedded Retry Projection
  -> standalone projection reconciliation
  -> introduction
  -> app tabs
```

The unresolved and Recovery gates render committed semantic truth even before scene projection and never load 3D. They embed or forward the same retry action so the higher-priority gate cannot hide the only recovery path. Once a fresh projection succeeds, resolution controls re-enable, but the dropped reveal/deposit/notice event never replays.

- [ ] **Step 6: Cover Share idempotent receipts and root priority**

Add tests that a fresh import returns only IDs carried by `.imported`, while `.alreadyImported` remains distinguishable and never masquerades as fresh truth. Event batching and no-replay behavior are added only after the coordinator exists in Task 17. Test root ordering as:

```text
store load/error -> unresolved Draw result with reconciliation action -> Shared Capture Recovery with reconciliation action -> standalone projection reconciliation -> introduction -> app tabs
```

- [ ] **Step 7: Run focused and existing launch tests**

```bash
xcodebuild test \
  -project SomedayBox.xcodeproj \
  -scheme SomedayBox \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:SomedayBoxTests/AppModelPresentationTests \
  -only-testing:SomedayBoxTests/SharePayloadExtractionTests \
  -only-testing:SomedayBoxUITests/AppLaunchTests
```

Expected: all three result branches, mutation blocking, stable reconciliation, Share receipt identity, and root priorities pass.

- [ ] **Step 8: Commit the truth boundary**

```bash
git add Application/CoreBoxMutationOutcome.swift Application/CoreBoxProjection.swift Application/CoreBoxPresentation.swift App/SomedayBoxApp.swift App/RootTabView.swift SomedayBoxTests/AppModelPresentationTests.swift SomedayBoxTests/CoreBoxPresentationTests.swift SomedayBoxTests/Support/CoreBoxTestFixtures.swift SomedayBox.xcodeproj/project.pbxproj
git commit -m "feat: preserve post-commit presentation truth" -m " - Distinguish failed commits from projection failures
 - Reconcile read-only state without replaying transient motion"
```

### Task 8: Migrate renderer preferences to v2 without touching product data

**Files:**

- Modify: `Application/CoreBoxPresentation.swift`
- Modify: `Data/StoreRecoveryService.swift`
- Modify: `App/SomedayBoxApp.swift`
- Modify: `Features/Home/HomeView.swift`
- Modify: `Resources/Localizable.xcstrings`
- Create: `SomedayBoxTests/CoreBoxPreferenceMigrationTests.swift`
- Modify: `SomedayBoxTests/StoreRecoveryTests.swift`
- Modify: `SomedayBoxUITests/AppLaunchTests.swift`
- Modify: `SomedayBox.xcodeproj/project.pbxproj`

- [ ] **Step 1: Write mapping, interruption, idempotency, malformed-value, and erase tests**

```swift
@Suite("Core Box preference v2 migration")
struct CoreBoxPreferenceMigrationTests {
    @Test(arguments: [
        ("lite3D", CoreBoxRendererPreference.automatic),
        ("full3D", CoreBoxRendererPreference.full3D),
        ("swiftUI2D", CoreBoxRendererPreference.simplified2D),
        ("invalid", CoreBoxRendererPreference.automatic),
    ])
    func mapsLegacyRenderer(_ source: String, _ expected: CoreBoxRendererPreference) {
        let defaults = isolatedDefaults()
        defaults.set(source, forKey: "core-box-presentation-v1.renderer")
        let value = CoreBoxPresentationPreferenceStore(defaults: defaults).loadMigratingIfNeeded()
        #expect(value.renderer == expected)
    }

    @Test func markerIsWrittenLastAndRetryIsIdempotent() {
        let source = InMemoryPreferenceStorage.legacyFixture
        let writes = CoreBoxPreferenceMigrator().v2Writes(from: source)
        #expect(writes.last?.key == "core-box-presentation-v2.migrationCompleted")
        for appliedCount in 0...writes.count {
            let storage = source.copy()
            storage.apply(Array(writes.prefix(appliedCount)))
            let retried = CoreBoxPresentationPreferenceStore(storage: storage).loadMigratingIfNeeded()
            #expect(retried.renderer == .automatic)
            #expect(retried.quickAnimations == true)
            #expect(retried.soundEnabled == false)
            #expect(retried.hapticsEnabled == true)
            #expect(retried.ambienceEnabled == false)
            #expect(retried.lastDrawContext == "preset:few_minutes")
            #expect(retried.hasSeenFirstAnimation == true)
        }
    }
}
```

- [ ] **Step 2: Run and confirm failure against namespace v1**

```bash
xcodebuild test \
  -project SomedayBox.xcodeproj \
  -scheme SomedayBox \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:SomedayBoxTests/CoreBoxPreferenceMigrationTests \
  -only-testing:SomedayBoxTests/StoreRecoveryTests
```

Expected: compile/test failure because v2 preference and migration marker do not exist.

- [ ] **Step 3: Separate user preference from internal effective tier**

```swift
public enum CoreBoxRendererPreference: String, CaseIterable, Codable, Sendable {
    case automatic
    case full3D
    case simplified2D

    public var maximumTier: CoreBoxRendererTier {
        switch self {
        case .automatic, .full3D: .full3D
        case .simplified2D: .swiftUI2D
        }
    }
}

public struct CoreBoxPresentationPreferences: Equatable, Sendable {
    public static let namespace = "core-box-presentation-v2"
    public static let legacyNamespace = "core-box-presentation-v1"
    public var renderer: CoreBoxRendererPreference
    public var quickAnimations: Bool
    public var soundEnabled: Bool
    public var hapticsEnabled: Bool
    public var ambienceEnabled: Bool
    public var lastDrawContext: String?
    public var hasSeenFirstAnimation: Bool
}
```

Default renderer is `.automatic`. Lite remains an internal automatic/safety tier and is never shown as a selectable value.

Update the current nested Settings implementation in `HomeView.swift` in this same task so the repository remains buildable after the stored type changes. Its Picker binds `CoreBoxRendererPreference` and renders exactly Automatic, Full 3D, and Simplified 2D. Pass `preferences.renderer.maximumTier` to any stage API that still expects `CoreBoxRendererTier`. Task 14 moves this already-correct Settings UI into `Features/Settings/SettingsView.swift`; it does not defer the type migration.

- [ ] **Step 4: Implement write-values-first, marker-last migration**

Introduce a small `CoreBoxPreferenceStorage` protocol implemented by a `UserDefaults` wrapper and the test's in-memory dictionary. `CoreBoxPreferenceMigrator.v2Writes(from:)` returns a deterministic ordered array of key/value writes whose final element is the Boolean `core-box-presentation-v2.migrationCompleted=true`. Read v1 once when the marker is absent; map renderer values as tested; copy valid Quick, ambience, sound, haptics, last-context, and first-animation values; apply every v2 value; apply the marker last; then remove all v1 keys in a separate idempotent cleanup phase. If interrupted before the marker, the same input produces the same v2 output. If the marker exists, ignore v1 values and finish leftover-key cleanup.

- [ ] **Step 5: Reset both namespaces during Erase All**

`CoreBoxPresentationPreferenceStore.resetAllNamespaces()` removes every v1 key, every v2 key, the migration marker, last context, and first-animation value. Both `StoreRecoveryService` and AppModel's successful `eraseAllData()` path call that same method; delete the old narrower reset implementation so neither Erase All entry point can leave v1 keys behind. Backup import/export remains unaware of presentation preferences.

- [ ] **Step 6: Run migration and full store recovery tests**

```bash
xcodebuild test \
  -project SomedayBox.xcodeproj \
  -scheme SomedayBox \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:SomedayBoxTests/CoreBoxPreferenceMigrationTests \
  -only-testing:SomedayBoxTests/StoreRecoveryTests \
  -only-testing:SomedayBoxUITests/AppLaunchTests/testSettingsExposesV2RendererChoicesOnly

rg -q 'renderer\.automatic' Features/Home/HomeView.swift
rg -q 'renderer\.full3D' Features/Home/HomeView.swift
rg -q 'renderer\.simplified2D' Features/Home/HomeView.swift
! rg -q 'renderer\.lite3D' Features/Home/HomeView.swift
```

Expected: all mappings, copied independent fields, every simulated interruption point, repeated migration, malformed values, Erase All, and backup exclusion pass.

Add `AppLaunchTests.testSettingsExposesV2RendererChoicesOnly`: open Settings, assert identifiers `renderer.automatic`, `renderer.full3D`, and `renderer.simplified2D` are present after opening the renderer control, assert `renderer.lite3D` is absent, select each supported value, and assert the Home stage's diagnostic maximum tier. Keep the static `rg` assertions as an additional source check, not as the only UI evidence.

- [ ] **Step 7: Commit the migration**

```bash
git add Application/CoreBoxPresentation.swift Data/StoreRecoveryService.swift App/SomedayBoxApp.swift Features/Home/HomeView.swift Resources/Localizable.xcstrings SomedayBoxTests/CoreBoxPreferenceMigrationTests.swift SomedayBoxTests/StoreRecoveryTests.swift SomedayBoxUITests/AppLaunchTests.swift SomedayBox.xcodeproj/project.pbxproj
git commit -m "feat: migrate Core Box presentation preferences" -m " - Replace user-selectable Lite with Automatic renderer policy
 - Reset v1 and v2 presentation keys safely during Erase All"
```

### Task 9: Build deterministic scene snapshots from committed state

**Files:**

- Modify: `Application/CoreBoxProjection.swift`
- Create: `SomedayBoxTests/CoreBoxProjectionTests.swift`
- Modify: `SomedayBoxTests/Support/CoreBoxTestFixtures.swift`
- Modify: `Application/CoreBoxPresentation.swift`
- Modify: `App/SomedayBoxApp.swift`
- Modify: `SomedayBox.xcodeproj/project.pbxproj`

- [ ] **Step 1: Write count, exclusion, stable-slot, tier, and version tests**

```swift
@Suite("Core Box stable projection")
struct CoreBoxProjectionTests {
    @Test func countIncludesUnsupportedActivePaperButExcludesCurrentAndUnresolved() throws {
        let state = PersistedProductState.fixture(
            activeDurations: [
                DurationBucket.upTo10Minutes.rawValue,
                "future-duration",
                DurationBucket.upTo30Minutes.rawValue,
                DurationBucket.upTo60Minutes.rawValue,
            ],
            currentIndex: 2,
            unresolvedIndex: 3
        )
        let snapshot = CoreBoxSceneSnapshotBuilder().build(
            state: state,
            inputs: .fixture(rendererTier: .full3D, drawContext: DrawContext(preset: .fewMinutes)),
            snapshotVersion: 7
        )
        #expect(snapshot.inBoxCount == 2)
        #expect(snapshot.drawAvailability.totalSupportedCount == 1)
        #expect(snapshot.drawAvailability.selectedContextEligibleCount == 1)
        #expect(snapshot.snapshotVersion == 7)
    }

    @Test func noSelectedContextKeepsAvailabilityVisibleButDoesNotArmDraw() throws {
        let state = PersistedProductState.fixture(activeDurations: [
            DurationBucket.upTo10Minutes.rawValue,
            DurationBucket.upTo60Minutes.rawValue,
            "future-duration",
        ])
        let snapshot = CoreBoxSceneSnapshotBuilder().build(
            state: state,
            inputs: .fixture(rendererTier: .full3D, drawContext: nil),
            snapshotVersion: 8
        )
        #expect(snapshot.inBoxCount == 3)
        #expect(snapshot.drawAvailability.totalSupportedCount == 2)
        #expect(snapshot.drawAvailability.selectedContextEligibleCount == 0)
        #expect(snapshot.drawAvailability.presetCounts.first { $0.preset == .fewMinutes }?.count == 1)
    }

    @Test func slotMappingIsStableAndLiteIsTheFullPrefix() throws {
        let state = PersistedProductState.fixture(activeCount: 30)
        let full = CoreBoxSceneSnapshotBuilder().build(
            state: state,
            inputs: .fixture(rendererTier: .full3D),
            snapshotVersion: 1
        )
        let lite = CoreBoxSceneSnapshotBuilder().build(
            state: state,
            inputs: .fixture(rendererTier: .lite3D),
            snapshotVersion: 2
        )
        #expect(full.papers.count == 24)
        #expect(lite.papers.count == 10)
        #expect(Array(full.papers.prefix(10)).map(\.visualSeed) == lite.papers.map(\.visualSeed))
    }

    @Test func frozenUUIDSeedAndAgeBoundaryAreExact() throws {
        let now = Date(timeIntervalSince1970: 10_000_000)
        let itemID = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
        let state = PersistedProductState.coreBoxFixture(
            itemID: itemID,
            createdAt: now.addingTimeInterval(-7 * 24 * 60 * 60)
        )
        let snapshot = CoreBoxSceneSnapshotBuilder().build(
            state: state,
            inputs: .fixture(rendererTier: .full3D, now: now),
            snapshotVersion: 3
        )
        #expect(snapshot.papers.first?.visualSeed == 8_296_213_676_016_154_585)
        #expect(snapshot.papers.first?.ageBand == 1)
    }
}
```

- [ ] **Step 2: Run the tests and confirm the builder is missing**

```bash
xcodebuild test \
  -project SomedayBox.xcodeproj \
  -scheme SomedayBox \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:SomedayBoxTests/CoreBoxProjectionTests
```

Expected: FNV/age-band and stable-detail failures against Task 7's deliberately conservative live builder; the production loader and type already compile.

- [ ] **Step 3: Define exact projection inputs and stable UUID hashing**

```swift
public struct CoreBoxSceneSnapshotBuilder: Sendable {
    public init() {}

    public func build(
        state: PersistedProductState,
        inputs: CoreBoxProjectionInputs,
        snapshotVersion: UInt64
    ) -> CoreBoxSceneSnapshot {
        let currentID = state.currentPick?.itemID
        let unresolvedID = state.attempts.first { $0.outcome == .unresolved }?.itemID
        let sourcesByItem = Set(state.sources.map(\.itemID))
        let stable = state.items
            .filter { $0.lifecycle == .active && $0.id != currentID && $0.id != unresolvedID }
            .sorted { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }
        func eligibleCount(for context: DrawContext) -> Int {
            switch CandidatePoolBuilder().build(
                items: stable,
                context: context,
                currentPick: nil,
                reservedItemID: nil,
                shownItemIDs: []
            ) {
            case let .candidates(values): values.count
            case .empty: 0
            }
        }
        let availability = CoreBoxDrawAvailability(
            totalSupportedCount: stable.lazy.filter { $0.supportedDuration != nil }.count,
            selectedContextEligibleCount: inputs.drawContext.map(eligibleCount(for:)) ?? 0,
            presetCounts: DrawPresentationPreset.allCases.map {
                CoreBoxPresetDrawCount(preset: $0, count: eligibleCount(for: DrawContext(preset: $0)))
            }
        )
        let projections = stable.map { item in
            CoreBoxPaperProjection(
                visualSeed: Self.fnv1a64(item.id.uuidString.lowercased().utf8),
                imported: sourcesByItem.contains(item.id),
                ageBand: Self.ageBand(createdAt: item.createdAt, now: inputs.now)
            )
        }
        return CoreBoxSceneSnapshot(
            inBoxCount: stable.count,
            drawAvailability: availability,
            memoryCount: state.memories.count,
            hasCurrentPick: currentID != nil,
            papers: projections,
            rendererTier: inputs.rendererTier,
            motionMode: inputs.motionMode,
            snapshotVersion: snapshotVersion
        )
    }
}
```

`inBoxCount` includes unsupported-duration active Papers because they still exist visually. `totalSupportedCount` reports all currently actionable Papers independent of context, `presetCounts` keeps the unselected context picker truthful, and `selectedContextEligibleCount` alone arms Draw. Unknown durations enter none of the three drawability counts. `ageBand` is `0` for 0...6 days, `1` for 7...29, `2` for 30...89, and `3` for 90 or more. `fnv1a64` uses offset basis `14695981039346656037` and prime `1099511628211`; do not use Swift `Hasher`, whose seed is process-randomized.

- [ ] **Step 4: Make AppModel the sole monotonic version and effective-tier producer**

Every successful initial load, committed projection, reconciliation, renderer transition, and foreground refresh increments `snapshotVersion` exactly once. A failed projection does not publish or increment a snapshot. Add `requestRendererPreference(_:)` and `requestEffectiveRendererTier(_:reason:)` to AppModel: both settle through the root coordinator callback, update projection inputs/session caps, and publish a new snapshot before an adapter swap. Loader, Low Power, thermal, memory, or frame-budget components may request a tier but never mutate an adapter or snapshot tier themselves. Adapters receive only AppModel's `sceneSnapshot`, never rebuild counts independently. Thus asset failure cannot leave a snapshot claiming Full while the visible stable pose is 2D.

- [ ] **Step 5: Run focused tests and commit**

```bash
xcodebuild test \
  -project SomedayBox.xcodeproj \
  -scheme SomedayBox \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:SomedayBoxTests/CoreBoxProjectionTests \
  -only-testing:SomedayBoxTests/AppModelPresentationTests

git add Application/CoreBoxProjection.swift Application/CoreBoxPresentation.swift App/SomedayBoxApp.swift SomedayBoxTests/CoreBoxProjectionTests.swift SomedayBoxTests/Support/CoreBoxTestFixtures.swift SomedayBox.xcodeproj/project.pbxproj
git commit -m "feat: project deterministic Core Box scene truth" -m " - Derive stable Paper slots and authoritative counts from committed state
 - Publish monotonic snapshot versions from AppModel"
```

### Task 10: Implement coordinator priority, correlation, and channel ownership

**Files:**

- Create: `Application/CoreBoxPresentationCoordinator.swift`
- Create: `SomedayBoxTests/CoreBoxPresentationCoordinatorTests.swift`
- Modify: `Application/CoreBoxPresentation.swift`
- Modify: `SomedayBoxTests/CoreBoxPresentationTests.swift`
- Modify: `SomedayBox.xcodeproj/project.pbxproj`

- [ ] **Step 1: Write stale-command, priority, ownership, interruption, and terminal-pose tests**

```swift
@MainActor
@Suite("Core Box presentation coordinator")
struct CoreBoxPresentationCoordinatorTests {
    @Test func rejectsStaleSequenceAndSnapshotVersion() {
        let coordinator = CoreBoxPresentationCoordinator(snapshot: .fixture(version: 8))
        #expect(coordinator.accept(.fixture(sequence: 1, sourceVersion: 7)) == false)
        #expect(coordinator.accept(.fixture(sequence: 1, sourceVersion: 8)) == true)
        #expect(coordinator.accept(.fixture(sequence: 1, sourceVersion: 8)) == false)
    }

    @Test func committedPresentationInterruptsGestureAndOwnsOnlyDeclaredChannels() {
        let coordinator = CoreBoxPresentationCoordinator(snapshot: .fixture(version: 4))
        #expect(coordinator.beginRibbonPull(context: DrawContext(preset: .fewMinutes), nativeDrawEnabled: true))
        coordinator.updateRibbonPull(progress: 0.8)
        let result = coordinator.enqueue(
            event: .captureDeposit(itemID: UUID()),
            sourceSnapshotVersion: 4
        )
        #expect(result.cancelledOwner == .directGesture)
        #expect(coordinator.owner(of: .paper) == .committedTransaction)
        #expect(coordinator.owner(of: .leftEye) == nil)
        #expect(coordinator.owner(of: .rightEye) == nil)
    }
}
```

- [ ] **Step 2: Run and verify red**

```bash
xcodebuild test \
  -project SomedayBox.xcodeproj \
  -scheme SomedayBox \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:SomedayBoxTests/CoreBoxPresentationCoordinatorTests \
  -only-testing:SomedayBoxTests/CoreBoxPresentationTests
```

Expected: failure because current command acceptance ignores snapshot version and there is no coordinator or ownership model.

- [ ] **Step 3: Define exact ownership and priority values**

```swift
public enum CoreBoxChannel: CaseIterable, Hashable, Sendable {
    case root, lid, leftEye, rightEye, ribbon, paper, camera, memorySeam
}

public enum CoreBoxPresentationOwner: Int, Comparable, Sendable {
    case idle = 0
    case notice = 1
    case directGesture = 2
    case committedTransaction = 3
    case lifecycle = 4
    case rootGate = 5

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

public struct CoreBoxCorrelatedEvent: Equatable, Sendable {
    public let sequence: UInt64
    public let event: CoreBoxPresentationEvent
    public let sourceSnapshotVersion: UInt64
    public let motionMode: CoreBoxMotionMode

    public init(
        sequence: UInt64,
        event: CoreBoxPresentationEvent,
        sourceSnapshotVersion: UInt64,
        motionMode: CoreBoxMotionMode
    ) {
        self.sequence = sequence
        self.event = event
        self.sourceSnapshotVersion = sourceSnapshotVersion
        self.motionMode = motionMode
    }
}
```

The coordinator stores one optional owner per channel. A new owner may preempt only a lower-priority owner and receives only the channels declared for its event. Root gates and lifecycle may settle all channels. Stable settling always returns to a pose derived from the latest accepted snapshot.

Implement `CoreBoxPresentationCoordinator` as one `@MainActor @Observable final class`, importing `Observation`; its methods mutate actor-isolated class state and tests bind it with `let`. `RootTabView` later owns that single observable instance in SwiftUI `@State`. Do not also create a value-type reducer with the same responsibility, and do not copy a coordinator into child views.

- [ ] **Step 4: Correlate every command with current truth**

`accept(_:)` requires foreground lifecycle, `command.sequence > latestSequence`, and `command.sourceSnapshotVersion == snapshot.snapshotVersion`. Rejecting a command never advances `latestSequence`. Accepting a new snapshot clears commands created from older versions and rebuilds the stable pose instead of replaying them.

- [ ] **Step 5: Make Normal, Quick, and Reduced reach identical terminals**

Define timing selection as a pure function over motion mode plus `hasSeenFirstAnimation`:

```swift
public enum CoreBoxMotionTimingProfile: Equatable, Sendable {
    case first
    case normal
    case rapid
    case reduced
}

public enum CoreBoxMotionFamily: Equatable, Sendable {
    case lid, captureDeposit, ribbonReturn, drawReveal, peek, completion
}

public struct CoreBoxMotionTiming: Equatable, Sendable {
    public let durationMilliseconds: Int
    public let usesDepthMotion: Bool
}

public func timingProfile(
    motionMode: CoreBoxMotionMode,
    hasSeenFirstAnimation: Bool
) -> CoreBoxMotionTimingProfile {
    switch motionMode {
    case .reduced: .reduced
    case .quick: .rapid
    case .normal: hasSeenFirstAnimation ? .normal : .first
    }
}
```

Use this exact deterministic matrix, each value lying inside the approved parent range:

| Family | First | Normal | Rapid | Reduced |
| --- | ---: | ---: | ---: | ---: |
| Lid | 400 ms | 280 ms | 150 ms | state swap + 120 ms fade |
| Capture deposit | 775 ms | 470 ms | 220 ms | 150 ms fade/scale |
| Ribbon return | gesture + 220 ms | gesture + 220 ms | gesture + 220 ms | immediate rest + 120 ms fade |
| Draw reveal | 850 ms | 625 ms | 340 ms | 180 ms cross-fade |
| Peek | 550 ms | 425 ms | 220 ms | no camera travel + 150 ms content fade |
| Completion | 750 ms | 525 ms | 285 ms | immediate state + 150 ms fade |

Reduced mode never plays depth motion or idle and applies the same terminal pose. The first eligible, non-idle presentation uses `.first`; write `hasSeenFirstAnimation=true` only after that presentation reaches its stable terminal. An interrupted first presentation leaves the flag false. Add tests for profile mapping, every matrix value, the interrupted-first rule, and terminal equality for `capture.deposit`, `draw.reveal`, `paper.return`, and `memory.stamp` across all profiles.

Centralize new character haptics:

```swift
public enum CoreBoxHapticEvent: Equatable, Sendable {
    case thresholdLatch
    case committedDeposit
    case committedReveal
    case committedCompletion
}

public struct CoreBoxHapticPolicy: Sendable {
    public func permits(_ event: CoreBoxHapticEvent, hapticsEnabled: Bool) -> Bool {
        hapticsEnabled
    }
}
```

Only those four events are permitted. Threshold fires once per hysteresis latch; deposit/reveal/completion require their correlated committed snapshot; sequence deduplication prevents repeats. Idle, touch, Peek, Share notice, Current attach, failure, and fallback emit no new character haptic. Existing native time-preset selection feedback remains separate. Tests run all four events with Haptics off and assert zero generator calls.

- [ ] **Step 6: Run and commit**

```bash
xcodebuild test \
  -project SomedayBox.xcodeproj \
  -scheme SomedayBox \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:SomedayBoxTests/CoreBoxPresentationCoordinatorTests \
  -only-testing:SomedayBoxTests/CoreBoxPresentationTests

git add Application/CoreBoxPresentationCoordinator.swift Application/CoreBoxPresentation.swift SomedayBoxTests/CoreBoxPresentationCoordinatorTests.swift SomedayBoxTests/CoreBoxPresentationTests.swift SomedayBox.xcodeproj/project.pbxproj
git commit -m "feat: coordinate Core Box motion ownership" -m " - Reject stale presentation commands by sequence and snapshot
 - Settle interrupted channels to authoritative stable poses"
```

### Task 11: Implement the context-armed ribbon gesture contract

**Files:**

- Create: `Features/Home/CoreBox/CoreBoxInteractionSurface.swift`
- Create: `SomedayBoxTests/CoreBoxRibbonInteractionTests.swift`
- Modify: `Application/CoreBoxPresentation.swift`
- Modify: `Application/CoreBoxPresentationCoordinator.swift`
- Modify: `SomedayBox.xcodeproj/project.pbxproj`

- [ ] **Step 1: Write exact threshold, hysteresis, cancel, second-finger, and one-intent tests**

```swift
@Suite("Core Box ribbon interaction")
struct CoreBoxRibbonInteractionTests {
    @Test func unselectedOrDisabledRibbonCannotBegin() {
        var state = CoreBoxRibbonInteractionState()
        #expect(state.begin(context: nil, nativeDrawEnabled: true, pointerCount: 1) == false)
        #expect(state.begin(context: DrawContext(preset: .fewMinutes), nativeDrawEnabled: false, pointerCount: 1) == false)
    }

    @Test func thresholdLatchesOnceAndRearmerIsPointFiveFive() {
        var state = CoreBoxRibbonInteractionState()
        #expect(state.begin(context: DrawContext(preset: .fewMinutes), nativeDrawEnabled: true, pointerCount: 1))
        #expect(state.update(progress: 0.73) == .thresholdLatched)
        #expect(state.update(progress: 0.71) == .progressChanged)
        #expect(state.update(progress: 0.73) == .progressChanged)
        #expect(state.update(progress: 0.54) == .thresholdRearmed)
        #expect(state.update(progress: 0.73) == .thresholdLatched)
    }

    @Test func releaseEmitsExactlyOneIntentOnlyAtOrAbovePointSevenTwo() {
        var state = CoreBoxRibbonInteractionState()
        #expect(state.begin(context: DrawContext(preset: .fewMinutes), nativeDrawEnabled: true, pointerCount: 1))
        _ = state.update(progress: 0.72)
        #expect(state.release() == .draw(DrawContext(preset: .fewMinutes)))
        #expect(state.release() == .none)
    }

    @Test func secondPointerAndViewDisappearanceCancelToRest() {
        var state = CoreBoxRibbonInteractionState.armedFixture
        _ = state.update(progress: 1.0)
        #expect(state.pointerCountChanged(to: 2) == .cancelled)
        #expect(state.progress == 0)
        #expect(state.isLatched == false)
    }

    @Test func resolvedBodyTapReactsThenPeeksOnlyWhenSemanticTargetIsAvailable() {
        #expect(CoreBoxBodyTapPolicy().disposition(peekIntentAvailable: true) == .reactThenPeek)
        #expect(CoreBoxBodyTapPolicy().disposition(peekIntentAvailable: false) == .reactOnly)
    }
}
```

- [ ] **Step 2: Run and confirm failure**

```bash
xcodebuild test \
  -project SomedayBox.xcodeproj \
  -scheme SomedayBox \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:SomedayBoxTests/CoreBoxRibbonInteractionTests
```

Expected: compile failure for the new state and intent values.

- [ ] **Step 3: Implement the pure gesture state before SwiftUI wiring**

```swift
public enum CoreBoxRibbonFeedback: Equatable, Sendable {
    case none
    case progressChanged
    case thresholdLatched
    case thresholdRearmed
    case cancelled
    case draw(DrawContext)
}

public enum CoreBoxBodyTapDisposition: Equatable, Sendable {
    case reactOnly
    case reactThenPeek
}

public struct CoreBoxBodyTapPolicy: Sendable {
    public init() {}
    public func disposition(peekIntentAvailable: Bool) -> CoreBoxBodyTapDisposition {
        peekIntentAvailable ? .reactThenPeek : .reactOnly
    }
}

public struct CoreBoxRibbonInteractionState: Equatable, Sendable {
    public static let threshold = 0.72
    public static let hysteresisRearm = 0.55

    public private(set) var context: DrawContext?
    public private(set) var progress = 0.0
    public private(set) var isLatched = false
    public private(set) var isActive = false
    public private(set) var hasEmittedIntent = false
}
```

`begin` accepts exactly one pointer, a selected valid context, foreground lifecycle, no covering gate, and the same `nativeDrawEnabled` Boolean used by the native Draw button. `update` clamps progress to `0...1`; a first upward crossing of `0.72` latches and may emit one haptic; it cannot latch again until progress goes below `0.55`. `release` at or above `0.72` emits exactly one `.draw(context)`; every lower release returns to `.armed` rest, not general interaction idle. Cancellation, second pointer, scene teardown, sheet, root gate, background, and renderer transition return exact rest with no intent.

- [ ] **Step 4: Connect RealityKit hit proxies and count active pointers**

When an asset is installed, configure only `Hit_Ribbon`, `Hit_Lid`, `Hit_Box`, and `Hit_MemorySeam` as inputs. For each, derive a box shape from its authored visual bounds and install:

```swift
let bounds = hitEntity.visualBounds(relativeTo: hitEntity)
hitEntity.components.set(
    CollisionComponent(
        shapes: [.generateBox(size: bounds.extents)],
        mode: .trigger
    )
)
hitEntity.components.set(InputTargetComponent(allowedInputTypes: .all))
```

The 3D ribbon uses `DragGesture(minimumDistance: 0).targetedToAnyEntity()` and ignores targets whose entity name is not `Hit_Ribbon`. Normalize downward screen-space translation with `progress = clamp(translation.height / 92.0, 0, 1)`. Simultaneously attach `SpatialEventGesture().targetedToAnyEntity()`; for `Hit_Ribbon`, count events whose phase is `.active` and kind is `.touch`. Passing a count greater than one to `pointerCountChanged(to:)` immediately cancels to rest. The lid targeted gesture accepts only `Hit_Lid` and opens Peek directly. A resolved `Hit_Box` tap always emits one `react.touch`; when the shared `peekIntentAvailable` predicate is true (foreground, stable Home, no covering gate/mutation/reconciliation, and native Peek enabled), the coordinator opens Peek after the touch reaches its terminal. That exact resolved hit is the specification's “clear target.” When the predicate is false it reacts without opening; an un-targeted empty-stage tap does nothing. The 2D body hit region follows the same rule.

The functional 2D adapter uses a 54×132 pt screen-right SwiftUI hit region and the same pure state; it adds a small UIKit multi-touch observer whose `UIPanGestureRecognizer.maximumNumberOfTouches = 1` converts a second touch into cancellation. Send continuous progress to the adapter on changes and business intent only from the pure state's release result.

- [ ] **Step 5: Run tests and commit**

```bash
xcodebuild test \
  -project SomedayBox.xcodeproj \
  -scheme SomedayBox \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:SomedayBoxTests/CoreBoxRibbonInteractionTests \
  -only-testing:SomedayBoxTests/CoreBoxPresentationCoordinatorTests

git add Features/Home/CoreBox/CoreBoxInteractionSurface.swift Application/CoreBoxPresentation.swift Application/CoreBoxPresentationCoordinator.swift SomedayBoxTests/CoreBoxRibbonInteractionTests.swift SomedayBox.xcodeproj/project.pbxproj
git commit -m "feat: add the context-armed ribbon interaction" -m " - Share Draw enablement across native and side-ribbon controls
 - Enforce threshold hysteresis cancellation and one intent"
```

### Task 12: Add seeded idle scheduling and stable-boundary degradation

**Files:**

- Create: `Application/CoreBoxIdleScheduler.swift`
- Create: `Application/CoreBoxRendererHealthPolicy.swift`
- Create: `App/CoreBoxRendererHealthMonitor.swift`
- Create: `SomedayBoxTests/CoreBoxIdleSchedulerTests.swift`
- Create: `SomedayBoxTests/CoreBoxRendererHealthPolicyTests.swift`
- Modify: `Application/CoreBoxPresentationCoordinator.swift`
- Modify: `Application/CoreBoxPresentation.swift`
- Modify: `Features/Home/CoreBox/CoreBoxSceneAdapter.swift`
- Modify: `App/SomedayBoxApp.swift`
- Modify: `SomedayBox.xcodeproj/project.pbxproj`

- [ ] **Step 1: Write deterministic scheduling and cancellation tests**

```swift
@Suite("Core Box idle scheduler")
struct CoreBoxIdleSchedulerTests {
    @Test func opportunitiesStayWithinTwelveToTwentyFourSeconds() {
        var scheduler = CoreBoxIdleScheduler(seed: 42)
        let delays = (0..<20).map { _ in scheduler.nextDelaySeconds() }
        var repeatedScheduler = CoreBoxIdleScheduler(seed: 42)
        let repeated = (0..<20).map { _ in repeatedScheduler.nextDelaySeconds() }
        #expect(delays.allSatisfy { 12...24 ~= $0 })
        #expect(delays == repeated)
    }

    @Test func preconditionsFilterVocabulary() {
        var scheduler = CoreBoxIdleScheduler(seed: 7)
        let empty = scheduler.nextAction(preconditions: .stableEmpty)
        #expect([.blink, .listen].contains(empty))
        let current = scheduler.nextAction(preconditions: .stableWithPapersAndCurrent)
        #expect([.blink, .listen, .paperRustle, .currentGlance].contains(current))
    }

    @Test func coveringGateCancelsSleepAndTerminalSchedulesTheNextOpportunity() async {
        let clock = TestIdleClock()
        let recorder = CoreBoxIdleActionRecorder()
        let controller = CoreBoxIdleController(clock: clock, seed: 9, onAction: recorder.record)
        await controller.begin(preconditions: .stableEmpty)
        #expect(await clock.pendingSleepCount == 1)
        await clock.advanceNextSleep()
        #expect(await recorder.actions.count == 1)
        #expect(await clock.pendingSleepCount == 0)
        await controller.actionDidSettle(preconditions: .stableEmpty)
        #expect(await clock.pendingSleepCount == 1)
        await controller.cancel(reason: .coveringGate)
        #expect(await clock.cancelledSleepCount == 1)
        #expect(await clock.pendingSleepCount == 0)
    }
}
```

Add pure health-policy tests in the same red step:

```swift
@Suite("Core Box renderer health policy")
struct CoreBoxRendererHealthPolicyTests {
    @Test func lowPowerCapsFullAtLiteAndNeverUpgradesExplicit2D() {
        var full = CoreBoxRendererHealthPolicy(preference: .full3D, effectiveTier: .full3D)
        #expect(full.receive(.lowPowerChanged(true), nowSeconds: 10) == .lite3D)
        var twoD = CoreBoxRendererHealthPolicy(preference: .simplified2D, effectiveTier: .swiftUI2D)
        #expect(twoD.receive(.lowPowerChanged(false), nowSeconds: 10) == nil)
    }

    @Test func frameBudgetRequiresTwoConsecutiveCompleteBreachWindows() {
        var policy = CoreBoxRendererHealthPolicy(preference: .automatic, effectiveTier: .full3D)
        let breach = CoreBoxFrameWindow(sampleCount: 120, elapsedMilliseconds: 3_000, p95Milliseconds: 26, hardBudgetFraction: 0.11)
        #expect(policy.receive(.frameWindow(breach), nowSeconds: 10) == nil)
        #expect(policy.receive(.frameWindow(breach), nowSeconds: 14) == .lite3D)
    }

    @Test func accumulatorCarriesActiveSamplesAcrossSettledActionGaps() {
        var accumulator = CoreBoxFrameWindowAccumulator(requiredSampleCount: 120)
        for _ in 0..<60 {
            #expect(accumulator.appendActiveFrame(milliseconds: 26) == nil)
        }
        accumulator.suspendAtStableBoundary()
        #expect(accumulator.sampleCount == 60)
        for index in 0..<60 {
            let window = accumulator.appendActiveFrame(milliseconds: 26)
            #expect((index == 59) == (window != nil))
        }
        #expect(accumulator.sampleCount == 0)
    }

    @Test func accumulatorResetsOnlyForLifecycleOrTierDiscontinuity() {
        var accumulator = CoreBoxFrameWindowAccumulator(requiredSampleCount: 120)
        _ = accumulator.appendActiveFrame(milliseconds: 16)
        accumulator.suspendAtStableBoundary()
        #expect(accumulator.sampleCount == 1)
        accumulator.reset(reason: .background)
        #expect(accumulator.sampleCount == 0)
    }

    @Test func sustainedSlowWindowsRemainBreachesBeyondFourSeconds() {
        let fullSlow = CoreBoxFrameWindow(sampleCount: 120, elapsedMilliseconds: 4_080, p95Milliseconds: 34, hardBudgetFraction: 1.0)
        var full = CoreBoxRendererHealthPolicy(preference: .automatic, effectiveTier: .full3D)
        #expect(full.receive(.frameWindow(fullSlow), nowSeconds: 1) == nil)
        #expect(full.receive(.frameWindow(fullSlow), nowSeconds: 6) == .lite3D)

        let liteSlow = CoreBoxFrameWindow(sampleCount: 120, elapsedMilliseconds: 4_920, p95Milliseconds: 41, hardBudgetFraction: 0.0)
        var lite = CoreBoxRendererHealthPolicy(preference: .automatic, effectiveTier: .lite3D)
        #expect(lite.receive(.frameWindow(liteSlow), nowSeconds: 1) == nil)
        #expect(lite.receive(.frameWindow(liteSlow), nowSeconds: 7) == .swiftUI2D)
    }

    @Test func healthyWindowResetsBreachAndCooldownCoalescesStrongestRequest() {
        var policy = CoreBoxRendererHealthPolicy(preference: .automatic, effectiveTier: .full3D)
        let breach = CoreBoxFrameWindow(sampleCount: 120, elapsedMilliseconds: 3_000, p95Milliseconds: 26, hardBudgetFraction: 0.11)
        let healthy = CoreBoxFrameWindow(sampleCount: 120, elapsedMilliseconds: 3_000, p95Milliseconds: 16, hardBudgetFraction: 0.0)
        _ = policy.receive(.frameWindow(breach), nowSeconds: 1)
        #expect(policy.receive(.frameWindow(healthy), nowSeconds: 5) == nil)
        #expect(policy.receive(.frameWindow(breach), nowSeconds: 9) == nil)
        #expect(policy.receive(.memoryWarning, nowSeconds: 10) == .lite3D)
        policy.didPublish(tier: .lite3D, nowSeconds: 10)
        #expect(policy.receive(.thermal(.critical), nowSeconds: 15) == nil)
        #expect(policy.poll(nowSeconds: 40) == .swiftUI2D)
    }
}
```

- [ ] **Step 2: Run and verify red**

```bash
xcodebuild test \
  -project SomedayBox.xcodeproj \
  -scheme SomedayBox \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:SomedayBoxTests/CoreBoxIdleSchedulerTests \
  -only-testing:SomedayBoxTests/CoreBoxRendererHealthPolicyTests
```

Expected: compile failure for scheduler, clock, preconditions, controller, health signals, policy, and frame windows.

- [ ] **Step 3: Implement seeded opportunity and action selection**

Use SplitMix64 with the injected seed. Map the next value to integer seconds `12...24`; map another value onto the filtered action list. Idle actions are `blink`, `listen`, `paperRustle`, and `currentGlance`; Paper rustle requires non-empty committed pool, and Current glance requires committed Current Pick. Reduced Motion, non-visible Home, covering sheet/gate, active interaction, mutation, renderer transition, background, or reconciliation yields no action and cancels the current sleep task.

```swift
public enum CoreBoxIdleAction: CaseIterable, Equatable, Sendable {
    case blink, listen, paperRustle, currentGlance
}

public struct CoreBoxIdlePreconditions: Equatable, Sendable {
    public let isEligible: Bool
    public let hasPapers: Bool
    public let hasCurrentPick: Bool

    public static let stableEmpty = Self(isEligible: true, hasPapers: false, hasCurrentPick: false)
    public static let stableWithPapersAndCurrent = Self(isEligible: true, hasPapers: true, hasCurrentPick: true)
}

public protocol CoreBoxIdleClock: Sendable {
    func sleep(for duration: Duration) async throws
}

public struct CoreBoxIdleScheduler: Sendable {
    private var generator: SplitMix64
    public init(seed: UInt64) { generator = SplitMix64(seed: seed) }

    public mutating func nextDelaySeconds() -> Int {
        12 + Int(generator.next() % 13)
    }

    public mutating func nextAction(preconditions: CoreBoxIdlePreconditions) -> CoreBoxIdleAction? {
        guard preconditions.isEligible else { return nil }
        var actions: [CoreBoxIdleAction] = [.blink, .listen]
        if preconditions.hasPapers { actions.append(.paperRustle) }
        if preconditions.hasCurrentPick { actions.append(.currentGlance) }
        return actions[Int(generator.next() % UInt64(actions.count))]
    }
}

public struct SplitMix64: Sendable {
    private var state: UInt64

    public init(seed: UInt64) { state = seed }

    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}

public actor CoreBoxIdleController {
    private let clock: any CoreBoxIdleClock
    private var scheduler: CoreBoxIdleScheduler
    private var task: Task<Void, Never>?
    private let onAction: @Sendable (CoreBoxIdleAction) async -> Void
    private var lastPreconditions: CoreBoxIdlePreconditions?

    public init(
        clock: any CoreBoxIdleClock,
        seed: UInt64,
        onAction: @escaping @Sendable (CoreBoxIdleAction) async -> Void = { _ in }
    ) {
        self.clock = clock
        scheduler = CoreBoxIdleScheduler(seed: seed)
        self.onAction = onAction
    }

    public func begin(preconditions: CoreBoxIdlePreconditions) {
        task?.cancel()
        lastPreconditions = preconditions
        guard let action = scheduler.nextAction(preconditions: preconditions) else {
            task = nil
            return
        }
        let delay = scheduler.nextDelaySeconds()
        task = Task {
            do {
                try await clock.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { return }
                await onAction(action)
            } catch {
                return
            }
        }
    }

    public func actionDidSettle(preconditions: CoreBoxIdlePreconditions) {
        guard lastPreconditions != nil else { return }
        begin(preconditions: preconditions)
    }

    public func cancel(reason: CoreBoxSettleReason) {
        task?.cancel()
        task = nil
        lastPreconditions = nil
    }
}
```

The coordinator calls `actionDidSettle` only after the adapter reports the idle action's stable terminal and supplies freshly evaluated preconditions; an interrupted or ineligible idle instead calls `cancel` and does not self-reschedule. `TestIdleClock` is continuation-driven, so the test advances virtual sleeps without wall-clock delay. Stable no-tick behavior is verified in `CoreBoxStageLifecycleTests` through a recording scene adapter with zero frame-update subscriptions; do not expose a Boolean that is never set merely to make this test pass.

- [ ] **Step 4: Implement exact health signals, windows, cooldown, and ownership**

Define the pure Application contract:

```swift
public enum CoreBoxThermalLevel: Equatable, Sendable { case nominal, fair, serious, critical }

public struct CoreBoxFrameWindow: Equatable, Sendable {
    public let sampleCount: Int
    public let elapsedMilliseconds: Int
    public let p95Milliseconds: Double
    public let hardBudgetFraction: Double
}

public enum CoreBoxRendererHealthSignal: Equatable, Sendable {
    case lowPowerChanged(Bool)
    case memoryWarning
    case thermal(CoreBoxThermalLevel)
    case frameWindow(CoreBoxFrameWindow)
}
```

`CoreBoxRendererHealthPolicy` is the sole decision reducer. Internal order is `swiftUI2D < lite3D < full3D`; it never returns an upgrade. Low Power true caps Automatic or Full 3D at Lite; false never upgrades during the launch. One memory warning requests exactly one lower tier. Thermal serious caps at Lite and critical caps at 2D. A complete frame window has exactly 120 active-presentation samples, positive `elapsedMilliseconds` with no upper bound, finite positive p95, and `hardBudgetFraction` in `0...1`; a directly injected invalid/incomplete window resets the policy's breach streak. A long window is never invalid merely because rendering was slow: 120 × 34 ms Full and 120 × 41 ms Lite remain complete breach windows. Compute p95 with nearest-rank index `ceil(0.95 * count) - 1` over ascending finite durations. Full breaches when p95 is greater than 25 ms or more than 10% exceed 33.3 ms; Lite breaches when p95 is greater than 40 ms or more than 10% exceed 66.7 ms. Two consecutive complete breach windows request one lower tier; a healthy window resets the streak. After AppModel publishes the requested tier, a 30-second monotonic cooldown begins. Signals during cooldown are coalesced to the strongest lower cap and `poll(nowSeconds:)` emits it once at expiry. Simplified 2D preference ignores every upgrade-like signal, and no policy state writes product data.

`CoreBoxRendererHealthMonitor` is `@MainActor` and owns the live signal sources: `Notification.Name.NSProcessInfoPowerStateDidChange` plus `ProcessInfo.isLowPowerModeEnabled`, `ProcessInfo.thermalStateDidChangeNotification` plus current `thermalState`, and `UIApplication.didReceiveMemoryWarningNotification`. It converts them to the pure enum with an injected monotonic-seconds closure and forwards accepted requests to the coordinator. It also owns `CoreBoxFrameWindowAccumulator`, whose raw finite positive frame durations survive terminal/settle gaps between bounded actions. `elapsedMilliseconds` is the rounded sum of those 120 active-frame durations, never wall-clock idle time; p95 and the tier-specific hard-budget fraction are computed only when sample 120 arrives. Emission atomically clears those 120 samples and begins the next window. A normal action terminal calls `suspendAtStableBoundary()` and preserves the partial count; backgrounding, scene teardown, effective-tier replacement, or an invalid frame duration calls `reset(reason:)`. No incomplete frame-window signal is emitted.

`CoreBoxSceneAdapter` subscribes to `SceneEvents.Update` only while a bounded animation or ribbon gesture owns a channel, forwards each active-frame duration to that persistent accumulator, and cancels the subscription at terminal/settle. Stable idle therefore has zero frame subscription without discarding the 1...119 samples accumulated by earlier actions. Tests inject signal streams and time, never post global system notifications.

The coordinator stores at most one pending health cap. If a gesture, committed presentation, root gate, background settlement, or reconciliation owns channels, it first reaches/cancels to a stable boundary; then it calls AppModel's `requestEffectiveRendererTier`. Only AppModel's newer snapshot authorizes replacement. A memory/thermal/frame source never mutates an adapter or tier directly, and an asset-load failure remains the separate immediate validation path from Task 13.

- [ ] **Step 5: Add lifecycle tests and run green**

Test background cancellation within one second, no resume of interrupted animation, stable foreground rebuild, explicit 2D never upgraded, and no degradation during a partially sampled gesture until it has settled. With injected signal streams, also prove one subscription per live notification source, cancellation on monitor teardown, exact thermal mapping, 60 + 60 active frames from two separate actions produce one complete window, an intervening stable gap preserves the first 60 samples, background/tier replacement clears partial samples, healthy frame-window streak reset, 30-second cooldown, strongest-cap coalescing, and zero `SceneEvents.Update` subscription after terminal settle.

```bash
xcodebuild test \
  -project SomedayBox.xcodeproj \
  -scheme SomedayBox \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:SomedayBoxTests/CoreBoxIdleSchedulerTests \
  -only-testing:SomedayBoxTests/CoreBoxRendererHealthPolicyTests \
  -only-testing:SomedayBoxTests/CoreBoxPresentationCoordinatorTests
```

- [ ] **Step 6: Commit scheduler and policy**

```bash
git add Application/CoreBoxIdleScheduler.swift Application/CoreBoxRendererHealthPolicy.swift App/CoreBoxRendererHealthMonitor.swift App/SomedayBoxApp.swift Features/Home/CoreBox/CoreBoxSceneAdapter.swift Application/CoreBoxPresentationCoordinator.swift Application/CoreBoxPresentation.swift SomedayBoxTests/CoreBoxIdleSchedulerTests.swift SomedayBoxTests/CoreBoxRendererHealthPolicyTests.swift SomedayBoxTests/CoreBoxPresentationCoordinatorTests.swift SomedayBox.xcodeproj/project.pbxproj
git commit -m "feat: schedule restrained Core Box idle motion" -m " - Use a seeded cancellable idle opportunity stream
 - Degrade renderers only after stable channel settlement"
```

### Task 13: Wire the shared snapshot/event contract into RealityView and 2D

**Files:**

- Create: `Features/Home/CoreBox/CoreBoxStage.swift`
- Create: `Features/Home/CoreBox/CoreBoxRealityStage.swift`
- Modify: `Features/Home/CoreBox/CoreBoxSceneAdapter.swift`
- Modify: `Features/Home/CoreBox/CoreBox2DAdapter.swift`
- Create: `SomedayBoxTests/CoreBoxStageLifecycleTests.swift`
- Modify: `SomedayBoxTests/CoreBox2DParityTests.swift`
- Modify: `SomedayBox.xcodeproj/project.pbxproj`

- [ ] **Step 1: Write update, teardown, transition, and parity tests**

```swift
@MainActor
@Suite("Core Box stage lifecycle")
struct CoreBoxStageLifecycleTests {
    @Test func aNewSnapshotUpdatesAnExistingAdapter() async throws {
        let adapter = RecordingCoreBoxAdapter()
        let controller = CoreBoxStageController(loader: .failingFixture, adapter: adapter)
        controller.update(snapshot: .fixture(version: 1, inBoxCount: 2), event: nil)
        controller.update(snapshot: .fixture(version: 2, inBoxCount: 3), event: nil)
        #expect(adapter.appliedSnapshotVersions == [1, 2])
        #expect(adapter.stablePaperCounts == [2, 3])
    }

    @Test func teardownCancelsEverySubscription() {
        let adapter = RecordingCoreBoxAdapter(subscriptionCount: 3)
        CoreBoxStageController(loader: .failingFixture, adapter: adapter).teardown()
        #expect(adapter.cancelledSubscriptionCount == 3)
        #expect(adapter.hasPerFrameWork == false)
    }

    @Test func sameSnapshotEventDoesNotReapplyStablePoseFirst() {
        let adapter = RecordingCoreBoxAdapter()
        let controller = CoreBoxStageController(loader: .failingFixture, adapter: adapter)
        let snapshot = CoreBoxSceneSnapshot.fixture(version: 4, inBoxCount: 2)
        controller.update(snapshot: snapshot, event: nil)
        controller.update(snapshot: snapshot, event: .fixture(sequence: 9, sourceVersion: 4))
        #expect(adapter.appliedSnapshotVersions == [4])
        #expect(adapter.appliedEvents.count == 1)
    }

    @Test func stablePoseHasNoFrameUpdateSubscription() {
        let adapter = RecordingCoreBoxAdapter()
        let controller = CoreBoxStageController(loader: .failingFixture, adapter: adapter)
        controller.update(snapshot: .fixture(version: 1, inBoxCount: 2), event: nil)
        #expect(adapter.frameUpdateSubscriptionCount == 0)
    }

    @Test func staleReplacementCannotWinAnABATierChange() async {
        let loader = ControllableCoreBoxAssetLoader()
        let controller = CoreBoxStageController(loader: loader.loader, adapter: RecordingCoreBoxAdapter())
        controller.install(.fixture(tier: .full3D))
        async let first: Void = controller.prepareReplacement(tier: .lite3D)
        await loader.waitForRequestCount(1)
        await controller.prepareReplacement(tier: .full3D)
        loader.succeedRequest(at: 0, with: .fixture(tier: .lite3D))
        _ = await first
        #expect(controller.takePreparedReplacement()?.tier == nil)
    }
}
```

- [ ] **Step 2: Run and verify the missing update path**

```bash
xcodebuild test \
  -project SomedayBox.xcodeproj \
  -scheme SomedayBox \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:SomedayBoxTests/CoreBoxStageLifecycleTests \
  -only-testing:SomedayBoxTests/CoreBox2DParityTests
```

Expected: compile failure for stage/controller and adapter recording hooks.

- [ ] **Step 3: Implement one make path and one update path**

```swift
import Foundation
import Observation

struct CoreBoxStablePose: Equatable, Sendable {
    let snapshotVersion: UInt64
    let inBoxCount: Int
    let visiblePapers: [CoreBoxPaperProjection]
    let hasCurrentPick: Bool
    let memorySeamVisible: Bool
    let lid: CoreBoxLidState
    let draw: CoreBoxDrawState
    let rendererTier: CoreBoxRendererTier
    let motionMode: CoreBoxMotionMode
}

enum CoreBoxStageError: Error {
    case generationExhausted
}

@MainActor @Observable
final class CoreBoxStageController {
    private let loader: CoreBoxAssetLoader
    private var adapter: any CoreBoxPresentationAdapter
    private var latestSnapshotVersion: UInt64?
    private var latestEventSequence: UInt64 = 0
    private var preparedReplacement: CoreBoxLoadedAsset?
    private var installedTier: CoreBoxRendererTier?
    private var requestedTier: CoreBoxRendererTier?
    private var activeReplacementRequestID: UUID?
    private let requestEffectiveTier: @MainActor (CoreBoxRendererTier, CoreBoxFallbackReason) -> Void
    private(set) var replacementGeneration: UInt64 = 0
    private(set) var isAwaitingTierProjection = false
    var hasInstalledAsset: Bool { installedTier != nil }

    init(
        loader: CoreBoxAssetLoader,
        adapter: any CoreBoxPresentationAdapter,
        requestEffectiveTier: @escaping @MainActor (CoreBoxRendererTier, CoreBoxFallbackReason) -> Void = { _, _ in }
    ) {
        self.loader = loader
        self.adapter = adapter
        self.requestEffectiveTier = requestEffectiveTier
    }

    func load(tier: CoreBoxRendererTier) async throws -> CoreBoxLoadedAsset {
        try await loader.load(tier: tier)
    }

    func install(_ loaded: CoreBoxLoadedAsset) {
        adapter.settle(reason: .rendererTransition)
        installedTier = loaded.tier
        requestedTier = nil
        activeReplacementRequestID = nil
        adapter = CoreBoxSceneAdapter(loaded: loaded)
        latestSnapshotVersion = nil
    }

    func prepareReplacement(tier: CoreBoxRendererTier) async {
        guard hasInstalledAsset else { return }
        if tier == installedTier {
            requestedTier = nil
            activeReplacementRequestID = nil
            preparedReplacement = nil
            return
        }
        guard tier != requestedTier else { return }
        let requestID = UUID()
        requestedTier = tier
        activeReplacementRequestID = requestID
        do {
            let loaded = try await loader.load(tier: tier)
            guard !Task.isCancelled,
                  activeReplacementRequestID == requestID,
                  requestedTier == tier else { return }
            guard replacementGeneration < UInt64.max else {
                reject3DForLaunch(CoreBoxStageError.generationExhausted)
                return
            }
            preparedReplacement = loaded
            replacementGeneration += 1
        } catch {
            guard !Task.isCancelled,
                  activeReplacementRequestID == requestID,
                  requestedTier == tier else { return }
            reject3DForLaunch(error)
        }
    }

    func takePreparedReplacement() -> CoreBoxLoadedAsset? {
        defer { preparedReplacement = nil }
        return preparedReplacement
    }

    func update(snapshot: CoreBoxSceneSnapshot, event: CoreBoxCorrelatedEvent?) {
        if snapshot.rendererTier == .swiftUI2D {
            isAwaitingTierProjection = false
        }
        if let latestSnapshotVersion {
            guard snapshot.snapshotVersion >= latestSnapshotVersion else { return }
            if snapshot.snapshotVersion > latestSnapshotVersion {
                adapter.apply(snapshot: snapshot)
                self.latestSnapshotVersion = snapshot.snapshotVersion
            }
        } else {
            adapter.apply(snapshot: snapshot)
            latestSnapshotVersion = snapshot.snapshotVersion
        }
        guard let event,
              event.sourceSnapshotVersion == snapshot.snapshotVersion,
              event.sequence > latestEventSequence else { return }
        latestEventSequence = event.sequence
        adapter.apply(event: event.event, sourceSnapshotVersion: event.sourceSnapshotVersion)
    }

    func reject3DForLaunch(_ error: any Error) {
        adapter.settle(reason: .validationFailure)
        requestedTier = nil
        activeReplacementRequestID = nil
        isAwaitingTierProjection = true
        let reason: CoreBoxFallbackReason = (error is CoreBoxAssetValidationError || error is CoreBoxStageError) ? .assetValidation : .assetLoad
        requestEffectiveTier(.swiftUI2D, reason)
    }

    func teardown() {
        requestedTier = nil
        activeReplacementRequestID = nil
        adapter.settle(reason: .cancelled)
    }
}

struct CoreBoxRealityStage: View {
    let snapshot: CoreBoxSceneSnapshot
    let event: CoreBoxCorrelatedEvent?
    let controller: CoreBoxStageController

    var body: some View {
        let replacementGeneration = controller.replacementGeneration
        RealityView { content in
            do {
                let loaded = try await controller.load(tier: snapshot.rendererTier)
                content.camera = .virtual
                content.add(loaded.root)
                content.cameraTarget = loaded.root.findEntity(named: "Camera_Default")
                controller.install(loaded)
                controller.update(snapshot: snapshot, event: event)
            } catch {
                controller.reject3DForLaunch(error)
            }
        } update: { content in
            _ = replacementGeneration
            if let loaded = controller.takePreparedReplacement() {
                content.entities.replaceAll([loaded.root])
                content.camera = .virtual
                content.cameraTarget = loaded.root.findEntity(named: "Camera_Default")
                controller.install(loaded)
            }
            controller.update(snapshot: snapshot, event: event)
        }
        .task(id: snapshot.rendererTier) {
            guard controller.hasInstalledAsset else { return }
            await controller.prepareReplacement(tier: snapshot.rendererTier)
        }
        .onDisappear { controller.teardown() }
        .accessibilityHidden(true)
    }
}
```

`CoreBoxStage` creates `CoreBoxRealityStage` only for `.full3D` or `.lite3D`; a `.swiftUI2D` snapshot never enters the RealityKit loader. It may keep its already-mounted functional 2D surface visible while `isAwaitingTierProjection` is true, but that flag is not renderer truth. AppModel records the launch-local 3D rejection cap and publishes a newer `.swiftUI2D` snapshot; only then does the stage select the 2D adapter and clear the pending flag. It never retries 3D during that launch. On an intentional snapshot-authorized tier transition it first settles, prepares the new asset, replaces the content root once, then reapplies the latest snapshot; Full and Lite never coexist in the content collection. Every replacement request receives a unique ID, so an older Full/Lite load cannot win after an A→B→A request sequence.

`CoreBoxStageError.generationExhausted` is a stable internal validation error that fails the launch to 2D instead of wrapping. The make closure shows a temporary stable functional 2D surface until identity validation and async load finish. The update closure applies only a strictly newer snapshot; a later event on the same snapshot is accepted without reapplying stable pose first, so SwiftUI recomputation cannot cancel an animation and then lose it to sequence deduplication. Installing a replacement resets only snapshot application, not `latestEventSequence`, so the latest stable pose is rebuilt without replaying a transient event. The scene adapter resolves named entities once into a dictionary, validates uniqueness, retains subscriptions explicitly, and permits per-frame work only while sampling `ribbon.pull` or a bounded active animation.

- [ ] **Step 4: Make both adapters converge on the same stable model**

`CoreBoxStablePose` is the adapter-independent result of snapshot plus interaction state. Both adapters implement:

```swift
func apply(snapshot: CoreBoxSceneSnapshot)
func apply(event: CoreBoxPresentationEvent, sourceSnapshotVersion: UInt64)
func applyRibbon(progress: Double, latched: Bool)
func settle(reason: CoreBoxSettleReason)
```

2D must show the same in-Box count, selected context/armed state, Current presence, Memory seam state, Peek stable open state, Reveal semantic state, and disabled conditions. It may simplify depth motion but may not remove an action.

- [ ] **Step 5: Run stage and parity tests, then commit**

```bash
xcodebuild test \
  -project SomedayBox.xcodeproj \
  -scheme SomedayBox \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:SomedayBoxTests/CoreBoxStageLifecycleTests \
  -only-testing:SomedayBoxTests/CoreBox2DParityTests \
  -only-testing:SomedayBoxTests/CoreBoxRealityKitAssetTests

git add Features/Home/CoreBox/CoreBoxStage.swift Features/Home/CoreBox/CoreBoxRealityStage.swift Features/Home/CoreBox/CoreBoxSceneAdapter.swift Features/Home/CoreBox/CoreBox2DAdapter.swift SomedayBoxTests/CoreBoxStageLifecycleTests.swift SomedayBoxTests/CoreBox2DParityTests.swift SomedayBox.xcodeproj/project.pbxproj
git commit -m "feat: update Core Box adapters from shared scene truth" -m " - Apply snapshots and correlated events through RealityView updates
 - Keep functional 2D terminal states equivalent to 3D"
```

### Task 14: Hard-cut Home to context-first Draw and root-owned coordination

**Files:**

- Create: `Features/Draw/DrawContextPicker.swift`
- Create: `Features/Draw/DrawRevealGate.swift`
- Create: `Features/Capture/CaptureView.swift`
- Create: `Features/Settings/SettingsView.swift`
- Create: `Features/Home/CoreBox/CoreBoxPeekView.swift`
- Create: `App/UITestLaunchConfiguration.swift`
- Create: `SomedayBoxUITests/Support/UITestLauncher.swift`
- Modify: `Features/Home/HomeView.swift`
- Modify: `App/SomedayBoxApp.swift`
- Modify: `App/RootTabView.swift`
- Modify: `Resources/Localizable.xcstrings`
- Create: `SomedayBoxUITests/CoreBoxHomeUITests.swift`
- Modify: `SomedayBox.xcodeproj/project.pbxproj`

- [ ] **Step 1: Add stable accessibility identifiers and write the context-first UI tests**

Create the shared UI-test launcher in the test target before writing journeys:

```swift
enum CoreBoxUITestFixture: Equatable {
    case emptyBox
    case activePapers(Int)
    case manyPapers(Int)
    case drawReady
    case unresolvedAttempt
    case unresolvedAttemptWithAlternative
    case exhaustedRedraw
    case current
    case memories
    case freshShare(Int)
    case alreadyImportedShare
    case recovery

    var launchValue: String {
        switch self {
        case .emptyBox: "empty-box"
        case let .activePapers(count): "active-papers:\(count)"
        case let .manyPapers(count): "many-papers:\(count)"
        case .drawReady: "draw-ready"
        case .unresolvedAttempt: "unresolved-attempt"
        case .unresolvedAttemptWithAlternative: "unresolved-attempt-with-alternative"
        case .exhaustedRedraw: "exhausted-redraw"
        case .current: "current"
        case .memories: "memories"
        case let .freshShare(count): "fresh-share:\(count)"
        case .alreadyImportedShare: "already-imported-share"
        case .recovery: "recovery"
        }
    }
}

struct CoreBoxUITestLaunchOptions {
    var assetFailure: String? = nil
    var projectionFailures = 0
    var renderer: String? = nil
    var motionMode: String? = nil
    var lowPowerCap = false
}

extension XCTestCase {
    @MainActor
    func launchFixture(
        _ fixture: CoreBoxUITestFixture,
        options: CoreBoxUITestLaunchOptions = .init()
    ) -> XCUIApplication {
        let app = XCUIApplication()
        let runID = UUID().uuidString.lowercased()
        var environment = [
            "SOMEDAY_BOX_UI_TESTING": "1",
            "SOMEDAY_BOX_UI_TEST_RUN_ID": runID,
            "SOMEDAY_BOX_UI_TEST_FIXTURE": fixture.launchValue,
            "SOMEDAY_BOX_UI_TEST_PROJECTION_FAILURES": String(options.projectionFailures),
            "SOMEDAY_BOX_UI_TEST_LOW_POWER_CAP": options.lowPowerCap ? "1" : "0",
        ]
        if let value = options.assetFailure { environment["SOMEDAY_BOX_UI_TEST_ASSET_FAILURE"] = value }
        if let value = options.renderer { environment["SOMEDAY_BOX_UI_TEST_RENDERER"] = value }
        if let value = options.motionMode { environment["SOMEDAY_BOX_UI_TEST_MOTION_MODE"] = value }
        app.launchEnvironment = environment
        app.launch()
        addTeardownBlock { app.terminate() }
        return app
    }
}
```

```swift
@MainActor
final class CoreBoxHomeUITests: XCTestCase {
    func testContextSelectionArmsBothDrawEntrypoints() {
        let app = launchFixture(.activePapers(3))
        let nativeDraw = app.buttons["home.draw"]
        let ribbon = app.otherElements["home.ribbon"]
        XCTAssertFalse(nativeDraw.isEnabled)
        XCTAssertEqual(ribbon.value as? String, "Not armed")

        app.buttons["draw.context.fewMinutes"].tap()

        XCTAssertTrue(nativeDraw.isEnabled)
        XCTAssertEqual(ribbon.value as? String, "Armed, a few minutes")
        XCTAssertEqual(app.otherElements["home.drawable.selected.count"].value as? String, "3")
    }

    func testRibbonBelowThresholdReturnsArmedWithoutStartingDraw() {
        let app = launchFixture(.activePapers(3))
        app.buttons["draw.context.fewMinutes"].tap()
        let ribbon = app.otherElements["home.ribbon"]
        let start = ribbon.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 60)))
        XCTAssertFalse(app.otherElements["draw.reveal.result"].exists)
        XCTAssertEqual(ribbon.value as? String, "Armed, a few minutes")
    }

    func testRibbonAboveThresholdStartsDrawWithoutReopeningContextPicker() {
        let app = launchFixture(.activePapers(3))
        app.buttons["draw.context.fewMinutes"].tap()
        let ribbon = app.otherElements["home.ribbon"]
        let start = ribbon.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 72)))
        XCTAssertTrue(app.otherElements["draw.reveal.result"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.sheets["draw.context.sheet"].exists)
    }
}
```

These coordinate drags are end-to-end smoke checks deliberately placed safely below and above the threshold; they do not claim pixel-exact `0.72` coverage. The pure Task 11 state tests remain authoritative for exact `0.72`, `0.55`, cancellation, and exactly-once intent behavior.

- [ ] **Step 2: Run and prove the current prototype violates the contract**

```bash
xcodebuild test \
  -project SomedayBox.xcodeproj \
  -scheme SomedayBox \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:SomedayBoxUITests/CoreBoxHomeUITests
```

Expected: failure because current ribbon release opens Draw Context and the context selector is not embedded before arming.

- [ ] **Step 3: Implement the minimum Debug-only isolated launch configuration**

`UITestLaunchConfiguration` accepts the launcher keys only under `#if DEBUG`, validates `SOMEDAY_BOX_UI_TEST_RUN_ID` as a lowercase UUID, and lets the app—not the XCTest runner—derive a child named with that run ID under `FileManager.default.temporaryDirectory/someday-box-ui-tests/` inside the app sandbox. At every UI-test launch the app removes only its exact `someday-box-ui-tests` child before creating the run directory; UI tests are serial, so cleanup cannot race another fixture. Never pass an XCTest-container absolute path to the app. Task 14 implements decoding/seeding for `empty-box`, `active-papers:3`, and `draw-ready`; the associated-value fixture vocabulary is frozen now, and each later journey task adds its app-side decoder/seed before using another case. In non-Debug builds the configuration is always disabled and does not read process environment. App composition selects the isolated repository before constructing AppModel; production repository selection is unchanged when disabled.

- [ ] **Step 4: Move page-local types out of `HomeView.swift`**

Move Capture, Peek, Settings, stage, and 2D implementations into their mapped files without behavior changes first. Keep `HomeView` as composition plus native actions. Add each file explicitly to the project. Extract String Catalog updates as the same task because identifiers and visible text must land together; do not overwrite unrelated catalog entries.

- [ ] **Step 5: Make Root own one coordinator across Home and reveal**

`RootTabView` creates one `@State`/observable `CoreBoxPresentationCoordinator` and passes it into Home, Capture, Peek, and Draw Reveal. It survives Home → unresolved reveal transition. Recovery remains independent: it does not construct, validate, or load the coordinator's 3D adapter.

- [ ] **Step 6: Replace the old mutation sheet with selection-only context UI**

`DrawContextPicker` displays the existing time choices and writes only the selected `DrawContext` plus last-context preference. It reads `presetCounts` before selection, never treats `totalSupportedCount` as eligibility for a chosen context, and never calls `StartDrawUseCase`. Selection and clearing call `AppModel.updateDrawContext(_:)`, which updates `projectionInputs.drawContext`, rebuilds a read-only snapshot from the latest committed state, and publishes `snapshotVersion + 1`; therefore `selectedContextEligibleCount`, native Draw enablement, and ribbon enablement change atomically. A projection failure leaves both controls disabled and enters the same read-only reconciliation surface. Remove `presentsDrawContext`, the old `DrawContextView` mutation route, and the ribbon callback that merely opens that sheet.

Both entry points call one closure:

```swift
let drawEnabled = selectedContext != nil
    && snapshot.drawAvailability.selectedContextEligibleCount > 0
    && !model.requiresProjectionReconciliation
    && !model.isMutating
    && model.unresolvedAttempt == nil

func requestDraw() {
    guard drawEnabled, let selectedContext else { return }
    Task { await startDraw(context: selectedContext) }
}
```

The async Draw handler switches all three results. `.committed` applies snapshot and reveal event; `.committedButProjectionUnavailable` enters the embedded reconciliation path; `.notCommitted` enqueues `.failureSettle` against the current snapshot, returns the ribbon to armed rest, and displays the native error. The same failure mapping applies whether intent came from the ribbon or native Draw button.

Threshold crossing only updates latch/haptic. Release at or above `0.72` calls `requestDraw()` exactly once. Native Draw calls the same function. Release below threshold returns ribbon to armed rest.

- [ ] **Step 7: Make reveal semantic content immediate and focused**

`DrawRevealGate` renders the persisted result text immediately at opacity 1. Optional 3D/2D presentation begins independently and never delays the result. Add `@AccessibilityFocusState` and focus `draw.reveal.result` as soon as the committed projection is available. Reduced Motion applies the stable result with a short fade and no Paper flight.

- [ ] **Step 8: Run Home, reveal, root gate, and accessibility smoke tests**

```bash
xcodebuild test \
  -project SomedayBox.xcodeproj \
  -scheme SomedayBox \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:SomedayBoxUITests/CoreBoxHomeUITests \
  -only-testing:SomedayBoxUITests/AppLaunchTests \
  -only-testing:SomedayBoxTests/CoreBoxRibbonInteractionTests \
  -only-testing:SomedayBoxTests/AppModelPresentationTests
```

Expected: context selection arms both paths; disabled states match; below threshold never mutates; at threshold release mutates exactly once; persisted reveal is immediately visible and focused; root priorities remain unchanged.

- [ ] **Step 9: Commit the Home flow hard cut**

```bash
git add Features/Home/HomeView.swift Features/Home/CoreBox Features/Draw Features/Capture/CaptureView.swift Features/Settings/SettingsView.swift App/SomedayBoxApp.swift App/RootTabView.swift App/UITestLaunchConfiguration.swift Resources/Localizable.xcstrings SomedayBoxUITests/Support/UITestLauncher.swift SomedayBoxUITests/CoreBoxHomeUITests.swift SomedayBox.xcodeproj/project.pbxproj
git commit -m "feat: make Home Draw context-first" -m " - Arm native and side-ribbon Draw from one selected context
 - Keep reveal semantics immediate across optional character motion"
```

**Slice B exit gate:** product mutations return atomic receipts; AppModel distinguishes all three truth states; reconciliation prevents duplicates and replay; v2 preferences migrate safely; snapshots are deterministic; coordinator priority/channel ownership is tested; the side ribbon obeys context, threshold, hysteresis, and cancellation; RealityView updates existing scenes; and Home uses the approved choose-time-then-pull flow.

## Slice C — Production character, complete journeys, and release closure

### Task 15: Replace the proof mesh with the production paper-spirit character

**Files:**

- Modify: `Assets/CoreBoxCharacter/CoreBoxCharacter.blend`
- Delete: `Assets/CoreBoxCharacter/scripts/build-core-box-spike.py`
- Replace: `Assets/CoreBoxCharacter/textures/core-box-basecolor.png`
- Replace: `Assets/CoreBoxCharacter/textures/core-box-normal.png`
- Replace: `Assets/CoreBoxCharacter/textures/core-box-roughness.png`
- Replace: `Assets/CoreBoxCharacter/textures/core-box-ao.png`
- Modify: `Assets/CoreBoxCharacter/scripts/export-core-box.py`
- Replace: `SomedayBoxTests/Fixtures/CoreBoxProofFull.usdz`
- Replace: `SomedayBoxTests/Fixtures/CoreBoxProofLite.usdz`
- Replace: `SomedayBoxTests/Fixtures/CoreBoxProofReport.json`
- Replace: `SomedayBoxTests/Generated/CoreBoxProofIdentity.generated.swift`
- Modify: `scripts/tests/test_core_box_blend_source.py`
- Create: `SomedayBoxTests/CoreBoxContactShadowTests.swift`
- Create: `docs/design/core-box-character-model-sheet.md`
- Modify: `SomedayBox.xcodeproj/project.pbxproj`

- [ ] **Step 1: Tighten source tests to production geometry and material targets**

```python
PRODUCTION_TARGETS = {
    "full": {
        "triangleTarget": 40000,
        "triangleCeiling": 60000,
        "renderableTarget": 60,
        "renderableCeiling": 80,
        "materialSlotCeiling": 8,
    },
    "lite": {
        "triangleTarget": 16000,
        "triangleCeiling": 25000,
        "renderableTarget": 30,
        "renderableCeiling": 36,
        "materialSlotCeiling": 6,
    },
}

class ProductionBlendSourceTests(unittest.TestCase):
    def test_final_character_uses_only_approved_expression_channels(self) -> None:
        report = run_blender_preflight()
        self.assertEqual(report["mouthMeshCount"], 0)
        self.assertEqual(report["limbMeshCount"], 0)
        self.assertEqual(report["electronicDisplayCount"], 0)
        self.assertEqual(
            set(report["expressionChannels"]),
            {"BoxRoot", "LidPivot", "EyeLeftPivot", "EyeRightPivot", "RibbonRoot"},
        )

    def test_final_character_meets_tier_targets_or_hard_ceilings(self) -> None:
        report = run_blender_preflight()
        for tier, target in PRODUCTION_TARGETS.items():
            self.assertLessEqual(report[tier]["triangles"], target["triangleCeiling"])
            self.assertLessEqual(report[tier]["renderables"], target["renderableCeiling"])
            self.assertLessEqual(report[tier]["materialSlots"], target["materialSlotCeiling"])
```

- [ ] **Step 2: Run production source tests against the proof model**

```bash
/usr/bin/python3 -B -m unittest scripts.tests.test_core_box_blend_source -v
```

Expected: failure because the proof mesh lacks final topology, UV/fiber detail, production texture dimensions, and final geometry reports.

- [ ] **Step 3: Model the Full silhouette at real scale**

Model in `SOURCE_SHARED` and author explicit production meshes in `EXPORT_FULL`. Preserve `BoxRoot` identity, meter units, `+Y` up, and the 0.30 m × 0.18 m × 0.22 m physical envelope.

Use this exact shape construction:

- Body: 0.300 m wide, 0.148 m tall, 0.214 m deep; top is 3% narrower than bottom; four folded corner bands are 0.012 m wide; bevel radius is 0.006...0.010 m with two support loops.
- Lid: separate 0.306 m × 0.038 m × 0.222 m folded shell; rear fold pivots around `LidPivot`; front lip is 0.014 m deep and never occludes the eyes at `Camera_Default`.
- Eyes: two moss-ink paper inlays, each 0.024 m × 0.014 m, centered at local X `-0.052` and `+0.052`; no mouth, limb, electronic face, or emission.
- Ribbon: screen-right local `+X` mount at `(0.132, 0.102, 0.086)`; five bounded segments plus tip; 0.018 m visible width; woven edge thickness 0.0015 m; no face crossing in rest or sampled pull.
- Paper pool: thin folded cards at named rest anchors, visible only from committed projection; no rigid-body or cloth simulation.
- Memory seam: 0.180 m × 0.003 m near the lower front edge; emission intensity is zero when memory count is zero, stable low amber when nonzero, and one bounded pulse only from a committed `memory.stamp`.
- Contact shadow: `ShadowReceiver` is a visible 32-segment horizontal ellipse centered at `(0.0, 0.001, 0.012)`, no larger than `0.240 m × 0.105 m`, with no collision/input component. It binds `MAT_ContactShadow`, whose UVs sample a moss-black radial alpha patch in the basecolor atlas: center alpha `0.14`, alpha `0` at the perimeter, roughness `1`, metallic `0`, no normal detail, and no emission. Hit proxies remain invisible and never contribute visible triangles.

Allocate the Full target approximately as body/folds 14k, lid 7k, eyes 1k, ribbon 4k, Papers 6k, seam/interior/decoration 3k, leaving at least 5k target headroom. Hard ceiling remains 60k.

- [ ] **Step 4: Author an explicit Lite mesh rather than runtime decimation**

Keep semantic pivots and unchanged objects in `SOURCE_SHARED`, linked into both export collections. For any mesh, light, or material binding that differs, author `FullSource__Name` only in `EXPORT_FULL` and `LiteSource__Name` only in `EXPORT_LITE`, with both objects carrying the same exact `coreBoxPublicName`. The exporter performs the temporary public-name normalization defined in Task 3; the checked-in `.blend` never contains ambiguous duplicate public names. Remove hidden loops, bake fold relief into normals, simplify ribbon cross-sections, and keep exactly 10 Lite Paper anchors. Target body/folds 6k, lid 3k, eyes 500, ribbon 1.5k, Papers 2k, seam/interior/decoration 1.5k. Hard ceiling remains 25k. Lite retains every interaction, the same rest silhouette, and every stable terminal pose.

- [ ] **Step 5: Paint four source atlases and export three runtime maps**

Author all four source PNGs at 2048×2048. Task 3's audited converter resamples AO, multiplies it into linear basecolor, and emits exactly three runtime maps: production Full at 2048 basecolor plus 512 normal/roughness, and Lite at 1024 basecolor plus 512 normal/roughness. The original four 2048 sources remain the editable master inputs; no standalone AO relationship enters USDZ.

- Maple paper base center: `#E5C99F`; roughness centered at `0.78`; normal amplitude no more than `0.15`; fiber scale remains visible at Home size without becoming noisy.
- Sage ribbon base center: `#768B68`; edge `#5D7255`; roughness centered at `0.82`; weave stays directional along the ribbon.
- Moss-ink eye base center: `#1F3328`; roughness centered at `0.62`; catchlight comes from lighting, not emission.
- Interior/Memory amber center: `#D68B46`; emission is adapter-controlled and bounded; no full-screen bloom.

All texture paths are repository-relative. There are no UDIMs, linked libraries, generated temporary images, or unpacked absolute paths. Every active render UV map is exactly `st`. Using the conservative RGBA8 full-mip formula, Full must report 25,165,820 bytes and Lite 8,388,604 bytes; any standalone AO output, different staging dimension, or value above 32/16 MiB fails.

- [ ] **Step 6: Fix the virtual cameras and lighting composition**

Author:

- `Camera_Default` at `(0.0, 0.27, 0.58)`, 52 mm lens, aimed at `(0.0, 0.095, 0.0)`; ribbon remains screen right.
- `Camera_Peek` at `(0.0, 0.35, 0.36)`, aimed at `(0.0, 0.105, 0.0)`.
- `Camera_Overview` at `(0.0, 0.31, 0.48)`, aimed at `(0.0, 0.09, 0.0)`.
- Full `Light_Key` at `(-0.28, 0.42, 0.34)` with one restrained shadow and angular softness `6°`, plus `Light_Fill` at `(0.24, 0.26, 0.30)` without a second shadow. Dynamic shadow opacity must not make any pixel beneath the body more than 24% darker than the same fixed-camera render with `Light_Key` shadow disabled.
- Lite exports one non-shadowing fill/environment solution and no shadow-casting light; its authored `MAT_ContactShadow` ellipse supplies the same grounded reading without a runtime shadow pass.

`CoreBoxContactShadowTests` loads both proof tiers through the validated loader and asserts `ShadowReceiver` has the exact mesh/material/no-input contract; Full reports one shadow-casting light and Lite zero. The model-sheet captures fixed-camera Full and Lite renders on light and dark SwiftUI stage colors, plus a debug-only shadow-hidden comparison. Visual acceptance requires a soft connected shadow beneath the body, no hard edge, no face/ribbon contamination, and no shadow pixel outside the authored `0.240 m × 0.105 m` footprint. Physical-device review in Task 22 repeats those four frames. The character palette remains stable between appearances.

- [ ] **Step 7: Capture model-sheet evidence**

`docs/design/core-box-character-model-sheet.md` records front, three-quarter, side, and top orthographic screenshots; Full/Lite wireframes; UV atlas; material swatches; default/Peek/Overview camera frames; contact-shadow light/dark and hidden-reference frames; triangle/entity/material/texture counts; screen-right ribbon safe-region overlay; and a statement that no mouth, limb, pressure emotion, audio, or remote asset exists.

Delete `build-core-box-spike.py` after the final `.blend` is saved and preflighted. Git history retains the proof builder; leaving an authoring command that can overwrite the final source with proof geometry would create an unsafe alternate pipeline.

- [ ] **Step 8: Run source and asset budgets, then commit the model**

```bash
make core-box-pipeline-tests
make core-box-export BLENDER_BIN=/Applications/Blender.app/Contents/MacOS/Blender EXPORT_PROFILE=pipeline-spike-v1
make core-box-repro-check BLENDER_BIN=/Applications/Blender.app/Contents/MacOS/Blender CHECKED_OUT_ASSETS="$PWD" EXPORT_PROFILE=pipeline-spike-v1
make core-box-proof-audit
xcodebuild test -project SomedayBox.xcodeproj -scheme SomedayBox -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' -only-testing:SomedayBoxTests/CoreBoxContactShadowTests
git add -A Assets/CoreBoxCharacter SomedayBoxTests/Fixtures/CoreBoxProofFull.usdz SomedayBoxTests/Fixtures/CoreBoxProofLite.usdz SomedayBoxTests/Fixtures/CoreBoxProofReport.json SomedayBoxTests/Generated/CoreBoxProofIdentity.generated.swift SomedayBoxTests/CoreBoxContactShadowTests.swift SomedayBox.xcodeproj/project.pbxproj docs/design/core-box-character-model-sheet.md
git commit -m "feat: author the production Core Box character" -m " - Replace proof geometry with paper-crafted Full and Lite models
 - Add reviewed PBR atlases cameras lighting and side ribbon"
```

### Task 16: Author and validate the complete motion vocabulary through the selected encoding

**Files:**

- Modify: `Assets/CoreBoxCharacter/CoreBoxCharacter.blend`
- Modify: `Assets/CoreBoxCharacter/export-config.json`
- Modify: `Assets/CoreBoxCharacter/scripts/export-core-box.py`
- Modify: `Assets/CoreBoxCharacter/scripts/compose-core-box-clips.py`
- Replace: `SomedayBoxTests/Fixtures/CoreBoxProofFull.usdz`
- Replace: `SomedayBoxTests/Fixtures/CoreBoxProofLite.usdz`
- Replace: `SomedayBoxTests/Fixtures/CoreBoxProofReport.json`
- Replace: `SomedayBoxTests/Generated/CoreBoxProofIdentity.generated.swift`
- Create: `Resources/CoreBoxCharacterFull.usdz`
- Create: `Resources/CoreBoxCharacterLite.usdz`
- Replace: `Resources/CoreBoxAssetManifest.json`
- Create: `Generated/CoreBoxAssetIdentity.generated.swift`
- Modify: `Features/Home/CoreBox/CoreBoxAssetLoader.swift`
- Modify: `CompatibilityHost/CoreBoxCompatibilityProbeView.swift`
- Modify: `CoreBoxCompatibilityUITests/CoreBoxCompatibilityProbeUITests.swift`
- Create: `SomedayBoxTests/CoreBoxAssetIdentityTests.swift`
- Modify: `SomedayBoxTests/CoreBoxRealityKitAssetTests.swift`
- Create: `SomedayBoxTests/CoreBoxMotionTerminalTests.swift`
- Modify: `docs/design/core-box-character-model-sheet.md`
- Modify: `docs/design/core-box-compatibility-decision.md`
- Modify: `SomedayBox.xcodeproj/project.pbxproj`

- [ ] **Step 1: Add the exact 13-name production test without weakening the proof contract**

```swift
let expectedAnimationNames: Set<String> = [
    "idle.blink",
    "idle.listen",
    "idle.paperRustle",
    "idle.currentGlance",
    "react.touch",
    "react.notice.single",
    "react.notice.aggregate",
    "capture.receive",
    "capture.deposit",
    "draw.reveal",
    "current.attach",
    "paper.return",
    "memory.stamp",
]

@Test(arguments: [CoreBoxRendererTier.full3D, .lite3D])
func providesExactProductionMotionSet(_ tier: CoreBoxRendererTier) async throws {
    let loaded = try await CoreBoxAssetLoader.production.load(tier: tier)
    let inventory = loaded.validatedInventory
    #expect(Set(inventory.publicMotionNames) == expectedAnimationNames)
    #expect(inventory.publicMotionNames.count == 13)
    switch inventory.animationEncoding {
    case .usdNamedResourcesV1:
        #expect(Set(inventory.realityKitAnimationNames) == expectedAnimationNames)
    case .runtimeTransformRecipesV1:
        #expect(Set(inventory.runtimeRecipeNames) == expectedAnimationNames)
    }
    #expect(inventory.ribbonSampleProgress == [0.0, 0.72, 1.0])
}
```

Keep the existing `loadsProofTierWithNamedMotions` assertion at exactly three names. This new test uses `CoreBoxAssetLoader.production`; proof and production identities remain separate and neither test substitutes one source for the other.

Extend the verification-only host with launch source `--core-box-source production-v1`. Its own Resources phase references the same production manifest/Full/Lite files that the app target packages, while the production app still contains no proof/host resource. Add `testProductionVocabularyPlaysOnRealityView()` to launch each tier, require `make:1,update:1,roots:1`, play all 13 exact public names sequentially through the selected encoding, and expose one audited terminal result per name plus ribbon samples `0/0.72/1`. The test fails on fallback to proof identity, missing/extra name, timeout, nonterminal transform, root replacement, or a 2D substitution.

- [ ] **Step 2: Run and confirm the production contract is intentionally red**

```bash
xcodebuild test \
  -project SomedayBox.xcodeproj \
  -scheme SomedayBox \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:SomedayBoxTests/CoreBoxRealityKitAssetTests \
  -only-testing:SomedayBoxTests/CoreBoxMotionTerminalTests
```

Expected: production bundle source/resource failure because the production manifest, identity, and Full/Lite packages do not exist yet. A run that silently falls back to the three-motion proof source is also a failure.

- [ ] **Step 3: Author all non-looping actions and retime them to canonical durations**

Author at 60 fps across each clip's exact configured `authoringFrameCount`; fractional F-curve key positions are allowed for shaping, but export sampling remains the frozen integer domain. Task 3's composer retimes that domain to `0...durationMilliseconds` on the 1000-time-code-per-second stage, so 340/460/560/620/820 ms clips do not pretend to be integer 60 Hz lengths. Every clip has anticipation, act, and settle beats; Papers, eyes, and ribbon may trail Box body by 80...150 ms. No action contains cyclic extrapolation or an infinite NLA repeat.

| Action | Required authored behavior | Terminal |
| --- | --- | --- |
| `idle.blink`, 340 ms | Eye inlays compress once with 40 ms asymmetry | Exact neutral closed pose |
| `idle.listen`, 1000 ms | Lid +3°, root +1.5° lean, ribbon delayed 100 ms | Exact neutral closed pose |
| `idle.paperRustle`, 900 ms | One or two occupied visual slots move ≤4 mm | Neutral with current stable slots |
| `idle.currentGlance`, 820 ms | Eyes/root acknowledge Current anchor without urgency | Neutral with Current unchanged |
| `react.touch`, 200 ms | Root compresses ≤1%, weighted rebound | Neutral |
| `react.notice.single`, 460 ms | One bounded receive beat | Neutral with rebuilt density |
| `react.notice.aggregate`, 620 ms | One aggregate receive beat, never four individual loops | Neutral with rebuilt density |
| `capture.receive`, 300 ms | Lid opens to stable `captureOpen` | Stable `captureOpen` |
| `capture.deposit`, 560 ms | Visual Paper follows deposit path, body receives ≤1.2% weight | Closed from verified snapshot |
| `draw.reveal`, 750 ms | Bounded shuffle and one visual Paper exit | Stable semantic result-visible pose |
| `current.attach`, 420 ms | Reveal visual moves to Current anchor, one small nod | Stable Current attached |
| `paper.return`, 500 ms | Visual Paper folds and returns | Closed/armed before correlated next reveal |
| `memory.stamp`, 650 ms | Soft stamp, root nod, one seam pulse | Closed with committed seam state |

- [ ] **Step 4: Author the exact ribbon sample transforms**

Store local transforms for `BoxRoot`, `RibbonRoot`, `RibbonJoint_01...05`, and `RibbonTip` at progress `0`, `0.72`, and `1`. Rest uses the model's exact authored transforms. At threshold, root lean is 1.2°, tip vertical displacement is 0.066 m, and tension distributes progressively across the five joints. At maximum, root lean is 2.0°, tip vertical displacement is 0.092 m, and no entity enters either eye safe region.

Runtime samples smoothstep independently in `0...0.72` and `0.72...1`, interpolates translation/scale linearly, and rotation with shortest-arc quaternion interpolation. Cancel samples from the current pose to exact rest in 220 ms; Reduced Motion uses immediate rest plus a light fade.

- [ ] **Step 5: Add terminal transform tolerance tests**

For each action and tier, sample the selected encoding's last frame: a RealityKit resource for `usdNamedResourcesV1`, or the deterministic recipe's final keyframe for `runtimeTransformRecipesV1`. Compare each controlled entity with the manifest terminal transform. Translation tolerance is `0.0005 m`, rotation tolerance is `0.25°`, and scale tolerance is `0.001`. Reject NaN, infinity, hierarchy detachment, extra public name, looping extrapolation, and duration error greater than 1 ms.

Add `CoreBoxAssetLoader.production` with a `CoreBoxAssetSource` that reads `CoreBoxAssetManifest.json`, Full/Lite USDZ, and `CoreBoxAssetIdentity` from the app bundle. It uses the Task 5 load path unchanged and therefore returns only structurally attested `CoreBoxLoadedAsset`; production has no direct `Entity(contentsOf:)` bypass. Generate `CoreBoxAssetIdentity.generated.swift` only after the canonical production manifest validates with the exact 13-clip inventory. Add its source to the app target; add manifest and both USDZ files to the app Resources phase; add `CoreBoxAssetIdentityTests.swift` to the test target. The identity test hashes `Bundle.main` bytes and compares all three digests with the generated constants.

The production generator validates all three inputs against `^[0-9a-f]{64}$` and emits this source from values computed in the same export run:

```python
def swift_asset_identity_source(manifest_digest: str, full_digest: str, lite_digest: str) -> bytes:
    values = (manifest_digest, full_digest, lite_digest)
    if any(re.fullmatch(r"[0-9a-f]{64}", value) is None for value in values):
        raise AssetAuditError("invalid_generated_digest", ",".join(values))
    source = f'''import Foundation

enum CoreBoxAssetIdentity {{
    static let schemaVersion = 1
    static let manifestCanonicalizationVersion = "raw-utf8-v1"
    static let authoringTreeDigestVersion = "path-sha256-v1"
    static let assetVersion = "core-box-character-v1"
    static let manifestSHA256 = "{manifest_digest}"
    static let fullTierSHA256 = "{full_digest}"
    static let liteTierSHA256 = "{lite_digest}"
}}
'''
    return source.encode("utf-8")
```

- [ ] **Step 6: Regenerate both sealed profiles, export production twice, and run RealityKit proof**

```bash
make core-box-export \
  BLENDER_BIN=/Applications/Blender.app/Contents/MacOS/Blender \
  EXPORT_PROFILES=pipeline-spike-v1,production-v1
make core-box-repro-check BLENDER_BIN=/Applications/Blender.app/Contents/MacOS/Blender CHECKED_OUT_ASSETS="$PWD" EXPORT_PROFILE=pipeline-spike-v1
make core-box-proof-audit
make core-box-repro-check BLENDER_BIN=/Applications/Blender.app/Contents/MacOS/Blender CHECKED_OUT_ASSETS="$PWD" EXPORT_PROFILE=production-v1
make core-box-asset-audit
xcodebuild test \
  -project SomedayBox.xcodeproj \
  -scheme SomedayBox \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:SomedayBoxTests/CoreBoxAssetIdentityTests \
  -only-testing:SomedayBoxTests/CoreBoxRealityKitAssetTests \
  -only-testing:SomedayBoxTests/CoreBoxMotionTerminalTests
mkdir -p "$PWD/.build/core-box/reports"
production_gate_root="$(mktemp -d "$PWD/.build/core-box/reports/production-vocabulary.XXXXXX")"
production_simulator_result="$production_gate_root/simulator.xcresult"
production_device_result="$production_gate_root/device.xcresult"
xcodebuild test \
  -project SomedayBox.xcodeproj \
  -scheme CoreBoxCompatibilityHost \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -resultBundlePath "$production_simulator_result" \
  -only-testing:CoreBoxCompatibilityUITests/CoreBoxCompatibilityProbeUITests/testProductionVocabularyPlaysOnRealityView
test -n "${CORE_BOX_PRODUCTION_DEVICE_UDID:-}"
xcodebuild test \
  -project SomedayBox.xcodeproj \
  -scheme CoreBoxCompatibilityHost \
  -destination "platform=iOS,id=$CORE_BOX_PRODUCTION_DEVICE_UDID" \
  -resultBundlePath "$production_device_result" \
  -only-testing:CoreBoxCompatibilityUITests/CoreBoxCompatibilityProbeUITests/testProductionVocabularyPlaysOnRealityView
production_simulator_digest="$(/usr/bin/python3 -B scripts/core_box_tree_digest.py --version xcresult-tree-sha256-v1 --root "$production_simulator_result")"
production_device_digest="$(/usr/bin/python3 -B scripts/core_box_tree_digest.py --version xcresult-tree-sha256-v1 --root "$production_device_result")"
test "${#production_simulator_digest}" -eq 64 -a "${#production_device_digest}" -eq 64
case "$production_simulator_digest$production_device_digest" in *[!0-9a-f]*) exit 1 ;; esac
```

The proof profile still selects only `idle.listen`, `capture.deposit`, and `draw.reveal` from the now 13-action source. Regenerating its packages, report, and generated identity in the same task keeps the authoring-tree digest honest instead of leaving Task 15 evidence stale. Expected: proof outputs match the three-motion contract; both production tiers provide exactly 13 public motion names through the selected encoding; every name plays in a real `RealityView` and reaches its audited terminal on Simulator and the connected physical device; every duration, sample, hierarchy, budget, canonical manifest byte, compiled digest, and both result-tree digests pass; two isolated exports match committed outputs byte for byte. Record the device model/OS, production identity digests, and both result-tree digests in `docs/design/core-box-compatibility-decision.md`; do not commit machine-specific result paths. A missing physical-device result blocks Task 16.

- [ ] **Step 7: Record motion contact sheets and commit assets atomically**

Add three-frame contact sheets for anticipate/act/settle of every action, plus ribbon 0/0.72/1 overlays, to the model-sheet document. Then commit source and generated runtime outputs together.

```bash
git add Assets/CoreBoxCharacter SomedayBoxTests/Fixtures/CoreBoxProofFull.usdz SomedayBoxTests/Fixtures/CoreBoxProofLite.usdz SomedayBoxTests/Fixtures/CoreBoxProofReport.json SomedayBoxTests/Generated/CoreBoxProofIdentity.generated.swift Resources/CoreBoxCharacterFull.usdz Resources/CoreBoxCharacterLite.usdz Resources/CoreBoxAssetManifest.json Generated/CoreBoxAssetIdentity.generated.swift Features/Home/CoreBox/CoreBoxAssetLoader.swift CompatibilityHost/CoreBoxCompatibilityProbeView.swift CoreBoxCompatibilityUITests/CoreBoxCompatibilityProbeUITests.swift SomedayBoxTests/CoreBoxAssetIdentityTests.swift SomedayBoxTests/CoreBoxRealityKitAssetTests.swift SomedayBoxTests/CoreBoxMotionTerminalTests.swift docs/design/core-box-character-model-sheet.md docs/design/core-box-compatibility-decision.md SomedayBox.xcodeproj/project.pbxproj
git commit -m "feat: author the complete Core Box motion vocabulary" -m " - Add thirteen bounded character actions and ribbon samples
 - Regenerate sealed Full and Lite runtime identities"
```

### Task 17: Correlate Capture and Share presentations with verified truth

**Files:**

- Modify: `Features/Capture/CaptureView.swift`
- Modify: `App/SomedayBoxApp.swift`
- Modify: `App/UITestLaunchConfiguration.swift`
- Modify: `Application/CoreBoxPresentationCoordinator.swift`
- Modify: `SomedayBoxUITests/Support/UITestLauncher.swift`
- Create: `SomedayBoxUITests/CoreBoxMutationJourneyUITests.swift`
- Modify: `SomedayBoxTests/AppModelPresentationTests.swift`
- Modify: `SomedayBoxTests/CoreBoxPresentationCoordinatorTests.swift`
- Modify: `SomedayBox.xcodeproj/project.pbxproj`

- [ ] **Step 1: Write Capture cancel/commit/projection-failure and Share batch tests**

```swift
func testCaptureCancelNeverDeposits() {
    let app = launchFixture(.emptyBox)
    app.buttons["home.capture"].tap()
    app.buttons["capture.cancel"].tap()
    XCTAssertEqual(app.otherElements["home.box.summary"].value as? String, "0 papers")
    XCTAssertEqual(app.otherElements["debug.motion.capture.deposit.count"].value as? String, "0")
}

func testCommittedCaptureDepositsOnce() {
    let app = launchFixture(.emptyBox)
    capture(title: "Walk", durationIdentifier: "capture.duration.upTo30", in: app)
    XCTAssertEqual(app.otherElements["home.box.summary"].value as? String, "1 paper")
    XCTAssertEqual(app.otherElements["debug.motion.capture.deposit.count"].value as? String, "1")
}

func testProjectionFailureDoesNotOfferDuplicateSaveOrReplayDeposit() {
    let app = launchFixture(.emptyBox, options: .init(projectionFailures: 1))
    capture(title: "Walk", durationIdentifier: "capture.duration.upTo30", in: app)
    XCTAssertTrue(app.otherElements["projection.reconciliation"].exists)
    XCTAssertFalse(app.buttons["capture.save"].exists)
    app.buttons["projection.retry"].tap()
    XCTAssertEqual(app.otherElements["home.box.summary"].value as? String, "1 paper")
    XCTAssertEqual(app.otherElements["debug.motion.capture.deposit.count"].value as? String, "0")
}
```

- [ ] **Step 2: Run and verify the event wiring is red**

```bash
xcodebuild test \
  -project SomedayBox.xcodeproj \
  -scheme SomedayBox \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:SomedayBoxUITests/CoreBoxMutationJourneyUITests/testCaptureCancelNeverDeposits \
  -only-testing:SomedayBoxUITests/CoreBoxMutationJourneyUITests/testCommittedCaptureDepositsOnce \
  -only-testing:SomedayBoxUITests/CoreBoxMutationJourneyUITests/testProjectionFailureDoesNotOfferDuplicateSaveOrReplayDeposit
```

Expected: tests fail because the current UI consumes Bool results and has no correlated motion identifiers.

- [ ] **Step 3: Apply the exact Capture event sequence**

Opening Capture presents the native editor and moves semantic focus immediately in every motion mode. If an adapter is already ready, `.captureReceive` runs in parallel; asset loading, interruption, fallback, or stable-open completion never gates editor visibility or input. Reduced Motion uses only a short parallel fade. Cancel emits no success event and settles closed. Save handles results as:

```swift
switch await model.capture(title: title, note: note, duration: duration) {
case let .committed(outcome, snapshot):
    dismissEditor()
    coordinator.apply(snapshot)
    coordinator.enqueue(
        event: .captureDeposit(itemID: outcome.itemID),
        sourceSnapshotVersion: snapshot.snapshotVersion
    )
case .committedButProjectionUnavailable:
    dismissEditor()
    coordinator.settle(reason: .reconciliation)
case let .notCommitted(failure):
    if let snapshot = model.sceneSnapshot {
        coordinator.enqueue(
            event: .failureSettle,
            sourceSnapshotVersion: snapshot.snapshotVersion
        )
    }
    presentNativeError(failure)
}
```

- [ ] **Step 4: Apply Share arrival grouping without replay**

Add `ShareImportBatchResult: Equatable, Sendable` with ordered `freshItemIDs`, `alreadyImportedCount`, and optional Recovery identity. `ingestSharedCaptures` acquires the existing AppModel mutation gate once, processes each mailbox envelope through the atomic import use case, removes only successfully handled envelopes, and returns the final committed repository state plus one typed batch receipt. It stops at the first recovery-required envelope; already committed prefix results remain truth. The batch is passed through one final projection, not one projection per envelope. If that projection fails, reconciliation rebuilds only stable density and the entire batch notice occurrence is permanently dropped. A duplicate-only batch removes handled envelopes but publishes no transient event. Collect only `.imported` Item IDs from the typed receipts; never infer freshness from counts. After one verified final snapshot:

- count 1...3: emit one `.shareArrival(freshItemIDs:)`; adapter plays at most three `react.notice.single` beats inside one bounded presentation;
- count 4 or more: emit one event; adapter plays `react.notice.aggregate` once and rebuilds density;
- zero fresh IDs, `.alreadyImported`, refresh, expiry, background drop, or Recovery: emit nothing.

Never infer freshness from `inBoxCount` difference.

Under Debug UI testing, inject a bounded `CoreBoxPresentationProbe` into the root coordinator and expose stable, always-present accessibility values such as `debug.motion.capture.deposit.count`. The probe increments only when the coordinator accepts a correlated event; animation views themselves remain hidden from accessibility. Production and Release compile no probe view. Unit tests remain authoritative for event identity/order; XCUITest reads these stable counters only to prove end-to-end wiring and no replay.

- [ ] **Step 5: Run typed model and journey tests**

```bash
xcodebuild test \
  -project SomedayBox.xcodeproj \
  -scheme SomedayBox \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:SomedayBoxTests/AppModelPresentationTests \
  -only-testing:SomedayBoxTests/CoreBoxPresentationCoordinatorTests \
  -only-testing:SomedayBoxTests/SharePayloadExtractionTests \
  -only-testing:SomedayBoxUITests/CoreBoxMutationJourneyUITests
```

Expected: cancel has no deposit; committed projection deposits once; projection failure blocks duplicate and never replays; fresh Share grouping is bounded; every no-replay path is quiet.

- [ ] **Step 6: Commit Capture and Share correlation**

```bash
git add Features/Capture/CaptureView.swift App/SomedayBoxApp.swift App/UITestLaunchConfiguration.swift Application/CoreBoxPresentationCoordinator.swift SomedayBoxUITests/Support/UITestLauncher.swift SomedayBoxUITests/CoreBoxMutationJourneyUITests.swift SomedayBoxTests/AppModelPresentationTests.swift SomedayBoxTests/CoreBoxPresentationCoordinatorTests.swift SomedayBox.xcodeproj/project.pbxproj
git commit -m "feat: correlate Capture and Share character feedback" -m " - Play deposits only from committed verified projections
 - Group fresh Share arrivals without replaying idempotent imports"
```

### Task 18: Correlate reveal, Accept, Redraw, and Dismiss presentations

**Files:**

- Modify: `Features/Draw/DrawRevealGate.swift`
- Modify: `App/RootTabView.swift`
- Modify: `App/SomedayBoxApp.swift`
- Modify: `App/UITestLaunchConfiguration.swift`
- Modify: `Application/CoreBoxPresentationCoordinator.swift`
- Modify: `SomedayBoxUITests/Support/UITestLauncher.swift`
- Modify: `SomedayBoxUITests/CoreBoxMutationJourneyUITests.swift`
- Modify: `SomedayBoxTests/AppModelPresentationTests.swift`
- Modify: `SomedayBoxTests/CoreBoxPresentationCoordinatorTests.swift`

- [ ] **Step 1: Add persisted-before-reveal and resolution-event tests**

```swift
func testPersistedAttemptIsSemanticBeforeOptionalRevealMotion() {
    let app = launchFixture(.drawReady)
    app.buttons["draw.context.fewMinutes"].tap()
    app.buttons["home.draw"].tap()
    XCTAssertTrue(app.otherElements["draw.reveal.result"].waitForExistence(timeout: 1))
    XCTAssertEqual(app.otherElements["draw.reveal.persistence"].value as? String, "Persisted unresolved attempt")
}

func testAcceptAnimatesOnlyCurrentAttach() {
    let app = launchFixture(.unresolvedAttempt)
    app.buttons["draw.accept"].tap()
    XCTAssertEqual(app.otherElements["debug.motion.current.attach.count"].value as? String, "1")
    XCTAssertEqual(app.otherElements["debug.motion.paper.return.count"].value as? String, "0")
}

func testRedrawReturnsThenRevealsCorrelatedAttempt() {
    let app = launchFixture(.unresolvedAttemptWithAlternative)
    app.buttons["draw.redraw"].tap()
    XCTAssertEqual(
        app.otherElements["debug.motion.accepted.journal"].value as? String,
        "paper.return,draw.reveal"
    )
    XCTAssertEqual(app.otherElements["draw.reveal.attempt"].value as? String, "2")
}
```

- [ ] **Step 2: Run resolution tests and confirm missing event correlation**

```bash
xcodebuild test \
  -project SomedayBox.xcodeproj \
  -scheme SomedayBox \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:SomedayBoxUITests/CoreBoxMutationJourneyUITests/testPersistedAttemptIsSemanticBeforeOptionalRevealMotion \
  -only-testing:SomedayBoxUITests/CoreBoxMutationJourneyUITests/testAcceptAnimatesOnlyCurrentAttach \
  -only-testing:SomedayBoxUITests/CoreBoxMutationJourneyUITests/testRedrawReturnsThenRevealsCorrelatedAttempt
```

Expected: one or more failures because resolution methods are Bool-based or motion is not tied to the receipt IDs.

- [ ] **Step 3: Correlate Start Draw and reveal**

Only `.committed(.revealed(attempt), snapshot)` emits `.drawReveal(attemptID:itemID:)`. The root unresolved-result gate is already authoritative before animation. The event may enhance the gate with the same character asset, but missing/degraded/interrupted motion cannot hide result text, delay focus, or make the Attempt dismissible outside existing rules.

- [ ] **Step 4: Correlate all three resolution paths**

- Accept `.committed(AcceptDrawResult, snapshot)`: apply the snapshot, then emit `.currentAttach` with exact Attempt and Item IDs.
- Redraw `.committed(.revealed(previousAttemptID:previousItemID:attempt:), snapshot)`: emit `.paperReturn` for `previousItemID`, then emit `.drawReveal` for the exact new Attempt under one serialized committed presentation.
- Redraw `.committed(.exhausted(previousAttemptID:previousItemID:sessionID:context:), snapshot)`: emit `.paperReturn` for `previousItemID`; close the ended Session and return to a stable exhausted semantic state. A later Reshuffle is a distinct explicit start action.
- Dismiss `.committed(DismissDrawResult, snapshot)`: emit `.paperReturn` for its exact Item and return to stable closed/armed state.
- Either committed-but-projection-unavailable case: dismiss retryable mutation UI, enter reconciliation, and emit none of the above.
- Any not-committed Start/Accept/Redraw/Dismiss result: enqueue `.failureSettle` against the current snapshot, preserve the semantic current surface, and show the native error; do not leave Paper, ribbon, lid, or camera in a prepared pose.

Add `CoreBoxCorrelatedSequence` with one monotonic sequence number, one source snapshot version, motion mode, and a non-empty ordered `[CoreBoxPresentationEvent]`. `enqueue(event:)` wraps one event; Redraw submits one sequence containing `paperReturn` then `drawReveal`. The coordinator reserves the union of declared channels once and advances same-owner segments internally after each terminal, so equal-priority continuation is not rejected as a competing owner. Interruption drops the remaining segments and settles from the newest snapshot. Recording-adapter tests assert exact order and that a repeated sequence number is ignored.

Add `DrawPostResolution.exhausted(sessionID:context:)` as root-owned semantic presentation state. On the exhausted committed receipt, set it after applying the verified snapshot; the unresolved gate disappears, but this explicit surface remains ahead of tabs with a visible Done action and a Reshuffle action. Reshuffle starts a new Session through a distinct `startDraw(context:)` call and can itself return any of the three projection outcomes. Add UI tests for exhausted text, Done, and exactly one new Start Draw from Reshuffle. Root priority becomes store load/error → unresolved → Shared Capture Recovery → reconciliation → Draw post-resolution → introduction → tabs.

- [ ] **Step 5: Verify unsupported policy and background interruption**

An unsupported historical policy keeps its persisted result readable and disables only Redraw. Background during reveal cancels optional motion within one second; foreground rebuilds the semantic result and stable pose without replay.

- [ ] **Step 6: Run all Draw tests and commit**

```bash
xcodebuild test \
  -project SomedayBox.xcodeproj \
  -scheme SomedayBox \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:SomedayBoxTests/ApplicationUseCaseTests \
  -only-testing:SomedayBoxTests/AppModelPresentationTests \
  -only-testing:SomedayBoxTests/CoreBoxPresentationCoordinatorTests \
  -only-testing:SomedayBoxUITests/CoreBoxMutationJourneyUITests

git add Features/Draw/DrawRevealGate.swift App/RootTabView.swift App/SomedayBoxApp.swift App/UITestLaunchConfiguration.swift Application/CoreBoxPresentationCoordinator.swift SomedayBoxUITests/Support/UITestLauncher.swift SomedayBoxUITests/CoreBoxMutationJourneyUITests.swift SomedayBoxTests/AppModelPresentationTests.swift SomedayBoxTests/CoreBoxPresentationCoordinatorTests.swift
git commit -m "feat: correlate Draw resolution character motion" -m " - Keep persisted reveal semantics ahead of optional animation
 - Tie Accept Redraw and Dismiss motion to exact receipts"
```

### Task 19: Integrate Peek, Current Pick, Put Back, Complete, and Memory

**Files:**

- Modify: `Features/Home/CoreBox/CoreBoxPeekView.swift`
- Modify: `Features/Home/CoreBox/CoreBoxInteractionSurface.swift`
- Modify: `Features/Home/HomeView.swift`
- Modify: `App/SomedayBoxApp.swift`
- Modify: `App/UITestLaunchConfiguration.swift`
- Modify: `Application/CoreBoxPresentationCoordinator.swift`
- Modify: `SomedayBoxUITests/Support/UITestLauncher.swift`
- Modify: `SomedayBoxUITests/CoreBoxHomeUITests.swift`
- Modify: `SomedayBoxUITests/CoreBoxMutationJourneyUITests.swift`
- Modify: `SomedayBoxTests/CoreBoxPresentationCoordinatorTests.swift`

- [ ] **Step 1: Write native/3D Peek parity and lifecycle-reset tests**

```swift
func testLidBodyAndNativePeekReachTheSameSemanticSurface() {
    for identifier in ["home.peek", "home.hit.lid", "home.hit.box"] {
        let app = launchFixture(.activePapers(4))
        app.buttons[identifier].tap()
        XCTAssertTrue(app.otherElements["peek.summary"].exists)
        XCTAssertEqual(app.otherElements["peek.summary"].value as? String, "4 papers")
        XCTAssertFalse(app.staticTexts["Fixture paper title"].exists)
        if identifier == "home.hit.box" {
            XCTAssertEqual(app.otherElements["debug.motion.react.touch.count"].value as? String, "1")
        }
    }
}

func testPeekDismissRestoresClosedStablePose() {
    let app = launchFixture(.activePapers(4))
    app.buttons["home.peek"].tap()
    app.buttons["peek.close"].tap()
    XCTAssertEqual(app.otherElements["home.lid.state"].value as? String, "Closed")
    XCTAssertEqual(app.otherElements["home.camera.state"].value as? String, "Default")
}

func testPeekBackgroundAndForegroundRestoreWithoutReplay() {
    let app = launchFixture(.activePapers(4))
    app.buttons["home.peek"].tap()
    XCUIDevice.shared.press(.home)
    app.activate()
    XCTAssertEqual(app.otherElements["home.lid.state"].value as? String, "Closed")
    XCTAssertEqual(app.otherElements["home.camera.state"].value as? String, "Default")
    XCTAssertEqual(app.otherElements["debug.motion.peek.open.count"].value as? String, "1")
}
```

- [ ] **Step 2: Add Current/Complete/Put Back identity tests**

Test Accept attaches exact Current Item, Put Back emits `paper.return` but creates no Memory, Complete emits `memory.stamp` with the exact Memory ID, clears Current if it matches, and leaves one stable seam pulse rather than a loop. Coordinator/recording-adapter unit tests assert exact receipt/event identities and order; the UI journey asserts stable debug probe counters plus final Current/Memory semantics rather than querying transient animation elements.

- [ ] **Step 3: Run focused journeys and verify red**

```bash
xcodebuild test \
  -project SomedayBox.xcodeproj \
  -scheme SomedayBox \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:SomedayBoxUITests/CoreBoxHomeUITests \
  -only-testing:SomedayBoxUITests/CoreBoxMutationJourneyUITests
```

Expected: failures for exact lid hit parity, camera/lid reset, and receipt-correlated Complete/Put Back events.

- [ ] **Step 4: Implement Peek as presentation-only state**

The named `Hit_Lid` proxy and visible native Peek button open Peek directly. A resolved `Hit_Box` uses the Task 11 rule: one `react.touch`, then Peek only when `peekIntentAvailable` is true; empty-stage taps are ignored. Peek opens around `LidPivot` and uses `Camera_Overview` in Normal/Quick. SwiftUI owns counts, Organize, close, and accessibility. It never renders Paper title or note. Reduced Motion swaps directly to the stable Peek composition with a short fade. Close/background/covering gate resets camera to `Camera_Default` and lid closed before idle resumes.

- [ ] **Step 5: Correlate lifecycle receipts**

Handle:

```swift
func applyPutBack(_ result: AppMutationProjection<PutBackPaperResult>) {
    guard case let .committed(outcome, snapshot) = result else { return }
    coordinator.apply(snapshot)
    coordinator.enqueue(
        event: .paperReturn(itemID: outcome.itemID),
        sourceSnapshotVersion: snapshot.snapshotVersion
    )
}

func applyCompletion(_ result: AppMutationProjection<CompletePaperResult>) {
    guard case let .committed(outcome, snapshot) = result else { return }
    coordinator.apply(snapshot)
    coordinator.enqueue(
        event: .memoryStamp(itemID: outcome.itemID, memoryID: outcome.memoryID),
        sourceSnapshotVersion: snapshot.snapshotVersion
    )
}
```

The typed handlers show the exact committed mapping; their full switches also implement the two failure branches described below. Put Back never creates a Memory. Complete's seam intensity comes from the committed `memoryCount`, while the glow pulse comes only from its correlated event.

For a not-committed Put Back or Complete result, enqueue `.failureSettle` against the current snapshot, keep Current and Memory semantics unchanged, and show the native error. For committed-but-projection-unavailable, enter reconciliation and emit no return or stamp event.

- [ ] **Step 6: Run journeys and commit**

```bash
xcodebuild test \
  -project SomedayBox.xcodeproj \
  -scheme SomedayBox \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:SomedayBoxTests/CoreBoxTransactionReceiptTests \
  -only-testing:SomedayBoxTests/CoreBoxPresentationCoordinatorTests \
  -only-testing:SomedayBoxUITests/CoreBoxHomeUITests \
  -only-testing:SomedayBoxUITests/CoreBoxMutationJourneyUITests

git add Features/Home/CoreBox/CoreBoxPeekView.swift Features/Home/CoreBox/CoreBoxInteractionSurface.swift Features/Home/HomeView.swift App/SomedayBoxApp.swift App/UITestLaunchConfiguration.swift Application/CoreBoxPresentationCoordinator.swift SomedayBoxTests/CoreBoxPresentationCoordinatorTests.swift SomedayBoxUITests/Support/UITestLauncher.swift SomedayBoxUITests/CoreBoxHomeUITests.swift SomedayBoxUITests/CoreBoxMutationJourneyUITests.swift
git commit -m "feat: complete Core Box lifecycle interactions" -m " - Unify native and lid-proxy Peek with stable reset behavior
 - Correlate Current return and Memory feedback to exact receipts"
```

### Task 20: Finish 2D parity, renderer Settings, and paper-language page echoes

**Files:**

- Modify: `Features/Home/CoreBox/CoreBox2DAdapter.swift`
- Modify: `Features/Home/CoreBox/CoreBoxStage.swift`
- Modify: `Features/Settings/SettingsView.swift`
- Modify: `App/SomedayBoxApp.swift`
- Modify: `App/UITestLaunchConfiguration.swift`
- Modify: `Features/Box/BoxView.swift`
- Modify: `Features/Memories/MemoriesView.swift`
- Modify: `DesignSystem/Brand.swift`
- Modify: `Resources/Localizable.xcstrings`
- Modify: `SomedayBoxTests/CoreBox2DParityTests.swift`
- Create: `SomedayBoxUITests/CoreBoxFallbackAccessibilityUITests.swift`
- Modify: `SomedayBoxUITests/Support/UITestLauncher.swift`
- Modify: `SomedayBox.xcodeproj/project.pbxproj`

- [ ] **Step 1: Write one complete forced-2D journey and renderer Settings test**

```swift
func testForcedAssetFailureKeepsTheCompleteProductJourneyUsable() {
    let app = launchFixture(.emptyBox, options: .init(assetFailure: "validation"))
    XCTAssertEqual(app.otherElements["home.renderer"].value as? String, "Simplified 2D")
    capture(title: "Walk", durationIdentifier: "capture.duration.upTo30", in: app)
    app.buttons["draw.context.fewMinutes"].tap()
    app.buttons["home.draw"].tap()
    app.buttons["draw.accept"].tap()
    app.buttons["home.current.complete"].tap()
    app.tabBars.buttons["Memories"].tap()
    XCTAssertTrue(app.staticTexts["Walk"].exists)
}

func testSettingsExposeThreeUserChoicesAndNeverLite() {
    let app = launchFixture(.emptyBox)
    app.buttons["home.settings"].tap()
    app.buttons["renderer.preference.control"].tap()
    XCTAssertTrue(app.buttons["renderer.automatic"].exists)
    XCTAssertTrue(app.buttons["renderer.full3D"].exists)
    XCTAssertTrue(app.buttons["renderer.simplified2D"].exists)
    XCTAssertFalse(app.buttons["renderer.lite3D"].exists)
}
```

- [ ] **Step 2: Run and confirm 2D is not yet fully equivalent**

```bash
xcodebuild test \
  -project SomedayBox.xcodeproj \
  -scheme SomedayBox \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:SomedayBoxUITests/CoreBoxFallbackAccessibilityUITests \
  -only-testing:SomedayBoxTests/CoreBox2DParityTests
```

Expected: failure where 2D lacks a stable interaction/motion state or Settings still exposes Lite.

- [ ] **Step 3: Complete the 2D adapter without creating a second business flow**

Render a folded maple-paper Box silhouette, moss-ink eyes, side sage ribbon, committed Paper density, Current anchor, and Memory seam from the same `CoreBoxStablePose`. Use the same native actions and disabled predicates. Implement stable Capture-open, deposit, armed ribbon, reveal, Current, Peek, return, completion, fallback-settle, and Reduced Motion states with SwiftUI transitions. No 2D code calls a repository or use case directly.

- [ ] **Step 4: Present only Automatic, Full 3D, and Simplified 2D**

The Picker never writes the preference store directly. It calls AppModel's `requestRendererPreference(_:)`; AppModel asks the coordinator to settle, persists the preference, computes the allowed effective tier, republishes one newer snapshot, and only then permits the stage transition. Settings displays the internal effective tier only as noninteractive diagnostic text when Automatic has degraded. The flow performs zero product-store writes. Use an explicit `renderer.preference.control` identifier and open it in UI tests before asserting the three option identifiers, so the test does not assume a Picker style keeps all options mounted.

- [ ] **Step 5: Extend the paper visual language without a persistent mascot**

In `Brand.swift`, define reusable paper surface, fold line, sage accent, moss ink, and amber seam tokens. Apply them to Box cards and Memories cards with restrained native insertion/completion transitions. Do not render the 3D character, eye motif, idle loop, or mascot on either tab. Keep existing navigation, sorting, editing, and accessibility semantics unchanged.

- [ ] **Step 6: Verify localization, light/dark, and parity**

Add English and Simplified Chinese strings for renderer choices, ribbon armed/disabled values, reconciliation, asset fallback, Peek state, and semantic motion completion. Run the forced-2D journey in both appearances and both languages; terminal product state must match Full/Lite for the same fixture.

- [ ] **Step 7: Run tests and commit page-level integration**

```bash
xcodebuild test \
  -project SomedayBox.xcodeproj \
  -scheme SomedayBox \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:SomedayBoxTests/CoreBox2DParityTests \
  -only-testing:SomedayBoxTests/CoreBoxPreferenceMigrationTests \
  -only-testing:SomedayBoxUITests/CoreBoxFallbackAccessibilityUITests

git add Features/Home/CoreBox/CoreBox2DAdapter.swift Features/Home/CoreBox/CoreBoxStage.swift Features/Settings/SettingsView.swift Features/Box/BoxView.swift Features/Memories/MemoriesView.swift DesignSystem/Brand.swift App/SomedayBoxApp.swift App/UITestLaunchConfiguration.swift SomedayBoxUITests/Support/UITestLauncher.swift Resources/Localizable.xcstrings SomedayBoxTests/CoreBox2DParityTests.swift SomedayBoxUITests/CoreBoxFallbackAccessibilityUITests.swift SomedayBox.xcodeproj/project.pbxproj
git commit -m "feat: complete Core Box fallback and page language" -m " - Preserve every product journey in functional SwiftUI 2D
 - Echo paper materials in Box and Memories without a mascot"
```

### Task 21: Add isolated UI fixtures and close accessibility/input parity

**Files:**

- Modify: `App/UITestLaunchConfiguration.swift`
- Modify: `SomedayBoxUITests/Support/UITestLauncher.swift`
- Modify: `App/SomedayBoxApp.swift`
- Modify: `SomedayBoxUITests/AppLaunchTests.swift`
- Modify: `SomedayBoxUITests/CoreBoxHomeUITests.swift`
- Modify: `SomedayBoxUITests/CoreBoxMutationJourneyUITests.swift`
- Modify: `SomedayBoxUITests/CoreBoxFallbackAccessibilityUITests.swift`
- Modify: `SomedayBox.xcodeproj/project.pbxproj`
- Modify: `Resources/Localizable.xcstrings`

- [ ] **Step 1: Write launch-isolation and Release-ignore tests**

The Debug UI test contract uses these exact environment keys:

```swift
enum UITestEnvironmentKey {
    static let enabled = "SOMEDAY_BOX_UI_TESTING"
    static let runID = "SOMEDAY_BOX_UI_TEST_RUN_ID"
    static let fixture = "SOMEDAY_BOX_UI_TEST_FIXTURE"
    static let renderer = "SOMEDAY_BOX_UI_TEST_RENDERER"
    static let assetFailure = "SOMEDAY_BOX_UI_TEST_ASSET_FAILURE"
    static let projectionFailures = "SOMEDAY_BOX_UI_TEST_PROJECTION_FAILURES"
    static let motionMode = "SOMEDAY_BOX_UI_TEST_MOTION_MODE"
    static let lowPowerCap = "SOMEDAY_BOX_UI_TEST_LOW_POWER_CAP"
}
```

Add a Debug unit test for validation and disabled cases. Release exclusion is proved separately in Step 7 by compiling the actual Release app and inspecting its executable; do not describe a Debug XCTest as Release proof.

- [ ] **Step 2: Extend the Debug-only deterministic fixtures and fault injection**

```swift
#if DEBUG
struct UITestLaunchConfiguration: Sendable {
    static func load(environment: [String: String] = ProcessInfo.processInfo.environment) -> Self {
        guard environment[UITestEnvironmentKey.enabled] == "1" else { return .disabled }
        return Self.validated(environment: environment)
    }
}
#else
struct UITestLaunchConfiguration: Sendable {
    static let current = Self.disabled
}
#endif
```

The runner passes only a UUID run ID. The Debug app validates it, removes only its own app-sandbox `temporaryDirectory/someday-box-ui-tests` child, and creates the run child there; runner teardown only terminates the app. Disable parallel UI execution for this scheme. The associated-value fixtures cover empty, active Papers, 5,000 Papers, Current, unresolved Attempt, alternative Redraw, exhausted Redraw, Memories, fresh Share 1/3/4, already-imported Share, and Recovery. Asset failure/missing node, projection-failure count, Low Power cap, renderer, and motion mode remain orthogonal launch options. Tasks 17-20 have already added app-side support for every case they use; this task closes the full matrix. Production Release accepts none of these switches or the stable presentation probe.

- [ ] **Step 3: Add stable semantic identifiers and values**

Keep decorative RealityKit content hidden. SwiftUI exposes visible native controls or explicit accessibility actions for lid, ribbon, Box, and Memory seam. Ribbon label is `Draw a paper`; value is `Not armed`, `Armed, \(context.accessibilityLabel)`, or `Pull \(Int(progress * 100)) percent`; hint explains release threshold without relying on color. Reveal focus moves to the semantic result once, with no duplicate announcement.

- [ ] **Step 4: Automate accessibility and largest Dynamic Type audits**

```swift
func testPrimarySurfacesPassAccessibilityAudit() throws {
    let app = launchFixture(.activePapers(4))
    try app.performAccessibilityAudit()
    app.buttons["home.peek"].tap()
    try app.performAccessibilityAudit()
    app.buttons["peek.close"].tap()
    app.buttons["home.capture"].tap()
    try app.performAccessibilityAudit()
}
```

Run Home, Capture, Peek, Reveal, Current, Box, Memories, Settings, Recovery, reconciliation, empty/error, and forced-2D surfaces. Add `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge` for the largest size. Assert required actions remain hittable and stage summary/ribbon/native controls do not overlap.

- [ ] **Step 5: Test Reduce Motion and input equivalents**

Run the complete journey with `SOMEDAY_BOX_UI_TEST_MOTION_MODE=reduced` and assert the same semantic terminal result as Normal through native controls. In recording-adapter unit tests, assert reduced timing requests zero depth/camera/Paper-flight samples and idle schedules no action. This injected mode does not prove the operating-system accessibility setting or actual Voice Control/Switch Control operation; those remain explicit items in the physical-device matrix.

- [ ] **Step 6: Perform the manual assistive-technology matrix**

On a physical device, record VoiceOver, Voice Control, Switch Control, Increase Contrast, Differentiate Without Color, Reduce Transparency, Reduce Motion, light/dark appearance, and English/Simplified Chinese for Home → Capture → Draw → Accept/Redraw/Dismiss → Peek → Current → Complete/Put Back → Memories plus Recovery and forced 2D. Record device, OS, candidate SHA, build configuration, screenshots/recording, result, and any exception owner. Automated Simulator evidence does not close this manual gate.

- [ ] **Step 7: Run all UI suites and commit the test control plane**

```bash
xcodebuild test \
  -project SomedayBox.xcodeproj \
  -scheme SomedayBox \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:SomedayBoxUITests

release_audit_root="$(mktemp -d /tmp/someday-box-release-ui-audit.XXXXXX)"
xcodebuild build \
  -project SomedayBox.xcodeproj \
  -scheme SomedayBox \
  -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$release_audit_root/DerivedData" \
  CODE_SIGNING_ALLOWED=NO
release_app="$release_audit_root/DerivedData/Build/Products/Release-iphonesimulator/SomedayBox.app"
test -x "$release_app/SomedayBox"
! strings "$release_app/SomedayBox" | rg 'SOMEDAY_BOX_UI_TEST_(RUN_ID|FIXTURE|RENDERER|ASSET_FAILURE|PROJECTION_FAILURES|MOTION_MODE|LOW_POWER_CAP)|debug\.(motion|presentation)'

git add App/UITestLaunchConfiguration.swift App/SomedayBoxApp.swift SomedayBoxUITests/Support/UITestLauncher.swift SomedayBoxUITests Resources/Localizable.xcstrings SomedayBox.xcodeproj/project.pbxproj
git commit -m "test: close Core Box UI and accessibility parity" -m " - Add isolated deterministic fixtures and fault injection
 - Verify semantic native paths across motion and renderer modes"
```

Expected: Debug UI suites pass; the Release app builds; none of the UI-test environment keys or probe identifiers is present in its executable.

### Task 22: Hard-replace obsolete production 3D and close CI/package gates

**Files:**

- Delete: `Resources/CoreBox.usda`
- Modify: `Features/Home/HomeView.swift`
- Modify: `SomedayBox.xcodeproj/project.pbxproj`
- Modify: `scripts/audit-core-box-assets.sh`
- Modify: `scripts/audit-core-box-release.sh`
- Create: `scripts/audit-core-box-package.sh`
- Create: `scripts/generate-core-box-candidate-manifest.py`
- Modify: `Makefile`
- Modify: `.github/workflows/ci.yml`
- Delete: `docs/release/core-box-candidate-manifest.json`
- Create: `docs/release/core-box-candidate-manifest.schema.json`
- Modify: `docs/release/release-manifest-template.md`
- Modify: `docs/release/acceptance-checklist.md`
- Modify: `docs/release/feature-upgrade-summary.md`

- [ ] **Step 1: Write hard-cut source and archive audit tests**

The source audit must fail if any production code contains `makeCoreBoxScene`, `CoreBox.usda`, obsolete primitive hierarchy construction, an unvalidated RealityKit load, or a fallback that bypasses `CoreBox2DAdapter`. It must also fail if Full/Lite/manifest/generated identity is missing from project resources/sources.

`scripts/audit-core-box-assets.sh` remains a thin orchestrator: start with `set -eu`; invoke the config-driven toolchain verifier; run every host standard-library canonical/schema/digest subprocess under `env -i` with `/usr/bin/python3 -B`; invoke `run-core-box-blender.sh` with `inspect-core-box-usd.py` for each real committed USDZ; then compare the two derived inventory reports to the canonical manifest. It snapshots checkout `__pycache__`/`.pyc` paths before and after and runs one poisoned-parent regression. Missing Blender/`pxr`, a handwritten inventory without matching traversal, any changed report under the poisoned parent, any new bytecode checkout write, or any real dependency/PNG/prim mismatch fails; no shell string scan may declare an asset valid.

The signed-package audit public CLI is exact:

```bash
scripts/audit-core-box-package.sh "$archive_path" "$release_manifest_path"
```

It exits 64 for invalid arguments and nonzero for signature, bundle metadata, identity, asset, inventory, privacy, or manifest mismatch.

- [ ] **Step 2: Run the new source audit before deletion and confirm red**

```bash
make core-box-asset-audit
make audit
```

Expected: the new hard-cut assertion fails because `Resources/CoreBox.usda` and runtime primitive construction still exist.

- [ ] **Step 3: Delete the obsolete production path**

Remove `Resources/CoreBox.usda` from disk, PBX file references, and Resources build phase. Delete production `makeCoreBoxScene()` and its primitive materials/camera/light helpers from `HomeView.swift`. If the primitive hierarchy remains useful for tests, recreate it only under `SomedayBoxTests/Fixtures/CoreBoxTestSceneFactory.swift`; production code cannot import or reach it. Functional `CoreBox2DAdapter` is the only production fallback.

- [ ] **Step 4: Add complete read-only Make gates**

```make
RESULT_BUNDLE_PATH ?=
BLENDER_BIN ?= /Applications/Blender.app/Contents/MacOS/Blender
DEVELOPER_DIR ?= $(shell /usr/bin/xcode-select -p)
RESULT_BUNDLE_ARGUMENT = $(if $(strip $(RESULT_BUNDLE_PATH)),-resultBundlePath "$(RESULT_BUNDLE_PATH)",)

.PHONY: core-box-toolchain-audit core-box-pipeline-tests core-box-export core-box-repro-check core-box-asset-audit core-box-package-audit core-box-compatibility-test

core-box-toolchain-audit:
	env -i DEVELOPER_DIR="$(DEVELOPER_DIR)" TZ=UTC LC_ALL=C LANG=C PYTHONDONTWRITEBYTECODE=1 /usr/bin/python3 -B scripts/core_box_toolchain.py --source-root "$(CURDIR)" --scope full --blender "$(BLENDER_BIN)"

core-box-pipeline-tests:
	PYTHONDONTWRITEBYTECODE=1 /usr/bin/python3 -B -m unittest discover -s scripts/tests -p 'test_core_box_*.py' -v

core-box-export: core-box-toolchain-audit
	./scripts/core-box-export.sh --write-reviewed-output

core-box-repro-check: core-box-toolchain-audit
	./scripts/core-box-repro-check.sh

core-box-asset-audit: core-box-toolchain-audit core-box-pipeline-tests
	./scripts/audit-core-box-assets.sh

core-box-package-audit: core-box-toolchain-audit
	@test -n "$(ARCHIVE_PATH)" || { echo "ARCHIVE_PATH is required." >&2; exit 64; }
	@test -n "$(RELEASE_MANIFEST_PATH)" || { echo "RELEASE_MANIFEST_PATH is required." >&2; exit 64; }
	./scripts/audit-core-box-package.sh "$(ARCHIVE_PATH)" "$(RELEASE_MANIFEST_PATH)"

core-box-compatibility-test: core-box-toolchain-audit
	xcodebuild test -project SomedayBox.xcodeproj -scheme CoreBoxCompatibilityHost -destination "$(SIMULATOR_DESTINATION)" -only-testing:CoreBoxCompatibilityUITests

ci-check: audit test
	@xcodebuild -version >/dev/null 2>&1 || { echo "Full Xcode is required for ci-check." >&2; exit 1; }
	$(MAKE) xcode-test
	$(MAKE) core-box-compatibility-test

xcode-test:
	@if [ -n "$(RESULT_BUNDLE_PATH)" ]; then test ! -e "$(RESULT_BUNDLE_PATH)" || { echo "RESULT_BUNDLE_PATH already exists." >&2; exit 64; }; mkdir -p "$$(dirname "$(RESULT_BUNDLE_PATH)")"; fi
	xcodebuild test -project SomedayBox.xcodeproj -scheme SomedayBox -destination "$(SIMULATOR_DESTINATION)" $(RESULT_BUNDLE_ARGUMENT)
```

`make audit` invokes `core-box-asset-audit` but never invokes `core-box-export`. Candidate verification remains read-only with respect to tracked and untracked checkout files.

`scripts/audit-core-box-package.sh` starts with `set -eu` and, before inspecting arguments, invokes `core_box_toolchain.py --scope full` under the empty host environment. It contains no expected tool literal, so its direct CLI is fail-closed through the same config/provenance/live verifier rather than Make dependency ordering. Every later host Python subprocess, including imports of `core_box_tree_digest.py`, runs under `env -i` with `/usr/bin/python3 -B`; every Blender Python invocation goes through `run-core-box-blender.sh`. A before/after bytecode-path snapshot must remain identical, and a poisoned parent environment must produce the same audit report bytes as a clean parent.

When `CORE_BOX_REPRO_REPORT_PATH` or `CORE_BOX_ASSET_AUDIT_REPORT_PATH` is supplied, the corresponding wrapper resolves the destination, requires it to be a new path beneath `.build/`, creates the canonical JSON report atomically, and fails if the path exists or escapes that evidence root. With neither variable set, the wrappers use their documented disposable `.build/core-box/reports/` defaults; they never write a report into tracked source or test-fixture directories.

- [ ] **Step 5: Replace string-only release audit with identity and version verification**

Replace the old tracked candidate-status snapshot with `core-box-candidate-manifest.schema.json`, a closed schema for external candidate evidence. Tracked files contain only the schema, template, and acceptance instructions; they never claim that the current checkout has physical-device or signed-package proof. `generate-core-box-candidate-manifest.py` reads the canonical asset manifest, current source contracts, signed archive, reproducibility report, asset-audit report, and `.xcresult`, validates their candidate SHA/tool/source identities, then emits an external manifest version 2 under `.build/release/` with:

- renderer `core-box-renderer-v2`;
- asset `core-box-character-v1` and exact manifest/Full/Lite digests;
- interaction `core-box-interaction-v2`;
- animation timing `core-box-timing-v2`;
- fallback `core-box-fallback-v2`;
- outcome `core-box-outcome-v2`;
- preference namespace `core-box-presentation-v2`;
- default `automatic` and user choices `automatic/full3D/simplified2D`;
- internal tiers `full3D/lite3D/swiftUI2D`;
- unchanged time-context, selection-policy, schema, backup, and generation-digest versions read from current source;
- local source/Simulator status only from the supplied exact reports; physical-device, manual accessibility, network/privacy, and promotion decision remain blocked until their separate evidence exists.

The generator requires `--repro-report`, `--asset-audit-report`, and `--xcresult` in addition to archive/source/candidate/output arguments; missing, stale, unsigned, or mismatched evidence remains `blocked` and cannot be promoted to pass by a command-line flag. The release audit recomputes raw manifest and tier digests, compares generated Swift literals, checks candidate versions, checks project resource inventory, verifies virtual non-AR camera and absence of camera usage text, and asserts Recovery has no scene dependency.

The external manifest records the archive and result-bundle tree digests using the exact Section 1.4 framing. Package audit recomputes both before trusting any embedded status; neither generator nor audit accepts a caller-supplied digest in place of traversing the directory.

- [ ] **Step 6: Pin and verify Blender in GitHub Actions**

The macOS 26 iOS job first sets `DEVELOPER_DIR` to the runner's Xcode 26.6 installation and fails closed on the exact build, then installs Blender:

```bash
selected_developer_dir="/Applications/Xcode_26.6.app/Contents/Developer"
test -d "$selected_developer_dir"
export DEVELOPER_DIR="$selected_developer_dir"
echo "DEVELOPER_DIR=$DEVELOPER_DIR" >> "$GITHUB_ENV"
env -i DEVELOPER_DIR="$DEVELOPER_DIR" TZ=UTC LC_ALL=C LANG=C PYTHONDONTWRITEBYTECODE=1 \
  /usr/bin/python3 -B scripts/core_box_toolchain.py --source-root "$PWD" --scope host

blender_dmg="$RUNNER_TEMP/blender-5.2.0-arm64.dmg"
blender_mount="$RUNNER_TEMP/blender-mount"
curl -fsSL \
  'https://download.blender.org/release/Blender5.2/blender-5.2.0-macos-arm64.dmg' \
  -o "$blender_dmg"
echo 'ed4d8390166dec5ea0a2813a03db6221f206ce016442be7f59f41d760972568a  '"$blender_dmg" | shasum -a 256 -c -
mkdir -p "$blender_mount"
hdiutil attach "$blender_dmg" -nobrowse -readonly -mountpoint "$blender_mount"
cp -R "$blender_mount/Blender.app" "$RUNNER_TEMP/Blender.app"
hdiutil detach "$blender_mount"
export BLENDER_BIN="$RUNNER_TEMP/Blender.app/Contents/MacOS/Blender"
echo "BLENDER_BIN=$BLENDER_BIN" >> "$GITHUB_ENV"
make core-box-toolchain-audit BLENDER_BIN="$BLENDER_BIN"
make core-box-repro-check CHECKED_OUT_ASSETS="$PWD" EXPORT_PROFILE=production-v1
```

The job is valid only when the single config/provenance/live verifier passes; selecting a nominal macOS/Xcode image whose build or OS-bundled USD identity differs fails closed and requires an explicit provenance/config update before export. The install/repro block exports values for itself and writes both paths to `$GITHUB_ENV`, so later `make ci-check` and upload steps receive the same toolchain. Run `make ci-check` with a candidate-SHA result path under `$RUNNER_TEMP` and upload `.xcresult`, normalized comparison, USD compliance logs, package-closure report, canonical manifest, asset inventory, and budget reports through `actions/upload-artifact@v4`. A missing or mismatched Blender or Apple USD tuple fails; CI never skips the asset gate.

- [ ] **Step 7: Run the full pre-commit regression gate**

```bash
precommit_result_root="$(mktemp -d /tmp/core-box-precommit-results.XXXXXX)"
make core-box-pipeline-tests
make core-box-asset-audit
make audit
make ci-check \
  SIMULATOR_DESTINATION='platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  RESULT_BUNDLE_PATH="$precommit_result_root/CoreBox-precommit.xcresult"
```

Expected: pipeline tests, static audits, 79 baseline tests plus every new unit/UI suite pass against the staged implementation. This pre-commit run does not claim a clean candidate SHA; it exists to avoid committing a known red state.

- [ ] **Step 8: Commit hard cut and executable gates**

```bash
git add -A Resources/CoreBox.usda Features/Home/HomeView.swift SomedayBox.xcodeproj/project.pbxproj scripts Makefile .github/workflows/ci.yml docs/release
git commit -m "chore: gate the authored Core Box release path" -m " - Remove obsolete production primitives and USDA fallback
 - Add reproducible CI archive identity and rollback evidence gates"
```

- [ ] **Step 9: Run the complete clean-checkout candidate gate**

```bash
test -z "$(git status --porcelain)"
candidate_sha="$(git rev-parse HEAD)"
candidate_evidence_root="$PWD/.build/core-box/candidates/$candidate_sha"
if test -e "$candidate_evidence_root"; then
  prior_evidence_root="$(mktemp -d /tmp/core-box-prior-candidate.XXXXXX)"
  mv "$candidate_evidence_root" "$prior_evidence_root/"
fi
mkdir -p "$candidate_evidence_root"
repro_report="$candidate_evidence_root/repro-report.json"
asset_audit_report="$candidate_evidence_root/asset-audit-report.json"
result_bundle="$candidate_evidence_root/CoreBox-${candidate_sha}.xcresult"
CORE_BOX_REPRO_REPORT_PATH="$repro_report" \
  make core-box-repro-check BLENDER_BIN=/Applications/Blender.app/Contents/MacOS/Blender CHECKED_OUT_ASSETS="$PWD" EXPORT_PROFILE=production-v1
CORE_BOX_ASSET_AUDIT_REPORT_PATH="$asset_audit_report" make core-box-asset-audit
make audit
make ci-check \
  SIMULATOR_DESTINATION='platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  RESULT_BUNDLE_PATH="$result_bundle"
git diff --exit-code
test -z "$(git status --porcelain)"
```

Expected: two isolated exports match each other and committed outputs; all gates pass; the result bundle is candidate-SHA named; the checkout remains clean. If this post-commit gate fails, fix the task and amend the Task 22 commit before continuing.

- [ ] **Step 10: Build and audit a signed candidate archive**

After the task commit, derive paths from the candidate SHA:

```bash
candidate_sha="$(git rev-parse HEAD)"
candidate_evidence_root="$PWD/.build/core-box/candidates/$candidate_sha"
repro_report="$candidate_evidence_root/repro-report.json"
asset_audit_report="$candidate_evidence_root/asset-audit-report.json"
result_bundle="$candidate_evidence_root/CoreBox-${candidate_sha}.xcresult"
archive_root="$PWD/.build/archive"
archive_path="$archive_root/SomedayBox-${candidate_sha}.xcarchive"
release_root="$PWD/.build/release"
release_manifest_path="$release_root/CoreBox-${candidate_sha}.json"
mkdir -p "$archive_root" "$release_root"
test -f "$repro_report"
test -f "$asset_audit_report"
test -d "$result_bundle"
if test -e "$archive_path" || test -e "$release_manifest_path"; then
  prior_package_root="$(mktemp -d /tmp/core-box-prior-package.XXXXXX)"
  test ! -e "$archive_path" || mv "$archive_path" "$prior_package_root/"
  test ! -e "$release_manifest_path" || mv "$release_manifest_path" "$prior_package_root/"
fi

xcodebuild archive \
  -project SomedayBox.xcodeproj \
  -scheme SomedayBox \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$archive_path"

/usr/bin/python3 -B scripts/generate-core-box-candidate-manifest.py \
  --source-root "$PWD" \
  --archive "$archive_path" \
  --candidate-sha "$candidate_sha" \
  --repro-report "$repro_report" \
  --asset-audit-report "$asset_audit_report" \
  --xcresult "$result_bundle" \
  --output "$release_manifest_path"

make core-box-package-audit \
  ARCHIVE_PATH="$archive_path" \
  RELEASE_MANIFEST_PATH="$release_manifest_path"
```

The package audit verifies `codesign --verify --deep --strict`, bundle identifier/version/build, `xcarchive-tree-sha256-v1`, signing identity/CDHash, exact manifest and tier bytes, generated identity literals present in the signed executable, and supplied repro/audit/xcresult evidence digests. For each signed USDZ it runs `usdzip --list`, both strict checker passes, and the inspector through the clean Blender launcher; it requires exact equality among actual members, recursively root-reachable members, localized-path inventory, and the manifest dependency inventory. Both encodings require one packaged root `.usdc` and exactly basecolor/normal/roughness textures; `usdNamedResourcesV1` additionally requires all and only selected localized action layers, while `runtimeTransformRecipesV1` requires zero packaged action layers and validates its embedded recipe digest instead. Missing/external/unresolved/wrongly localized/extra/colliding members fail. It also proves absence of every `CoreBoxProof*`/compatibility-host resource or identifier from the production app, no remote asset reference, no added audio, no camera entitlement or usage string, and equality with the external manifest schema.

- [ ] **Step 11: Close physical-device performance and operational evidence**

Install that exact signed candidate on the oldest supported iPhone/iOS 18 reference device and a current iPhone/current iOS reference device. For both Full and Lite, prove exact animation names or activated recipe identities plus ribbon 0/0.72/1 samples. Record:

- Full 60-second Capture/Peek/Draw trace: frame-time p95 ≤16.7 ms and frames over 33.3 ms ≤1%.
- Lite trace: frame-time p95 ≤33.3 ms and frames over 66.7 ms ≤1%.
- Full peak resident-memory increase over the same 2D journey ≤120 MiB.
- Fifty-cycle journey with no thermal serious/critical, scene leak, duplicated subscription, stale event, or product duplication.
- Fixed-camera Full/Lite screenshots on light/dark stage backgrounds proving the authored contact shadow stays soft, connected, and inside its footprint; Full has one restrained dynamic shadow, Lite has none, and neither contaminates eyes or ribbon.
- Low Power Mode, memory warning, background/foreground, forced asset failure, offline mode, and Recovery.
- App Privacy Report and runtime inspection proving no remote asset dependency or new sensitive permission.

Attach device IDs, OS, candidate SHA, signed `xcarchive-tree-sha256-v1`, Instruments traces, screenshots, recordings, manual accessibility matrix, and package report to the external candidate evidence. Do not mark release accepted from Simulator, unsigned archive, or source-only results.

- [ ] **Step 12: Verify rollback as a source/release operation**

Build the previous signed compatible source with functional 2D, import current product data, and confirm no schema or backup downgrade is required. A bad 3D candidate is forward-fixed or replaced by a binary defaulting to Simplified 2D; no remote flag, remote asset swap, server kill switch, or destructive data rollback is introduced.

**Slice C exit gate:** the final paper-spirit model and all 13 motions meet source/runtime budgets; the sage ribbon remains at screen right; every character event follows committed verified truth; 2D completes the same journeys; accessibility/input parity is closed; obsolete production primitives and USDA are deleted; clean CI is reproducible and read-only; and the exact signed candidate has physical-device, performance, privacy, package, and rollback evidence.

## 3. Final acceptance matrix

| Area | Required executable evidence | Release blocker |
| --- | --- | --- |
| Source identity | `make core-box-pipeline-tests`, source tree digest, canonical manifest | Any schema, provenance, path, or digest mismatch |
| Reproducibility | Two isolated exports plus committed-byte comparison | Any normalized USDA, USDZ, manifest, or generated Swift mismatch |
| Runtime assets | Full/Lite load, hierarchy, 13 motions, ribbon samples | Missing/extra name, bad terminal, NaN, unsafe ribbon, or partial scene |
| Product truth | Transaction receipt and AppModel three-state suites | Any success motion without committed verified projection |
| Interaction | Coordinator, ribbon, idle, lifecycle, and degradation suites | Duplicate intent, stale event, channel conflict, or unstable fallback |
| UI journeys | Full/Lite/2D Capture, Draw, resolution, Peek, Current, Complete, Share, Recovery | Any renderer loses a semantic action or changes product result |
| Accessibility | Automated audits plus manual assistive-technology matrix | Hidden required action, delayed result focus, overlap, or motion-only meaning |
| Performance | Physical-device percentile, memory, thermal, and 50-cycle evidence | Any hard threshold breach, leak, duplicate subscription, or stale replay |
| Signed package | Exact archive signature, resources, identities, USD compliance, privacy | Missing/unsealed resource, mismatch, remote dependency, or new permission |
| Rollback | Previous compatible source plus current data and functional 2D | Requires destructive data change, remote control plane, or silent legacy path |

## 4. Definition of done

Implementation is complete only when all 22 task commits are green, all three slice exit gates pass, the worktree remains clean, the user-owned stash remains untouched, the actual signed candidate passes the final acceptance matrix, and release evidence clearly distinguishes source tests, Simulator proof, physical-device proof, and packaged proof.

# ADR 0004: RealityKit `RealityView` renders a presentation-only box scene

- Status: Accepted for Lived-in Box implementation
- Implementation status: tracked in the [Lived-in Box readiness ledger](../release/lived-in-box-readiness.md), never here
- Date: 2026-08-16
- Feature contract: [Lived-in Box](../features/lived-in-box.md)

## Context

The Lived-in Box release turns Home into a tangible 3D box: a lid that opens for capture, a soft strap that draws a paper, a peek-inside camera, a paper stack whose density and age reflect stored records, and slowly appearing seams and traces.

The product's existing authority chain is strict and must stay intact: SwiftUI Features → Application use cases (MutationArbiter) → pure Domain rules, with SwiftData adapters underneath. Selection is persisted before any reveal animation; the unresolved-result gate and generation-switching restore/erase are non-negotiable. The app has zero third-party dependencies, no network, and a hard performance/accessibility bar; the owner has fixed the 3D box as the product's sole Home surface and sole development target.

A rendering technology is needed that can host a programmable, lit, animated 3D scene inside the existing SwiftUI shell, on iOS 18.0, using only Apple frameworks.

## Decision

Render the box scene with **RealityKit through `RealityView`**, hosted inside the existing SwiftUI Home surface, as a **presentation-only layer**:

- The scene consumes an immutable `BoxSceneSnapshot` produced by a pure, versioned reducer (`box-scene-v1`) from the persisted product snapshot plus an injected clock/calendar. Data flow is one-directional; the scene diff-applies snapshots.
- Scene gestures (lid, strap, dial, peek) resolve to **intents** forwarded to the existing application use cases. The scene layer never opens a ModelContext, never writes product records, and never introduces a record type.
- All text-bearing UI (capture sheet, result card, reasons, errors) stays SwiftUI — via `RealityView` attachments or conventional overlays — so localization, Dynamic Type, VoiceOver, and copy contracts are untouched.
- Selection, resolution, completion, and every other transaction commit **before** their presentation plays; interrupting any animation loses nothing (existing DRW-08/LIFE-04 semantics).
- Geometry is **procedural for B1** (parametric meshes and PBR materials). Authored, self-made USDZ/Reality Composer Pro assets may replace parts later within the budgets in the feature spec §15.4. No third-party assets without a recorded license review.
- Paper "physics" is deterministic animation (springs/keyframes) with seeded layout; no physics simulation participates in any correctness path.
- The 3D scene is the **sole Home surface** (owner decision, feature spec LB-D19); no parallel 2D product mode exists. Degradation is an in-scene quality-tier ladder (effects, materials, instance caps — Q0/Q1/Q2). Catastrophic initialization/asset failure presents a minimal **data-safety recovery surface** — retry plus full Settings data controls — never a parallel product UI, so a scene-layer failure can never corrupt, hide, or trap data.
- The Share Extension links no RealityKit, audio, or scene code.

## Layer placement

The reducer and scene code live in the Features layer (`Features/Home/Scene/`), beside the views they serve:

| Concern | Authority |
| --- | --- |
| Product records and transitions | Domain + Application + Data (unchanged) |
| What the scene may display | `BoxSceneStateReducer` (`box-scene-v1`), pure and unit-tested |
| Entity graph, materials, camera, animation | RealityKit layer, main-actor, diff-driven |
| Presentation preferences | `UserDefaults` per baseline 9.7, excluded from backup |
| Assets | App bundle with a hashed asset manifest in the development plan |

`Domain/` stays Foundation-only; nothing in `Domain/` or `Application/` may import RealityKit.

## Consequences

- iOS 18.0 remains the minimum target; `RealityView` on iOS requires it, so the deployment floor is unchanged.
- The local-only audit keeps passing by construction (RealityKit is an Apple framework; no new entitlement or capability). The audit's content-logging scan now also covers scene, audio, and render-diagnostic code.
- New evidence classes join acceptance: frame-rate/memory/thermal Instruments runs on the newest and oldest reference devices, a quality-tier behavior matrix, a gesture-to-control equivalence audit, and motion-comfort review. The single-surface decision makes the oldest-device frame floor a hard release gate rather than a fallback trigger.
- Bundle weight grows within stated budgets (B1 ≤ 10 MB new, audio ≤ 1.5 MB).
- Determinism is preserved for tests: seeded layout, injected clock for light and age tiers, and a pure reducer make scene derivation fixture-testable without rendering.
- Simulator evidence remains partial: RealityKit renders in the simulator on Apple silicon, but frame-rate, thermal, haptic, and material truth require physical devices — the same evidence separation the project already enforces.

## Rejected alternatives

### SceneKit

Runs everywhere iOS 18 does, but it is in maintenance mode without a SwiftUI-native container; investing the product's signature surface in a stagnant API contradicts the multi-year lived-in roadmap.

### SpriteKit / 2.5D layered illustration

Cannot deliver believable volume, lid/strap dimensionality, lighting, or the peek camera — and the owner has fixed the 3D object as the sole development target; a flat rendition is not a product surface in this generation.

### Custom Metal renderer

Maximal control, but it re-implements lighting, shadows, asset loading, and accessibility bridging that RealityKit provides, with a much larger correctness and maintenance surface for a single-developer, evidence-driven project.

### Third-party engines (Unity, Godot, Filament…)

Prohibited by the zero-third-party-dependency contract; they also embed telemetry/runtime layers that would break the local-only audit and privacy claims.

### Full RealityKit physics simulation for papers

Rejected for correctness paths: simulation is non-deterministic across devices and OS versions, hostile to fixtures, and unnecessary — animation that *reads* as physics meets the experience bar (feature spec LB-D15).

## Revisit triggers

Revisit this decision only if:

- Apple deprecates or materially regresses `RealityView` on iOS;
- measured B1 evidence shows the oldest reference device cannot hold the frame floor even at the lowest quality tier — in which case the owner decides an explicit device-support or budget change, never a silent fallback mode;
- an approved future feature requires scene capabilities RealityKit cannot express; or
- the product adopts a different presentation architecture through a replacement ADR.

Any revisit keeps the presentation-only authority boundary and the data-safety recovery surface; neither is negotiable under a renderer change. Reintroducing a parallel 2D product mode would reverse owner decision LB-D19 and requires the owner's explicit, recorded reversal.

# ADR 0004: RealityKit core-box presentation

- Status: Accepted for vNext implementation
- Date: 2026-07-19
- Scope: Core Box Home presentation and interaction only
- Parent contract: [Core Box Living Experience Upgrade](../core-box-living-experience-upgrade.md)

## Context

The existing app already owns durable Paper, Draw Attempt, Current Pick, Memory, Share import, backup, restore, erase, and Recovery truth. Its current Home Box is a simple SwiftUI illustration. The vNext product direction requires a warmer digital-object experience with volume, a lid, a soft pull ribbon, Paper accumulation, a Peek view, material response, lighting, shadows, sound, and consistent physical feedback.

The project remains an iPhone app with an iOS 18.0 minimum, Apple frameworks only, no account, no developer server, no product network request, no LLM, and no new sensitive permission. The 3D presentation must not weaken the existing mutation, persistence, accessibility, performance, or recovery contracts.

Apple provides an iOS/macOS `RealityView` initializer backed by `RealityViewCameraContent` on iOS 18 or later. A virtual camera can render RealityKit content without camera passthrough or AR placement.

## Decision

Use SwiftUI plus RealityKit `RealityView` for the vNext Core Box Home under the following fixed boundaries.

### Presentation mode

- Use `RealityViewCameraContent` and explicitly assign its camera to `.virtual`.
- Treat the Box as an inline, non-AR 3D scene.
- Do not request camera permission, use camera passthrough, world tracking, scene reconstruction, or room placement.
- Keep all models, textures, audio, environment assets, and 2D fallbacks bundled in the app.
- Freeze a version-controlled Reality or USD-family asset path that builds with the pinned production toolchain. Reality Composer Pro is optional and may be used only after its authoring/linking requirements are proven compatible or its deterministic exports build on the pinned line.

### Truth and dependency direction

- RealityKit remains in the App/presentation layer.
- Domain, Application, Data, and the Share Extension do not import or depend on RealityKit.
- The renderer consumes an immutable, content-minimized scene snapshot derived from committed product state.
- A 3D gesture emits a user intent. The interaction coordinator calls the existing or versioned application use case.
- A transaction returns a structured committed outcome. A verified refetch produces the correlated presentation command; commit-with-refetch-failure enters read-only reconciliation and drops presentation rather than permitting a duplicate mutation.
- The renderer never selects a Paper, opens SwiftData, mutates lifecycle, creates a Memory, or becomes a second product-state store.
- Capture, Draw, Accept, Redraw, Dismiss, Complete, and Share-import success motion occurs only after the corresponding authoritative transaction succeeds.

### SwiftUI semantic ownership

- SwiftUI continues to own navigation, text entry, time controls, result text, errors, destructive confirmation, Recovery, Settings, and data management.
- Every 3D interaction has a visible native control and an accessibility action equivalent.
- Exact user content is rendered in SwiftUI, not baked into scene textures.
- RealityKit accessibility metadata may enhance the scene but is never the only assistive-technology path.

### Renderer parity and degradation

Ship and verify three equivalent renderer tiers:

1. Full 3D.
2. Lite 3D with reduced entities/effects.
3. Functional SwiftUI 2D.

Normal, Quick, and Reduce Motion are independent motion variants across those tiers. Reduce Motion uses static states and short fades; it is not a fourth renderer.

Asset-load failure, required-entity validation failure, memory pressure, serious thermal pressure, or sustained frame-budget failure can lower the renderer at a stable interaction boundary. Renderer changes write no product data. Recovery and unresolved-result gates remain usable even when the 3D scene never initializes.

### Asset and motion boundary

- Freeze entity names, units, pivots, anchors, material/texture budgets, collision proxies, and asset digests in the release contract. Build/archive audits own geometry, texture, audio, package, and provenance ceilings; runtime verifies the signed manifest identity and structural anchors.
- Cap visible Paper entities; use pooled entities and aggregate geometry rather than mirroring every stored Paper.
- Use authored transforms, animation resources, deterministic paths, and bounded deformation for the lid, ribbon, Papers, and P0 memory seam. An openable drawer remains separately scoped P1 work.
- Do not use full cloth simulation or a large rigid-body Paper pile in the first release.
- Physics may affect presentation-only settling but never business outcomes.
- Stop animations, audio, particles, gesture processing, and unnecessary per-frame work when the app backgrounds.

### Compatibility-gate animation encoding

- RealityKit on the pinned iOS 26.5 simulator and iPhone 17 Pro Max / iOS 26.5.2 loads the proof USDZ hierarchy but does not expose its composed USD clip resources through Entity.availableAnimations.
- The Task 5 proof therefore uses runtimeTransformRecipesV1: deterministic, named rigid-node transforms for the same public motion identifiers. This applies to the three proof motions only; Task 16 still requires the final 13-motion production verification.
- Exact-byte validation, required hierarchy checks, one-root RealityView installation, sampled ribbon safety, and functional 2D rejection remain mandatory. The fallback never introduces extra runtime USDZ files, a network dependency, or a return to runtime primitive modeling.

## Alternatives considered

### SwiftUI-only 2D as the sole presentation

Rejected as the only vNext path because it cannot fully deliver the requested material, depth, camera, lighting, and object-presence direction. It remains the required fallback and accessibility-equivalent renderer.

### `ARView` with camera passthrough

Rejected. The product is a private digital object, not an AR-placement experience. Camera use would add permission, privacy, environmental variability, testing cost, and a false implication that the Box occupies the user’s room.

### SceneKit

Not selected. RealityKit integrates directly with the chosen SwiftUI `RealityView` path, current Apple 3D asset tooling, entity/component interaction, lighting, audio, and the existing iOS 18 baseline.

### A game engine or third-party renderer

Rejected for this release. It would expand runtime supply-chain, privacy, binary-size, accessibility, update, and removal costs without evidence that native RealityKit is insufficient for one bounded scene.

### Renderer-owned physics and selection

Rejected. A visible collision or Paper position cannot provide durable, interruption-safe, testable Draw truth.

### Remote or downloadable 3D assets

Rejected. They violate the offline/local-only boundary, introduce availability and version skew, and weaken packaged acceptance and rollback evidence.

## Consequences

### Positive

- The Box can become a coherent digital object while the proven domain and persistence boundaries remain intact.
- The app retains a native semantic interface and a complete 2D path.
- A renderer defect can be contained without modifying personal data.
- Bundled, versioned assets keep offline and release evidence auditable.
- Presentation timing can evolve without changing selection or lifecycle truth.

### Costs

- The project gains a versioned 3D asset pipeline, entity contract, performance budgets, device testing, and visual regression work.
- Three renderer tiers and their required motion variants require parity evidence.
- Targeted gestures and 3D accessibility need physical-device testing beyond ordinary SwiftUI audits.
- Asset changes require provenance, digest, load, budget, and rollback evidence.

### Risks controlled by this decision

- A missing model cannot block the product because 2D is complete.
- A broken animation cannot invent or lose a Paper because mutations precede presentation.
- A renderer cannot leak into data/recovery layers because the dependency direction is fixed.
- AR/camera scope cannot appear as an incidental implementation choice.
- Thousands of stored Papers cannot become thousands of scene entities.

## Operational requirements

- Record renderer, asset, interaction, animation-timing, fallback-policy, schema, backup, and Draw-policy versions in each release manifest.
- Use signed local build configuration for internal rollout; no remote flag or remote kill switch.
- Do not gate schema migration on renderer availability.
- If Full/Lite 3D cannot meet the oldest-device contract, ship 2D as the default until measured evidence supports promotion.
- Pause and forward-fix a released defect; binary downgrade is not a data-recovery promise.
- Remove expired prototype renderers and flags after the documented parity/removal gate.

## Validation required before release

- Required-entity and asset-digest validation.
- D0/D1/D2 functional parity under required Normal/Quick/Reduced Motion variants.
- Capture/Draw/Current Pick/Memory commit-before-animation interruption tests.
- Manual VoiceOver, Voice Control, Switch Control, largest Dynamic Type, and Reduce Motion evidence.
- Oldest/current physical-device load, frame, memory, thermal, background, and stress evidence.
- Airplane-mode and runtime-network inspection.
- Signed packaged candidate with bundled-asset inventory and no camera entitlement/permission usage.

## References

- [RealityView](https://developer.apple.com/documentation/realitykit/realityview)
- [RealityViewCameraContent](https://developer.apple.com/documentation/realitykit/realityviewcameracontent)
- [RealityView virtual camera](https://developer.apple.com/documentation/realitykit/realityviewcamera/virtual)
- [InputTargetComponent](https://developer.apple.com/documentation/realitykit/inputtargetcomponent)
- [Loading entities from a file](https://developer.apple.com/documentation/realitykit/loading-entities-from-a-file)
- [Reality Composer Pro](https://developer.apple.com/documentation/realitycomposerpro)
- [Improving RealityKit performance](https://developer.apple.com/documentation/realitykit/improving-the-performance-of-a-realitykit-app)
- [AccessibilityComponent](https://developer.apple.com/documentation/realitykit/accessibilitycomponent)
- [Human Interface Guidelines: Motion](https://developer.apple.com/design/human-interface-guidelines/motion)

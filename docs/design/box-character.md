# Someday Box character

## Shape and material

The character is a 24 × 17 × 19 cm kraft cardboard carton with thin walls, two
folding top flaps, cocoa eyes, tiny highlights, coral cheeks, and a curved smile.
The top has split packing tape, a visible centre seam, and exposed corrugated cut
edges. A continuous curved tape ribbon wraps over the front flap edge and overlaps the
fixed tape end below the hinge. The ribbon follows the flap when it opens; the
front tail stays on the body. Corner folds continue onto the front. There is no pull-tab.
The body remains hollow and retains its paper stack and conditional growth structures.
The front camera shows a little of the right side to make its depth legible.

Geometry and PBR materials are authored in RealityKit without downloaded assets.
A shared deterministic 512 px texture adds paper fibres and subtle pressing lines.
Kraft uses high roughness and low reflectance; tape has a slightly smoother finish.
Texture construction failures propagate to the existing scene recovery boundary.
`BoxCharacter` builds the face; `BoxGeometry` owns the container; `BoxIdleAnimator`
applies presentation-only transforms. No product records or capture state live in
these components.

## Idle performance

A ten-second performance plays when the active front view becomes idle:

| Time | Action |
| --- | --- |
| 0–10 s | Subtle breathing with a soft entrance and exit |
| 1.3–1.58 s | Quick blink |
| 2.1–4.3 s | Eyes look aside, followed by a curious head/body tilt |
| 4.1–4.4 s | Second blink |
| 5.4–7.1 s | Anticipation squash, small hop, landing compression, settling rebound |
| 7.5–9.6 s | Gentle contented sway |
| After 10 s | Neutral pose; animation task ends |

Raised-cosine envelopes have zero velocity at their boundaries. Breathing preserves
approximate volume; squash and rotation compensate for floor contact. Absolute
elapsed time drives every pose, avoiding accumulated drift and frame-rate-dependent
motion. Geometry is built once and reused.

Capture and camera transitions immediately restore the neutral body pose. Idle
animation never writes either flap hinge. The front flap folds outward to keep the
capture paper visible. Reduce Motion disables the performance;
inactive scenes and disappearing views cancel the task. This preserves PRF-03's
existing ten-second idle limit. Returning to the front view starts a new performance.

## Verification

Run `make audit test` and the Xcode unit/UI test suite. Rendering tests cover the
blink, lift, neutral reset, finite duration, and independence from the capture hinge.
Inspect the simulator for facial contrast, ground contact, lid hit testing, and
capture-paper visibility. Simulator results do not establish physical-device frame
rate or energy budgets.

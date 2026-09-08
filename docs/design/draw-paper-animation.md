# Draw paper animation

The existing draw use case commits the selected attempt before the reveal scene
appears. `DrawRevealGate` is keyed by attempt ID, so redraws play a new performance
and always display `unresolvedItem` from the persisted result. The scene snapshot
excludes that reserved item from the resting stack.

## Choreography

- 0–0.85 s: a short, accelerating-looking cardboard shake.
- 0.70–1.05 s: the two flaps open.
- 0.88–2.25 s: a folded paper leaves the cavity along a raised quadratic arc,
  unfolds, rolls gently, and decelerates to a point 42 cm in front of the virtual
  camera. Its face turns toward that camera.
- 1.85–2.25 s: the flaps close after the paper clears the opening.
- 2.25–2.47 s: the 3D paper fades into a readable SwiftUI paper surface with the
  selected title, optional note, and duration. Long notes scroll; controls remain
  outside the scroll region.
- 2.65 s: the animation clock ends. Accept, redraw, and dismiss continue to call
  the existing use cases. No selection or persistence logic is duplicated.

All entity changes live in `Features/Home/Scene`. The scene owns no product records.
Reduce Motion skips the flight. Leaving the foreground settles the reveal rather
than replaying it on return. The task cancels with its view, and a cached snapshot
avoids deriving paper layout on every animation frame.

## Verification

Rendering tests verify that the paper clears the box, finishes in front of the
camera, and hides after handoff while the box returns to its closed neutral pose.
An end-to-end UI test captures an idea, draws a paper, checks the readable result,
accepts it, and returns it to the box. The normal source-layer and domain audits
remain required. Simulator verification does not establish device frame-rate or
energy budgets.

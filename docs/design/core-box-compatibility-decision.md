# Core Box RealityKit compatibility decision

## Decision

The Core Box proof uses `runtimeTransformRecipesV1` for presentation motion.

RealityKit on the iOS 26.5 simulator loads both exact-byte proof USDZ packages
and their required hierarchy, but exposes no values through
`Entity.availableAnimations`. The composed USD clip names `idle.listen`,
`capture.deposit`, and `draw.reveal` therefore cannot be used as runtime
playback identifiers. The physical-device rerun is intentionally deferred
until the final acceptance pass, per the current development instruction.

The fallback preserves these public names and applies a deterministic recipe to
the named authored entities. It is not a second asset format and does not add a
network dependency, a remote flag, or a production primitive scene.

## Evidence

- Proof profile: `pipeline-spike-v1`
- Report SHA-256: `ea274a476fbb43c815f8e7182e681e8a895cf6fe3c5d262d986dd67f165b4ac2`
- Full SHA-256: `f92ad6341fd8f01e6c96d93f52814c2cab27dfca5fe5cd1f0dda47dc1941b3ab`
- Lite SHA-256: `28db80b83e09e010bb20be8e4509a49e49d49e6c0fcebaeb02cbc7c8e3ac1357`
- Simulator: iPhone 17 Pro, iOS 26.5
- Physical device: intentionally not run before final acceptance

The verification-only compatibility host contains one RealityView make/update
path, the three representative recipe terminals, ribbon samples at 0, 0.72,
and 1, plus a forced structural rejection that keeps the seven 2D actions
available.

On 2026-07-21, `make core-box-compatibility-test` passed both cases on the
iPhone 17 Pro Simulator running iOS 26.5:

- Simulator result tree (`xcresult-tree-sha256-v1`):
  `bde0a38a8fcf33b7ad170b40723478500734f18b00e0d21ec1d74430ca91344a`
- Physical-device result tree (`xcresult-tree-sha256-v1`): pending final
  acceptance rerun.

The Simulator result records `testValidatedAssetCreatesOneRealityRoot` and
`testStructuralFailureShowsTwoDFallbackWithNoRealityRoot` as passed. The
physical-device tree remains deliberately unrecorded until the final
acceptance run. These are the Task 5 three-motion compatibility gates; Task 16
remains the separate complete 13-motion production verification.

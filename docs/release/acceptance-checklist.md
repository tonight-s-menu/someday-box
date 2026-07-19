# Release acceptance checklist

Use this checklist with a candidate-specific release manifest. Preserve logs, result bundles, screenshots, recordings, reports, and archive identifiers outside transient build directories.

## 1. Static evidence

- [ ] `make audit` passes at the candidate SHA.
- [ ] The audit output is attached to the manifest.
- [ ] Linked frameworks, Swift packages, entitlements, privacy manifest, generated Info.plist keys, and production feature flags receive human review.
- [ ] No network, analytics, CloudKit, LLM, account, or sensitive capability is approved for this MVP.

Static evidence is source/configuration evidence only. It does not prove runtime traffic, signed entitlements, device behavior, or packaged behavior.

## 2. Unit evidence

- [ ] Domain boundary, lifecycle, invariant, journal-retention, and deterministic draw tests pass.
- [ ] Application mutation-gate and use-case tests pass.
- [ ] The `.xcresult`, command, Xcode version, and candidate SHA are retained.

## 3. Integration evidence

- [ ] In-memory mapping and transaction tests pass.
- [ ] Temporary disk-backed relaunch and durability tests pass.
- [ ] Released-schema migration fixtures pass without silent reset.
- [ ] Backup round trip, invalid import, staged restore, interruption, and deletion-closure matrices pass.
- [ ] Failures demonstrate zero unintended authoritative-store changes.

## 4. Local runtime evidence

- [ ] A simulator or development-signed device completes Capture → relaunch → Draw → Redraw/Accept → Complete → Memories using persisted records.
- [ ] Unresolved reveal and Current Pick survive forced termination.
- [ ] Error, capacity, unsupported-data, empty, and recovery states are visibly verified.
- [ ] The device/simulator identifier, OS, build configuration, timestamp, and recording are retained.

Local runtime evidence is not packaged acceptance.

## 5. Offline evidence

- [ ] Airplane mode is enabled before cold launch.
- [ ] Capture, draw, lifecycle, relaunch, export, erase, and restore remain functional.
- [ ] No feature degrades into an undisclosed remote dependency.
- [ ] The device App Privacy Report and runtime network inspection are retained separately.

## 6. Accessibility evidence

- [ ] Automated accessibility audit passes on every primary screen and major error state.
- [ ] VoiceOver and Voice Control journeys pass manually.
- [ ] Largest Dynamic Type remains usable without hidden required actions.
- [ ] Reduce Motion alternatives preserve state truth and completion.
- [ ] Light/dark appearance and Simplified Chinese/English are checked.

## 7. Physical-device evidence

- [ ] The oldest supported reference iPhone on iOS 18 passes the release matrix.
- [ ] A current iPhone/current iOS version passes the release matrix.
- [ ] Haptics, background/foreground, forced termination, low-storage handling where practical, and Files import/export are checked.
- [ ] Upgrade from the previous public build is checked.

## 8. Packaged evidence

- [ ] A signed Release archive is produced from the manifest SHA and immutable tag.
- [ ] Archive privacy report and signed entitlements are reviewed.
- [ ] The installed archive or TestFlight build completes the same persisted core journey on physical devices.
- [ ] Archive checksum, signing identity, provisioning profile, version/build, and TestFlight build identifier are recorded.
- [ ] Rollback/containment and known limitations are approved.

Only this section can close packaged acceptance. Green source scans, unit tests, simulator runs, or a successful archive command cannot substitute for the installed signed-candidate journey.

## 9. Conditional Share to Box evidence

Complete this section only when the candidate manifest declares Share to Box as shipped. Marking the feature “not shipped” is not a substitute if the archive embeds or advertises the extension.

- [ ] The App Group is registered and associated with both App IDs/provisioning profiles under the same development team.
- [ ] The extension has its own bundle identifier, is embedded as the intended `.appex` under the archived app’s `PlugIns` directory, and passes archive validation.
- [ ] The production extension uses `com.apple.share-services`, activation dictionary v2, strict matching, URL max 1, and text support; it contains no `TRUEPREDICATE`, image/movie/file/webpage declaration, or `UIBackgroundModes`.
- [ ] Signed entitlements—not the project capability UI—show the exact same reviewed App Group and Complete Data Protection on app and extension; SwiftData remains outside the group with CloudKit disabled.
- [ ] `APPLICATION_EXTENSION_API_ONLY=YES` covers the extension and every shared module, which contain no networking, WebKit, source-platform SDK, analytics, ads, or unapproved sensitive capability.
- [ ] URL-only, text-only, URL-plus-text, empty/unsupported, provider-error, cancellation, validation, capacity, low-storage, and repeated-save states are verified.
- [ ] Forced termination before final envelope publication yields zero final captures; termination after publication yields one readable envelope; active-window replay materializes exactly one Paper plus Source Reference.
- [ ] Main-app ingestion, drawable count, source detail, source removal, Paper deletion, and source-neutral draw behavior use persisted records.
- [ ] Immediate-predecessor migration (using the exact public binary when one exists), promised older-backup import, current backup cutoff/round trip, restore interruption, Erase All, corrupt/future envelope, and mailbox cleanup matrices pass.
- [ ] Protected Data unavailable is injected during provider load, temporary write, publication, and readback; no case reports false success or leaves a permanent coordination owner.
- [ ] Given the same delivered representation, airplane-mode publication and ingestion plus runtime inspection prove that neither app nor extension initiates a connection; host-side offline differences and Open Original are recorded separately.
- [ ] English/Simplified Chinese, light/dark appearance, largest Dynamic Type, VoiceOver, Voice Control, Reduce Motion, iPhone, and required universal-extension host layouts pass.
- [ ] Physical-device evidence records the actual representations and outcome for Safari, Xiaohongshu, Instagram, TikTok, YouTube, Google Maps, Apple Maps, and a plain-text host; unavailable or partial results remain labeled honestly.
- [ ] The installed signed candidate survives immediate-predecessor upgrade, host dismissal, app suspension, device locking, and later containing-app launch without losing or duplicating the active capture.

This conditional gate is closed only by the installed packaged app and extension. Main-app unit tests, a synthetic host, Debug signing, or an extension screenshot do not prove real-host payloads, entitlements, lifecycle, or packaged ingestion.

## 10. Conditional Core Box living-experience evidence

Complete this section only when the candidate manifest declares the [Core Box living experience](../core-box-living-experience-upgrade.md) as shipped. A scene hidden in the archive or reachable production path cannot be treated as “not shipped.”

- [ ] The candidate records the renderer, interaction, asset, animation-timing, fallback-policy, Draw-context, selection-policy, schema, and backup-format versions plus the compiled asset digest.
- [ ] Every 3D model, texture, environment resource, audio file, and 2D fallback is bundled; source/provenance records are retained; archive and runtime inspection find no remote asset or product-network dependency.
- [ ] The RealityView uses the reviewed virtual-camera, non-AR path and requests no camera, location, microphone, Photos, Contacts, Calendar, or notification permission for the core experience.
- [ ] Runtime validates the bundled manifest digest and required entity/pivot/anchor contract; build/archive audit separately proves triangle/entity/Paper/light/material/texture/audio/package/provenance ceilings and full/Lite variants.
- [ ] A missing/corrupt asset and every injected required-anchor failure select a functional 2D path without changing product data or blocking Capture, Draw, unresolved-result recovery, Shared Capture Recovery, or store Recovery.
- [ ] D0 Full 3D, D1 Lite 3D, and D2 SwiftUI 2D under required Normal/Quick/Reduced Motion variants complete the same Capture → Draw → Accept/Redraw/Dismiss → Current Pick → Complete/Put back → Memories journey and major error states.
- [ ] Capture deposit, Paper reveal, Current Pick attachment, completion stamp/seam, and Share deposit occur only after structured transaction outcomes plus verified refetch; injected post-commit refetch failure enters reconcile and never duplicates a Paper, Attempt, Current Pick, Memory, Source Reference, or Share success animation.
- [ ] Ribbon release below threshold writes no Session/Attempt, release at threshold submits exactly once, and the visible native Draw control provides an equivalent path for assistive technologies and renderer failure.
- [ ] Peek exposes no readable Paper title/note, has a visible Organize action, and restores a stable camera/presentation state across background and foreground.
- [ ] Startup unresolved results bypass new selection, unsupported old policy disables Redraw only, and exhausted Redraw closes the old Session, refreshes deferred Share/Recovery work, then creates a distinct same-context Session only after explicit Reshuffle.
- [ ] `inBoxCount` includes unsupported-duration Active Papers while `drawableCount` excludes them; scene density, Peek, Draw availability, and VoiceOver report the appropriate values.
- [ ] P0 time-context v2 proves the full fit table, exact Custom boundaries, custom independent-generation schema v2 → v3 migration with no active legacy field/sentinel/dual write, canonical backup v1/v2 → v3 adapters, generation-digest coverage, old unresolved-result recovery, and non-reinterpretation of historical policy versions.
- [ ] Concurrent ingestion of one Share envelope returns exactly one fresh transaction outcome; `alreadyImported`, post-commit refetch failure, background, and expired presentation batches emit no deposit replay.
- [ ] Automated audits plus manual VoiceOver, Voice Control, Switch Control, largest Dynamic Type, Increase Contrast, Differentiate Without Color, Reduce Transparency, and Reduce Motion pass on physical devices.
- [ ] Oldest/current physical iPhones pass p95 native Home/3D readiness, D0/D1 percentile+hitch, main-thread stall, peak-memory, 50-cycle thermal, Low Power Mode, memory-pressure fallback, audio interruption, and background-stop budgets in Release without the debugger.
- [ ] The checked-in deterministic 5,000-Paper fixture remains inside the fixed visible entity/Paper ceilings, and renderer switching at a stable boundary performs zero product-store writes.
- [ ] Product restore preserves the versioned presentation preferences; Erase All resets renderer/Quick/ambience/sound/haptics/last-context/first-animation values plus introduction state.
- [ ] Full independent Store Recovery is usable without constructing the scene; a Retry-only load-failure surface does not close this gate.
- [ ] Airplane-mode and runtime network/privacy inspection cover time-of-day ambience, sound, Share materialization feedback, renderer fallback, backup/restore, and relaunch.
- [ ] The installed signed candidate—not only a preview, simulator, Debug build, or unsigned archive—completes the full renderer/accessibility/device matrix and has approved containment and forward-fix decisions.

This conditional gate is closed only when the packaged scene and every supported fallback preserve the same product truth. A polished model, a smooth simulator recording, or green domain tests cannot substitute for asset, accessibility, performance, interruption, and physical-device evidence.

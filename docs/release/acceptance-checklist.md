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

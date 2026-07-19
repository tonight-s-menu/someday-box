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

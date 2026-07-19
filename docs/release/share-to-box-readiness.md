# Share to Box readiness

Status date: 2026-07-19 (Australia/Melbourne)

This ledger separates source completion from release acceptance. It is not a candidate manifest and does not authorize shipping.

| Milestone | Source status | Evidence available now | Evidence still required |
| --- | --- | --- | --- |
| S1 | Implemented | URL/text compose flow, explicit title/duration, bilingual states, simulator build | Named real-host payload matrix on a physical device |
| S2 | Implemented | Canonical envelope, atomic readback, capacity checks, coordinated mailbox generations, unit interruption-state coverage | Forced termination, protected-data, low-storage, and signed App Group proof |
| S3 | Implemented | Schema v2, Source Reference, idempotent ingestion, source-neutral draw tests | Exact predecessor fixture and visible packaged end-to-end journey |
| S4 | Implemented | Backup v1/v2 round trips, pending-envelope export, shared operation journal, corrupt/future raw recovery | Complete process-interruption and physical-device Files matrix |
| S5 | Locally implemented | Automated accessibility and Dynamic Type tests; static local-only and content-log audits | Manual VoiceOver/Voice Control, Instruments, App Privacy Report, oldest-device timing |
| S6 | Blocked | Unsigned Release archive and structural embedded-extension audit | Signed distribution candidate, two reference iPhones, real hosts, offline/upgrade/containment approval |

## Reproducible local evidence

- `make ci-check` passed with 50 XCTest tests, 9 Swift Testing tests, and 5 UI tests, including the automated accessibility audit.
- `make audit` passed with the app and Share Extension included in the network/API scan and with no production user-content logging surface.
- `xcodebuild archive -project SomedayBox.xcodeproj -scheme SomedayBox -configuration Release -destination 'generic/platform=iOS' -archivePath <path> CODE_SIGNING_ALLOWED=NO` produced a Release archive.
- `make share-package-audit ARCHIVE_PATH=<path>` proved the embedded `ShareExtension.appex`, `com.apple.share-services`, activation dictionary v2, strict matching, URL max 1, text support, and absence of prohibited activation/background declarations.

The unsigned archive explicitly does not prove signed entitlements, installability, real-host payload behavior, physical-device lifecycle, runtime traffic, upgrade behavior, or packaged acceptance. Those rows must remain `not run` or `blocked` in a candidate manifest until immutable evidence exists.

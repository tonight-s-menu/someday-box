# someday-box / 改天盲盒

Native, local-only iPhone app for capturing an idea now and drawing a suitable one later. The product contract is in [docs/product-requirements-and-technical-foundation.md](docs/product-requirements-and-technical-foundation.md).

## Product documents

- [MVP product and technical baseline](docs/product-requirements-and-technical-foundation.md)
- [Share to Box feature specification](docs/features/share-to-box.md) — selected post-MVP feature; S1–S5 implemented with release evidence still open, S6 blocked on a signed physical-device candidate
- [Share to Box readiness ledger](docs/release/share-to-box-readiness.md) — separates local source/test proof from the remaining packaged acceptance gates
- [Share Extension local-mailbox authority decision](docs/adr/0003-share-extension-local-import-mailbox.md) — accepted implementation boundary

The feature specification is a development contract, not current-runtime evidence. The implementation and verification boundaries below describe the repository as it exists today.

## Development setup

The app target is intentionally native: Swift 6, SwiftUI, SwiftData, iOS 18.0, and Apple frameworks only. The pinned production toolchain is Xcode 26.6; before making an archive or submission, refresh the toolchain requirement against Apple's current guidance.

1. Install the full Xcode app (not Command Line Tools) and select it with `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`.
2. Open `SomedayBox.xcodeproj` in Xcode, choose the `SomedayBox` scheme, and run on an iPhone simulator or device running iOS 18 or later.
3. Run `make check`. It always runs the static local-only audit and deterministic host verification; it runs the shared scheme's iOS tests when full Xcode is selected.

There are no environment variables, service credentials, accounts, remote configuration, or third-party runtime dependencies. Do not add network, analytics, CloudKit, or sensitive-device capabilities without an approved product and architecture change.

## Repository boundaries

```text
SwiftUI Features → Application Use Cases → Pure Domain Rules
                                           ↑
                         SwiftData / File / OSLog adapters
```

- `Domain/` is Foundation-only and is independently testable through Swift Package Manager.
- `Application/` defines user-intent use cases and repository protocols.
- `Data/` owns durable-store, backup, migration, and generation-switching adapters.
- `Features/` owns short-lived UI state by user action; it must not write SwiftData directly.
- `Resources/` holds the String Catalog and privacy manifest.

## Current implementation boundary

The repository currently contains:

- Pure domain models, content/invariant validation, deterministic draw policy, and bounded draw-journal compaction.
- Transactional application use cases with a global unresolved-result mutation gate.
- A versioned SwiftData schema, generation bootstrap, domain mapping, repository adapter, and canonical backup format.
- A connected persisted core workflow for capture, relaunch/refetch, draw/reveal, redraw, accept/dismiss, complete, put back, edit, archive/restore, permanent-delete closure, Box browsing, and Memories.
- The Share to Box URL/text extension now publishes atomic local envelopes, the main app ingests them through the product mutation gate, Source References persist in schema v2, and backup v2, coordinated restore/erase, and Shared Capture Recovery are implemented. Signed real-host and physical-device acceptance remain open and are not represented by simulator or unsigned-archive evidence.
- Unit, application, persistence, backup, and launch-test sources in the shared Xcode scheme.

Settings exposes bounded file export, validated full-replacement restore, journaled empty-generation erase, and version/count status. Restore and erase use an independently reopened generation and a durable manifest boundary, but rollback exports, disk-space preflight, and the full forced-termination injection matrix are still open. Source presence and host checks also do not prove the connected workflow in an iOS runtime, accessibility, offline behavior, physical-device behavior, or a signed packaged candidate. Xcode tests, runtime journeys, remaining recovery closure, and packaged acceptance stay open until candidate-specific evidence is recorded in [the release checklist](docs/release/acceptance-checklist.md).

## Commands

| Command | Purpose |
| --- | --- |
| `make audit` | Scan production source and project configuration for prohibited local-only dependencies, APIs, and capabilities. |
| `make test` | Run deterministic domain-policy verification on the host toolchain. |
| `make check` | Run the static audit and host verification, then iOS tests when full Xcode is selected. |
| `make ci-check` | Require full Xcode after the host gates and run the shared scheme's simulator tests. |
| `make xcode-test` | Run unit and UI test actions from the shared scheme. Override `SIMULATOR_DESTINATION` when needed. |

## Current verification boundary

`make audit` proves only that the checked repository source and configuration contain none of its prohibited patterns. It cannot prove runtime network silence, the entitlements embedded in a signed archive, App Privacy Report results, or device behavior.

`make check` is a host convenience command and may skip Xcode tests when full Xcode is unavailable. `make ci-check` is the strict source-and-simulator gate, but it still does not close integration, runtime, offline, accessibility, physical-device, network/privacy runtime, or packaged acceptance. Use the [release manifest template](docs/release/release-manifest-template.md) and keep those evidence levels separate.

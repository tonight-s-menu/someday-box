# someday-box / 改天盲盒

Native, local-only iPhone app for capturing an idea now and drawing a suitable one later. The product contract is in [docs/product-requirements-and-technical-foundation.md](docs/product-requirements-and-technical-foundation.md).

## Development setup

The app target is intentionally native: Swift 6, SwiftUI, SwiftData, iOS 18.0, and Apple frameworks only. The pinned production toolchain is Xcode 26.6; before making an archive or submission, refresh the toolchain requirement against Apple's current guidance.

1. Install the full Xcode app (not Command Line Tools) and select it with `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`.
2. Open `SomedayBox.xcodeproj` in Xcode, choose the `SomedayBox` scheme, and run on an iPhone simulator or device running iOS 18 or later.
3. Run `make check`. It always runs the pure-domain test suite; it runs the iOS tests when full Xcode is selected.

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

The initial app surface is an intentionally thin M0/M1 scaffold. Persistence, capture, and draw workflows must be added through use cases with the acceptance tests defined by the baseline document; no preview-only data path is accepted as product truth.

## Commands

| Command | Purpose |
| --- | --- |
| `make test` | Run deterministic domain-policy verification on the host toolchain. |
| `make check` | Run host checks, then iOS tests when full Xcode is selected. |
| `make ci-check` | Require full Xcode and run the complete test gate. |
| `make xcode-test` | Run the Xcode scheme's unit and UI tests on an iOS simulator. |

## Current verification boundary

This repository has been bootstrapped with the macOS Command Line Tools, which can run the deterministic host verification executable but cannot build or launch an iOS app. `make check` is a local convenience command and may skip iOS tests; `make ci-check` is the strict gate. Full simulator, accessibility, device, offline, archive, privacy-report, backup/restore, and packaged-release evidence remain required before an MVP completion claim.

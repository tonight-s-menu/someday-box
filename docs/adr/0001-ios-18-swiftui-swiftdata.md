# ADR 0001: Native iOS 18 foundation

- Status: Accepted
- Date: 2026-07-19

## Context

The MVP is a local-only, portrait-first iPhone app. It needs accessible native UI, durable on-device product data, no account or server, and an auditable dependency boundary.

## Decision

Use Swift 6, SwiftUI, Observation, SwiftData, Swift Testing, XCTest/XCUIAutomation, Foundation JSON, CryptoKit, OSLog, String Catalogs, and Apple system frameworks only. Set the iOS deployment target to 18.0 and the iPhone device family only. The pinned production toolchain is Xcode 26.6, recorded in `.xcode-version`.

The repository is a modular monolith. SwiftUI features call application use cases; use cases call pure-domain rules through repository protocols; SwiftData, file, and OS adapters implement those protocols. Views do not own persistence rules.

## Consequences

No third-party runtime package, backend, CloudKit, analytics SDK, or network dependency is permitted in this MVP. The toolchain pin must be refreshed before implementation milestones, CI image changes, and every App Store submission. The pure domain target is also exposed as a local Swift Package so boundary tests run even when a machine lacks full Xcode.

# Release manifest

Copy this file to `docs/release/manifests/<version>-<build>.md` for a release candidate. Replace every `REQUIRED` value and attach immutable evidence links before approval. A completed manifest records evidence; it does not create evidence.

## Candidate identity

| Field | Value |
| --- | --- |
| Marketing version | `REQUIRED` |
| Build number | `REQUIRED` |
| Commit SHA | `REQUIRED` |
| Immutable release tag | `REQUIRED` |
| Archive checksum | `REQUIRED` |
| Candidate owner | `REQUIRED` |
| Test window, UTC | `REQUIRED` |

## Toolchain and platform

| Field | Value |
| --- | --- |
| Xcode version and build | `REQUIRED` |
| Swift version | `REQUIRED` |
| iOS SDK version | `REQUIRED` |
| Minimum iOS version | `18.0` — verify against archive |
| Oldest reference device and OS | `REQUIRED` |
| Current reference device and OS | `REQUIRED` |

## Frozen product-data contracts

Values below describe the current source contract and must be checked against the candidate commit rather than copied blindly.

| Contract | Candidate value |
| --- | --- |
| SwiftData schema | `1.0.0` — verify |
| Backup format / canonicalization | `1 / 1` — verify |
| Backup canonical byte limit | `134,217,728` — verify |
| Backup item / Current Pick limits | `5,000 / 1` — verify |
| Backup Session / Attempt / Memory limits | `10,000 / 50,000 / 5,000` — verify |
| Selection policy | `mvp-v1` — verify |
| Draw-journal retention policy | `draw-journal-v1` — verify |
| Retained ended Sessions / resolved Attempts | `1,000 / 25,000` — verify |
| Store-generation manifest | `1` — verify |
| Supported recovery journal phases | `REQUIRED` |
| Production feature flags | `none`, or list owner/default/introduction/removal versions |
| Oldest readable data version | `REQUIRED` |
| Migration fixture versions | `REQUIRED` |

## Evidence ledger

Use only `pass`, `fail`, `blocked`, or `not run`. A lower evidence level never substitutes for a higher one.

| Evidence level | Status | Command or procedure | Immutable artifact |
| --- | --- | --- | --- |
| Static local-only audit | `not run` | `make audit` | `REQUIRED` |
| Unit | `not run` | Xcode scheme unit action | `REQUIRED` |
| Integration | `not run` | Disk persistence, migration, backup, restore, deletion suites | `REQUIRED` |
| Local runtime | `not run` | Simulator/device persisted core journey | `REQUIRED` |
| Offline | `not run` | Airplane-mode cold launch and full core journey | `REQUIRED` |
| Accessibility | `not run` | Automated audit plus manual assistive-technology matrix | `REQUIRED` |
| Physical device | `not run` | Oldest and current reference devices | `REQUIRED` |
| Network/privacy runtime | `not run` | Instruments and App Privacy Report | `REQUIRED` |
| Packaged | `not run` | Signed Release/TestFlight journey | `REQUIRED` |

## Known limitations and exceptions

- `REQUIRED`

Every exception must name its owner, user impact, rollback or containment, approval, and removal target. An unreviewed exception is a failed gate.

## Approval

| Role | Name | Decision | Timestamp |
| --- | --- | --- | --- |
| Engineering | `REQUIRED` | `REQUIRED` | `REQUIRED` |
| Product | `REQUIRED` | `REQUIRED` | `REQUIRED` |
| Release owner | `REQUIRED` | `REQUIRED` | `REQUIRED` |

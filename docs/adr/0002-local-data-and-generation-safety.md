# ADR 0002: Local data is authoritative and generation-safe

- Status: Accepted
- Date: 2026-07-19
- Last implementation review: 2026-07-19

## Context

Papers, Current Pick, draw attempts, and memories are personal product truth. A restore or future migration must never partially replace active data.

## Decision

Keep authoritative product records in an on-device SwiftData store behind repository interfaces. `UserDefaults` may hold only non-authoritative presentation preferences. Use a versioned schema, independent staging generations, a checksummed active-generation manifest, an operation journal, fresh-container validation, and an explicit recovery path for migration, restore, and erase.

Exports are versioned `.somedaybox` JSON documents. Restore is full replacement after preflight, validation, preview, and confirmation; merge is out of scope.

An embedded extension may not become a second writer of the authoritative product store. [ADR 0003](0003-share-extension-local-import-mailbox.md) permits a dedicated App Group capture mailbox for Share to Box while keeping SwiftData generations app-owned.

## Consequences

The repository now contains the versioned SwiftData store, generation manifest/bootstrap, operation journal, validated full-replacement restore path, and journaled empty-generation erase described by this decision. Their source presence does not prove every runtime or release claim: rollback-export creation, disk-space preflight, the complete interruption-injection matrix, physical-device recovery, and packaged acceptance remain open until candidate-specific evidence closes them.

Any schema change must include its migration fixture and tests in the same commit. Generation switching, compaction, restore, and erase stay behind application use cases and must prove the rollback/commit boundary described in the product baseline. README and the release checklist are the current implementation and evidence boundary when this ADR's architectural intent is broader than shipped proof.

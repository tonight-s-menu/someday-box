# ADR 0002: Local data is authoritative and generation-safe

- Status: Accepted
- Date: 2026-07-19

## Context

Papers, Current Pick, draw attempts, and memories are personal product truth. A restore or future migration must never partially replace active data.

## Decision

Keep authoritative product records in an on-device SwiftData store behind repository interfaces. `UserDefaults` may hold only non-authoritative presentation preferences. Before the first public migration or restore feature, add the document's versioned schema, independent staging generation, active-generation manifest, operation journal, fresh-container validation, and explicit recovery path.

Exports are versioned `.somedaybox` JSON documents. Restore is full replacement after preflight, validation, preview, and confirmation; merge is out of scope.

## Consequences

The current scaffold does not claim persistence implementation. Any schema change must include its migration fixture and tests in the same commit. Generation switching, compaction, restore, and erase must stay behind application use cases and prove the rollback/commit boundary described in the product baseline.

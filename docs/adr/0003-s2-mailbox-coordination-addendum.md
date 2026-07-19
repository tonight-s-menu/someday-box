# ADR 0003 S2 addendum: mailbox coordination and publication

- Status: Accepted for S2 implementation
- Date: 2026-07-19
- Parent decision: [ADR 0003](0003-share-extension-local-import-mailbox.md)

## Decision

S2 uses Foundation `NSFileCoordinator` alone. There is no POSIX advisory lock. Every short mailbox mutation coordinates the `ShareMailbox` root directory, which serializes the directory-level manifest, generation, incoming-file, temporary-file, and quarantine mutations needed by this release. A coordination anchor exists only as a fixed, content-free coordination URL for future maintenance diagnostics; it is never interpreted as a lock or liveness proof.

The only acquisition order is:

1. product operation journal, when a containing-app maintenance operation requires it;
2. mailbox root directory through `NSFileCoordinator`;
3. active-generation directory mutation;
4. individual final envelope file readback.

Extension save does not acquire the product journal. It coordinates only the mailbox root. Ingestion, export, restore, and erase must acquire the product journal before the mailbox root and must not wait for user interaction while either resource is held.

## Publication protocol

The writer coordinates the mailbox root, validates or creates an idle v1 manifest and active generation, rechecks count and byte limits, writes a complete UUID-named temporary file, applies Complete data protection, atomically moves it to `{envelope-id}.capture`, then reopens and validates the final bytes before returning success. The manifest is written through the same temporary-and-rename protocol before its active generation is used.

The writer does not overwrite a final envelope. A pre-existing final name is an idempotent success only when its decoded envelope exactly equals the candidate; otherwise it fails closed. Temporary files are ignored by readers and may be removed only when their UUID and `.tmp` suffix prove they are writer-owned incomplete artifacts.

## Cancellation, process death, and protected data

Each extension invocation owns a UUID token. A cancelled or expired invocation invalidates that token before it releases UI ownership. A late accessor may remove only its own temporary file; it may not publish, alter the manifest, or report success. No fixed timeout is attributed to `NSFileCoordinator`; the UI watchdog is an invocation-state concern, not a claim that a coordinator callback cannot arrive.

If protected data is unavailable before the temporary write, during final move, or during final readback, the operation fails as unsaved and leaves no final success claim. Process termination before final move leaves no final envelope; termination after move leaves a complete replayable envelope. A leftover anchor or temporary file is never evidence of a held lock or saved capture.

## Frozen URLs and limits

All paths are derived from the App Group root and generated UUIDs only:

```text
ShareMailbox/
  coordination-anchor
  manifest-v1.json
  generations/{generation-id}/incoming/{envelope-id}.capture
  generations/{generation-id}/temporary/{temporary-id}.tmp
  generations/{generation-id}/quarantine/
```

S2 enforces 256 final incoming envelopes, 4 MiB aggregate final bytes, 64 temporary files, and 1 MiB aggregate temporary bytes. A full mailbox fails recoverably and never evicts a final or quarantined capture.

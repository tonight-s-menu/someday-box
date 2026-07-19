# ADR 0003: Share Extension uses a local import mailbox

- Status: Accepted for Share to Box implementation
- Implementation status: In progress — S1 payload shell and S2 mailbox foundation present; milestone exit evidence remains open
- Date: 2026-07-19
- Feature contract: [Share to Box](../features/share-to-box.md)

## Context

Share to Box must accept a URL or plain text from another iOS app, persist the user-confirmed capture without a server, and later expose it as an ordinary Paper.

A Share Extension and its containing app run as separate processes with separate containers. The current product data path is deliberately single-writer: application use cases pass through MutationArbiter, SwiftData lives in an app-owned active generation, and migration, restore, and erase are coordinated by the product operation journal. Direct extension access to that store would bypass or duplicate those authority boundaries.

The feature also needs a truthful interruption contract. The system may terminate an extension shortly after it completes, and the containing app usually is not running. A successful share therefore cannot depend on an in-memory callback to the app.

## Decision

Add one dedicated App Group shared by the containing app and the Share Extension. Use it only for a bounded, versioned Share Capture mailbox and the minimum content-free coordination metadata required to operate that mailbox.

The Share Extension:

- reads the system-provided extension context;
- validates one URL/text capture;
- requires a user-confirmed title and duration;
- writes one canonical, checksummed envelope through coordinated atomic file publication;
- completes the extension request only after final-file readback succeeds;
- never opens or writes the product ModelContainer, generation manifest, backup, or product operation journal.

The containing app:

- remains the only writer of authoritative SwiftData product records;
- ingests envelopes through existing application and mutation boundaries;
- transactionally creates one Box Item and one Source Reference;
- uses the envelope UUID stored on Source Reference as the idempotency key for the active envelope-to-cleanup retry window;
- removes the envelope only after product commit;
- reconciles mailbox data before presenting Home, Box, or Draw truth.

SwiftData remains in the containing app’s private generation directories with CloudKit disabled and no SwiftData group container. The App Group is transport, not the product database.

## Authority table

| Concern | Authority |
| --- | --- |
| Host payload representations | The system extension context |
| Unsaved compose fields | Share Extension process memory |
| Accepted capture awaiting ingestion | Active App Group mailbox generation |
| Paper, lifecycle, duration, Current Pick, draw, and Memory | App-owned SwiftData active generation |
| Cross-record mutation | Containing-app application use case and MutationArbiter |
| Store migration/restore/erase | Product operation journal |
| Mailbox switch/cleanup during restore or erase | Product operation journal plus cross-process mailbox coordination |
| Platform label | Local deterministic presentation derived from accepted URL host |

## Shared-file coordination

Mailbox access requires Foundation file coordination, atomic publication, app-owned UUID paths, and a shared acquisition order. A writer publishes a temporary file only after complete bounded encoding, then atomically replaces or moves it to its final name and verifies the final bytes. Readers ignore temporary files.

This ADR freezes required properties and authority, not the final coordination primitive. Before the S2 mailbox milestone begins, an accepted implementation addendum must name whether NSFileCoordinator is used alone or with a POSIX advisory lock, every coordinated URL, acquisition order, process-death release behavior, cancellation/watchdog token semantics, late-accessor rejection, directory/manifest replacement order, and protected-data-unavailable behavior. A leftover anchor file never proves that a process still owns a lock.

Long product transactions do not run inside the extension. NSFileCoordinator does not provide a caller-selected fixed deadline, so a cancelled UI invalidates the invocation token and ignores late accessors rather than assuming cancellation prevents a callback. Restore and erase record every store and mailbox generation target before changing an authority pointer, so interruption recovery never guesses a cleanup path.

Complete file protection applies to shared capture files. A protection, storage, or coordination failure is reported as unsaved unless the final envelope crossed the atomic-publication and readback boundary. That boundary proves recovery after host/extension process termination; it is not an absolute hardware power-loss guarantee.

## Data and operation consequences

- The local-only claim changes from “app sandbox only” to “the app and its dedicated App Group containers on this device.”
- App Group membership is a reviewed exception to the original MVP capability allowlist; it does not permit CloudKit, networking, Background Modes, analytics, or broader shared storage.
- Share Capture Envelope, mailbox manifest, Source Reference, SwiftData schema, and backup format receive independent versions.
- Full backup includes valid published envelopes visible at its explicit mailbox snapshot cutoff; a later share remains on the device for the next export.
- Restore and Erase All coordinate both the store generation and mailbox generation.
- Corrupt or future envelopes are quarantined, never silently deleted or rewritten.
- A feature-off containment build may stop new share writes, but it must retain supported ingestion, export, source removal, and erase behavior until the public compatibility window closes.
- App and extension targets require signed-entitlement, airplane-mode, privacy-report, extension-lifecycle, and packaged-host evidence.

## Rejected alternatives

### Let the extension write the product SwiftData store

Rejected because it introduces a second process writer around app-only transaction, generation, Current Pick, unresolved-result, restore, and capacity rules. Actor isolation in the containing app does not coordinate another process.

### Move authoritative SwiftData into the App Group

Rejected for this feature. SwiftData can be configured for a group container, but doing so would expand the trust, migration, concurrency, backup, and rollback surface without improving the short capture task.

### Use shared UserDefaults for Paper payloads

Rejected because user content is authoritative structured data, not a preference. Shared defaults do not provide the required envelope bounds, corruption validation, idempotent lifecycle, or recovery evidence.

### Open the containing app to finish every share

Rejected because a Share Extension cannot depend on direct communication with or automatic launch of its containing app, and doing so would restore the interruption that the feature is meant to remove.

### Fetch remote metadata before saving

Rejected because it violates the no-product-network contract, makes host/network availability part of capture success, and creates a false promise of semantic extraction.

## Revisit triggers

Revisit this decision only if:

- Apple changes the extension or shared-container execution model;
- an approved attachment feature needs a separately bounded asset pipeline;
- measured mailbox coordination cannot meet the oldest-device acceptance envelope; or
- the product deliberately adopts a new cross-target authoritative-store architecture through a replacement ADR.

A revisit must preserve old envelope readability and include migration, rollback, privacy, and packaged evidence. It may not turn a temporary fallback into an indefinite second write path.

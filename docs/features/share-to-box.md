# Share to Box

## Product requirements, functional translation, and development contract

| Field | Decision |
| --- | --- |
| Document status | Selected post-MVP feature; S1–S5 implemented with release evidence open, S6 blocked on signed packaged acceptance |
| Parent product contract | [Product requirements and technical foundation](../product-requirements-and-technical-foundation.md) |
| vNext presentation contract | [Core Box Living Experience Upgrade](../core-box-living-experience-upgrade.md) |
| vNext integration status | Transaction-derived fresh/imported outcome and post-commit refetch reconciliation are open Core Box C6 prerequisites; not part of the current S1–S5 implementation claim |
| Product | someday-box / 改天盲盒 |
| System-facing name | Add to someday-box / 放进改天盲盒 |
| Feature-facing name | Share to Box |
| Primary platform | iPhone on iOS 18 or later |
| First release payloads | One logical capture containing an HTTP(S) URL, plain text, or both |
| Runtime boundary | Fully on-device; no account, server, sync, analytics, ads, webpage fetch, or LLM |
| Languages | Simplified Chinese and English |
| Last reviewed | 2026-07-19 |

This document translates the cross-platform sharing idea into an implementation-oriented feature contract. It resolves the gap between a compelling product story and what an iOS Share Extension can truthfully receive, persist, and prove. It contains no implementation code and does not claim that the complete feature has passed release acceptance. S1–S5 are implemented in source and pass the locally executable automated gates. Real-host, signed-entitlement, physical-device, manual assistive-technology, performance, interruption, privacy-report, and immediate-predecessor evidence remains open. S6 therefore remains blocked even though an unsigned Release archive passes the structural package audit.

The parent product contract remains authoritative for Paper lifecycle, duration, drawing, Current Pick, Memories, backup safety, accessibility, and low-pressure language. The vNext Core Box contract owns only the main-app presentation that may occur after a shared capture has become committed product truth. This document owns Share Extension payload, publication, mailbox, main-app materialization, Source Reference, and recovery behavior. The explicitly labeled vNext/C6 additions below are future requirements and do not retroactively claim that the current S1–S5 source already returns those outcomes. If the documents appear to conflict, the stricter privacy, data-integrity, transport-truth, and user-visible-truth rule applies until the conflict is explicitly resolved.

---

## 1. Executive decision

Share to Box lets a person send an idea from another app into someday-box through the iOS share sheet. The feature is source-app independent: Xiaohongshu, Instagram, TikTok, YouTube, Google Maps, Apple Maps, Safari, and other apps are compatibility hosts, not product integrations.

The feature consumes only the payload that the host app deliberately gives to the system share request. It does not:

- sign in to another service;
- inspect an account or saved-items collection;
- monitor the clipboard or another app in the background;
- fetch a webpage, expand a short link, download a thumbnail, or validate a venue;
- infer category, place, duration, cost, weather, availability, or intent;
- use an LLM, embedding model, classifier, OCR pipeline, or remote metadata service.

The first release keeps the existing Paper truth intact:

> A shared idea becomes a drawable Paper only after the person confirms a valid title and explicitly selects a duration.

There is no default duration and no hidden confidence score. A share request that has not reached the local publication boundary is not reported as saved. The containing app ingests every capture at or before its foreground mailbox watermark before opening Home, Box, or a new Draw; an existing Unresolved Draw Attempt and explicit recovery surfaces remain higher-priority gates.

### 1.1 Product value

Platform-native saves preserve content inside the platform where it was found. Share to Box converts a passing interest into a future life option:

    See something interesting
        → Share
        → Add to someday-box
        → Confirm title and duration
        → Rediscover it in a later draw

The value is not better bookmarking. It is closing the distance between “I might like this” and “I have time for something now.”

### 1.2 One-line descriptions

**English**

> Turn a link or a piece of shared text into a Paper without leaving what you are browsing.

**Simplified Chinese**

> 把别处看到的链接或文字直接变成一张纸条，留到真正有空时再抽出来。

### 1.3 Product copy boundary

The share-sheet action may be named **Add to someday-box / 放进改天盲盒**. Inside the app, the capability is **Share to Box**.

Recommended explanatory copy:

> When you find something you may want to try later, share it to someday-box. Confirm a title and time, and it will be ready for a future draw.

Do not promise “smart extraction,” “automatic planning,” “we found this place,” or “works with every post.” Those phrases exceed the payload and inference contract.

---

## 2. User problem and jobs to be done

### 2.1 The current friction

Without this feature, a person must:

1. copy a link or remember an idea;
2. leave the source app;
3. open someday-box;
4. recreate the idea;
5. return to what they were doing.

That interruption is large relative to the value of a passing idea, so capture is often abandoned or left in a platform-specific save list.

### 2.2 Primary jobs

When I find something interesting in another app, I want to put it into someday-box in a few seconds, so I do not lose the idea or break my browsing flow.

When I later see the Paper, I want its original link to remain available, so I can return to the source without someday-box copying or impersonating that service.

When the source app shares only a link or plain text, I want the feature to stay useful and honest, so a missing thumbnail, author, address, or title never becomes a failure or a fabricated value.

### 2.3 Emotional requirement

The interaction should feel like slipping a note into a box, not triaging an inbox. It must not create a second backlog, a red review count, an overdue state, or pressure to organize imported content.

### 2.4 Success outcomes

The feature succeeds when:

- a normal URL or text share can be confirmed with a title and one duration tap;
- the extension dismisses only after the capture envelope crosses the local atomic-publication and readback boundary;
- the containing app materializes exactly one ordinary Paper and one structured source reference;
- that Paper follows the same lifecycle and draw rules as a manually captured Paper;
- the original HTTP(S) URL, when present, can be opened through an explicit user action;
- given the same representations already delivered by a host, airplane mode does not change someday-box parsing, publication, ingestion, browsing, draw, or deletion behavior;
- cancellation, validation failure, low storage, capacity, interruption, and replay of the same published envelope identifier during its active retry window do not create a partial or duplicate Paper.

When a host already supplies a usable title, at least 80% of moderated first-time participants should complete the flow within 10 seconds using one duration tap and one save tap, without help. Success adds no Done button; the brief confirmation closes automatically.

The app contains no production analytics. Product-value evidence comes from moderated usability sessions, opt-in user feedback outside the runtime, and candidate-specific test artifacts rather than hidden event collection.

### 2.5 Scenario translation

The feature supports many kinds of life inspiration without turning them into semantic categories:

| Scenario | Host-delivered input | Person confirms | Resulting Paper | Not generated |
| --- | --- | --- | --- | --- |
| Xiaohongshu restaurant post | URL and possibly share text | Actionable title, duration, optional note | Ordinary Paper plus source link | Restaurant type, address, price, booking, thumbnail |
| Google or Apple Maps place | URL and possibly place title | What they want to do, duration | Ordinary Paper plus source link | Travel time, distance, opening hours, current location |
| YouTube recipe/tutorial | URL and possibly video title | Actionable title, duration, optional note | Ordinary Paper plus source link | Recipe extraction, ingredients, skill level, automatic time estimate |
| Plain-text event or activity | Plain text | Short title, duration, optional note | Ordinary Paper with text-share provenance | Deadline, expiry alert, semantic event type |

The Paper may still describe a restaurant, place, tutorial, activity, film, or shopping idea in human language. “No automatic category” means the app does not convert that meaning into hidden fields or draw behavior; it does not mean those ideas are unsupported.

### 2.6 Original-idea decision ledger

| Concept input | P0 translation | Decision reason |
| --- | --- | --- |
| Share from named social/maps/browser apps | One source-app-independent iOS Share Extension | Host payload is the contract; no platform SDK or account access |
| One-tap quick save | Compact title plus one explicit duration tap | Duration truth cannot be defaulted or guessed |
| Save without opening the full app | Publish a local envelope, then ingest on next app foreground | Preserves the browsing flow without a second SwiftData writer |
| Preserve source context | Structured accepted URL, capture time, and deterministic host label | Keeps provenance without copying the external page |
| Thumbnail, author, address, place data | Not in P0 | Usually absent from host payload and would require attachment/network/semantic scope |
| Imported Inbox or Needs Review | Rejected | Creates a second backlog and allows incomplete non-drawable content to accumulate |
| Category, location, cost, reservation, weather, expiry | Rejected for P0 | Breaks the time-only, low-friction, low-pressure product contract |
| Duplicate detection and merging | New invocation may create another Paper; same envelope replay is idempotent | Similarity is ambiguous and automatic merge can destroy intent |
| Image share | Follow-up only after a separate attachment contract | Requires bounded decoding, asset backup, restore, and deletion closure |
| LLM enrichment | Rejected, not a roadmap item | Violates the permanent local no-LLM boundary |

---

## 3. Guardrails and permanent non-goals

### 3.1 Existing product contracts remain unchanged

- A title and explicit supported duration are required before a shared capture can become a Paper.
- Time remains the only draw context.
- Source platform, URL host, and shared text never alter eligibility or weighting.
- Duplicate titles remain valid.
- Current Pick, unresolved-result reservation, lifecycle, Memory, capacity, and mutation-gate rules apply without a share-specific exception.
- A Paper is a possibility, not a task.

### 3.2 No Imported Inbox

The first release has no Imported Inbox, Needs Review list, or fourth root tab. The extension itself collects the minimum honest fields. If the person is not ready to choose a duration, they cancel; nothing is silently placed into a hidden backlog.

An internal transport envelope may wait durably until the next successful containing-app ingestion, including when the app is not opened for days or weeks. That is an implementation state, not a user-managed product state and not a second source of Paper truth.

### 3.3 No automatic semantic enrichment

The first release does not add:

- restaurant, attraction, video, activity, shopping, or other semantic categories;
- location, address, price, reservation, weather, company, preparation, or energy fields;
- event deadlines, end dates, alerts, expiring badges, or pressure notifications;
- automatic title rewriting, next-action generation, or duration estimation;
- confidence labels or looser drawing rules for incomplete metadata.

A person may write relevant context in the existing note. The app does not turn that text into hidden structured behavior.

### 3.4 No LLM roadmap

LLMs, embeddings, cloud inference, and local generative models are permanent non-goals for this feature and are not a “later phase” in this document. Introducing any such capability would require a separate product decision and a replacement privacy and architecture contract; it cannot appear as an enhancement, experiment, fallback, or implementation shortcut.

### 3.5 No platform-account integration

The feature does not use source-platform SDKs, OAuth, cookies, private APIs, scraping, or batch import. Platform names describe tested share-sheet hosts only. The host controls whether a share action is available and which representations it supplies.

### 3.6 No attachment scope in the first release

Images, video, audio, files, live photos, and thumbnails are not accepted by the first release. Attachment support requires a separate contract for decoding, file protection, size limits, backup packaging, restore, deletion closure, memory pressure, and physical-device testing.

Image-only sharing may be considered after URL/text packaged acceptance, but it must not be enabled in the production activation rule before that contract is implemented and verified.

---

## 4. Release scope

### 4.1 P0 for the first Share to Box release

| Capability | Decision |
| --- | --- |
| iOS extension | One embedded Share Extension target |
| Accepted payload | One logical URL, plain-text value, or URL-plus-text capture |
| URL scheme | HTTP and HTTPS only |
| Compose surface | Editable title, all duration choices, optional note, read-only source summary |
| Save | One explicit Save for the Box action |
| Local transport | Versioned, checksummed capture envelope in a dedicated App Group mailbox |
| Product ingestion | Containing app validates and transactionally creates one Paper plus one source reference |
| Source detail | Display source label/host and capture date; open or remove the source |
| Drawing | Same duration and lifecycle rules as manual capture |
| Data lifecycle | Schema migration, backup/restore, erase, source deletion, and mailbox cleanup |
| Privacy | No app-initiated network request in either binary |
| Quality | Bilingual, Dark Mode, Dynamic Type, VoiceOver, Voice Control, Reduce Motion |
| Release | Real-host, interruption, offline, signed-extension, and packaged-device evidence |

### 4.2 Follow-up candidates

These are not part of P0 and require evidence before selection:

| Candidate | Required evidence and contract |
| --- | --- |
| One user-shared image preview | URL/text feature is stable; attachment storage, backup package, decoding limits, and deletion closure are approved |
| Exact-URL duplicate advisory | Repeated exact links cause visible clutter; Keep both remains available |
| Multiple source references per Paper | Users deliberately save the same intention from several sources and need manual aggregation |
| Additional manual context fields | Time-only draws repeatedly fail for a stable reason and people accept the extra capture cost |

Fuzzy title matching, automatic merging, image similarity, and semantic duplicate detection remain out of scope.

---

## 5. Payload and compatibility contract

### 5.1 Activation rule

The extension point identifier is **com.apple.share-services**. The production extension uses the standard activation dictionary with:

- activation dictionary version 2;
- strict matching enabled;
- web URL maximum count 1;
- text support enabled.

Version 2 permits the extension to appear when an item provider offers at least one supported representation, even if it also advertises an image or another representation that P0 ignores. The standard dictionary cannot prove that a request contains exactly one NSExtensionItem, limit text to one representation, or use attributedTitle/attributedContentText as activation truth. Runtime validation therefore remains mandatory.

P0 processes at most one unambiguous logical URL/text capture. It rejects an ambiguous multi-item request without partially selecting content. The activation rule does not advertise image, movie, file, webpage preprocessing, or arbitrary attachment support, and it must never ship with TRUEPREDICATE.

### 5.2 Payload matrix

| Host-provided payload | P0 behavior |
| --- | --- |
| URL plus text/title | Keep the accepted HTTP(S) URL serialization; derive an editable title candidate from host text |
| URL only | Keep the accepted URL serialization; show its host in Source and require the person to enter a Paper title |
| Plain text only | Derive an editable title candidate; allow the visible remainder to be used as the note |
| Text containing an HTTP(S) URL | Detect the first valid URL locally and show that exact choice before save |
| Several distinct URLs in one text representation | Use the first deterministic HTTP(S) substring and disclose that only the first link is retained |
| Several input items or ambiguous provider groups | Reject the request and ask the person to share one item at a time |
| Custom-scheme, file, data, or JavaScript URL | Do not make it openable; retain usable plain text when present or show unsupported content |
| Image, video, audio, or file only | Extension is not offered by the P0 activation rule; fail safely if a host violates the declaration |
| Empty or unavailable provider | Show that the content could not be read and permit Cancel/Retry |
| Provider load timeout or error | Keep any independently loaded valid representation; never invent the missing value |

### 5.3 Compatibility tiers

The feature reports compatibility by observed payload, not by brand:

- **Verified:** a named host and version supplied a usable URL/text payload in a packaged physical-device test.
- **Partial:** the host supplied only a URL or only text; capture still completed with the documented fallback.
- **Unavailable:** the host did not expose a supported representation or did not show the extension.
- **Unknown:** not tested for the candidate.

Xiaohongshu, Instagram, TikTok, YouTube, Google Maps, Apple Maps, and Safari belong in the release test matrix. They are not stable API promises. A platform update may change what it shares without a someday-box code change.

### 5.4 Input trust

Every host value is untrusted input.

- Resolve only supported Uniform Type Identifiers.
- Load no more than one logical capture.
- Reject unsupported control characters using the same content rules as manual capture.
- For a detected text URL, preserve the accepted substring. For a URL object, preserve the absoluteString received by the extension. The product does not subsequently strip parameters, expand redirects, or rewrite that accepted serialization.
- Validate scheme, parseability, byte bounds, and display safety before enabling Open Original.
- Never use a host-provided filename, path, identifier, or URL component as a local filesystem path.
- Never execute HTML, JavaScript, rich text attachments, or webpage preprocessing output.
- Never read the pasteboard as a fallback.

### 5.5 Bounded values

P0 freezes these feature-specific transport limits:

| Resource | Limit |
| --- | ---: |
| Logical captures per extension invocation | 1 |
| Queued capture envelopes | 256 |
| Canonical encoded envelope | 16 KiB |
| Accepted URL serialization | 4,096 UTF-8 bytes |
| Host plain text accepted after provider delivery | 32 KiB |
| Source-kind raw value | 64 UTF-8 bytes |
| Source References | 5,000 and never more than Box Items |
| Active incoming envelope bytes | 4 MiB total |
| Quarantine | 256 files and 4 MiB total |
| Temporary mailbox files | 64 files and 1 MiB total |
| Whole mailbox generation | 10 MiB total |
| Raw mailbox recovery export | 10 MiB |
| Authoritative product graph v2 canonical payload | 144 MiB (150,994,944 bytes) |
| Backup format v2 canonical file | 152 MiB (159,383,552 bytes) |

Paper title and note continue to use the parent contract: title is at most 120 user-perceived characters and 512 UTF-8 bytes; note is at most 1,000 user-perceived characters and 4,096 UTF-8 bytes.

An NSItemProvider may materialize a complete text object before the extension can inspect its size. The 32 KiB value is therefore an acceptance/parsing boundary, not a pre-allocation or host-memory guarantee. After delivery, over-limit text is excluded with an explanation and is never silently truncated into product data. The person may still save an independently loaded valid URL with a manually entered title.

Automatic cleanup removes only proven incomplete temporary files that are not operation-journal targets. It never evicts a final incoming or quarantined capture to create capacity. At a limit, a new save fails recoverably; recovery export plus explicit user removal is the only path that releases quarantined user data.

The containing app enforces the 144 MiB product-graph budget before every growing product mutation. The extension independently enforces the 4 MiB final incoming budget. Backup v2 reserves the remaining 8 MiB for the maximum incoming set plus envelope/metadata overhead and still performs an exact 152 MiB encoded-size check. Ingestion that would exceed the product-graph budget retains the envelope in Shared Capture Recovery. This split avoids relying on a stale cross-process Box-count snapshot while keeping every valid non-quarantined state exportable.

Raising a frozen limit requires a new readable envelope version plus oldest-device memory, duration, backup, and round-trip evidence.

### 5.6 Provider concurrency and request lifetime

Payload selection is deterministic by input-item, attachment, provider, and representation priority; asynchronous callback completion order never chooses the winning value.

- Retain the Progress returned by provider loads when available. Cancellation is advisory and does not prove a callback cannot arrive.
- Assign every extension invocation a state-generation token. A callback whose token is no longer current may release local values but cannot update UI, change the draft, or publish an envelope.
- Move all visible state transitions to MainActor; provider work may complete on internal queues.
- Cancel remains available while Receiving, Ready, LoadFailed, SaveFailed, and while waiting to enter the publication critical section.
- Once final publication begins, the short critical section is not presented as cancellable. If cancel races publication, the state token records exactly one outcome: either no final envelope and Cancelled, or a published envelope and Saved.
- After cancelRequest or completeRequest, no callback may write UI or mailbox state.
- If the completion handler reports expiration, stop immediately. Correctness never depends on that handler, onDisappear, deinit, or another cleanup callback running.

---

## 6. Deterministic local extraction

### 6.1 Extraction is assistance, not inference

The extension may prefill editable fields only from representations supplied by the host. Prefill output is never treated as verified place, category, author, duration, or action intent.

### 6.2 URL selection

Use this order:

1. an explicit HTTP(S) URL representation supplied by the item provider;
2. otherwise, the first HTTP(S) URL found in supplied plain text by a local deterministic detector;
3. otherwise, no source URL.

Equivalent representations of the same URL are collapsed within the single request. Distinct links are not merged, expanded, followed, or compared semantically.

### 6.3 Title candidate

Use the first valid candidate in this order:

1. a host-supplied attributed title converted to plain text;
2. the first non-empty line of supplied plain text after removing a standalone selected URL;
3. otherwise, an empty title field with a localized action-oriented placeholder that the person must complete.

Candidate generation may trim surrounding whitespace. It must not:

- paraphrase or translate;
- add an action verb such as “Visit” or “Try” to host content;
- claim a venue, address, category, or author;
- silently truncate invalid content and present the result as complete.

If a candidate exceeds the Paper bounds, it is not inserted into the Title field. Title remains empty and focused, while a bounded, clearly labeled read-only preview helps the person write a shorter name. Visual preview truncation is presentation-only and disclosed; it is never persisted as a hidden or silently shortened source value.

### 6.4 Note behavior

The note remains optional and visible only after disclosure.

- URL-plus-text: do not silently copy promotional share text into the note.
- Text-only: the person may explicitly use the remaining shared text as the note only when it already fits the note contract.
- Existing note validation applies before commit.
- The raw host text is not retained as a hidden second copy after the person confirms the Paper.

### 6.5 Source label

The detail surface may map a known URL host to a localized platform hint through a versioned, deterministic table. Matching uses an exact approved host or an explicit subdomain boundary, never substring containment. User-facing copy says **Link from instagram.com / 来源链接：instagram.com**, not “Shared from Instagram,” because the URL host does not prove which host app initiated the share. Unknown hosts display the host itself or “Shared link.” A hint is presentation only and never a claim that the platform endorsed or integrated with someday-box.

Short-link hosts remain short-link hosts unless the person later opens the link. The app does not resolve them in the background.

---

## 7. Share Extension experience

### 7.1 Compact layout

The extension presents one restrained compose card:

    Add to someday-box

    Title
    [ editable title candidate                         ]

    Source
    [ Link from instagram.com ]  [ Remove link ]

    How long might it take?
    [10m] [30m] [1h] [2h] [4h] [8h]

    [ Add a note ]

    Cancel                         Save for the Box

All duration choices remain visible without opening another screen. No category picker, tag editor, image carousel, settings mode, or full Box browser appears inside the extension.

### 7.2 Interaction rules

- Keyboard focus begins in Title only when the candidate is empty or invalid.
- No duration is preselected, including the last-used duration.
- Save for the Box is enabled only when draft-local title, duration, optional note, any retained accepted URL, and projected envelope size validate.
- A mailbox-capacity preflight may show a hint, but the writer rechecks capacity inside the publication critical section; a racing full mailbox becomes SaveFailed without replacing an older capture.
- The source row shows only information actually available. A low-emphasis Remove link action immediately changes the draft to “No link will be saved” without changing title or note.
- Cancel accepted before final publication writes no final envelope. Once final publication begins, the UI resolves the race to Saved or Cancelled and never reports Cancelled while a final envelope exists.
- Repeated taps while saving have no additional effect.
- The extension does not attempt to open the containing app after save.
- The extension calls the system completion API only after atomic envelope publication and readback verification.

### 7.3 Success copy

The local truth at extension completion is that a complete capture has been published for later containing-app ingestion. Recommended action and success copy:

> Save for the Box
>
> Saved for your Box. It will wait safely until you next open someday-box.

> 先替我收好
>
> 已替你收好。它会安心等到你下次打开改天盲盒。

The extension must not display a Box count or claim that the authoritative SwiftData transaction has already run.

After the publication boundary, a restrained 150–250 ms paper-drop confirmation may echo the main app’s Box metaphor before dismissal. It never chooses data, delays persistence, or blocks completion. Reduce Motion replaces it with an immediate opacity change and stable checkmark.

### 7.4 Extension UI state machine

~~~mermaid
stateDiagram-v2
    [*] --> Receiving
    Receiving --> Ready: supported payload loaded
    Receiving --> LoadFailed: no usable payload or provider error
    Ready --> Ready: edit title, duration, or note
    Ready --> Saving: valid explicit save
    Saving --> Saved: final publication and readback succeed
    Saving --> Cancelled: cancel wins before final publication
    Saving --> SaveFailed: validation, capacity, storage, or coordination failure
    SaveFailed --> Ready: retry
    LoadFailed --> Receiving: retry
    Receiving --> Cancelled: cancel
    Ready --> Cancelled: cancel
    LoadFailed --> Cancelled: cancel
    SaveFailed --> Cancelled: cancel
    Saved --> [*]: complete extension request
    Cancelled --> [*]: cancel extension request
~~~

The publication boundary is between Saving and Saved. Termination before final publication yields zero final envelopes, although a proven incomplete temporary file may remain for safe cleanup; termination after publication yields one replayable final envelope with the same idempotency identifier.

### 7.5 Accessibility and motion

- Use native controls and semantic headings.
- Focus order is Title, Source, Remove link when present, Duration, Note disclosure/content, Cancel, Save for the Box.
- Every duration chip exposes label, selected state, and button trait.
- Validation errors are announced and associated with the field.
- Largest Dynamic Type keeps required actions reachable by scrolling.
- Voice Control names match visible labels.
- Loading and success never rely on motion or color alone.
- Reduce Motion removes decorative transitions; state and completion remain unchanged.
- The extension uses the containing app icon and localized display name according to system rules.
- The containing app remains iPhone-first, but the extension target and compose layout satisfy Apple’s universal-extension requirements and remain usable in iPad and rotated host presentations.

### 7.6 Performance envelope

- When the host immediately provides a supported representation, the compose surface should become usable in under one second on the oldest supported reference device.
- Provider loading time is measured separately from extension rendering so a slow host is not hidden inside an aggregate success number.
- A normal bounded envelope commit and readback should complete within 500 ms at the 95th percentile on the oldest reference device.
- The extension does not open SwiftData, fetch a webpage, decode an attachment, or scan the existing Box.
- Provider loading and pre-publication coordination remain cancellable. The final publication critical section is short, has one terminal outcome, and never leaves the host waiting indefinitely.

---

## 8. Main-app experience

### 8.1 Ingestion before root product truth is shown

On cold launch and foreground activation, the containing app:

1. reconciles any unfinished store or mailbox operation journal;
2. checks the authoritative store for the existing global Unresolved Draw Attempt;
3. if one exists, resumes that exact reveal flow before any share ingestion or root-tab mutation;
4. after the flow reaches a state with no Unresolved Draw Attempt, enters coordinated mailbox access and records a watermark consisting of mailbox generation plus the sorted final envelope IDs and checksums visible at that instant;
5. validates each envelope and its supported version;
6. ingests valid envelopes through the application mutation boundary;
7. creates one Box Item and one Source Reference atomically;
8. records the envelope identifier on the Source Reference for idempotency;
9. removes the envelope only after the product transaction is committed and refetched;
10. refetches counts and presents Home, Box, or Draw.

The persisted unresolved reveal is the only ordinary product surface allowed ahead of share ingestion. It already reserves its Paper and blocks Capture/edit/lifecycle mutations under the parent contract, so ingestion waits rather than bypassing that gate. Draw another may create the next Unresolved Attempt in the same flow; ingestion still waits until no unresolved result remains.

Home, Box, and a new Draw use product truth after every valid capture at or before the watermark has either been ingested or routed to Shared Capture Recovery. A new envelope published after the watermark belongs to the next foreground or explicit mailbox-change refresh and does not retroactively make the completed snapshot claim false. A failure to ingest one envelope does not corrupt or duplicate other valid captures.

If the containing app has never launched, its normal first-run store bootstrap and introduction remain authoritative. Successful envelopes may be materialized during bootstrap, but no Home/Box snapshot appears before the introduction. User-visible priority is load failure/full Store Recovery when implemented, persisted unresolved reveal, Shared Capture Recovery for a blocked envelope, first-launch introduction, then root tabs. After the introduction, the first Home/Box snapshot already includes every successfully ingested share; no sample or placeholder Paper substitutes for it.

### 8.2 Materialization rules

A valid envelope becomes:

- one Active Box Item with the confirmed title, note, duration, and containing-app ingestion transaction time for createdAt and updatedAt;
- one Source Reference linked to that item, containing the accepted URL serialization when present, source kind, capture time, and envelope identifier.

Source metadata does not change lifecycle, duration, draw weight, Current Pick, or Memory behavior.

Source Reference capturedAt preserves the extension’s wall-clock value for approximate display only. A later device-clock correction, backward time change, or apparently future capture time does not reject an otherwise valid capture or alter draw behavior.

The vNext Core Box scene may play an individual or aggregate Paper-deposit response only when ingestion returns a freshly imported result after the containing app commits and refetches this Box Item plus Source Reference. Fresh-versus-existing is the result of the same serialized transaction that creates or observes the Source Reference; a snapshot check made before that transaction is not authoritative under concurrent ingestion. The idempotent `alreadyImported` result—such as replay after product commit succeeded but envelope cleanup was interrupted—performs reconciliation without replaying deposit motion. The visual event is optional, short-lived presentation state: losing or interrupting it never retries materialization, and extension publication alone never qualifies. Four or more freshly committed imports use bounded aggregate feedback rather than a blocking sequence of full animations. Queue size, expiry, background-drop, and post-commit-refetch-failure behavior are owned by the linked Core Box contract.

### 8.3 Source detail

An imported Paper detail defaults to one quiet **Link from host** chip plus **Open Original** when a structurally supported HTTP(S) URL is present. Capture date, the accepted URL serialization, Copy Link, and Remove Source live behind an explicit disclosure or secondary menu so the Paper does not become a bookmark-management screen.

Open Original hands the URL to the system and may launch an external app or browser. That user-initiated handoff may use the network outside someday-box. The containing app performs no preflight request, redirect resolution, web view rendering, or availability probe.

If iOS cannot perform the external handoff, the Paper and Source Reference remain intact and the UI offers Copy Link or Remove Source. The app does not infer whether the remote resource is unavailable. A handoff failure never archives, completes, or deletes its Paper automatically.

### 8.4 Editing and lifecycle

- Editing title, note, or duration does not rewrite the accepted URL serialization or capture time.
- Removing a source leaves the Paper and its lifecycle intact.
- Completing, archiving, restoring, accepting, drawing, and putting back use the existing rules.
- A Completion Memory does not duplicate the Source Reference in P0.
- A Memory may display source context only while its source Paper still exists.
- Permanent Paper deletion cascades to its Source Reference under the existing confirmation boundary.

### 8.5 No duplicate automation

P0 allows the same URL and title to produce separate Papers. The same link may represent different intentions, such as “watch this video” and “visit this place.”

The envelope identifier prevents transport replay from producing a duplicate during the active envelope-to-cleanup window. It is not user-content deduplication or a permanent tombstone.

No exact-link warning, auto-merge, source aggregation, Completed-paper revival, or fuzzy matching ships in P0. A later exact-URL advisory must always offer Keep both and must define behavior for Active, Archived, Completed, Current Pick, and Memories before implementation.

### 8.6 Recoverable ingestion failures

| Failure | Required behavior |
| --- | --- |
| Box capacity reached | Retain the envelope; show a calm local-capture recovery message and routes to export/manage content |
| Unsupported future envelope | Quarantine without deletion; identify the required app version without exposing content in logs |
| Corrupt checksum or invalid graph | Quarantine raw bytes; do not create a partial Paper |
| Product mutation blocked by unresolved reveal | Resume the exact persisted reveal flow until no Unresolved Attempt remains, then retry ingestion before root tabs or a new Draw |
| Data operation in progress | Retain the envelope and retry after migration/restore/erase finalizes |
| Low storage or persistence failure | Preserve the envelope when already published; show retry and recovery actions |

The normal flow has no Inbox. A recovery message appears only when a locally accepted capture cannot be materialized automatically; it is informational, not a guilt-producing backlog badge.

### 8.7 Shared Capture Recovery

After the unresolved-reveal gate, a capture that cannot be materialized opens one focused Shared Capture Recovery surface before normal root navigation. It handles one capture at a time in capture order and is never a permanent tab, folder, red badge, or list to organize.

Every state offers a route out:

- **Retry** revalidates and retries the same envelope without changing its ID.
- **Manage Box** opens a restricted Box management mode backed by authoritative product data. Draw, Capture, and unrelated lifecycle actions remain unavailable; export and permanent deletion are available so the person can create safe capacity.
- **Discard This Capture** requires explicit confirmation and removes only that envelope or quarantine artifact.
- **Export Raw Recovery File** is available for corrupt or future-version bytes before explicit removal. A raw recovery file is not presented as a valid someday-box backup.
- **Update someday-box** is explanatory copy for a future envelope version when a newer compatible build may exist; the app does not probe the App Store.

Capacity recovery may show the locally validated title. Corrupt/future artifacts show capture time and content-free error identity only; they do not repeatedly parse or render untrusted content. When several captures need recovery, the surface reports a neutral count and advances only after the current one is successfully ingested or explicitly removed. Closing the app retains the current capture without advancing.

Closing the app leaves the capture protected for the next launch. Shared Capture Recovery never auto-deletes, auto-archives, starts a Draw, or blocks access to the explicit restricted management actions needed to resolve its own condition.

---

## 9. Data model and version contracts

### 9.1 Share Capture Envelope

The extension writes a schema-independent transport DTO, not a SwiftData model.

| Field | Meaning |
| --- | --- |
| envelopeFormatVersion | Closed integer format version |
| envelopeID | App-generated UUID and idempotency key |
| createdAtMilliseconds | Extension wall-clock capture value for approximate display |
| appBuild | Extension build that wrote the envelope |
| title | User-confirmed valid Paper title |
| note | User-confirmed optional note |
| durationBucketRaw | User-selected supported duration |
| acceptedURLString | Optional accepted HTTP(S) serialization: detected text substring or received URL absoluteString |
| sourceKindRaw | Bounded open value such as url or shared_text |
| canonicalizationVersion | Canonical JSON contract version |
| checksumSHA256 | Corruption checksum over the canonical payload |

Envelope v1 contains no image, source author, account ID, inferred category, location, confidence, tracking identity, or hidden raw share text.

### 9.2 Source Reference

Source Reference is a structured persisted record. A URL must never be hidden inside the Paper note.

| Field | Meaning |
| --- | --- |
| id | UUID |
| itemID | Owning Box Item UUID |
| importEnvelopeID | Idempotency link to the transport envelope |
| acceptedURLString | Optional accepted HTTP(S) serialization |
| sourceKindRaw | Bounded open raw value |
| capturedAt | Extension wall-clock capture value used as approximate display metadata |

P0 writes only the source-kind values url, shared_text, and share_sheet (when the person removes the only link). The field is bounded and open for backup compatibility but presentation-only: an unknown value must round-trip without acquiring behavior. P0 enforces at most one Source Reference per imported Paper, but uses a separate entity so a later approved multi-source feature can lift cardinality without overloading Box Item.

### 9.3 Invariants

- Every Source Reference ID is unique.
- Every Source Reference points to exactly one existing Box Item.
- P0 permits at most one Source Reference per Box Item and at most 5,000 Source References.
- Every importEnvelopeID is unique among Source References.
- A Source Reference may have no URL; in that case Open Original is absent.
- Every stored URL is valid UTF-8, within the byte limit, and HTTP(S).
- Every source raw value passes the open-value length/printability contract.
- Source kind never makes a URL required and never grants URL-opening behavior.
- Source capture time is approximate display metadata; clock movement cannot make the graph invalid or affect draw order/weight.
- Source presence never changes draw eligibility.
- A Box Item remains valid without a Source Reference.
- Permanent Item deletion removes its Source Reference.
- A failed transaction creates neither record.
- Every final incoming filename is an app-owned UUID that equals its decoded envelopeID; envelope IDs are unique within the final incoming set.
- Every final envelope passes byte, canonicalization, checksum, closed-version, title/note/duration, URL, and mailbox-generation validation before product mutation.
- A final envelope ID that has no matching Source Reference is pending ingestion.
- A final envelope ID that matches a committed Source Reference is a normal crash-replay state only when reconstructed title, note, duration, accepted URL, source kind, and capturedAt also match. The app removes that envelope before exposing its Paper.
- The same ID with different materialized content is an identity collision: quarantine the envelope, preserve the committed Paper, and enter Shared Capture Recovery.
- Remove Source is unavailable until the matching final envelope has been removed, so deleting the idempotency record cannot race the active replay window.

Backup and restore validate each authority independently before normalization. They then resolve a matching envelope/Source overlap as a committed replay by retaining the Item/Source and omitting the queued copy. A mismatched overlap, duplicate Source ID, duplicate importEnvelopeID, duplicate final envelope ID, second P0 Source for one Item, or broken Item reference rejects the normal backup/restore graph and makes zero authority changes.

### 9.4 SwiftData schema migration

The feature requires a new schema version. The migration:

1. adds Source Reference without changing existing Box Item meaning;
2. leaves every v1 Item with no source;
3. preserves all v1 IDs, lifecycle values, timestamps, Current Pick, Sessions, Attempts, and Memories;
4. validates source invariants after a fresh-container reopen;
5. includes a fixture produced by the immediate predecessor baseline build; if that build has a public packaged release, the fixture must be generated by that exact released binary;
6. follows the existing independent-generation migration journal and rollback boundary.

The authoritative SwiftData store remains in the containing app’s private generation directory and remains explicitly configured with no CloudKit and no SwiftData App Group container.

### 9.5 Backup format

The first release with Share to Box requires a new readable backup format.

It adds:

- Source References;
- valid, not-yet-ingested Share Capture Envelopes;
- envelope, source, and mailbox contract versions;
- checksummed counts and capacity limits for the new records.

Older format-v1 backups import with no sources or queued captures. A new build exports the current format and continues to read every older format that a public release promised. If no public build exists before Share to Box, predecessor-fixture coverage is still required but no public backward-compatibility claim is invented. Accepted URL serializations and unknown bounded source-kind values round-trip without product rewriting. A future unknown envelope or backup format is rejected without active-data writes.

Before export, the app attempts normal ingestion, acquires the product-data snapshot gate, then acquires the mailbox coordination boundary. While both are held it records an export cutoff containing the active store generation, mailbox generation, sorted remaining envelope IDs/checksums, and cutoff time; it copies the bounded mailbox DTO bytes into the export snapshot before releasing the mailbox boundary. Product DTOs remain immutable under the product gate until encoding completes.

Any valid envelope remaining at the cutoff is included as pending local capture so “full export” means all valid product data at that explicit cutoff. A new share published after the mailbox boundary is released remains on the device and belongs to the next export; it is not falsely claimed by the completed file. The preview and backup metadata disclose the cutoff and any later locally pending count.

Corrupt or future-version mailbox artifacts block a normal full-export claim and route to Shared Capture Recovery with a separate bounded raw recovery export; they are never silently omitted or deleted. Backup format v2 retains the 144 MiB product-graph budget, 152 MiB encoded-file cap, Source Reference and mailbox limits, and exact projected-size checks defined in Section 5.5.

### 9.6 Restore and erase

Restore and erase treat the app store generation and active mailbox generation as one product-data operation:

- acquire the application mutation gate and the cross-process mailbox maintenance coordination boundary;
- prevent the extension from reporting a new save while the destructive switch is in progress;
- stage and validate both product data and mailbox data;
- predeclare both cleanup target sets in the operation journal;
- roll both authorities back before the operation journal’s committed boundary;
- never roll either authority back after committed;
- finish idempotent cleanup before releasing product mutations or reporting success.

Erase All explicitly removes:

- every app-owned store generation authorized by the erase journal;
- every Source Reference;
- every active, staged, quarantined, or temporary mailbox artifact named by the journal;
- content-free mailbox manifests, coordination anchors, and operation markers after finalization.

If a new share begins after Erase All has fully finalized and released coordinated access, it is a new user-authorized capture and must not be deleted as part of the earlier operation.

---

## 10. App–extension authority and local pipeline

### 10.1 Authority decision

The containing app is the only writer of authoritative SwiftData product records, store-generation manifests, and product operation journals.

The Share Extension:

- reads only the system-provided extension context;
- validates and composes one capture;
- writes only a versioned envelope into the dedicated App Group mailbox;
- never opens the product ModelContainer;
- never invokes a view-layer or repository shortcut around MutationArbiter;
- never migrates, restores, erases, draws, or edits existing Papers.

The extension target and every shared module enable app-extension-safe API enforcement. Extension code does not call UIApplication.shared, request general background execution, or rely on the containing app being alive.

This preserves the existing single-writer product architecture while acknowledging that the extension is a separate, short-lived process.

### 10.2 Shared container scope

One reviewed App Group is permitted only for Share to Box transport and cross-process coordination. It is not:

- the authoritative SwiftData location;
- CloudKit or cross-device sync;
- a general cache;
- a place for analytics, preferences, or copied Box data;
- accessible to unrelated developer apps or targets.

Both binaries carry the exact same App Group entitlement and Complete data-protection policy. Production signing evidence must show the expected group identifier and no unapproved capability.

### 10.3 Mailbox layout

The group container uses fixed app-owned directories and UUID names:

    ShareMailbox/
      manifest-v1.json
      coordination-anchor
      generations/
        {mailbox-generation-uuid}/
          incoming/
            {envelope-uuid}.capture
          quarantine/
          temporary/

Host values never influence a path. Temporary files use app-generated UUIDs and a distinct suffix. Readers ignore incomplete temporary files.

The checksummed mailbox manifest contains only contract version, active mailbox-generation UUID, monotonically increasing local epoch, idle/maintenance state, and an optional app-generated operation UUID that cross-references the product operation journal. It contains no title, note, URL, or host identity. The extension may publish only against the active generation while the manifest is idle; any maintenance state fails closed with retry copy.

On a fresh install where the containing app has never launched, the extension may create only an empty mailbox-v1 generation and its checksummed manifest under the same coordination boundary. It never bootstraps SwiftData or fabricates containing-app preferences. The app later validates and adopts that mailbox before ingestion.

### 10.4 Local atomic-publication protocol

In this document, a **published** envelope is a complete final file that survives host/extension process termination and can be replayed on the next app launch. Atomic publication plus reopen/readback proves that process-recovery boundary; it is not an absolute claim about sudden hardware power loss. The S2 coordination addendum must name the Foundation/POSIX write and flush semantics actually used.

For one save:

1. request coordinated access to the frozen mailbox resources with the current invocation token;
2. inside that accessor, recheck the maintenance marker, mailbox generation, count, and byte capacity;
3. encode canonical envelope bytes;
4. write to an app-owned temporary file in the active mailbox generation;
5. apply Complete file protection;
6. publish by the approved atomic move/replace protocol;
7. reopen, bound-read, checksum, and decode the final file;
8. leave coordinated access;
9. only then transition the still-current invocation to Saved and complete the extension request.

Failure before final publication leaves no final envelope. A late accessor or callback whose invocation token expired may clean only its proven temporary artifact; it cannot publish, update UI, or report success.

### 10.5 Coordinated access

The app-process MutationArbiter cannot coordinate a second process. Mailbox writers and maintenance operations therefore require an interprocess-safe coordination protocol plus atomic file publication. ADR 0003 freezes this authority and the required safety properties, not a specific lock primitive.

Before S2 implementation begins, an accepted coordination addendum must freeze and test:

- whether NSFileCoordinator alone or NSFileCoordinator plus a POSIX advisory lock is used;
- the exact manifest, coordination-anchor, generation-directory, and file URLs coordinated for every operation;
- the single acquisition order shared by extension save, app ingestion, export, restore, and erase;
- process-death release semantics and the rule that a leftover anchor file is not itself a held lock;
- cancellation/watchdog behavior, invocation-token invalidation, and rejection of late accessors;
- which directory mutations require parent-directory coordination and how manifest replacement orders with envelope rename;
- mailbox manifest/maintenance schema, epoch comparison, and product-journal cross-reference ordering;
- protected-data-unavailable behavior before temporary write, during publication, and during readback.

NSFileCoordinator does not promise a caller-selected fixed deadline. A watchdog may cancel the invocation UI and invalidate its token, but correctness depends on late-accessor rejection rather than assuming cancellation prevents every callback.

The containing app never holds cross-process mailbox coordination while presenting UI or waiting for user confirmation. Restore/erase confirmation occurs first; coordinated access covers only the bounded operation and journal transition.

### 10.6 Idempotent ingestion

The commit/removal order is:

    published envelope
        → validate
        → transactionally create Item + Source Reference
        → verify committed Source Reference with envelope ID
        → remove envelope

Crash outcomes:

| Interruption point | Relaunch truth |
| --- | --- |
| Before final envelope publication | Zero final capture; a proven temporary artifact may remain |
| After rename, before product transaction | One envelope, zero Paper; retry ingestion |
| During failed product transaction | One envelope, zero partial records; retry |
| After product commit, before envelope removal | Existing envelope ID prevents a second Paper; remove envelope |
| After envelope removal | One Paper and Source Reference |

Exactly-once materialization is guaranteed across the normal active-envelope retry window by persistent identity and transaction ordering, not by assuming the extension completion callback runs once. The corresponding Paper is not exposed until the final envelope has been removed, so Remove Source cannot erase the idempotency record during that window. P0 makes no permanent replay-deduplication claim after both normal envelope cleanup and a later explicit Source removal.

The application outcome is also transactional. If two tasks race to ingest the same envelope, exactly one transaction may return `freshlyImported` with the committed IDs; the other returns `alreadyImported` with the existing committed identity. A preflight snapshot followed by an unconditional “imported” return is invalid because another task can commit in between. Refetch verifies the outcome but does not infer freshness. If commit succeeds and refetch fails, ingestion enters reconcile/load handling, removes no envelope until verification, emits no deposit event, and never offers a second materialization mutation.

This paragraph is a vNext Core Box C6 prerequisite and is not current implementation evidence. The existing S3 implementation claim remains limited to the previously accepted atomic materialization/idempotent replay contract; it must be hardened before any Core Box deposit animation or structured-outcome release claim is enabled.

### 10.7 Target and module boundaries

The second executable target creates real reuse, so a small app-extension-safe local module is justified. It contains only the envelope DTO, canonical codec, bounded validation, deterministic URL/text extraction primitives, clock/UUID abstractions, and content-free error codes. It imports Foundation, CryptoKit, and Uniform Type Identifiers as needed; it imports neither SwiftUI nor SwiftData.

~~~text
Host app
   → Share Extension UI
       → Share Capture Contract
       → App Group Mailbox Writer

Containing app foreground
   → Mailbox Reader
       → Share Capture Contract
       → Import Shared Paper Use Case
           → MutationArbiter
           → ProductRepository
           → app-owned SwiftData generation
~~~

Intended repository shape when implementation begins:

~~~text
someday-box/
├── ShareExtension/
│   ├── Compose/
│   ├── Payload/
│   └── Resources/
├── ShareCaptureContract/
├── Application/
│   └── ImportSharedPaperUseCase
├── Data/
│   ├── ShareMailbox/
│   └── SourceReference persistence
├── Features/
│   └── SourceDetail/
└── SomedayBoxShareExtensionTests/
~~~

Names are architectural guidance, not a request to create empty folders. Shared code must expose no extension-unavailable API. The extension target cannot link the app’s full Data, Features, or store-generation composition merely to reuse one validator.

---

## 11. Privacy and security

### 11.1 Local-only promise

The precise feature promise is:

> someday-box processes only the URL or text that you explicitly share. The app and its Share Extension do not contact the source service, fetch the page, or send the capture to a developer server.

App Group storage is an on-device sandbox shared only by signed related targets. It does not create sync, an account, or a network path. System device backups and user-selected backup destinations remain under iOS and user control as described by the parent contract.

### 11.2 Network boundary

Neither target may use:

- URLSession or another networking client;
- Link Presentation metadata fetching;
- WebKit or an in-app browser;
- source-platform SDKs;
- background transfer or Background Modes;
- remote configuration, analytics, crash-reporting SDKs, or ads.

Open Original is a visible user action handed to iOS. Runtime evidence must distinguish that external handoff from product-initiated traffic.

### 11.3 Logging

Never log:

- title, note, host plain text, or URL;
- URL host, query, path, or hash;
- envelope, Item, Source Reference, or mailbox-generation UUID;
- host app identity;
- full filesystem paths or filenames.

Allowed diagnostics are bounded counts, contract versions, stable content-free error codes, durations, and lifecycle phases. A diagnostic export receives the same review.

### 11.4 Data protection and cleanup

- Use Complete data protection for envelope and source content.
- Do not implement custom encryption or claim end-to-end encryption.
- Include a reviewed privacy manifest in every target that uses a required-reason API and verify the archived aggregate privacy report. P0 stores no capture or preference in shared UserDefaults.
- A raw recovery export may contain the original accepted capture bytes and is not an encrypted or validated backup. The system destination is user selected, and the confirmation explains that privacy follows that destination.
- Remove temporary files after a safe age only when they are proven incomplete and not journal targets.
- Quarantined bytes remain protected and user-removable; they are never parsed repeatedly on every foreground without a retry limit.
- Source removal and Paper deletion must close previews, cached display values, backup DTOs, search indexes, and accessibility summaries if those are later introduced.

### 11.5 URL safety

- Only HTTP and HTTPS URLs can power Open Original.
- A source URL requires a non-empty host and contains no embedded username or password.
- Display uses a safe host-oriented summary; the full link is available through an explicit disclosure/copy action.
- Do not execute custom schemes, JavaScript URLs, data URLs, or local file URLs.
- Do not preflight a link, resolve redirects, or claim that it is safe or available.
- A malformed or unsupported URL cannot block saving a valid text-only Paper if the person removes the source.

---

## 12. Functional requirements and acceptance rules

### 12.1 Invocation and payload

| ID | Requirement | Acceptance rule |
| --- | --- | --- |
| SHR-01 | Declare the bounded share capability | Production uses com.apple.share-services, activation dictionary v2, strict matching, URL max 1, and text support; it advertises no other P0 type and contains no TRUEPREDICATE |
| SHR-02 | Accept one logical capture | One URL, text, or URL-plus-text request produces at most one save action and one envelope |
| SHR-03 | Treat host data as untrusted | Unsupported types, schemes, controls, and bounds fail without execution, path use, or partial persistence |
| SHR-04 | Work across source apps by payload | A host is supported when its actual request provides a supported representation; no platform login or SDK is used |
| SHR-05 | Stay offline | Given identical delivered representations, airplane mode produces the same someday-box parsing and publication result; host failure to supply a payload is recorded separately |

### 12.2 Compose experience

| ID | Requirement | Acceptance rule |
| --- | --- | --- |
| CMP-01 | Require a valid title | Save stays disabled for empty, over-limit, byte-invalid, or control-invalid title |
| CMP-02 | Require explicit duration | No duration is preselected or inferred; all six choices are visible |
| CMP-03 | Keep note optional | Note disclosure can remain closed without blocking save |
| CMP-04 | Show and control source truth | The source row displays only a provided URL host or honest text-only state and offers Remove link when a URL is present |
| CMP-05 | Preserve drafts on failure | Provider, validation, coordination, capacity, low-storage, and write failures keep editable input |
| CMP-06 | Cancel cleanly | A cancel that wins before final publication leaves zero final envelopes and product records; a publication that wins reports Saved, never Cancelled |
| CMP-07 | Prevent double submission | Repeated taps during Saving yield one envelope identifier |
| CMP-08 | Report only published success | Saved appears only after atomic final publication, reopen, bounds check, decode, and checksum validation |
| CMP-09 | Stay low friction | With a valid host title, at least 80% of moderated first-time participants finish within 10 seconds using one duration tap and one save tap without help |

### 12.3 Mailbox and ingestion

| ID | Requirement | Acceptance rule |
| --- | --- | --- |
| MBX-01 | Keep product store single-writer | Static review shows the extension cannot import/open the SwiftData product container |
| MBX-02 | Write atomically | Forced termination before final publication yields zero final envelope; after publication yields one valid replayable envelope |
| MBX-03 | Bound shared storage | Every Section 5.5 count/byte limit fails recoverably without deleting an incoming or quarantined capture |
| MBX-04 | Coordinate processes | Concurrent save, ingest, restore, and erase tests show no partial file, lost committed capture, or guessed cleanup path |
| ING-01 | Materialize atomically | Item and Source Reference appear together or neither appears |
| ING-02 | Be idempotent in the active replay window | Reprocessing the same final envelope ID before envelope cleanup creates no second Paper; P0 does not claim permanent replay deduplication after later Source removal |
| ING-03 | Ingest before Draw truth | Home/Box counts and a new Draw cover every valid capture at or before the recorded mailbox watermark, after any unresolved reveal |
| ING-04 | Preserve recoverable failures | Capacity, future version, corruption, and operation-gate failures retain or quarantine the envelope and open Shared Capture Recovery |
| ING-05 | Remove only after commit | A product persistence failure leaves the final envelope available for retry |
| ING-06 (vNext C6, open) | Return transactional idempotency truth | Concurrent ingestion of one envelope produces one Item/Source and exactly one `freshlyImported` result; every losing/replay path returns `alreadyImported` |
| ING-07 (vNext C6, open) | Separate commit and refetch failure | A committed transaction with failed projection refresh enters reconcile, emits no success animation, and cannot be resubmitted as a new import |

### 12.4 Source behavior

| ID | Requirement | Acceptance rule |
| --- | --- | --- |
| SRC-01 | Persist source structurally | URL and source fields are stored in Source Reference, never hidden in note |
| SRC-02 | Preserve accepted URL serialization | Envelope, Source Reference, backup round trip, and edit do not rewrite the URL serialization accepted by this product |
| SRC-03 | Keep source out of draw policy | Identical Papers with and without sources have identical eligibility and weight inputs |
| SRC-04 | Open only by user action | No network or URL handoff occurs before tapping Open Original |
| SRC-05 | Survive an external handoff failure | An iOS open failure leaves the Paper and source record intact and offers copy/remove actions without claiming remote availability |
| SRC-06 | Close deletion | Removing source preserves Paper; permanent Paper deletion removes source |
| SRC-07 | Avoid automatic duplicate decisions | Repeated URLs may save as separate Papers; only active-window replay of the same envelope is deduplicated |

### 12.5 Data, privacy, and operation

| ID | Requirement | Acceptance rule |
| --- | --- | --- |
| DAT-01 | Migrate predecessor data without fabrication | A fixture from the immediate predecessor build upgrades unchanged with zero Source References; use the exact public binary only when such a release exists |
| DAT-02 | Back up all feature truth | Current backup format round-trips sources and valid queued envelopes |
| DAT-03 | Restore atomically | Every pre-commit interruption restores the prior store/mailbox authorities; post-commit cleanup never rolls back |
| DAT-04 | Erase with closure | Erase removes every authorized app-store and mailbox artifact and does not remove a later new share |
| DAT-05 | Preserve promised backup readability | Every older format promised by a public release remains importable with empty source collections; no unreleased compatibility claim is invented |
| PRV-01 | Initiate no network | Static scans, Instruments, and App Privacy Report show no app/extension domain access during capture and ingestion |
| PRV-02 | Keep logs content-free | Injected sensitive strings and URLs never appear in logs or diagnostic exports |
| PRV-03 | Limit entitlement expansion | Signed app and extension contain only the reviewed App Group and existing data-protection entitlements |

### 12.6 Accessibility and localization

| ID | Requirement | Acceptance rule |
| --- | --- | --- |
| A11Y-01 | Support large text | Largest Dynamic Type keeps every required field and action reachable |
| A11Y-02 | Support VoiceOver | Focus, labels, selected duration, error announcements, and save completion are coherent |
| A11Y-03 | Support Voice Control | Visible action names activate the expected controls |
| A11Y-04 | Avoid motion dependence | Reduce Motion changes presentation only, never save state |
| L10N-01 | Ship bilingual UI | Extension name, compose, errors, source detail, and recovery states are complete in English and Simplified Chinese |
| L10N-02 | Preserve user content | Extraction never translates or locale-normalizes title, note, or URL |

---

## 13. Error and edge-state copy

Copy must be calm, specific, and recoverable.

| State | English direction | Simplified Chinese direction |
| --- | --- | --- |
| No supported content | This share does not contain a link or text that someday-box can use. | 这次分享里没有改天盲盒可使用的链接或文字。 |
| Provider failed | The shared content could not be read. Try again or cancel. | 暂时无法读取分享内容。请重试或取消。 |
| Shared text too large | This text is too large to use here. Share a link instead, or cancel. | 这段文字太长，暂时无法在这里使用。请改为分享链接，或取消。 |
| Duration missing | Choose roughly how long this might take. | 请选择这件事大概需要多久。 |
| Mailbox busy | someday-box is busy for a moment. Please try again. | 改天盲盒暂时有点忙，请稍后重试。 |
| Mailbox full | Open someday-box to make room for saved shares, then try again. | 请先打开一次改天盲盒，为已收好的分享腾出空间，再回来重试。 |
| Protected data unavailable | Unlock this iPhone, then try again. | 请解锁这台 iPhone 后重试。 |
| Low storage | There is not enough local storage to save this share. Your draft is still here. | 本地储存空间不足，暂时无法保存；当前内容仍保留在这里。 |
| Save failed | This was not saved. Your draft is still here. | 尚未保存，当前内容仍保留在这里。 |
| Success | Saved for your Box. It will wait safely until you next open someday-box. | 已替你收好。它会安心等到你下次打开改天盲盒。 |
| Open failed | iOS could not open this link. The Paper is still in your Box. | iOS 暂时无法打开这个链接，纸条仍保留在盲盒中。 |

Do not use “syncing,” “uploading,” “AI,” “recognized,” “recommended,” “overdue,” “needs review,” or “failed task.”

---

## 14. Test and evidence strategy

### 14.1 Pure and application tests

Cover:

- every title, note, URL, source raw value, envelope byte, envelope count, mailbox total, backup v2, and post-delivery text-acceptance boundary;
- deterministic selection among explicit URL and text representations;
- multiple URL disclosure;
- unsupported scheme and control characters;
- source invariants and deletion cascade;
- source neutrality in candidate filtering and weighting;
- envelope canonicalization, checksum, and future version rejection;
- identical envelope ID replay;
- old-schema migration and old-backup import.

### 14.2 Integration and interruption tests

Use temporary disk-backed app and App Group-equivalent containers.

Cover:

- the accepted coordination addendum’s acquisition order, URL granularity, process-death behavior, cancellation token, late accessor, and protected-data-unavailable cases;
- atomic envelope temporary-write/final-publication/readback;
- termination before publication, after publication, before product commit, after product commit, and before envelope deletion;
- simultaneous extension saves with unique IDs;
- simultaneous ingestion attempts for the same final envelope, proving one fresh transaction result and one `alreadyImported` result;
- ingestion while an unresolved reveal or data operation gate exists;
- coordination cancellation/watchdog behavior, late NSItemProvider callbacks, and stale temporary cleanup;
- current/previous mailbox generation reconciliation;
- backup and restore with zero, one, maximum, and quarantined envelope sets;
- restore/erase interruption around every store-manifest and mailbox-manifest switch;
- erase racing a new share before, during, and after finalization;
- capacity and canonical-byte headroom;
- no duplicate Item after retry;
- product commit followed by injected refetch failure, proving no false “not changed,” no second mutation, and no deposit event;
- matching and mismatched envelope/Source identity collisions plus backup/restore normalization;
- Shared Capture Recovery retry, restricted management, raw export, explicit discard, close/relaunch, and multiple-capture sequencing.

### 14.3 UI tests

Cover:

- URL-only, text-only, and URL-plus-text compose;
- ambiguous multi-item rejection, over-limit text preview behavior, and Remove link;
- invalid/empty title and missing duration;
- optional note;
- cancel, retry, repeated save tap, load failure, write failure, and success;
- source detail, copy, open failure, remove source, and Paper deletion;
- post-ingestion Home/Box count and draw eligibility;
- English and Simplified Chinese;
- light/dark appearance, largest Dynamic Type, VoiceOver order, Voice Control names, and Reduce Motion.

UI automation inside a synthetic host is useful but does not replace real share-sheet tests.

### 14.4 Real-host physical-device matrix

For each release candidate, record:

| Host | Host version | Shared object | Actual UTTypes/representations | Result | Evidence |
| --- | --- | --- | --- | --- | --- |
| Safari | REQUIRED | Webpage | REQUIRED | REQUIRED | Recording/log |
| Xiaohongshu | REQUIRED | Post | REQUIRED | REQUIRED | Recording/log |
| Instagram | REQUIRED | Post/Reel | REQUIRED | REQUIRED | Recording/log |
| TikTok | REQUIRED | Video link | REQUIRED | REQUIRED | Recording/log |
| YouTube | REQUIRED | Video | REQUIRED | REQUIRED | Recording/log |
| Google Maps | REQUIRED | Place | REQUIRED | REQUIRED | Recording/log |
| Apple Maps | OS build | Place | REQUIRED | REQUIRED | Recording/log |
| Notes or another text host | OS build | Selected text | REQUIRED | REQUIRED | Recording/log |

Record Partial or Unavailable honestly. Do not alter the activation rule or add scraping to force a green platform label.

Run the matrix once after a fresh install before the containing app has ever launched, then again with the app suspended and with existing Box data. The first later app launch must complete onboarding and materialize the same saved capture exactly once.

### 14.5 Offline and privacy evidence

- Enable airplane mode before opening the host.
- Complete Share → compose → published save → containing-app ingestion → Draw → source detail.
- Record whether the third-party host supplies the same representation offline; a host-side difference is compatibility evidence, not permission for someday-box to fetch content.
- Replay an identical local fixture representation online and offline to prove the product-controlled path is equivalent.
- Inspect both app and extension processes for product-initiated connections.
- Review linked frameworks, packages, activation rule, entitlements, privacy manifests, Info.plist, and signed archive.
- Verify that tapping Open Original is the first external handoff and is clearly user initiated.
- Search logs and diagnostic exports with seeded sensitive content.

### 14.6 Packaged acceptance

Only an installed signed Release/TestFlight candidate can prove:

- the App Group is registered to both App IDs and provisioning profiles under one team;
- the separately identified extension appears as the expected `.appex` in the archived app’s `PlugIns` directory and passes archive validation;
- signed app and extension entitlements contain the same exact App Group and Complete Data Protection, with no CloudKit or unapproved capability;
- `APPLICATION_EXTENSION_API_ONLY=YES` covers the extension and shared contract module;
- the signed extension Info.plist contains `com.apple.share-services`, activation dictionary v2, strict matching, URL/text-only declarations, no `TRUEPREDICATE`, and no `UIBackgroundModes`;
- the extension is discoverable and localized and its universal iPhone/iPad host layout remains usable;
- host apps supply the recorded payloads;
- the mailbox works under real extension suspension and memory limits;
- protected-data-unavailable interruption before/during/after publication never reports false success or strands coordination;
- airplane-mode product behavior is unchanged for the same delivered representation, with host-side differences labeled separately;
- a share survives host dismissal and later app launch;
- upgrade from the immediate predecessor build preserves its store and accepts new captures; when a prior public app exists, test that exact installed release.

Green main-app tests, source scans, previews, or an extension-scheme Debug run are lower evidence levels.

---

## 15. Delivery plan

### S0 — Contract freeze

Deliver:

- this feature specification;
- the Share Extension/App Group authority ADR;
- frozen payload, envelope, source, schema, backup, privacy, and copy contracts;
- explicit update to the local-only audit policy and release manifest.

Exit evidence:

- product and engineering review;
- no unresolved conflict with the parent product baseline;
- no implementation claim.

### S1 — Extension shell and payload truth

Implementation status: **implemented; exit evidence open**. The URL/text compose flow, explicit title and duration validation, bilingual accessible states, cancellation, and local publication are present. A real-host physical-device matrix is still required.

Deliver:

- embedded target and exact activation rule;
- local URL/text loading and deterministic candidates;
- bilingual accessible compose UI;
- no product-store write.

Exit evidence:

- real-host payload matrix on a device;
- unsupported content and extension-lifecycle tests;
- static network/dependency audit.

### S2 — Atomic local mailbox

Implementation status: **implemented; exit evidence open**. Versioned canonical envelopes, coordinated publication, bounded capacity, generation maintenance, readback, and checksums are present. Forced-termination, protected-data, low-storage, and signed-entitlement device evidence is still required.

Deliver:

- App Group provisioning for both targets;
- accepted coordination addendum freezing primitive, URLs, order, cancellation tokens, late-accessor behavior, and protected-data cases;
- versioned envelope codec;
- coordinated atomic mailbox write and readback;
- capacity, low-storage, cancellation/watchdog, and interruption behavior.

Exit evidence:

- forced-termination matrix;
- signed entitlement proof;
- no partial file or false success.

### S3 — Product ingestion and source detail

Implementation status: **implemented; exit evidence open**. Schema v2, Source Reference persistence, idempotent mutation-gated ingestion, source detail/open/remove, and source-neutral draw behavior are covered locally. The immediate-predecessor fixture and visible packaged journey remain required.

Deliver:

- schema migration and Source Reference;
- idempotent ingestion through application use cases;
- source detail/open/remove;
- unchanged draw and lifecycle semantics.

Exit evidence:

- immediate-predecessor fixture migration, generated by the exact public binary when one exists;
- active-envelope exactly-once interruption tests;
- visible end-to-end journey and source-neutral draw tests.

### S4 — Backup, restore, erase, and recovery closure

Implementation status: **implemented; exit evidence open**. Backup v2 reads v1, includes sources and valid pending envelopes, and coordinates store/mailbox restore or erase with a durable shared journal. Corrupt and future envelopes retain a raw export and explicit discard path. The complete process-interruption and physical-device Files matrix remains required.

Deliver:

- new backup adapter and pending-envelope coverage;
- explicit cross-process export cutoff and backup v2 resource limits;
- store/mailbox operation-journal coordination;
- deletion and erase closure;
- corrupt/future-envelope recovery.

Exit evidence:

- old/new backup round trips;
- complete interruption matrix;
- full-export truth and raw recovery path.

### S5 — Product hardening

Implementation status: **locally implemented; device evidence open**. English/Simplified Chinese feature copy, Reduce Motion handling, Dynamic Type reachability, automated accessibility checks, extension-inclusive local-only scans, and content-log scans pass locally. VoiceOver, Voice Control, Instruments, App Privacy Report, and oldest-device measurements remain required.

Deliver:

- bilingual copy;
- accessibility and motion closure;
- oldest-device performance;
- local-only and content-free diagnostics audits.

Exit evidence:

- automated and manual accessibility reports;
- Instruments and App Privacy Report;
- extension launch/save measurements on reference devices.

### S6 — Packaged acceptance

Status: **blocked on external release evidence**. An unsigned Release archive proves that the app embeds the expected `.appex` and carries the strict URL/text-only activation configuration. It cannot prove distribution signing, installed entitlements, real-host payloads, physical-device lifecycle, runtime network silence, upgrade, or phased-release approval.

Deliver:

- signed candidate with embedded extension;
- phased release/containment decision;
- candidate-specific manifest and evidence archive.

Exit evidence:

- packaged real-host journey on oldest and current reference iPhones;
- immediate-predecessor upgrade, including the exact prior public version when one exists;
- offline, signed-entitlement, and rollback/containment approval.

---

## 16. Rollout, rollback, and removal

### 16.1 Rollout

- Use a phased App Store release.
- The production share activation rule is a signed build contract, not remote configuration.
- Internal builds may compile the extension off or use a separate test App Group, but production data and identifiers never cross environments.
- A release manifest names the extension bundle version, App Group identifier, activation-rule contract, envelope version, source schema, backup format, and oldest readable versions.

### 16.2 Containment

A bad Share Extension cannot be remotely disabled. The containment plan is:

1. pause phased rollout;
2. stop promotion of the affected candidate;
3. ship a forward fix or containment build;
4. preserve readable envelopes and Source References;
5. if capture must be disabled, keep the containing app’s ingestion/export/delete compatibility until every envelope version promised by a public release leaves the support window.

Removing the visible extension must not strand accepted local envelopes.

### 16.3 Data rollback

Source schema changes use expand/contract migration. Rolling source code back is not equivalent to safely downgrading a user store.

- Before the migration/restore journal’s committed boundary, retain the prior store and mailbox authorities.
- After committed, use a forward fix; do not select an older incompatible generation.
- Unknown future envelopes are quarantined, not rewritten as v1.
- A supported feature-off build stops new share writes while retaining safe read, export, remove, and erase behavior.
- Compatibility code receives an explicit removal version and evidence; it is not an indefinite fallback.

---

## 17. Risks and mitigations

| Risk | User impact | Mitigation |
| --- | --- | --- |
| Host app supplies only a link | Preview appears sparse | Show the host as source, focus an empty Paper title, and keep the accepted URL useful |
| Product copy implies semantic understanding | Trust is damaged | Deterministic extraction contract and prohibited copy list |
| Extension writes product SwiftData directly | Concurrency or restore truth is corrupted | App-only product-store writer; App Group mailbox only |
| Extension is killed mid-save | Idea is lost or duplicated | Atomic envelope publication, readback, and active-window idempotent ingestion |
| Mailbox and restore race | A share disappears behind a generation switch | Frozen interprocess coordination, mailbox generation, shared operation journal |
| App Group weakens local-only claim | Privacy language becomes misleading | Narrow entitlement, no CloudKit/network, signed/runtime audit |
| URL contains hostile or private content | Execution or log disclosure | HTTP(S) allowlist, bounded validation, no fetch, content-free logs |
| Platform payload changes | A named integration unexpectedly fails | Payload-based compatibility status and candidate host matrix |
| Imported content becomes another backlog | Product becomes a task manager | No Inbox, no review count, complete compose before save |
| Automatic duplicate merge removes intent | Distinct possibilities are lost | P0 allows duplicates; only transport ID is idempotent |
| Attachment scope causes memory/data loss | Extension termination or incomplete backup | URL/text-only P0; separate attachment contract |
| Lower evidence is mistaken for release proof | Feature fails in real share sheets | Packaged host/device acceptance gate |

---

## 18. Definition of Done

Share to Box is complete only when one signed candidate proves all of the following:

1. The extension declares only URL/text support, appears when the system finds at least one supported representation, and safely rejects ambiguous runtime requests; it does not appear for requests with no supported P0 representation.
2. A person can confirm a valid title and explicit duration in a compact bilingual interface.
3. Cancellation and every pre-publication interruption create zero final captures.
4. A reported success corresponds to one atomically published, reopened, checksummed local envelope that is replayable after process termination.
5. The containing app materializes exactly one ordinary Paper plus one Source Reference before exposing draw truth.
6. The source can be opened only by an explicit action and never affects draw eligibility.
7. Immediate-predecessor stores and every publicly promised older backup upgrade without fabricated sources or data loss.
8. Backup, restore, delete, and Erase All include every feature-owned record and mailbox artifact.
9. App and extension initiate no network request and log no user content.
10. VoiceOver, Voice Control, largest Dynamic Type, Dark Mode, and Reduce Motion remain usable.
11. Real packaged tests record actual payload behavior for the named host matrix on physical devices.
12. Rollout, containment, upgrade, and compatibility-removal evidence is attached to the release manifest.
13. Shared Capture Recovery can retry, open restricted management, export raw recovery bytes, explicitly discard, and survive close/relaunch without becoming an Inbox.
14. The moderated title-present flow meets the under-10-second usability target, and the S2 coordination addendum plus signed packaging checklist are approved.

A polished compose screen, a successful envelope unit test, an embedded appex, or a green simulator journey alone does not satisfy this definition.

---

## 19. Apple platform references

These primary references support the feature boundary. Apple behavior and submission requirements are date-sensitive and must be rechecked at implementation and release:

- [App Extension Programming Guide — Share](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Share.html)
- [App Extension Programming Guide — Understand How an App Extension Works](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/ExtensionOverview.html)
- [App Extension Programming Guide — Handling Common Scenarios](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/ExtensionScenarios.html)
- [App Extension Programming Guide — Creating an App Extension](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/ExtensionCreation.html)
- [Human Interface Guidelines — Activity views](https://developer.apple.com/design/human-interface-guidelines/activity-views)
- [Configuring app groups](https://developer.apple.com/documentation/xcode/configuring-app-groups)
- [NSExtensionActivationRule](https://developer.apple.com/documentation/bundleresources/information-property-list/nsextension/nsextensionattributes/nsextensionactivationrule)
- [NSExtensionContext completeRequest](https://developer.apple.com/documentation/foundation/nsextensioncontext/completerequest(returningitems:completionhandler:))
- [NSExtensionItem](https://developer.apple.com/documentation/foundation/nsextensionitem)
- [NSItemProvider](https://developer.apple.com/documentation/foundation/nsitemprovider)
- [Uniform Type Identifiers](https://developer.apple.com/documentation/uniformtypeidentifiers)
- [NSFileCoordinator](https://developer.apple.com/documentation/foundation/nsfilecoordinator)
- [Atomic data writing](https://developer.apple.com/documentation/foundation/nsdata/writingoptions/atomic)
- [ModelContainer](https://developer.apple.com/documentation/swiftdata/modelcontainer)
- [LPMetadataProvider](https://developer.apple.com/documentation/linkpresentation/lpmetadataprovider)

The archived extension guide remains useful for extension architecture, but current SDK headers, Xcode templates, App Review requirements, and signed-candidate behavior are the release authority.

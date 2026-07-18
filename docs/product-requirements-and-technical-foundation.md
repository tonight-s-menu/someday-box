# someday-box / 改天盲盒

## Product requirements, functional translation, and native iOS technical foundation

| Field | Decision |
| --- | --- |
| Document status | Product and engineering baseline for the MVP |
| Product name | `someday-box` in English; `改天盲盒` in Simplified Chinese |
| Product category | A serendipity-driven activity box for free time |
| Primary platform | iPhone, portrait-first |
| Minimum deployment target | iOS 18.0 |
| Runtime model | Fully on-device; no account, server, sync, analytics, ads, or LLM |
| MVP language support | Simplified Chinese and English |
| Last reviewed | 2026-07-19 |

This document translates the initial concept into a bounded product specification and an implementation-oriented technical foundation. It is deliberately more specific than a concept brief: ambiguous behaviors are resolved, source-of-truth boundaries are stated, and acceptance evidence is defined. It does not contain implementation code.

### Document map

- **Product definition:** Sections 1–5 define the promise, users, guardrails, MVP boundary, and paper semantics.
- **Experience and behavior contracts:** Sections 6–10 define navigation, end-to-end flows, functional requirements, sources of truth, and the draw policy.
- **Design and engineering foundation:** Sections 11–16 define the interaction language, quality attributes, native iOS stack, architecture, persistence, and private diagnostics.
- **Verification and operation:** Sections 17–19 define tests, delivery gates, release evidence, rollback, and recovery.
- **Product validation and readiness:** Sections 20–23 define scenarios, risks, Definition of Done, and the final MVP acceptance statement.
- **Platform sources:** Section 24 records the dated Apple references behind the technical baseline.

---

## 1. Executive decision

`someday-box` is not a task manager. It stores things a person might enjoy doing later and helps rediscover one when free time appears.

The product loop has only two primary verbs:

1. **Put it in** — capture a passing interest without scheduling it.
2. **Draw it out** — describe the available moment and receive a suitable surprise.

The MVP validates one central hypothesis:

> When people have unstructured free time, a context-compatible random draw is more inviting and more actionable than browsing another saved-items list.

The first public MVP is a native, offline-capable iOS app. Its only situational variable is time: every paper has a user-selected duration bucket, and every draw begins with the time currently available. Deterministic rules form an eligible candidate pool, then a weighted random draw chooses inside that pool. The app contains no natural-language classification, task decomposition, recommendation service, LLM, account, backend, or developer-operated data collection.

The MVP must feel complete despite being small. It includes the full user lifecycle from capture through memory, as well as local persistence, versioned migration, manual backup and restore, privacy controls, accessibility, release validation, and a credible rollback path.

### 1.1 One-line product descriptions

**English**

> A serendipity-driven activity box for your free time.

**Simplified Chinese**

> 把“改天想做”收进盲盒，在有空的时候抽一张。

### 1.2 The product promise

- Capture should feel lighter than creating a task.
- A draw should be surprising, but never incompatible with the selected time.
- Skipping should carry no guilt or penalty.
- Completing an idea should create a memory, not a productivity score.
- Personal content should remain under the user's control and should not be transmitted by the app.

---

## 2. Problem definition

### 2.1 The timing mismatch

Interest and availability often happen at different moments. A person sees a restaurant, recipe, film, walk, creative technique, article, or small social gesture while they are busy. Later, free time arrives, but the earlier interest is buried among screenshots, browser tabs, social-media saves, and notes.

Traditional task tools solve a different problem:

- A task manager asks, **“What must I do?”**
- `someday-box` asks, **“What could I enjoy doing now?”**

The product therefore connects two moments:

```text
Interest appears → capture a possibility → free time appears → rediscover a possibility
```

### 2.2 Primary jobs to be done

When I encounter something interesting but cannot act on it now, I want to store it in a few seconds without deciding a date, so that the interest is not lost.

When I unexpectedly have free time, I want one suitable suggestion without scanning a long list, so that choosing does not consume the free time itself.

When I actually do something from the box, I want it to become part of a gentle life record, so that the app reflects experiences rather than unfinished obligations.

### 2.3 Initial target user

The first target user regularly saves ideas across social apps, notes, screenshots, and browser tabs, but does not want another planning system. They are comfortable making a one-tap estimate such as “about 30 minutes” and value surprise more than optimization.

The MVP does not target teams, household coordination, professional project management, clinical behavior change, or people who require deadline-driven planning.

---

## 3. Product principles and hard guardrails

These are product contracts, not optional tone guidelines.

### 3.1 Low pressure by construction

- No deadline, due date, overdue state, urgency, or priority.
- No red warning for inactivity.
- No streaks, completion rate, productivity chart, or backlog guilt.
- No notification designed to pressure a return.
- A time estimate describes situational fit; it is not a promise to finish.

### 3.2 Capture before classification

- A title and one duration tap are the only fields required to save.
- The app does not guess duration because the MVP has no LLM or classifier.
- The duration requirement is the smallest honest input contract that makes time-safe drawing possible.
- An optional note stays collapsed by default and never becomes a save gate.

### 3.3 Constrained surprise

- Rules decide which papers are eligible.
- Randomness chooses among eligible papers.
- The algorithm must never silently relax a condition to manufacture a result.
- The UI must say when there is no match and let the person change the context or add a new paper.

### 3.4 User-visible truth

- A label such as “fits 30 minutes” is shown only when the stored metadata supports it.
- A paper cannot enter the Box without an explicit duration choice; the app never disguises a guess as user input.
- A completed memory is backed by a persisted completion record.
- A “local only” claim is backed by the shipped dependency graph, capabilities, runtime network evidence, and privacy manifest—not by interface copy alone.

### 3.5 The Box remains the mental model

- Home emphasizes **Put in** and **Draw out**.
- The list is a management surface, not the primary product surface.
- Internal categories may support filtering, but the person should not need to manage multiple folders.
- Product copy uses “paper,” “box,” “draw,” “put back,” and “memory,” not “task,” “backlog,” “overdue,” or “productivity.”

---

## 4. MVP definition

### 4.1 P0: required for the first public MVP

| Capability | MVP decision |
| --- | --- |
| First launch | A permission-free introduction to “put in / draw out,” followed by an empty Home state |
| Quick capture | Title, one-tap duration estimate, and an optional note |
| Local persistence | All product data survives process termination and device restart |
| Draw context | Available time is the only situational input |
| Candidate filtering | Lifecycle, Current Pick, Unresolved-result reservation, time, and current-session repetition |
| Random draw | Versioned, testable weighted random selection among eligible candidates |
| Reveal | Short paper-draw animation, visible explanation chips, optional haptic feedback, and a Reduce Motion alternative |
| Outcome actions | Do this, draw another, dismiss, then complete or return the single Current Pick from Home/detail |
| Box management | Browse, search, filter, edit, archive, restore, and permanently delete |
| Memories | Month-grouped completion history with immutable snapshots and an option to put an idea back |
| Data management | Versioned local backup export, full restore, and erase-all-data controls |
| Local-only boundary | No product-initiated network request, account, CloudKit, remote configuration, analytics, ads, or third-party SDK |
| Languages | Simplified Chinese and English through String Catalogs |
| Quality | Dark mode, Dynamic Type, VoiceOver, Voice Control naming, Reduce Motion, automated accessibility audits, and physical-device validation |

The core product hypothesis can be tested internally after capture, time-safe draw, Current Pick, and Memories work end to end. Backup, recovery, privacy, localization, and packaged-device gates are still P0 for a public MVP; an internal interaction prototype must not be reported as a releasable app.

### 4.2 Explicitly outside the MVP

- LLMs, embeddings, semantic parsing, automatic tagging, automatic duration estimation, or automatic next-action generation.
- Accounts, sign-in, developer backend, CloudKit sync, cross-device merge, collaboration, or sharing between users.
- GPS, maps, weather, opening hours, travel-time calculation, booking, or background location.
- Photo, camera, microphone, audio, contact, calendar, or notification permission.
- Image and voice attachments, link previews, metadata scraping, or in-app web content.
- Share Extension, widgets, App Intents, Shortcuts, Apple Watch, macOS, and a dedicated iPad layout.
- Physical shake-to-draw. The explicit button is more discoverable and accessible; a physical gesture may be tested only after the core draw proves valuable.
- Three-choice mode, destiny mode, surprise slider, skip-reason learning, snooze, and personalized preference scoring.
- Automatic decomposition or a special long-term-project lifecycle. Static helper copy encourages one finite or time-boxed activity, but the app does not semantically classify or block a valid title.

### 4.3 Candidate follow-up scope

The next releases should be chosen from observed user friction, not from the size of the original idea list.

| Candidate | Earliest phase | Required evidence before work begins |
| --- | --- | --- |
| Share Extension for text and URLs | Post-MVP | Manual capture from other apps is a repeated source of abandonment |
| Three-choice draw | Post-MVP | Single draws feel coercive or repeated redraw is common |
| Snooze and skip reasons | Post-MVP | People repeatedly see temporarily unsuitable papers |
| Manual place and energy context | Post-MVP | Time-only draws are repeatedly unsuitable and users accept the extra capture fields |
| Physical shake gesture | Post-MVP experiment | The explicit draw loop already has repeat use and the gesture passes accessibility review |
| Surprise-level control | Later | Users can articulate a stable need beyond time fit and freshness |
| Long-term ideas and manual next actions | Later | Users repeatedly try to capture projects that cannot be expressed as one finite paper |
| Attachments | Later | Text and optional pasted source text are insufficient |
| On-device heuristics | Later, separate decision | Rule-based MVP evidence shows a concrete classification burden |
| Any LLM or cloud capability | Separate product, privacy, and architecture review | It must not be introduced as an invisible dependency or a fallback |

---

## 5. Product semantics

### 5.1 A paper is a possibility, not an obligation

Examples of good papers:

- Make an iced matcha latte.
- Message a university friend and ask how they are.
- Sort 20 photos from the last trip.
- Browse the second-hand shops in Fitzroy.
- Watch *Perfect Days*.

Broad titles that benefit from a more specific note:

- Learn Spanish.
- Build my own game.
- Travel around Tasmania.

These titles remain valid when paired with a duration: “Learn Spanish — 30 minutes” means spend up to 30 minutes on Spanish, not finish learning the language. Static helper copy suggests a more concrete paper such as “Complete one Spanish lesson” or “Spend 30 minutes writing the core game loop,” but the no-LLM MVP does not detect, rewrite, reject, or decompose the title. Any valid title plus duration can be saved.

### 5.2 Duration model

User-facing duration choices map to stable internal buckets.

| User-facing choice | Maximum duration used for filtering | Internal meaning |
| --- | ---: | --- |
| Up to 10 minutes | 10 minutes | Very small spark |
| Up to 30 minutes | 30 minutes | Short activity |
| Up to 1 hour | 60 minutes | Medium session |
| Up to 2 hours | 120 minutes | Focused session |
| Up to 4 hours | 240 minutes | Half-day activity |
| Up to 8 hours | 480 minutes | Day activity |

The maximum duration is used because a suggestion must fit inside the selected budget. Future releases may add ranges, but the MVP should not collect precision it cannot justify.

The stable raw identifiers are `up_to_10_minutes`, `up_to_30_minutes`, `up_to_60_minutes`, `up_to_120_minutes`, `up_to_240_minutes`, and `up_to_480_minutes`. Draw context uses the same six values plus `not_sure`. Localized labels may change; these persisted identifiers may not be repurposed.

### 5.3 Why time is the only MVP context variable

Place, energy, cost, and company can improve a mature recommendation pool. Without automatic classification, however, every new filter also adds a field to every captured paper. That directly threatens the ten-second capture promise before the basic draw behavior has been validated.

The MVP therefore makes a deliberate trade-off:

- Time is required and strictly enforced.
- All other situational facts remain part of the human-readable title or note.
- The result explains duration fit only.
- If usability evidence shows that time-fit papers are still frequently unsuitable for a stable reason, that reason can become the next explicit metadata field through a versioned product and schema change.

---

## 6. Information architecture

The root interface contains three tabs. Capture and Draw are focused flows launched from Home rather than permanent tabs.

| Surface | Purpose | Primary actions |
| --- | --- | --- |
| Home | Reinforce the product loop | Put in a new idea; draw a paper; resume the current paper |
| Box | Inspect and manage papers in the Box or archive | Search, filter, edit, archive, restore, delete |
| Memories | Revisit completed experiences | View by month; open detail; put back |
| Capture sheet | Save a passing idea with minimal friction | Save title and duration; optionally add a note |
| Draw flow | Describe the current moment and reveal one suitable paper | Select time; draw; accept; draw another |
| Settings | Control local behavior and data | Haptics; backup; restore; app status; erase data |

Settings is opened from a persistent trailing toolbar button on Home. The button uses the standard settings symbol with the visible or accessibility label **Settings / 设置**; it is not hidden in a gesture or an overflow menu.

### 6.1 Home

Home should contain:

- Localized greeting or a neutral time-of-day message.
- A central Box illustration whose paper density reflects the drawable-paper count without becoming a literal chart.
- Drawable paper count: Active papers with a supported duration, minus the Current Pick and any paper reserved by the single Unresolved Draw Attempt, before applying a time filter.
- Primary button: **抽一张 / Draw a paper**.
- Secondary button: **丢进一个想法 / Put in an idea**.
- The single current paper when one exists, with **Done** and **Put back** actions.
- Up to two recent memories as quiet reassurance, not a performance summary.

Home must not show overdue, completion rate, streak, priority, or a red badge for untouched ideas.

### 6.2 Capture

The Capture sheet opens with keyboard focus in the title field.

Required visible content:

- Prompt: **刚刚想到什么？ / What just came to mind?**
- Title field.
- Duration chips.
- Primary action: **丢进盲盒 / Put it in the Box**.

An optional note is disclosed below the primary fields. Save is enabled after title, note, duration, and projected-capacity validation succeeds. Character, byte, or unsupported-control failures are shown inline without rewriting the person's text. At full item capacity, the draft stays intact and the action links to Box management and backup. The prompt clarifies that a good paper is one small thing that can be started or completed during a single free period.

### 6.3 Draw context

The Draw flow asks one required question first:

**How much time do you have?**

- Up to 10 minutes
- Up to 30 minutes
- Up to 1 hour
- Up to 2 hours
- Up to 4 hours
- Up to 8 hours
- Not sure

Each finite choice is an upper bound: a person with only one hour selects 1 hour, never the 2-hour bucket. “Not sure” removes the budget comparison but still requires a supported stored duration; it does not mean that papers may omit their own duration. Place, energy, money, social company, exact location, and weather do not appear in the MVP.

### 6.4 Reveal and result

Selection is completed and persisted before the reveal animation begins. Animation never decides the result.

The normal reveal sequence is approximately 0.6–1.0 seconds:

1. The Box makes a short, restrained movement.
2. A paper rises and unfolds.
3. A light impact haptic accompanies the reveal when haptics are enabled.
4. The title and verified fit chips become readable.

The result presents:

- Paper title.
- Note when present.
- Duration.
- For a finite selected budget, a short explanation such as “Fits 30 minutes.” A “Not sure” draw shows the stored duration without claiming contextual fit.
- Primary action: **就做这个 / Do this**.
- Secondary action: **换一张 / Draw another**.
- Dismiss action.

With Reduce Motion enabled, the movement is replaced by a short cross-fade. VoiceOver announces the result only after the content is stable.

### 6.5 Box

The Box is visually paper-like but functionally uses familiar native list behavior.

MVP filters:

- All papers currently in the Box: Active papers minus the Current Pick and the paper reserved by an Unresolved Draw Attempt.
- Duration buckets.
- Current paper.
- Archived.

Local search matches title and note. Default sorting is newest first; a “least recently drawn” sort may be added only if usability testing shows a need.

If a migrated store contains an unknown duration raw value, the paper shows **Duration needs updating**, remains editable and exportable, and is excluded from every draw. The app must not crash, guess, or hide it.

Each paper detail shows the actions valid for its lifecycle: Active supports edit, mark as done, archive, and permanent delete; Archived supports restore and permanent delete. Permanent deletion requires confirmation and removes the paper, its associated memory snapshots, and any retained Draw Session containing that paper; other papers and their Memories remain intact. Archive is the non-destructive choice.

An Unresolved Draw Attempt reserves its paper. The reveal is presented as a global resumption gate before the three root tabs. Until the person accepts, redraws, or dismisses that result, no Capture, edit, lifecycle, delete, backup, restore, or erase mutation may begin. Application use cases enforce this global gate even if a stale view or accessibility action attempts a mutation; this also prevents deletion of an earlier paper from cascading through the still-open Session.

### 6.6 Memories

Memories are grouped by the device's current calendar month and display:

- Title snapshot.
- Completion date.
- Duration, or **Previous duration unavailable** when an opaque unsupported snapshot was preserved from migrated/imported data.

There is no score, streak, or “completed tasks” language. Every completion creates a new immutable Memory. The Memory action follows the source paper's current truth:

- Completed or Archived: **Put back in the Box** transitions the source to Active and preserves every historical Memory.
- Already Active in the Box: the action is disabled and says **Already in the Box**.
- Active as Current Pick: the action is disabled and says **Current paper**.
- Permanently deleted: impossible in the MVP because deletion cascades to its Memories.

Completed detail also permits permanent deletion through the same explicit cascade confirmation used elsewhere.

### 6.7 Settings and data management

Settings contains:

- Haptics toggle.
- A plain-language local-data and privacy explanation.
- Export backup.
- Restore backup.
- App status: app version, build, schema version, backup format version, selection-policy version, active generation, retained/quarantined generation status, total Active count, drawable count, memory count, and capacity headroom.
- Erase all local data.

Debug feature switches, a raw database browser, and editable production flags must never ship in this screen.

---

## 7. End-to-end user flows

### 7.1 First launch

1. The app opens without asking for any permission.
2. One short introduction explains “Put it in. Draw it out.”
3. Home shows an empty Box and prompts the person to add the first paper.
4. Optional starter suggestions are shown as prompts only; no sample data is saved without a tap.
5. After the first paper is saved, Home reflects the real persisted count.

### 7.2 Capture a paper

1. The person opens Capture.
2. The title field is already focused.
3. They enter a title and tap one duration.
4. They may expand an optional note.
5. The app validates locally and commits the paper in one transaction.
6. Success dismisses the sheet and updates Home immediately.
7. Failure keeps the draft visible and shows a recoverable error; it must not dismiss or silently lose text.

Target interaction time for title plus duration is under 10 seconds in moderated usability testing. Static helper copy shows examples of a finite next experience. The app neither detects that a title is a broad project nor generates a next action.

### 7.3 Draw a paper

1. The person selects available time.
2. The app builds the candidate pool using hard lifecycle, current-paper, reserved-result, time, and session rules.
3. If the pool is empty, the app explains that no papers fit and offers **Change time** or **Add a paper**. It does not ignore the selected time.
4. If the pool is not empty, the selection policy chooses one paper.
5. A Draw Session and Draw Attempt are persisted before reveal.
6. The app reveals that exact paper.

If an unresolved Draw Attempt already exists after an interruption, the app resumes it before exposing Home, Box, Memories, Capture, or another Draw flow. It never creates another session or selection.

### 7.4 Accept, redraw, or dismiss

- **Do this** atomically resolves the attempt as Accepted, creates the device's single Current Pick, and ends the Draw Session. The Box Item lifecycle remains Active, but the Current Pick reference excludes it from drawing until resolved by Done, Put back, Archive, or Delete.
- **Draw another** atomically resolves the current attempt as Redrawn and, when a candidate exists, creates the next Unresolved attempt in the same session. The paper stays Active and is excluded for the rest of that session.
- **Dismiss** resolves the current attempt as Dismissed and ends the Draw Session without altering the paper lifecycle.
- When no unseen candidate remains in the session, the app says the current round is exhausted and offers to change time or reshuffle explicitly.

If a restored or upgraded Unresolved result belongs to a policy version the current build can preserve but no longer execute, the exact persisted result still resumes and **Do this** and **Dismiss** remain available. **Draw another** is disabled with an explanation that this draw came from an older version; dismissing it permits a new Session under the current policy. The app never pretends that `mvp-v1` generated an older result.

When a Current Pick already exists, Home emphasizes resolving it with **Done** or **Put back**. Archive and permanent delete remain available in Current Pick detail and also clear the reference. A new draw is unavailable until one of those resolutions succeeds. This prevents accepted papers from accumulating into an “In Progress” backlog.

There is no hidden skip penalty in the MVP. Drawing another is too ambiguous to interpret as loss of interest.

### 7.5 Complete or put back

- **Done** is available from the Current Pick on Home/detail and from an Active paper's detail; it is not a third action on the initial reveal. It changes the Active paper to Completed, clears Current Pick when applicable, and creates an immutable Completion Memory snapshot in the same transaction. The accepted Draw Attempt remains Accepted while retained but is not needed to reconstruct Current Pick and may follow normal ended-record compaction.
- **Put back** clears Current Pick without changing the paper's Active lifecycle or applying a penalty.
- Completion has no deadline relationship and no lateness meaning.
- A failed save leaves the prior lifecycle intact and presents a retry.

### 7.6 Restore from a backup

The public MVP supports a full replacement restore, not a conflict-prone merge.

1. The user selects a `.somedaybox` file with the system file importer.
2. The app checks file size and disk headroom, then validates format, checksum, open/closed raw-value rules, and every Section 9.8 domain invariant before any active data is changed.
3. The app shows a preview of items, Current Pick when present, and memories that will replace current data.
4. The user confirms the destructive replacement.
5. The app acquires an exclusive product-data operation gate. Reads may remain visible during staging, but every Capture, draw, edit, lifecycle, delete, backup, restore, and erase mutation is disabled until rollback or journaled cleanup fully finalizes the operation.
6. When the current store is readable, the app creates an operation-scoped rollback export. It always leaves the prior store generation physically intact.
7. The app builds the restored dataset inside a separate store generation, saves it, releases every context/container reference, creates a fresh container for that generation, and verifies its counts and invariants before activation.
8. A small operation journal and atomic active-generation pointer switch activate the staged store. The UI then opens and refetches from only that generation.
9. A failure or interruption before the durable commit boundary keeps or returns the pointer to the prior generation. After that boundary, rollback is forbidden and idempotent cleanup removes normal retained generations and rollback exports before product mutations resume or success is shown.

Cross-device merge and conflict resolution are explicitly deferred.

### 7.7 Resume after interruption

- If the app is terminated after a result is selected but before the attempt is resolved, the persisted unresolved result is offered again on next launch.
- The app must not select a different paper merely because the animation was interrupted.
- No second unresolved attempt or Draw Session may be created while that result is awaiting resolution.
- The result is a global resumption gate. The reserved paper and all root-tab mutations remain unavailable until Accept, Draw another, or Dismiss resolves the Attempt and its Session transactionally.
- Draft text that has not been saved may be retained for the current process, but crash-safe draft recovery is not an MVP promise.

---

## 8. Functional requirements and acceptance rules

### 8.1 Capture

| ID | Requirement | Acceptance rule |
| --- | --- | --- |
| CAP-01 | Require only title and duration | When text and store capacity are valid, a trimmed title of 1–120 user-perceived characters and at most 512 UTF-8 bytes plus one duration choice can save without another semantic field |
| CAP-02 | Add a duration in one tap | All duration choices are visible without opening a second screen |
| CAP-03 | Require an explicit duration honestly | Save remains disabled until duration is selected; the app does not infer or hide a default duration |
| CAP-04 | Support an optional note | Note can be omitted without another prompt |
| CAP-05 | Prevent accidental draft loss on save failure | A forced persistence error leaves the entered draft on screen |
| CAP-06 | Permit duplicate titles | Two papers with the same title save as distinct UUID-backed records |
| CAP-07 | Keep user content local | Capture makes no network request and requires no permission |
| CAP-08 | Fail recoverably at a validation or capacity boundary | Unsupported control text, a byte overflow, or full item capacity keeps the draft visible, explains the exact local limit, and offers a route to manage or export existing data; nothing is silently truncated or deleted |

### 8.2 Draw

| ID | Requirement | Acceptance rule |
| --- | --- | --- |
| DRW-01 | Require an available-time choice | Draw cannot begin until a time or “Not sure” is selected |
| DRW-02 | Apply time as a hard constraint | A paper with a known maximum duration above the budget is never drawn |
| DRW-03 | Exclude non-actionable lifecycle states | Completed and Archived papers never enter the candidate pool |
| DRW-04 | Exclude the Current Pick | The accepted paper cannot be drawn again until Current Pick is resolved by Done, Put back, Archive, or Delete |
| DRW-05 | Keep the context model time-only | No hidden place, energy, cost, or preference inference affects an MVP result |
| DRW-06 | Preserve surprise | The final result is sampled from the eligible pool rather than always selecting the highest-ranked item |
| DRW-07 | Avoid current-round repetition | A shown paper does not reappear until the session is explicitly reshuffled |
| DRW-08 | Persist before animation | Force termination during reveal resumes the same unresolved result |
| DRW-09 | Explain an empty pool | The screen offers changing time or adding a paper and does not relax the selected time silently |
| DRW-10 | Version the policy | Every attempt stores the selection-policy version and eligible-candidate count |
| DRW-11 | Prevent a second current paper | A new Draw Session cannot start until the existing Current Pick is completed, put back, archived, or deleted |
| DRW-12 | Handle one candidate truthfully | The result is shown, and asking for another explains that no other paper fits rather than repeating it silently |
| DRW-13 | Prevent competing unresolved results | Entering Draw resumes the one global Unresolved attempt; it never creates a second unresolved result or session |
| DRW-14 | Fail safe on unsupported duration data | A paper whose persisted duration raw value is unknown remains manageable/exportable but never enters any draw, including Not sure |
| DRW-15 | Reserve the unresolved result | Before an Unresolved Attempt is resolved, only Accept, Draw another, and Dismiss product-data mutations are allowed; the reserved item is not counted as drawable or replaced by another result |
| DRW-16 | Close an unsupported-policy reveal safely | The persisted result can be accepted or dismissed, but Draw another is disabled until a new Session starts under a policy the build can execute |
| DRW-17 | Never deadlock a valid reveal at capacity | Deterministic maintenance plus reserved headroom always permits Accept and Dismiss; Redraw is offered only when the next Unresolved state also preserves an exit path |

### 8.3 Lifecycle and Memories

| ID | Requirement | Acceptance rule |
| --- | --- | --- |
| LIFE-01 | Accept a draw | The attempt records acceptance and the paper becomes the sole Current Pick |
| LIFE-02 | Draw another without punishment | The attempt records redraw; the paper stays Active and receives no long-term score penalty |
| LIFE-03 | Put a paper back | Current Pick is cleared; the Active paper and its original creation history remain intact |
| LIFE-04 | Complete from Current Pick or Active detail | The lifecycle change, Current Pick clearing when applicable, and Completion Memory are atomic; any retained accepted Attempt remains Accepted but may follow the ended-record compaction policy |
| LIFE-05 | Keep memory text stable | Restoring, editing, or archiving the source paper later does not rewrite an existing memory snapshot |
| LIFE-06 | Reopen a memory according to source truth | Completed/Archived becomes Active and keeps all Memories; already Active or Current Pick produces an explanatory no-op |
| LIFE-07 | Archive without deleting | Archived content is hidden from drawing but can be restored |
| LIFE-08 | Permanently delete with closure | Item, associated Memories, and every retained Session containing an Attempt for that Item are removed after confirmation; other Items, Memories, and `lastShownAt` values remain intact |
| LIFE-09 | Persist the Current Pick | Acceptance survives process termination and relaunch without creating a second accepted paper |
| LIFE-10 | Fail recoverably at Memory capacity | A completion that would exceed a count or canonical-size limit leaves Item, Current Pick, and Memories unchanged and offers export plus explicit content management; it never discards an older Memory automatically |

### 8.4 Box, search, and navigation

| ID | Requirement | Acceptance rule |
| --- | --- | --- |
| BOX-01 | Show the persisted drawable count | Home and Box use Active with SupportedDuration minus Current Pick and Unresolved-reserved item and agree after save, reveal, accept, dismiss, put back, archive, restore, complete, migration, and relaunch |
| BOX-02 | Search locally | Search returns title and note matches without transmitting a query |
| BOX-03 | Provide lifecycle/duration filters | Each filter derives from persisted fields or the Current Pick reference, not view-only labels |
| BOX-04 | Preserve navigation identity | Routes carry lightweight identifiers; loading failure shows an error rather than stale copied content |

### 8.5 Data management and privacy

| ID | Requirement | Acceptance rule |
| --- | --- | --- |
| DAT-01 | Persist locally | Airplane-mode create, edit, draw, complete, terminate, and relaunch all preserve truth |
| DAT-02 | Export a portable backup | A versioned `.somedaybox` JSON document contains product records: items, Current Pick, sessions/attempts, and memories |
| DAT-03 | Restore all-or-nothing | Corrupt, truncated, future-version, or domain-invalid files never replace the active store generation; every Section 9.8 invariant is validated before activation |
| DAT-04 | Erase local data explicitly | Two-step confirmation starts a journaled empty-generation switch and idempotent cleanup of every app-owned data copy; external exports and OS-owned data remain outside app control |
| DAT-05 | Keep content out of logs | Titles, notes, URLs, full file paths, and record UUIDs never appear in unified logs or diagnostic exports |
| DAT-06 | Make no product network request | Static dependency/capability review and runtime network inspection both show no app-initiated connection |
| DAT-07 | Avoid silent migration reset | A store-open or migration failure enters recovery UI and never automatically deletes the store |
| DAT-08 | Preserve the prior store during restore | Restore builds and reopens an independent store generation before an atomic active-generation switch; interruption before the durable commit boundary returns to the prior generation, while interruption after it resumes cleanup without rolling back committed truth |

---

## 9. Domain model and sources of truth

### 9.1 Separate lifecycle from draw behavior

“Drawn,” “accepted,” “redrawn,” and “dismissed” describe an encounter, not the permanent identity of a paper. They belong to Draw Attempt records. The paper lifecycle remains small:

```text
Active ── complete ──> Completed
Active ── archive ──> Archived
Archived ── restore ──> Active
Completed ── put back ──> Active, while preserving the prior memory
```

Acceptance creates the separate singleton Current Pick reference; it does not add another lifecycle state. Put back clears that reference. This prevents contradictory states such as a paper being simultaneously shown, redrawn, and accepted, and prevents accepted papers from becoming an unbounded in-progress list.

### 9.2 Box Item

| Field | Type-level meaning | Rules |
| --- | --- | --- |
| `id` | Stable UUID | Never reused |
| `title` | User-entered text | Trimmed single line; 1–120 user-perceived characters; at most 512 UTF-8 bytes; no C0 controls |
| `note` | Optional user-entered text | Maximum 1,000 user-perceived characters and 4,096 UTF-8 bytes; tab and line feed are the only permitted C0 controls |
| `durationBucketRaw` | Stable English raw value | Unknown values decode to a visible unsupported state, remain editable/exportable, and are excluded from every draw |
| `lifecycleRaw` | `active`, `completed`, or `archived` | Valid transitions are enforced by domain use cases |
| `createdAt` | Absolute timestamp | Immutable |
| `updatedAt` | Absolute timestamp | Updated by a successful mutation |
| `completedAt` | Optional absolute timestamp | Present only while the source paper is Completed; cleared when put back |
| `lastShownAt` | Optional absolute timestamp | Cross-session freshness authority; updated in the same transaction that persists a newly selected Attempt |

No unused future field is added “just in case.” Place, energy, readiness, snooze, attachments, URLs, next actions, and skip reasons require explicit schema additions when their feature is approved.

### 9.3 Current Pick

| Field | Meaning |
| --- | --- |
| `itemID` | The one accepted Active paper |
| `acceptedAt` | Absolute acceptance timestamp |

Current Pick is either absent or contains exactly one item reference. The acceptance transaction resolves the Draw Attempt and creates this self-contained reference; later workflow-record compaction is not required to reconstruct it. The referenced paper must be Active, but it is semantically outside the Box and excluded from the drawable count. Completing, putting back, archiving, or permanently deleting that paper clears Current Pick in the same transaction. Starting a new Draw Session is unavailable until one of those resolutions succeeds.

### 9.4 Draw Session

| Field | Meaning |
| --- | --- |
| `id` | Stable UUID for one context-setting round |
| `startedAt` / `endedAt` | Start is required; end is optional until accept, dismiss, candidate exhaustion, or explicit session replacement |
| `availableTimeRaw` | Selected time budget or Not sure |
| `policyVersion` | Exact draw-policy identifier |

### 9.5 Draw Attempt

| Field | Meaning |
| --- | --- |
| `id` | Stable UUID |
| `sessionID` | Owning Draw Session |
| `sequence` | Presentation order within the session |
| `itemID` | Selected paper |
| `eligibleCount` | Candidate count at selection time |
| `policyVersion` | Exact policy used for this selection |
| `shownAt` | Persisted before animation |
| `outcomeRaw` | `unresolved`, `accepted`, `redrawn`, or `dismissed` |
| `resolvedAt` | Optional absolute timestamp |

The persisted attempt is the source of truth for the current reveal and its session sequence. Production selection uses the system random generator; deterministic seeded generators are injected only in tests. A production seed is not required to make the already-persisted result truthful.

Draw Sessions and Attempts are a durable workflow journal, not an unlimited activity feed. Cross-session freshness reads `BoxItem.lastShownAt`, which is written atomically with each new Attempt. After a Session ends, its records are eligible for safe compaction; Current Pick is already self-contained and does not protect an ended Attempt.

Compaction is deterministic. Sort ended Sessions by `endedAt` descending, then `startedAt` descending, then UUID bytes ascending. Starting from the newest, retain the longest whole-Session prefix for which both the Session count is at most 1,000 and the cumulative resolved-Attempt count is at most 25,000. Delete every remaining ended Session and all of its Attempts in one transaction; never split a Session or renumber its Attempts. Before a new Session, backup, or Unresolved-result transition begins, this exact policy runs. Compaction never touches the open Session and never changes Box Items, `lastShownAt`, Current Pick, or Memories, so it cannot change user-visible life history or selection weights. The retention policy identifier is `draw-journal-v1`; changing ordering or limits requires a new identifier and fixtures.

### 9.6 Completion Memory

| Field | Meaning |
| --- | --- |
| `id` | Stable UUID |
| `sourceItemID` | Owning paper while it exists |
| `titleSnapshot` | Immutable title at completion |
| `noteSnapshot` | Optional immutable note at completion |
| `durationSnapshotRaw` | Duration at completion; an unknown opaque value is preserved and displayed as **Previous duration unavailable** |
| `completedAt` | Absolute completion timestamp |

Snapshots prevent a later edit from rewriting lived history. Repeated completions create repeated snapshots. Permanent deletion removes the source paper and all of its memory snapshots in the MVP; this closure is stated in the confirmation.

### 9.7 App metadata and preferences

SwiftData schema version remains the persistence authority. A small metadata record may expose:

- Backup format version.
- Selection-policy version.
- Last successful migration version and timestamp.
- Last successful manual backup timestamp.
- First launch timestamp.

`UserDefaults` is reserved for non-authoritative presentation preferences such as onboarding completion and haptics. It must not store papers, lifecycle state, draw outcomes, or completion truth. Presentation preferences are excluded from backup/restore and remain unchanged during product-data restore, avoiding a false cross-store atomicity claim.

### 9.8 Raw-value compatibility and domain invariants

Raw values are split deliberately into open and closed sets:

- `durationBucketRaw` and `durationSnapshotRaw` are open, non-empty opaque strings up to 64 UTF-8 bytes. Known values map to supported buckets. Unknown values round-trip unchanged, render as unsupported, and never enter a draw; they are not treated as an invalid enum during backup import.
- `policyVersion` is a printable, opaque identifier up to 64 UTF-8 bytes. Historical records may preserve a policy the current build no longer executes. An open Session with such a policy may resume its already-persisted result, but only Accept and Dismiss are executable; Redraw requires a policy in the build's explicit supported-policy set.
- `lifecycleRaw`, `availableTimeRaw`, and `outcomeRaw` are closed behavioral enums. An unknown value cannot be executed safely and makes a store generation or backup invalid.
- A released raw value is never reassigned to a different meaning. A format adapter may translate a documented older value, but generic decoding may not guess.

Every normal write, migration, staged restore, and fresh-container reopen validates the following persisted-state invariant set:

- One UUID identifies one logical record for its entire lifetime; duplicate IDs are invalid across each record type.
- Every Draw Attempt belongs to exactly one Draw Session and one existing paper unless all related records are removed together through the defined paper-deletion cascade.
- At most one Session has `endedAt == nil`; an open Session has exactly one final Unresolved Attempt. At most one Unresolved Attempt exists across the entire store.
- Every Session owns at least one Attempt. Attempt sequence values are contiguous from one within a Session, and one item may appear at most once in that Session. Only the final Attempt may be Unresolved; earlier Attempts are Redrawn. `resolvedAt` is absent exactly for Unresolved and present for every resolved outcome.
- A Session is open exactly while it owns an Unresolved Attempt. Accepted, Dismissed, or exhausted Sessions have `endedAt` and no Unresolved Attempt.
- The Unresolved Attempt references an Active paper with a supported duration, and that paper's `lastShownAt` equals the Attempt's `shownAt`.
- At most one Current Pick exists, and it references one existing Active paper. Current Pick is self-contained after the atomic acceptance transaction and does not require the Accepted Attempt to remain retained.
- Current Pick and an Unresolved Attempt cannot coexist.
- Every Attempt's `policyVersion` matches its Session, and its positive `eligibleCount` records the pre-weight eligible-set size for that selection.
- A Completed item has `completedAt` and at least one Completion Memory whose `completedAt` exactly equals it. The matching Memory is created in the same completion transaction; the app never infers it by taking the maximum timestamp because the device clock may move backward. Active and Archived items have no mutable `completedAt`; historical Memories may still exist for either.
- Every Completion Memory references an existing source item.
- Record counts, text bounds, raw-value bounds, reference graphs, and projected canonical backup size stay within the active backup-format limits.
- A store containing an Unresolved Attempt has computed resolution headroom after deterministic ended-Session compaction. `exitHeadroom` is the larger exact canonical-size delta of Accept and Dismiss. For an executable policy, `drawHeadroom` is the larger of `exitHeadroom` and one new Redraw Attempt plus `exitHeadroom`; at least one Attempt-count slot is also reserved. A newly activated or newly created Unresolved state must meet `drawHeadroom` when Redraw is offered, or only `exitHeadroom` when it is not.
- Diagnostic events are not a second product-history store.
- Cached counters and capacity estimates, if introduced, are derived and non-authoritative; an exact check decides any boundary mutation.

Application use cases additionally satisfy these transition postconditions; they are verified around the operation rather than inferred from an arbitrarily compacted snapshot:

- While an Unresolved Attempt exists, only Accept, supported-policy Redraw, and Dismiss may mutate product data; every unrelated or stale mutation fails with `drawResolutionRequired` and changes nothing.
- A successful selection creates an Attempt, sets the selected Box Item's `lastShownAt` to that Attempt's `shownAt`, and reserves exact capacity for at least one valid resolution atomically. This represents the latest selection event even if the wall clock was corrected backward.
- Accept, Redraw, and Dismiss first apply deterministic ended-Session compaction inside their transaction. Redraw commits only when the next Unresolved result retains at least `exitHeadroom`; if another Redraw would no longer fit, that action is disabled on the next reveal while Accept and Dismiss remain available. A failed capacity check leaves the prior result Unresolved and unchanged.
- Accept resolves the Unresolved Attempt, ends its Session, and creates Current Pick atomically. Completion changes lifecycle, creates one Memory, and clears Current Pick when applicable in one transaction.
- Putting a Completed paper back clears its mutable `completedAt`; the immutable Memory keeps the historical completion instant. Archiving or deleting the current paper clears Current Pick in the same transaction.
- Paper deletion removes the Item, all of its Memories, and every whole retained Session containing it in one transaction. Journal compaction never changes any Box Item, `lastShownAt`, Current Pick, or Memory.
- A generation-changing operation either reselects the complete prior generation before `committed` or retains the complete validated new generation at and after `committed`; no partial record-set replacement becomes authoritative.

---

## 10. MVP draw policy

### 10.1 Eligibility is a hard gate

For a paper to enter the candidate pool, every applicable condition must be true:

```text
Eligible =
  Active
  AND NotCurrentPick
  AND NotReservedByUnresolvedAttempt
  AND SupportedDuration
  AND TimeFit
  AND NotAlreadyShownInThisSession
```

#### Time fit

- For a known time budget, a paper fits only when its maximum duration is less than or equal to that budget.
- Every saved MVP paper has a duration because Save requires it.
- For “Not sure,” every Active paper with a supported duration except Current Pick or the Unresolved-reserved paper may participate.

### 10.2 Weighted surprise, not ranking

After filtering, each eligible paper receives a time-fit multiplier and a deliberately mild freshness multiplier.

```text
Draw weight = TimeFit × Freshness × RecentRepeat
```

Time fit favors an activity that makes meaningful use of the available period without excluding shorter options:

| Difference from selected time bucket | TimeFit |
| --- | ---: |
| Same bucket | 1.00 |
| One shorter | 0.85 |
| Two shorter | 0.70 |
| Three shorter | 0.55 |
| Four or more shorter | 0.45 |
| Draw time is Not sure | 1.00 |

`lastShownAt` is persisted on the Box Item in the same transaction as the selected Draw Attempt and remains authoritative after bounded Attempt compaction. With `age = max(0, now − lastShownAt)` measured as absolute elapsed seconds:

```text
Freshness = 1.5                                             when never shown
Freshness = 1.0 + 0.5 × min(age, 30 × 86,400) / (30 × 86,400) otherwise

RecentRepeat = 0.25 when lastShownAt exists,
                          age < 24 × 86,400,
                          and eligibleCount > 1
RecentRepeat = 1.00 otherwise
```

Exactly 24 hours is not recent; exactly 30 days receives the maximum freshness multiplier. A future `lastShownAt` caused by clock correction or damaged legacy data is clamped to age zero and is therefore both least fresh and recent. “An alternative exists” means another paper is present in the same final eligible set before weights are calculated, so it is exactly `eligibleCount > 1`.

- Weights stay in a narrow, explainable range so older and better-fitting papers gain visibility without turning the result into a deterministic ranking.
- Redraw count, acceptance count, and completion count do not change long-term weight in the MVP.
- Weighted random sampling supplies the randomness; no separate random score is added.

The policy identifier is `mvp-v1`, and the public v1 executable-policy set contains only that identifier. Any change to filtering or weighting requires a new policy version and regression fixtures. Retaining an older opaque identifier does not authorize the current engine to reinterpret it as `mvp-v1`.

### 10.3 Session behavior

- The set of already shown paper IDs is excluded during the current session.
- Creating the first or next Attempt also updates the selected item's `lastShownAt` to the same `shownAt` in that transaction; the reveal begins only after both persist.
- A redraw resolves the previous attempt and creates the next Unresolved attempt atomically; two unresolved results are never visible or persisted.
- If redraw finds no unseen candidate, it resolves the current attempt, sets the session's `endedAt`, and presents the exhausted-round state without creating another attempt.
- Accept and Dismiss both resolve the attempt and set `endedAt`; Accept also creates Current Pick in that transaction.
- Changing time resolves any visible attempt as Dismissed, ends the old session, and creates a new session only after the old transaction succeeds.
- Reshuffle is available only from an exhausted session and creates a new session with the same time. It does not reopen or mutate the ended session.
- Dismissing and later starting a new session allows previous papers to participate again under cross-session freshness weighting.
- Before a new Session starts or an Unresolved result resolves, ended workflow records are compacted to the Section 9.5 retention envelope inside the applicable transaction. A compaction failure reports a recoverable local error and does not create a partial transition.
- Candidate selection does not persist a new Unresolved Attempt unless the resulting store meets the Section 9.8 headroom rule. Accept and Dismiss are therefore guaranteed for every valid reveal. Redraw is enabled only when its projected next reveal preserves `exitHeadroom`; an edge-capacity explanation replaces the button otherwise.

### 10.4 Empty-pool diagnostics

The policy returns structured reasons, not only a null result:

- No active papers.
- Active papers exist, but their duration values are unsupported and require edit or Recovery.
- All papers exceed the selected time.
- All candidates were already shown in this session.

The UI converts these into supportive, non-technical copy. It never claims that an excluded paper was “bad” or that the user failed.

### 10.5 Testability

The policy is pure domain logic with injected:

- Clock.
- Calendar where needed.
- Random-number generator.

Unit tests use deterministic generators to verify exact selection boundaries. Distribution checks may exist as non-blocking health tests, but probabilistic tests must not make continuous integration flaky.

---

## 11. Visual and interaction direction

### 11.1 Brand character

The interface should feel warm, tactile, quiet, and lightly playful. It should not resemble a casino, productivity dashboard, or children's reward game.

Use:

- System typography with generous line height.
- One warm accent family plus semantic system colors.
- Paper surfaces with restrained depth and texture.
- Rounded native controls and clear hierarchy.
- SF Symbols where an icon genuinely clarifies an action.
- Light and dark palettes designed together.

Avoid:

- Excessive gradients, neon color, confetti, coins, points, and slot-machine language.
- Dense cards that expose every internal attribute.
- Fixed-height text that truncates at large Dynamic Type.
- Color as the only carrier of status.

Use semantic system controls and colors so the same content hierarchy remains coherent on both the minimum iOS 18 appearance and the current iOS 26 appearance. Do not hard-code a simulated glass treatment or adopt an Xcode 27 beta-only visual API for the MVP; both OS lines require visual acceptance.

### 11.2 Signature motion

The product needs one memorable motion: the Box briefly stirs and releases a paper. It should be fast enough that repeated use does not feel like waiting.

The animation is presentation-only. It cannot:

- Change the selected item.
- Delay persistence until completion.
- Block accessibility actions.
- Play indefinitely.
- Flash or rely on three-dimensional motion when Reduce Motion is enabled.

### 11.3 Haptics

- Context chip selection: light selection feedback.
- Paper reveal: light impact.
- Completion: success feedback.
- All haptics pair with visible state changes and can be disabled in Settings.
- Haptics never communicate information on their own.

### 11.4 Copy system

Preferred Simplified Chinese terms:

| Concept | Preferred copy |
| --- | --- |
| Capture | 丢进一个想法 / 丢进盲盒 |
| Draw | 抽一张 |
| Accept | 就做这个 |
| Redraw | 换一张 |
| Return | 放回盲盒 |
| Complete | 做过啦 |
| History | 回忆 |
| Capture guidance | 写下一件能在这段时间里开始的小事 |

Avoid “任务,” “待办,” “逾期,” “失败,” “效率,” and “完成率” in ordinary product copy.

---

## 12. Non-functional requirements

### 12.1 Offline and local-only behavior

The precise product promise is:

> The app creates no account and contains no developer server, sync, analytics, advertising, or product network request. Product data is stored in the app sandbox. System-level device backup and a file location explicitly selected by the user remain under iOS and user control.

This wording matters. iOS may include app data in a user-controlled iCloud or Finder device backup, and the system file picker may let the user export to iCloud Drive or another File Provider. Apple may also make system crash diagnostics available according to the person's OS sharing settings. Those are platform or user-controlled boundaries rather than app-operated sync or an embedded telemetry SDK, but they mean the product must not make the false absolute claim that data can never leave the physical device.

Release acceptance requires:

- No `URLSession`, web view, networking client, analytics SDK, ad SDK, or remote configuration in the product dependency path.
- No iCloud, CloudKit, App Group, Background Modes, Remote Notifications, Associated Domains, location, camera, microphone, Photos, Contacts, or calendar capability.
- SwiftData explicitly configured with no managed CloudKit database and no shared group container.
- Complete airplane-mode functionality.
- Runtime network inspection of the archived build.
- A clear Settings explanation that deleting the app may remove local data and that recovery depends on a manual export or the person's system-level device backup.

### 12.2 Privacy and security

- Use the app sandbox and iOS Data Protection for persistent user content.
- Set the app's default data protection to Complete because the MVP has no background data requirement.
- Do not implement custom encryption or claim end-to-end encryption.
- Do not log titles, notes, pasted text, URLs, record IDs, or full file paths.
- Use `OSLog.Logger` categories with stable error codes, counts, versions, and durations only.
- Add a privacy manifest from v1. Declare no tracking and no collected data when the shipped binary truthfully meets those conditions.
- Declare required-reason APIs used by the app, including app-owned UserDefaults access where applicable.
- Publish a plain-language privacy policy even if the App Store privacy label is “Data Not Collected.”
- An exported `.somedaybox` file is readable user data, not an encrypted vault. Its protection depends on the chosen destination.

### 12.3 Reliability and data integrity

- Each use case persists its complete related record set atomically: Session plus first Attempt plus `lastShownAt`, resolved Attempt plus next Attempt plus `lastShownAt`, accepted Attempt plus Current Pick, or completed Item plus Memory plus Current Pick clearing when it references that item. While an Unresolved Attempt exists, every product mutation other than Accept, Redraw, or Dismiss is rejected before its first write.
- One application-wide mutation arbiter serializes use cases. A restore holds its exclusive `dataOperationInProgress` gate from confirmation through `finalized` cleanup or completed pointer rollback, preventing a live-store write from being lost behind a staged-generation switch.
- A migration or store-open failure must never trigger automatic deletion.
- Backups that fail envelope, checksum, resource, or DTO/domain validation fail before the first staged-store write; a staged-store failure never changes the active-generation manifest.
- All published schema versions have upgrade fixtures generated by the corresponding released app, not only handwritten mock JSON.
- Absolute timestamps are stored independently of display timezone.
- A timezone change may alter month presentation but must not alter the completion instant.

### 12.4 Performance envelope

The expected personal dataset is small, but the implementation is tested against a frozen `performance-v1` fixture. It uses a fixed random seed and clock and contains 5,000 text-only Box Items: 4,000 Active, 500 Completed, and 500 Archived; there is no Current Pick or Unresolved Attempt; 1,000 ended Draw Sessions own 25,000 resolved Draw Attempts; and 5,000 Completion Memories are distributed across source items. Every item and memory uses an 80-character mixed Chinese/English title and a 500-character mixed Chinese/English note. The fixture is generated once, checked into the test-fixture bundle, and identified by a SHA-256 digest so performance results are reproducible. Candidate-selection and launch measurements use the full fixture. Capture persistence uses a derived fixture with one Active item removed; completion persistence uses one with one Memory removed. Each mutation ends exactly at, rather than above, the corresponding format-v1 capacity.

- Home becomes interactive within 1.5 seconds on the oldest supported reference iPhone in a release build under normal storage conditions.
- Capture persistence and candidate selection each complete within 150 milliseconds for the test dataset, excluding intentional reveal animation.
- Search updates without visible input lag.
- No animation or haptic loop continues in the background.
- Persistent app data remains comfortably below 50 MB for the 5,000-paper text fixture, excluding user-exported files.

These thresholds are release-test targets, not claims about every device under every storage condition.

A second frozen `backup-resource-v1` fixture exercises the public format limit rather than ordinary usage. Its canonical JSON is the largest payload at or below the byte cap that the fixture generator can construct within all other valid limits, is at least 100 MiB, contains both supported and bounded opaque unsupported durations, and has a checked-in generator recipe plus expected digest. On the oldest supported physical iPhone class, a Release build must:

- Preflight, decode, stage, release, reopen through a fresh container, validate, switch, and refetch this fixture in under 90 seconds without watchdog termination or memory pressure termination.
- Keep peak resident memory below 750 MiB as measured without the debugger attached.
- Keep the main thread responsive until the explicitly quiesced generation-switch interval, which remains below one second.
- At every forced-termination phase, recover the prior generation before `committed` and retain the committed generation while idempotently finishing cleanup at or after `committed`.
- Reject a 134,217,729-byte file from metadata before decode within one second and without a 25 MiB increase in resident memory.

If the stable implementation cannot satisfy these thresholds, the release must lower the advertised format limit in a new reviewed contract before any public v1 export exists; it may not ship a nominal limit that the oldest supported device cannot safely restore.

### 12.5 Accessibility

- Use native controls wherever possible.
- Support all Dynamic Type sizes without hiding primary actions or truncating the paper title.
- Interactive targets are at least 44 × 44 points.
- Every custom paper surface has a meaningful label, value, and actions.
- VoiceOver order follows visual order; visible action text matches Voice Control names.
- Status never relies on color alone.
- Test light/dark appearance, Increase Contrast, Differentiate Without Color, and Reduce Motion.
- Automated accessibility audits run on every major screen and state.
- Manual VoiceOver and Voice Control testing remains required because a green audit is not complete accessibility proof.

### 12.6 Localization

- All UI strings use String Catalogs; no user-facing string is assembled from English-only fragments.
- `zh-Hans` and `en` ship in the first public build.
- Dates, month grouping, pluralization, and numerals use system locale behavior.
- User-entered paper content is never auto-translated.
- Persisted enum values remain locale-independent.

---

## 13. Technical stack selection

The implementation should use the current stable Apple toolchain line, not beta-only APIs. As of this review, that means Xcode 26.6, Swift 6.3 compiler, Swift 6 language mode, and an iOS 18.0 deployment target. Xcode 26.6 requires a macOS Tahoe 26.2-or-later development/CI host; the exact Xcode and CI image must be pinned. Xcode 27 beta may be used for non-blocking compatibility smoke tests but not for production archives.

The toolchain choice is date-sensitive and must be refreshed before implementation and every App Store submission. Apple distinguishes the SDK required for upload from the app's lower deployment target.

The product and repository name remain `someday-box`; Swift target and module identifiers use `SomedayBox` because a hyphen is not a valid Swift identifier. The localized display names remain exactly `someday-box` and `改天盲盒`.

| Concern | Selected framework or approach | Why it fits | Not selected for MVP |
| --- | --- | --- | --- |
| Language | Swift, Swift 6 language mode | Native type safety, concurrency checking, no bridge layer | Objective-C, cross-platform runtime |
| UI | SwiftUI app lifecycle | Small native surface, adaptive text, animation, accessibility, dark mode | UIKit-first, React Native, Flutter |
| Navigation | `TabView`, `NavigationStack`, sheets | Matches three-root-tab information architecture | Custom coordinator framework |
| Transient UI state | Observation with `@Observable` | Modern, precise SwiftUI observation without Combine duplication | `ObservableObject` plus `@Published`, Redux framework |
| Persistent data | SwiftData local `ModelContainer` | New SwiftUI-first, small single-device model, native schema/migration support | Core Data, Realm, SQLite wrapper |
| Concurrency | MainActor for UI/main context; Swift Concurrency for file work | Clear isolation and `Sendable` boundaries | Callback queues, premature background model actor |
| Randomness | Injected random-number generator; system generator in production | Testable policy without custom runtime dependency | View-level `randomElement()` |
| Animation | SwiftUI phase/keyframe animation | Sufficient for one short staged reveal | SpriteKit, Core Animation framework layer |
| Haptics | SwiftUI sensory feedback | Native semantic feedback and simple fallback | Custom Core Haptics waveform |
| Backup | Foundation JSON, custom UTType, system file exporter/importer | Portable, versioned, user-controlled, no server | Copying an internal SQLite store, proprietary binary archive |
| Backup integrity | CryptoKit SHA-256 | Detects accidental corruption with a native implementation | Custom cryptography or a false encryption claim |
| Logging | `OSLog.Logger` | Native categories, levels, signposts, privacy controls | Third-party logging or crash SDK |
| Unit/integration tests | Swift Testing | Parameterized domain and persistence tests, concurrency-aware | New XCTest-only unit suite |
| UI/performance tests | XCTest and XCUIAutomation | Native UI automation, launch/performance metrics, accessibility audit | Third-party UI automation |
| Localization | String Catalog | Native pluralization and translation workflow | Hardcoded strings |
| Visual assets | SF Symbols and bundled assets | Offline and platform-consistent | Remote fonts or images |
| Runtime dependencies | Apple system frameworks only | Small supply chain and auditable local boundary | Any third-party runtime package |

### 13.1 Why iOS 18.0

iOS 17 is the lowest technical availability for several selected APIs, but it is not the recommended 2026 product baseline. iOS 18 retains essentially the same supported hardware class while reducing the compatibility and release-test matrix. Lowering to iOS 17 should require evidence that a meaningful part of the target cohort is unable or unwilling to update, not habit.

The minimum version is a product decision and must be recorded in an architecture decision record. It must not drift merely because a developer's installed SDK changes.

### 13.2 Why SwiftData

SwiftData is appropriate because the app is:

- New rather than migrating an existing Core Data store.
- SwiftUI-first.
- Single-device and text-heavy.
- Small enough to avoid complex batch-processing requirements.
- In need of explicit versioned schemas and migration tests.

SwiftData remains behind repository and mapping boundaries. SwiftUI views do not become the owners of persistence rules. If future evidence requires Core Data or explicit SQLite, the domain and application layers should remain intact.

### 13.3 Zero third-party runtime dependencies

This is an architectural choice, not an ideological rule for all time. For the MVP it provides:

- A smaller privacy and supply-chain audit.
- No hidden network or telemetry behavior.
- Fewer availability and upgrade constraints.
- Lower binary and maintenance complexity.

Any proposed dependency must later document its necessity, license, privacy manifest, network behavior, update policy, removal plan, and why the native framework is insufficient.

---

## 14. Architecture and dependency boundaries

Use a modular monolith inside one Xcode project. Do not create multiple packages merely to mirror the diagram; establish explicit folders and protocols first, then extract a local package only when a second target such as a Share Extension creates real reuse.

```text
SwiftUI Features
       ↓
Application Use Cases
       ↓
Pure Domain Rules
       ↑
Repository Protocols
       ↑
SwiftData / File / OSLog Adapters
```

### 14.1 App composition

Responsibilities:

- App lifecycle.
- Store-generation coordination and SwiftData container creation.
- Dependency construction.
- Root tabs and navigation routing.
- Recovery entry point when the store cannot open.
- Signed build configuration and feature manifest.

It contains no candidate filtering or random selection logic.

### 14.2 Domain

Pure Swift responsibilities:

- Box Item values and valid lifecycle transitions.
- Duration compatibility and Current Pick exclusion.
- Unresolved-result reservation and complete cross-record invariants.
- Candidate pool construction.
- Selection policy.
- Domain errors.
- Clock and random-number abstractions.

It must not import SwiftUI, SwiftData, OSLog, or localization resources.

### 14.3 Application use cases

User-intent boundaries:

- Capture item.
- Edit item.
- Start draw session.
- Draw next item.
- Accept draw.
- Dismiss or redraw.
- Complete item.
- Put back item.
- Archive and restore item.
- Permanently delete item.
- Export backup.
- Restore backup.
- Compact ended draw workflow records.
- Erase all data.

Use cases own transactions. A view must not directly change a SwiftData lifecycle value.

### 14.4 Data adapters

Responsibilities:

- SwiftData storage models.
- Domain/storage mapping.
- Repository implementations.
- `VersionedSchema` and `SchemaMigrationPlan`.
- Backup DTO encoding and validation.
- Store-generation manifests and operation journals.
- Import staging, independent-container validation, and atomic generation activation.
- Cascade deletion.

Persist mostly primitive values—String, Int, Bool, Date, and UUID—and stable raw enums. Avoid coupling the schema to complex nested Codable values.

### 14.5 Feature organization

Organize UI by user action:

- Home.
- Capture.
- Draw.
- Box.
- Memories.
- Settings and Data Management.
- Recovery.

Each feature owns short-lived `@Observable` state such as draft input, selected context, animation phase, and route. SwiftData remains the persistence truth; long-lived copied view models must not become a second item database.

### 14.6 Platform adapters

- Clock.
- Random generator.
- Haptic preference and sensory feedback.
- File importer/exporter.
- Logger.
- App version/build metadata.

JSON encoding may run away from the main actor, but only `Sendable` DTOs cross actor boundaries. SwiftData model instances remain in their owning context.

### 14.7 Intended repository shape

```text
someday-box/
├── App/
├── Domain/
├── Application/
├── Data/
├── Features/
│   ├── Home/
│   ├── Capture/
│   ├── Draw/
│   ├── Box/
│   ├── Memories/
│   ├── Settings/
│   └── Recovery/
├── DesignSystem/
├── Resources/
├── SomedayBoxTests/
├── SomedayBoxUITests/
└── docs/
```

This is a target shape for future implementation, not a request to create empty folders before they have content.

---

## 15. Persistence, migration, backup, and deletion

### 15.1 Local store configuration

- Use a SwiftData `ModelContainer` with an explicit schema and migration plan.
- Explicitly configure managed CloudKit as none.
- Explicitly configure no shared App Group container.
- Store durable support data in the app's Application Support area, not Caches or temporary directories.
- Place each physical SwiftData store in its own app-owned generation directory and open it through an explicit URL. A small checksummed active-generation manifest identifies the authoritative generation, schema version, and last clean-launch state; it is replaced atomically rather than edited in place.
- Keep an operation journal beside the manifest for migration and restore phases. The journal contains generation IDs, phase, versions, counts, and checksums, never titles or notes.
- Generation and artifact IDs are app-generated UUIDs resolved only beneath fixed app-owned Application Support directories. Imported filenames, JSON strings, paths, symlinks, and user-entered text can never become cleanup targets.
- Never copy, replace, or remove a SwiftData/SQLite store while a ModelContext or ModelContainer still references it. Quiesce UI access, save as required, tear down the owning UI subtree, and release all context/container references before a generation switch or cleanup.
- Use an in-memory configuration for tests.

### 15.2 Schema lifecycle

Start with `VersionedSchema` in v1 even though there is no earlier schema to migrate.

For every persisted change:

1. Create a new schema version.
2. State whether the change is lightweight or custom.
3. Keep old enum raw values readable.
4. Add a fixture created by the previously released build.
5. Verify record counts and invariants after migration.
6. Never gate schema migration behind a feature flag.
7. Prefer expand/contract changes; do not remove an old representation in the same release that introduces its replacement when rollback compatibility matters.

When an existing public generation requires migration, the app clones it before creating a container for that generation, runs migration in the clone, saves and releases all references, opens the clone through a fresh container, validates Section 9.8, then atomically switches the active-generation manifest. A failed or interrupted migration leaves the prior generation selected. If the container cannot open even without migration, production enters Recovery. It does not call a destructive delete API, fabricate an empty Box, or report success.

Migration runs before product UI and reuses the restore journal state machine with operation kind `migration`: `prepared` records prior/new generation IDs and schema versions; `validated` follows fresh-container validation; `switching` is durably flushed before manifest replacement; `switched` follows it; `committed` follows a fresh open plus invariant check and is the no-rollback boundary; `cleaning` owns removal of ordinary prior/staged artifacts; and `finalized` permits product UI and removal of the active-operation journal. Startup reconciles journal and manifest IDs. Any pre-`committed` normal migration selects the retained prior generation first; it may retry from that immutable source once in the current launch. At or after `committed`, startup keeps the new generation and resumes cleanup. A deterministic migration/validation failure enters Recovery without deleting either generation. Every pointer-switch and cleanup interruption phase is a released-store fixture test, not only a prose promise.

### 15.3 Backup contract

The `.somedaybox` format is a single, readable, versioned JSON document with a custom exported UTType conforming to JSON. Backup format versioning is independent of the internal SwiftData schema.

Envelope fields:

- Format version.
- Export timestamp.
- App marketing version and build.
- Schema version.
- Selection-policy version.
- Canonicalization version and SHA-256 checksum of the canonical payload, excluding the checksum field itself, for accidental corruption detection.
- Box Items.
- Current Pick when present.
- Draw Sessions and Attempts.
- Completion Memories.

Canonical payload encoding uses UTF-8, sorted object keys, integer timestamps in UTC milliseconds, no floating-point domain values, and stable UUID ordering for unordered record collections. User strings are preserved rather than normalized. The checksum detects corruption; it is not encryption, authentication, or proof of authorship.

Backup format v1 freezes the following resource limits. They are also product-store capacity limits, so a valid store remains fully exportable and a successful export can be re-imported by the same build.

| Resource | Format v1 maximum |
| --- | ---: |
| Encoded `.somedaybox` file | 128 MiB (134,217,728 bytes) |
| Box Items across all lifecycles | 5,000 |
| Current Pick records | 1 |
| Draw Sessions | 10,000 |
| Draw Attempts | 50,000 |
| Completion Memories | 5,000 |
| Title | 120 user-perceived characters and 512 UTF-8 bytes |
| Note or note snapshot | 1,000 user-perceived characters and 4,096 UTF-8 bytes |
| Duration raw value or snapshot | 64 UTF-8 bytes |
| Policy-version identifier | 64 UTF-8 bytes |

Every C0 control character is rejected from a title; a note permits tab and line feed only. The same rules apply whether text is typed, pasted, migrated, or imported. The application layer checks the applicable record count and conservative projected canonical size before a growing mutation; near the byte boundary it performs an exact canonical-size check before commit. It never deletes user content to make room and presents a non-destructive capacity state that keeps export and permanent-delete management available. Ended Draw workflow records use the separate safe-compaction contract in Section 9.5.

Export and import call the same format-v1 validator. Unknown duration raw values are the documented open-value exception and round-trip opaquely; unknown closed behavioral enums fail validation. The exporter writes to a temporary file, verifies the final encoded byte count and checksum, and exposes the document to the system picker only after validation succeeds. A store produced through valid application use is therefore exportable, and a successful export is re-importable by the same build. Raising any limit requires a new readable backup-format version plus round-trip and resource-use evidence on the oldest supported device.

After the source checksum and structural limits validate, restore validates the complete decoded source graph—including records that retention will later remove—against every Section 9.8 persisted-state invariant except post-compaction retention/headroom. Only a valid source graph may enter `draw-journal-v1` DTO compaction. The normalized graph is then validated again against the full invariant set plus `drawHeadroom` or `exitHeadroom` before staging. The preview reports post-normalization record counts. This prevents invalid old history from being hidden by compaction and prevents a maximum-size backup from activating a reveal that cannot be accepted or dismissed.

Every release manifest states the minimum and maximum readable backup format. Known older formats are decoded into version-specific DTOs and upgraded in memory before current validation; a future format is rejected without writes. Backup-format adapters are separate from SwiftData migrations and may not be removed while a public export format remains supported.

The MVP supports:

- Full export.
- Full replacement restore after preview and confirmation.
- No background upload.
- No automatic cloud destination.
- No merge.

“Full export” means every authoritative Box Item, Current Pick, freshness field, Completion Memory, and every workflow record remaining after the documented pre-export compaction. Compaction is part of the versioned data contract, not silent loss of a user-visible Memory.

### 15.4 Restore safety

- Access a user-selected file only through the system's security-scoped resource lifecycle.
- Reject unknown future formats safely.
- Reject a file above 134,217,728 bytes from file metadata before JSON decoding, then copy through a bounded reader that stops and rejects at byte 134,217,729 so stale or deceptive metadata cannot bypass the cap. Preflight free space before staging; the release contract requires at least twice the incoming file size plus the current generation's on-disk size plus a 100 MiB reserve. Insufficient space changes nothing and explains the requirement.
- After decoding and source-checksum verification, validate format-v1 structural/resource limits, the open-versus-closed raw-value policy, and the complete source graph before compaction. This first pass includes lifecycle/timestamp agreement, Attempt outcome and resolution agreement, contiguous Session sequences, open-Session state, reserved-item state, Current Pick item/lifecycle agreement, completion/Memory agreement, references, capacities, and singleton rules for every decoded record. Apply deterministic DTO-level draw-journal compaction only after that pass, then validate the normalized graph again against the full Section 9.8 persisted-state set plus resolution headroom before any staged-store write.
- Decode and upgrade into schema-independent DTOs away from the live model context.
- After preview and confirmation, acquire an exclusive product-data operation gate before writing `prepared`. While held, reads may render from the unchanged active generation during staging, but all application mutation use cases fail with `dataOperationInProgress`; a second generation-changing operation or import/export cannot begin. Hold the gate through `finalized` or completed pointer rollback, and reconcile the journal before enabling product UI after a process restart. A new migration or restore cannot overwrite a non-finalized active-operation journal.
- Preallocate app-owned IDs for the staged generation, rollback export, and temporary DTO copy, and write all of them with the prior generation ID in the durably flushed `prepared` journal before creating any artifact. Create the rollback export when the active generation is readable, and always retain that generation itself. A crash before `validated` can therefore remove only the predeclared artifacts and never guess a path.
- Build the full dataset in a newly created generation through a dedicated SwiftData context with autosave disabled and one explicit transaction. No object from the live context enters this transaction.
- Save the staged context, release every staged context/container reference, open that generation through a fresh container, re-run all invariants, and compare counts plus a canonical product-data digest with the validated DTOs. Construct two complete, checksummed ID lists: rollback cleanup deletes the staged generation and temporary/rollback artifacts but preserves the prior generation; committed cleanup deletes the prior generation and temporary/rollback artifacts but preserves the new generation. Atomically replace and durably flush the journal with phase `validated` and both lists before `switching` can begin.
- Mark and durably flush the journal as `switching`, then quiesce and tear down the root data-bound UI, save as required, release every active context/container reference, atomically replace the active-generation manifest, and mark the journal `switched`. Create a new container from the manifest, refetch the new generation, and re-run invariants before atomically replacing the journal with phase `committed` while preserving the already-validated cleanup lists. `committed` is therefore a self-contained no-rollback boundary with no target-list crash gap, but is not yet user-visible success.
- On launch, reconcile both the manifest generation ID and journal phase. For a normal restore, any exception, mismatch, or process termination before `committed` causes startup recovery to atomically point back to the retained prior generation before opening product UI, including a crash between manifest replacement and the `switched` journal write. In `prepared`, it cleans the predeclared planned-artifact IDs; from `validated` onward, it executes the checksummed rollback-cleanup list. It verifies cleanup before releasing the gate. A failure of pointer rollback or cleanup enters Recovery with every not-yet-deleted generation untouched; it never chooses an empty store.
- At `committed`, rollback is forbidden. Mark `cleaning`, execute the committed-cleanup list idempotently, treat an already-missing target as success, durably persist progress, verify every target is absent, and only then mark `finalized`. A crash at any deletion point resumes this same list before product UI. Multi-file deletion is never described as atomic.
- Remove or archive the content-free finalized journal, release the mutation gate, and display success only after `finalized`. No second generation-changing operation may start earlier. Preserve the user-selected source file on every outcome.

Recovery import has a separate executable path when the active generation cannot open:

1. Leave the unreadable generation and active manifest untouched and label the generation as quarantined in the operation journal; do not claim that an internal rollback export was possible.
2. Validate the selected backup and build, save and release it, then verify it through a fresh container without opening the unreadable generation.
3. After confirmation, atomically select the new validated generation. If interruption occurs after this switch, the next launch revalidates the new generation and advances to `committed` when valid; otherwise it returns to Recovery with the unreadable generation still preserved.
4. Exclude the quarantined generation from normal `cleaning`. Keep it until the person explicitly erases all data or separately confirms removal after a successful manual export. Settings and every permanent-delete confirmation disclose that an unreadable quarantined generation may still contain an earlier byte-level copy that cannot be edited record by record.
5. Cancelling leaves the active manifest and original generation unchanged. Temporary DTOs, staged generations, and the cancelled operation journal may have been created; cancel enters journaled, idempotent cleanup, and a crash resumes that cleanup before returning to Recovery.

### 15.5 Deletion closure

Archive is reversible and should be the easy option. Permanent deletion is explicit.

Deleting one paper removes:

- The Box Item.
- Every retained Draw Session containing an Attempt for that item, including all Attempts in that Session, so sequence and reference invariants cannot be left partially broken. Other papers keep their own `lastShownAt` selection truth.
- Its Completion Memories.

Erase All Data is itself a generation operation; it never deletes first and hopes to create an empty store afterward:

1. After two-step confirmation, acquire the exclusive mutation gate. In normal UI no other operation may be active. In Recovery, an explicitly confirmed Erase All may take over a failed non-finalized operation only by first copying every predeclared target ID from its journal into the new cleanup plan and durably marking that journal superseded. Durably write an `eraseAuthorized` tombstone containing the operation ID, confirmation timestamp, current manifest ID, a checksummed list of every app-owned generation/rollback/temporary artifact to remove, and flags for diagnostics/preferences. It contains no paper content.
2. Create a new empty generation, save and release it, reopen it through a fresh container, and verify the empty counts and Section 9.8 invariants while every old generation remains untouched.
3. Record `switching`, atomically select the empty generation, reopen it, and write its erase operation ID and timestamp into the checksummed active manifest. Mark `committed`; the durable authorization plus cleanup list now makes rollback to personal content forbidden.
4. Enter `cleaning` and idempotently remove all old, retained, staged, and quarantined generations; internal rollback exports and obsolete operation journals; app-owned diagnostic events; and app-owned preferences. Missing targets count as already cleaned. Persist progress and resume at the next launch after a force termination.
5. Verify absence of every target, mark `finalized`, remove the erase tombstone last, release the gate, and only then expose the permission-free first-launch state.

Before `committed`, a crash or resource failure leaves all personal generations intact and startup resumes the durably authorized erase rather than inventing an empty recovery. At or after `committed`, startup selects the verified empty generation and resumes cleanup before UI. The active manifest permanently distinguishes this user-authorized empty generation from an automatic failure fallback. Every phase and every between-file deletion point has a forced-termination fixture.

Ordinary retained generations and rollback exports never coexist with editable product UI: the generation operation gate remains held until their journaled cleanup is `finalized`. Therefore a later per-paper permanent delete has no hidden readable normal-rollback copy inside the app. An unreadable quarantined generation is the explicit exception because record-level deletion is impossible; its persistent warning and separate whole-generation deletion control make that boundary visible.

It cannot remove backup files the user exported to Files, iCloud Drive, Finder, or another provider. It also cannot erase iOS-owned unified logs, system backups, or crash diagnostics; product policy keeps user-entered content out of those logs. The confirmation must state this boundary without implying that Erase All Data controls operating-system data.

---

## 16. Observability without surveillance

No backend does not mean the app should be undiagnosable. It means diagnostics remain private, bounded, and user-controlled.

### 16.1 Unified logs

Suggested categories:

- `capture`
- `draw`
- `persistence`
- `migration`
- `backup`
- `uiLifecycle`

Allowed dynamic content:

- Stable error code.
- Count.
- Duration.
- Schema, format, policy, app, and build version.
- Boolean success/failure state.

Forbidden dynamic content:

- Paper title or note.
- Pasted URL or arbitrary user input.
- Full UUID.
- Full file path or file contents.

### 16.2 Product history versus diagnostics

Completion Memories, Current Pick, and `BoxItem.lastShownAt` are durable product truth. Draw Sessions and Attempts are also private product records while retained because they guarantee the current reveal and same-session non-repetition, but they are not a user-facing life-history feed. Ended workflow records follow the deterministic Section 9.5 compaction contract; Memories never participate in that compaction and persist until their source paper is deleted.

Diagnostic events are not product data. If a bounded local diagnostic event store is added, it contains only coarse enums, counts, versions, timings, and error codes; it retains no more than 90 days or 2,000 events and can be cleared separately.

### 16.3 Product validation without production analytics

The MVP does not transmit usage analytics. Product validation uses:

- Moderated usability sessions.
- Test builds with participant consent.
- A user-triggered export of coarse local research events if a study protocol explicitly requires it.
- Interviews and observed task completion.

A research build must remain visibly distinct from the App Store build. Opt-in research export must never quietly become production telemetry.

---

## 17. Test strategy

Apple's recommended pyramid applies: many isolated domain tests, fewer persistence integration tests, and a small set of high-value UI journeys.

### 17.1 Domain unit tests with Swift Testing

Cover:

- Every duration boundary.
- One below, exactly at, and one above every format-v1 count, character, and byte limit.
- Exact `exitHeadroom` and `drawHeadroom` calculations at byte and Attempt-count boundaries.
- Current Pick exclusion and singleton invariants.
- Valid and invalid lifecycle transitions.
- Current-session non-repetition.
- Candidate exhaustion.
- Empty-pool reason classification.
- Fixed-clock freshness weights.
- Identical selection weights before and after ended-record compaction.
- Deterministic injected-random sequences.
- Timezone and daylight-saving display boundaries where calendar grouping is involved.
- Repeated completion after a backward wall-clock correction, proving the current matching Memory is found by exact transaction timestamp rather than `max(completedAt)`.
- Raw enum values remaining independent of app language.

### 17.2 Persistence and integration tests

Use in-memory containers for fast mapping tests and temporary disk-backed containers for durability/migration tests.

Cover:

- Repository CRUD and mapping.
- Atomic related-record mutations: Capture writes one Item; Draw writes Session plus Attempt plus Item `lastShownAt`; Redraw resolves one Attempt plus creates the next and advances its Item `lastShownAt`; Accept resolves Attempt plus creates Current Pick; Completion updates Item plus creates Memory plus clears Current Pick when it references that Item; archive/delete of Current Pick clears it; ended-record compaction preserves all durable summary truth.
- Every Capture, content, lifecycle, delete, backup, restore, and erase mutation being rejected while an Unresolved Attempt exists, without changing any record or generation file.
- Ended-record compaction at, below, and above the retention envelope, proving Current Pick remains unchanged after its Accepted Attempt is compacted.
- Unique identity behavior.
- Process relaunch persistence.
- Every released schema fixture migrating to current.
- Migration failure preserving the original store.
- Backup round trip through an independently staged store generation.
- Same-build re-import of a maximum valid format-v1 export.
- Maximum-count and near-byte-limit backups with an open Unresolved Session, separately proving Accept, Dismiss, and one supported-policy Redraw can complete after deterministic compaction and can never strand the reveal.
- An otherwise well-formed Unresolved backup without required exit/draw headroom being rejected before staged-store creation.
- Truncated, corrupt, future-format, duplicate-ID, unknown closed-enum, and broken-reference backup files; unknown bounded duration raw values must instead round-trip unchanged.
- Every invalid graph named in Section 9.8, including Current Pick with a missing/non-Active Item, Current Pick plus Unresolved coexistence, outcome/resolution mismatch, noncontiguous sequence, invalid open Session, reserved non-Active item, and Completed-without-matching-Memory.
- A domain-invalid ended Session old enough to be removed by retention still being rejected during the pre-compaction source-graph pass.
- Restore failure producing zero active-generation data changes; any disposable stage follows the journal cleanup contract.
- Restore failure and forced termination before staging, after the staged-store transaction, after staged reopen, during pointer switch, and before `committed`, each proving the prior normal generation remains or becomes authoritative.
- Mutation attempts throughout `prepared` to `finalized` being rejected with `dataOperationInProgress`, followed by normal writes only after finalization or completed rollback releases the gate.
- A second migration/restore/export being rejected while an active-operation journal is non-finalized, so no journal or cleanup target list is overwritten.
- Forced termination before, between, and after each ordinary cleanup target deletion, proving startup resumes idempotently, never rolls back after `committed`, and never exposes editable UI before all normal readable rollback copies are gone.
- Recovery import succeeding through a new generation when the selected prior generation is intentionally unreadable, while preserving that quarantined generation.
- Migration interruption at every shared journal phase, manifest/journal mismatch reconciliation, immutable-source retry, and deterministic failure entering Recovery with both generations retained.
- Erase interruption before and after empty-generation switch and between every cleanup target, proving a durable authorization marker always distinguishes the resulting empty store from failure fallback.
- Recovery-authorized Erase All safely taking over a failed non-finalized operation without losing any of its predeclared cleanup targets.
- Deletion cascades.
- English and Chinese data remaining semantically identical.

### 17.3 UI and end-to-end tests with XCTest/XCUIAutomation

Cover at least:

- First launch and empty Box.
- Title-plus-duration capture.
- Save remaining disabled when duration is missing.
- Timed draw never showing an oversized paper.
- Empty candidate pool.
- Draw another without repetition.
- Unsupported-policy unresolved reveal allowing Accept/Dismiss but disabling Draw another with explanatory copy.
- Accept, put back, complete, and Memory display.
- Current Pick surviving force termination and relaunch.
- Relaunch during unresolved reveal.
- Global reveal resumption blocking root navigation and every stale mutation route until the result resolves.
- Inline title/note character, byte, control-character, item-capacity, and Memory-capacity errors preserving the user's prior state.
- Edit, archive, restore, and permanent delete.
- Permanent-delete disclosure and whole-generation deletion control when Recovery intentionally retains an unreadable quarantined generation.
- Export, erase, and restore.
- Simplified Chinese and English.
- Light and dark mode.
- Largest Dynamic Type.
- Reduce Motion.
- Automated accessibility audit on every primary screen and major error state.

### 17.4 Physical-device release checks

Every release candidate is tested on at least:

- The oldest supported reference iPhone on iOS 18.
- A current iPhone/iOS version.

Verify:

- Airplane-mode cold launch and complete core journey.
- Haptics on and off.
- VoiceOver and Voice Control.
- Background/foreground and forced termination.
- Low-storage error handling where practical.
- Upgrade from the previous public build.
- Files export/import.
- The complete `backup-resource-v1` timing, peak-memory, disk-preflight, oversize-rejection, and journal-interruption matrix without the debugger attached.
- Archived Release build, not only Debug or Preview.

### 17.5 Network and privacy verification

- Static review of linked frameworks, Swift packages, capabilities, entitlements, privacy manifest, and Info.plist usage descriptions.
- Xcode Network I/O and Instruments inspection during the entire journey.
- Device App Privacy Report review.
- Archive privacy report review.
- Airplane mode equivalence.

Absence of a networking call in source search is useful static evidence, but not sufficient runtime proof.

---

## 18. Delivery pipeline

### 18.1 Milestones

| Milestone | Outcome | Exit evidence |
| --- | --- | --- |
| M0 — Contract freeze | Product boundaries, state machine, data dictionary, draw policy, privacy promise, and design direction approved | This document plus focused ADRs for deployment target and persistence |
| M1 — Local vertical slice | Fresh install can capture, persist, relaunch, and browse a paper | Domain and repository tests; simulator recording; no UI-only fixture path |
| M2 — Draw truth | Context filtering, versioned selection, reveal, redraw, and interruption recovery work | Boundary tests; seeded policy tests; runtime journey |
| M3 — Lifecycle and Memories | Accept, put back, complete, archive, delete, and memory snapshot closure work | State tests; deletion-cascade tests; visible journey |
| M4 — Data safety | Versioned schema, backup, staged-generation restore, erase, and independent Recovery import work | Old-store fixture migration; corrupt import; pointer-interruption matrix; round-trip evidence |
| M5 — Product hardening | Bilingual UI, accessibility, motion fallback, performance, local-only audit | Automated audits; manual VoiceOver; Instruments; airplane-mode proof |
| M6 — Packaged acceptance | Signed candidate behaves like local development truth | TestFlight/Release build on physical devices; release manifest |

### 18.2 Continuous integration gates

Every change should run:

- Swift format/lint policy chosen by the project, if introduced.
- Swift 6 compile with warnings treated according to the release policy.
- Domain and application unit tests.
- Persistence integration tests.
- Selected UI smoke journeys.
- Privacy/capability manifest validation.

Release candidates additionally run the full test plan, migration fixtures, backup corruption suite, accessibility audits, and archive checks.

### 18.3 Commit and change policy

- One completed work item per commit.
- A follow-up that belongs to the same unfinished work item amends that commit.
- Do not mix unrelated formatting, generated files, or user work into the commit.
- Every persistent schema change includes its migration and test fixture in the same completed change.
- Every feature flag includes owner, default, introduction version, expiry/removal version, and on/off test evidence.
- Expired flags and disabled production paths are removed; they are not retained as indefinite legacy fallback.

### 18.4 Feature flags in a local-only app

There is no remote configuration. Production flags are signed build configuration, not secretly editable UserDefaults.

- Debug/Internal builds may expose a local development menu.
- Release builds use a fixed, reviewable manifest.
- A flag may control presentation or behavior, never whether schema migration runs.
- Turning a feature off must stop new writes for that feature while preserving safe reads for already-released data.
- A flag without a removal date is not accepted.

### 18.5 Release manifest

Each candidate records:

- Marketing version and build number.
- Commit SHA and immutable release tag.
- Xcode and Swift versions.
- Minimum iOS and SDK versions.
- SwiftData schema version.
- Backup format version and frozen byte/count/text limits.
- Selection-policy version.
- Draw-journal retention-policy version.
- Store-generation manifest version and supported recovery journal phases.
- Production feature-flag manifest.
- Oldest readable data version.
- Migration fixture versions.
- Known limitations.

---

## 19. Rollback and recovery strategy

“Rollback” has three different meanings and must not be collapsed into one claim.

### 19.1 Source rollback

- Every release has an immutable Git tag and manifest.
- A faulty source change can be reverted or a hotfix can start from the last stable tag.
- Source rollback does not prove user data can be downgraded.

### 19.2 Distribution rollback

Delivery path:

```text
Debug → Internal Release → TestFlight → Phased App Store Release
```

When a severe defect appears:

1. Stop TestFlight distribution or pause the phased App Store release.
2. Build a forward hotfix from the last stable line.
3. Re-run migration, local-only, and packaged-acceptance evidence.
4. Submit a fixed build.

The App Store does not provide a reliable mechanism to force every user back to an older binary. “Pause and forward-fix” is the operational rollback path.

### 19.3 Data recovery

An older binary may not understand a newer schema. Therefore binary downgrade is not a data-recovery plan.

Data safety relies on:

- Expand/contract migrations.
- Previous-release store fixtures.
- Generation-based migration and restore, where all staged container references are released and a fresh container validates the store before an atomic active-generation switch.
- Migration or normal-restore failure selecting the retained prior generation before product UI opens.
- User-controlled versioned backups.
- Operation journals and rollback exports that make an interrupted phase diagnosable.
- A Recovery screen for generation status, independent backup import, quarantined-store retention, and deliberate erase.
- A forward hotfix when released schema behavior is wrong.

If the selected generation cannot open, Recovery does not depend on that container: it can validate and populate a new generation from a backup while leaving the unreadable generation byte-for-byte in place. It cannot promise to export content it cannot decode. Cancelling leaves authoritative product truth unchanged and journal-cleans temporary artifacts; a successful import selects only a separately reopened and validated generation; deleting the quarantined generation always requires a distinct confirmation. The app must never describe an empty store created after failure as a successful recovery.

---

## 20. Product validation plan

Because the app has no production analytics, validation is explicit and consent-based.

### 20.1 Hypotheses

| Hypothesis | Test | Directional success signal |
| --- | --- | --- |
| Capture feels lighter than task creation | Ask participants to save three spontaneous ideas | At least 80% of title-plus-duration captures finish in under 10 seconds without help |
| Draw is preferred when free time appears | Give a seeded Box and a free-time scenario without directing navigation | A majority choose Draw before browsing Box |
| Constrained randomness feels trustworthy | Include deliberately incompatible durations | No incompatible result; participants can explain why the result fits |
| The reveal adds delight without delay | Compare normal and Reduce Motion paths qualitatively | Participants notice the reveal but do not describe it as waiting |
| Memories add emotional value | Complete two papers and revisit a later session | Participants describe Memories as experiences rather than completed work |

These thresholds guide a small formative study; they are not statistically representative product metrics.

### 20.2 Core scenarios

#### Tuesday evening

Box includes:

- Message a university friend — 10 minutes.
- Read a saved article — 30 minutes.
- Sort 20 travel photos — 30 minutes.
- Browse Fitzroy second-hand shops — up to 4 hours.

Context: 30 minutes.

Expected candidate truth:

- Message a university friend: eligible.
- Read a saved article: eligible.
- Sort 20 travel photos: eligible.
- Browse Fitzroy second-hand shops: excluded by time.

The selected result must be weighted-random among the three eligible papers, not globally random across four. The two 30-minute papers have a slightly higher TimeFit than the 10-minute paper, but no one result is guaranteed.

#### Saturday afternoon

Context: 4 hours.

The Fitzroy paper becomes eligible. Static Capture guidance may suggest “Complete the first Blender tutorial,” but “Learn Blender” plus a selected duration still saves and represents a time-boxed session. The MVP neither invents a next action nor stores a separate inert Journey state.

#### No match

Context: 10 minutes; every paper is a two-hour activity.

Expected result: a clear no-match state. The app must not draw a two-hour activity and must not quietly broaden the time.

---

## 21. Risks and mitigations

| Risk | Consequence | Mitigation |
| --- | --- | --- |
| The product drifts into Todo | Emotional promise collapses | Prohibit deadline/priority fields; review Home and Memories semantics at every release |
| Required duration makes capture feel slower | People return to generic notes | One visible tap, six clear upper-bound choices, no other classification fields, and a ten-second usability target |
| Unlimited redraw becomes list browsing | Signature interaction loses value | No current-session repetition; explicit exhausted-round state; study redraw behavior before adding limits |
| Randomness feels arbitrary | Users ignore results | Hard time filter first; visible duration fit; mild TimeFit and freshness weights |
| A broad title is not actionable enough | The drawn paper still leaves a decision | Always require a duration, show static concrete examples, allow a note, and add long-term modeling only through a later explicit design |
| Small Boxes frequently have no match | First-use experience feels broken | Onboarding prompts several papers; supportive no-match state; no silent relaxation |
| Accepted papers become another backlog | Pressure returns | Exactly one Current Pick; a new draw requires an explicit resolution; no deadline or badge |
| A stale action mutates the paper currently being revealed | Relaunch truth and lifecycle diverge | Global Unresolved-result gate plus use-case-level `drawResolutionRequired` rejection |
| SwiftData migration loses content | Personal memories are damaged | Versioned schema, released-store fixtures, non-destructive failure, backup/restore |
| A faulty release cannot be downgraded | Users remain affected | Phased rollout, forward hotfix, expand/contract schema, explicit recovery path |
| Logs expose intimate ideas | Privacy promise fails | Content-free log policy and diagnostic-export inspection |
| “Local only” is overstated | Product copy becomes misleading | Distinguish app networking from OS backup and user-selected file providers |
| Backup import partially overwrites data | Box becomes inconsistent | Full invariant validation in an independent generation before an atomic manifest switch |
| A nominal backup limit exhausts an older phone | Restore crashes despite a valid file | Frozen near-limit fixture, physical-device memory/timing gate, disk preflight, and a smaller contract before v1 if evidence fails |
| Animation blocks accessibility | Core action becomes unusable | Native controls, Reduce Motion cross-fade, explicit button, VoiceOver announcement |
| New toolchain APIs leak into minimum OS | Runtime or build instability | Stable Xcode line, availability checks, minimum/current OS test matrix |
| Architecture grows faster than product evidence | MVP is delayed | Modular monolith, zero third-party runtime dependencies, vertical milestones |

---

## 22. Definition of Done and evidence levels

The MVP is not complete because a screen exists, a preview looks polished, or local unit tests are green. Completion requires evidence at each level.

| Evidence level | Required proof |
| --- | --- |
| Contract | Approved product boundary, state machine, data dictionary, draw policy, privacy promise, and ADRs |
| Static | No LLM/network/analytics dependency; no CloudKit or sensitive capability; no deadline/priority/overdue model; release manifest present |
| Unit | Filter boundaries, lifecycle transitions, deterministic random fixtures, and empty-pool reasons pass |
| Integration | Real repositories, disk persistence, released-store migration fixtures, staged-generation activation/rollback, and deletion closure pass |
| Local runtime | Simulator and device complete Capture → Draw → Accept/Redraw → Complete → Memories using persisted data |
| Offline | Airplane-mode cold launch, save, draw, relaunch, export, and restore work |
| Accessibility | Automated audit plus manual VoiceOver, Voice Control, largest Dynamic Type, and Reduce Motion checks pass |
| Upgrade/recovery | Previous public data upgrades; migration failure does not clear; invalid restore makes zero active-generation changes |
| Network/privacy | Runtime instruments and App Privacy Report show no app-initiated domain access or undeclared sensitive capability |
| Packaged | Signed Release/TestFlight build completes the same physical-device journey as development |
| Product semantics | Home still prioritizes Put in / Draw out; no guilt, deadline, score, or productivity language has appeared |

Each release acceptance record includes:

- App version and build.
- Commit SHA and release tag.
- Device and iOS version.
- Schema, backup format, policy, and feature-manifest versions.
- Test timestamp.
- Screenshots or recording of the real packaged surface.
- Failures, exceptions, and known limitations.

---

## 23. Final MVP acceptance statement

The first public version of `someday-box` / `改天盲盒` is accepted only when a person can, on a physical iPhone and with no app-provided network connection:

1. Open a fresh app without creating an account or granting a permission.
2. Put a passing idea into the Box in a few seconds.
3. Relaunch and see the same persisted paper.
4. Describe available time with one choice.
5. Draw only from compatible, actionable papers.
6. Accept, draw another without immediate repetition, or leave without penalty.
7. Complete the paper and see an accurate Memory.
8. Edit, archive, restore, and permanently delete with documented closure.
9. Export a versioned backup, erase local data, and restore the same product truth.
10. Complete the full experience in Simplified Chinese or English, with VoiceOver and Reduce Motion alternatives.

If any result depends on an LLM, server, account, remote asset, analytics SDK, CloudKit sync, or undisclosed network call, it is not this MVP.

---

## 24. Apple platform references

The following primary sources support the technical choices. Availability and submission requirements are date-sensitive and must be rechecked before implementation and release.

- [Xcode support and current toolchain matrix](https://developer.apple.com/support/xcode/)
- [Upcoming App Store submission requirements](https://developer.apple.com/news/upcoming-requirements/)
- [Apple platform adoption statistics](https://developer.apple.com/support/app-store/)
- [iOS 18 compatible devices](https://support.apple.com/104985)
- [SwiftData: preserving model data across launches](https://developer.apple.com/documentation/swiftdata/preserving-your-apps-model-data-across-launches)
- [SwiftData ModelContainer](https://developer.apple.com/documentation/swiftdata/modelcontainer)
- [SwiftData SchemaMigrationPlan](https://developer.apple.com/documentation/swiftdata/schemamigrationplan)
- [SwiftData local CloudKit configuration](https://developer.apple.com/documentation/swiftdata/modelconfiguration/cloudkitdatabase-swift.struct/none)
- [Observation](https://developer.apple.com/documentation/observation)
- [SwiftUI NavigationStack](https://developer.apple.com/documentation/swiftui/navigationstack)
- [SwiftUI animation timing and movement](https://developer.apple.com/documentation/swiftui/controlling-the-timing-and-movements-of-your-animations)
- [Adopting the current Apple platform visual design](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass)
- [SwiftUI SensoryFeedback](https://developer.apple.com/documentation/swiftui/sensoryfeedback)
- [SwiftUI Reduce Motion environment value](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion)
- [SwiftUI accessibility fundamentals](https://developer.apple.com/documentation/swiftui/accessibility-fundamentals)
- [Performing accessibility audits](https://developer.apple.com/documentation/accessibility/performing-accessibility-audits-for-your-app)
- [Swift Testing](https://developer.apple.com/documentation/testing)
- [Xcode testing strategy](https://developer.apple.com/documentation/xcode/testing)
- [Unified logging](https://developer.apple.com/documentation/os/logging)
- [OSLog privacy](https://developer.apple.com/documentation/os/oslogprivacy)
- [App privacy details and the definition of collection](https://developer.apple.com/app-store/app-privacy-details/)
- [Using the file system effectively](https://developer.apple.com/documentation/foundation/using-the-file-system-effectively)
- [Defining custom file and data types](https://developer.apple.com/documentation/uniformtypeidentifiers/defining-file-and-data-types-for-your-app)
- [Data Protection entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.default-data-protection)
- [Required-reason API declarations](https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest)
- [Inspecting app network activity](https://developer.apple.com/documentation/network/inspecting-app-activity-data)
- [Generating an archive privacy report](https://developer.apple.com/documentation/bundleresources/describing-data-use-in-privacy-manifests)

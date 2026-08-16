# Documentation guide

This directory is the product's contract system. Code follows documents here; when reality and a document disagree, either the code is wrong or the document must be corrected in the same change — never neither.

Last reviewed: 2026-08-16.

## Map

```text
docs/
├── README.md                                        ← this guide (structure, conventions, operations)
├── product-requirements-and-technical-foundation.md ← the MVP baseline: product, domain, policy, stack, verification
├── features/                                        ← one development contract per selected post-MVP feature
│   ├── share-to-box.md                              ← feature 1: system-share import (S1–S5 implemented, S6 blocked)
│   └── lived-in-box.md                              ← feature 2: tangible 3D box experience (B0 contract only)
├── adr/                                             ← numbered, immutable-once-accepted architecture decisions
│   ├── 0001-ios-18-swiftui-swiftdata.md
│   ├── 0002-local-data-and-generation-safety.md
│   ├── 0003-share-extension-local-import-mailbox.md (+ 0003 S2 addendum)
│   └── 0004-realitykit-scene-presentation.md
├── plans/                                           ← living execution plans for code agents; archived when done
│   ├── lived-in-box-development-plan.md
│   └── archive/                                     ← completed plans move here untouched
└── release/                                         ← evidence and acceptance surfaces
    ├── acceptance-checklist.md                      ← generic per-candidate checklist
    ├── release-manifest-template.md                 ← per-candidate manifest template
    ├── share-to-box-readiness.md                    ← feature 1 evidence ledger
    └── lived-in-box-readiness.md                    ← feature 2 evidence ledger
```

## Document types and lifecycle

| Type | Location | Nature | Changes by |
| --- | --- | --- | --- |
| Baseline | `product-requirements-and-technical-foundation.md` | The MVP product and engineering contract; the acceptance claim it records is historical fact | Surgical, reviewed edits only; new scope goes to `features/`, not into the baseline |
| Feature contract | `features/*.md` | Requirements → functional translation → acceptance rules for one selected expansion; a development contract, **never** runtime evidence | Versioned decisions; each contract carries its own decision ledger |
| ADR | `adr/NNNN-*.md` | One architecture decision with context, alternatives, and revisit triggers | Never rewritten after acceptance; superseded by a new ADR that names it |
| Plan | `plans/*.md` | Work-package execution guide for code agents; contains no product truth | Freely maintained while active; moved to `plans/archive/` on completion |
| Readiness ledger | `release/*-readiness.md` | The only place implementation/evidence **status** lives | Updated in the same change as the work it describes |
| Checklist / template | `release/` | Candidate-time instruments | Extended when a feature adds evidence classes |

## Conventions

- **Language.** Documents are written in English for corpus consistency; all user-facing copy appears in bilingual (Simplified Chinese / English) tables inside the owning contract.
- **Header table.** Every contract begins with a field table including `Document status` and `Last reviewed` (ISO date). Update `Last reviewed` whenever content changes meaningfully.
- **Status lives in ledgers.** Specs and plans describe intent; only readiness ledgers state what is implemented and what evidence exists. Never write "implemented" into a spec body — link the ledger.
- **Evidence separation.** Source/test proof, simulator proof, device proof, and signed-package proof are distinct levels; a document may only claim the level its artifacts support. This rule is repeated in every ledger on purpose.
- **Decision ledgers.** Feature contracts resolve their source material's ambiguities in an explicit numbered ledger (`LB-D01`-style). Implementation follows the ledger, not the original brief.
- **Stable paths.** File paths are link targets from README, code review history, and past commits; prefer adding documents over moving them. A move must fix every inbound link in the same change.
- **No implementation code** in any document; text diagrams and tables only.

## Registry of versioned identifiers

Every persisted or behavioral contract identifier, and the document that owns it. A released identifier is never repurposed; changing behavior means a new identifier plus fixtures.

| Identifier | Meaning | Owning document |
| --- | --- | --- |
| SwiftData schema `v1`, `v2` | Persistent store schema generations | Baseline §15; Share to Box §9.4 |
| Backup format `v1`, `v2` | `.somedaybox` canonical export | Baseline §15.3; Share to Box §9.5 |
| `mvp-v1` | Draw selection policy (filter + weights) | Baseline §10 |
| `draw-journal-v1` | Ended-session compaction/retention | Baseline §9.5 |
| Share envelope / activation versions | Mailbox envelope codec; extension activation dictionary | Share to Box §5, §9.1 |
| `box-scene-v1` | Scene derivation (density bands, seeding, age tiers, lock states) | Lived-in Box §6, §8 |
| `draw-dial-v1` | Draw-context presentation mapping and Custom snap | Lived-in Box §7.3 |
| `traces-v1` | Trace/echo/growth derivation predicates | Lived-in Box §10 |

## Reading order

**A human getting oriented:** root `README.md` → baseline §1–§5 → the feature contracts' §1 → the readiness ledgers.

**A code agent starting a work package:** the plan's §0 execution rules → the feature contract sections the WP names → ADRs it cites → the readiness ledger row → then the code.

**Anyone judging "is X done":** the readiness ledgers, nothing else.

## Operations

- **Adding a feature:** write `features/<name>.md` (with decision ledger and acceptance IDs), an ADR if architecture changes, a plan in `plans/`, and a readiness ledger in `release/`; link all four from the root `README.md` and the baseline's selected-features section.
- **Adding an ADR:** next number, never reuse; if it replaces one, both must say so.
- **Quarterly review:** confirm each active document's `Last reviewed` date, prune dead links, verify ledgers still match repository truth, and archive completed plans.
- **Naming note:** the Simplified Chinese product name 有空箱 was adopted for the lived-in generation (decision LB-D01); MVP-era documents keep 改天盲盒 as the name under which MVP acceptance was claimed. Shipping the store-listing rename is a release-manifest decision.

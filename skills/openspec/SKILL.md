---
name: openspec
description: "Creates and manages per-feature OpenSpec change folders. Produces proposal, specs/stories, design, and tasks artifacts from product discovery artifacts. Archives completed changes on explicit instruction from development-workflow. Invoke when starting work on a story group or archiving a completed feature. Triggers: \"set up openspec for X\", \"create change folder for X\", \"archive feat-X\"."
metadata:
  type: flexible
---

# OpenSpec

## When to Use

**Invoke for:**
- Starting work on a story group — "set up openspec for X", "create change folder for X"
- Archiving a completed feature — "archive feat-X" (only when explicitly instructed by `development-workflow` after all sub-issues are confirmed closed)

**Not auto-triggered** — always an explicit act, never fired without a specific request.

**Entry detection** — before creating, check `openspec/changes/<feat-name>/` in the project repo:

| Existing state | Action |
|---|---|
| Folder does not exist | Create folder and all artifacts |
| Folder exists, artifacts complete | Output folder path, skip creation |
| Archive instruction received | Move folder to `openspec/changes/archive/<feat-name>/` — do not check issue state (development-workflow confirms first) |

## Principles

**Change folder location:** `openspec/changes/<change-name>/` inside the project repo. The change name is kebab-cased with the change type as prefix: `feat-` for a story group ("Onboarding" → `feat-onboarding`), `fix-` for a bug, `chore-` for non-feature work. Stories live in a `specs/` subdirectory within the change folder.

**Bug fixes and other changes with no story group:** write `proposal.md` with `**Story group:** none (<where the bug was found>)`, and write `specs/stories.md` from the bug itself: one story for the broken behaviour from the user's side, plus one for the regression guard if the fix adds one. Everything else is unchanged.

**Artifacts and their sources:**

| File | Source | Rule |
|---|---|---|
| `proposal.md` | `one-pager.md` or `lean-canvas.md` + story group | Derived — no questions needed |
| `specs/stories.md` | Story group from `job-stories.md` | Pulled verbatim; acceptance criteria derived from story outcomes |
| `design.md` | `architecture-review` skill output; for a `bounded` change, a short design note | Written verbatim from inline `architecture-review` invocation output — do not reformat or summarize. A `bounded` change (the Path in the Scope Brief) skips `architecture-review`: write the options as a short trade-off table, the choice, and what it sacrifices |
| `tasks.md` | Derived from `design.md` + story scope | `:shared` first, then `:android`, then `:backend`; omit empty layers |
| `sprint-contract.md` | Derived from `specs/stories.md` | Written by `development-workflow` from the evaluator's report at Phase 3 — do not create during Phase 0 |
| `issues.md` | Written by `linear` | Do not create — leave absent at this stage |

**Conversation flow:**
1. Confirm which story group this change covers
2. Derive `proposal.md` and `specs/stories.md` from discovery artifacts — no questions needed
3. Invoke `architecture-review` to produce `design.md`, or for a `bounded` change write the short design note yourself
4. Write `tasks.md` with ordered implementation steps broken by layer
5. Output the change folder path

**Archive action:**
Receives an explicit archive instruction from `development-workflow` (never self-triggers). Moves `openspec/changes/<feat-name>/` → `openspec/changes/archive/<feat-name>/`. Does not verify issue state — `development-workflow` handles that before invoking.

**`proposal.md` template:**
```markdown
# Proposal: <Feature Name>
**Change:** <feat-name>
**Story group:** <Onboarding | Core Loop | Edge Cases>
**Date:** YYYY-MM-DD

## Scope
[1-3 sentences: what this change builds]

## Rationale
[1-3 sentences: which job stories drive this, why now]

## Out of scope
[Explicit exclusions — YAGNI]
```

**`specs/stories.md` template:**
```markdown
# Specs: <Feature Name>

## Story 1
When [situation], I want to [motivation], so I can [outcome].

### Acceptance criteria
- [ ] [one checkbox per verifiable behavior derived from the outcome]

## Story 2
When [situation], I want to [motivation], so I can [outcome].

### Acceptance criteria
- [ ] [one checkbox per verifiable behavior derived from the outcome]
```

Each story gets its own section with acceptance criteria directly below it.

**`tasks.md` template:**
```markdown
# Tasks: <Feature Name>
**Change:** <feat-name>
**Date:** YYYY-MM-DD

## :shared
- [ ] [task]

## :android
- [ ] [task]

## :backend
- [ ] [task]
```

Omit layer sections that have no tasks for this story group.

**`sprint-contract.md` template:**
```markdown
# Sprint Contract: <Feature Name>
**Change:** <feat-name>
**Date:** YYYY-MM-DD
**Derived from:** specs/stories.md

## :<layer-name>
- [ ] [concrete testable assertion derived from acceptance criteria]
- [ ] [concrete testable assertion]
```

Layer names are taken from `tasks.md` headings — not hardcoded to `:shared/:android/:backend`. One section per layer present in `tasks.md`.

## Constraints

- When invoked with a Scope Brief (from `development-workflow`), keep `proposal.md` and `tasks.md` inside it: its **Explicitly out of scope** items go in the proposal as non-goals, and its **Also update** items become tasks
- `design.md` is written verbatim from `architecture-review` output — never reformatted or summarized (a `bounded` change's short design note is the exception)
- Checkboxes in `tasks.md` and `specs/stories.md` stay unticked: they are the plan, and `sprint-contract.md` is the record of what was verified. Reviewers shouldn't flag unticked boxes
- The archive move happens in the change's own PR, as its last commit (see `development-workflow` Phase 4), so merging archives it
- `issues.md` is written by `linear`, not `openspec` — do not create it here
- Archive action is only invoked by `development-workflow` — never self-triggered
- Change name is kebab-cased with a type prefix: `feat-` (story groups), `fix-` (bugs), `chore-` (non-feature work)
- Omit empty layer sections from `tasks.md`
- `sprint-contract.md` is written by `development-workflow` at Phase 3, from the evaluator's report — never created by `openspec` during Phase 0; leave absent at setup time

## Examples

**Creating a change folder:**

Story group: Onboarding (Habit Tracker)

Change folder created at `openspec/changes/feat-onboarding/`:

```
proposal.md       ← scope: first-time user adds a habit without friction
specs/
  stories.md      ← 3 onboarding stories, each with acceptance criteria below
design.md         ← architecture-review output (verbatim): HabitRepository in :shared, HabitListScreen in :android
tasks.md          ← :shared tasks + :android tasks (no :backend — this group has no backend work)
issues.md         ← absent at creation time; written later by linear
sprint-contract.md  ← absent at creation time; written at Phase 3 from the evaluator's report
```

`tasks.md` for this example:
```markdown
# Tasks: Onboarding
**Change:** feat-onboarding
**Date:** 2026-03-23

## :shared
- [ ] Define Habit schema in SqlDelight
- [ ] Implement HabitRepository with insert and getAll operations
- [ ] Write unit tests for HabitRepository

## :android
- [ ] Implement HabitListScreen composable with empty state
- [ ] Implement AddHabitScreen composable with a name field
- [ ] Wire navigation between HabitListScreen and AddHabitScreen
```

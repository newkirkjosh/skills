---
name: spec-writer
description: "Explicit-use only — invoke when the user explicitly names this skill, or when an active explicitly invoked workflow calls it. Creates and manages per-feature legacy custom change folders under openspec/changes (not CLI-validated): proposal, specs/stories, design and tasks artifacts from product discovery artifacts, and archives a completed change when dev says to."
metadata:
  type: flexible
---

# Spec Writer

## When to Use

**Invoke for:**
- Starting work on a story group — "set up spec-writer for X", "create change folder for X"
- Archiving a completed feature — "archive feat-X" (only when explicitly instructed by `dev`, as the last commit of the change's own PR, after its sprint contract and cross-model review are final)

**Explicit use only** — always an explicit act: the user names this skill, or `dev` calls it. Its handoff is the verified artifact path, not an implementation or publication run; later requests do not inherit it.

## Step 1: Detect setup or archive state

Before creating, check `openspec/changes/<feat-name>/` in the project repo:

| Existing state | Action |
|---|---|
| Folder does not exist | Create the setup artifacts in Steps 2–4; leave later-owned artifacts absent |
| Folder exists, artifacts complete | Output folder path, skip creation |
| Archive instruction received | Move folder to `openspec/changes/archive/<feat-name>/` — do not check issue state (the move ships in the change's PR, so merging archives it) |

For an archive instruction from `dev`, use Archive action below instead of setup. For a complete existing folder, report its path and stop. For a partial folder, identify what is missing and preserve valid existing artifacts while completing the requested setup.

## Step 2: Resolve scope and artifact sources

**Change folder location:** `openspec/changes/<change-name>/` inside the project repo. The change name is kebab-cased with the change type as prefix: `feat-` for a story group ("Onboarding" → `feat-onboarding`), `fix-` for a bug, `chore-` for non-feature work. Stories live in a `specs/` subdirectory within the change folder.

**Bug fixes and other changes with no story group:** use `**Story group:** none (<source of the requested change>)` in `proposal.md`. Derive `specs/stories.md` from the requested observable outcome and acceptance criteria; no discovery artifact or invented story group is required. For a bug, include the broken behaviour from the user’s side, plus a regression-guard story if the fix adds one. Everything else is unchanged.

**Artifacts and their sources:**

| File | Source | Rule |
|---|---|---|
| `proposal.md` | `one-pager.md` or `lean-canvas.md` + story group | Derived — no questions needed |
| `specs/stories.md` | Story group from `job-stories.md` | Pulled verbatim; acceptance criteria derived from story outcomes |
| `design.md` | `arch-review` skill output; for a `bounded` change, a short design note | Written verbatim from inline `arch-review` invocation output — do not reformat or summarize. A `bounded` change (the Path in the Scope Brief) skips `arch-review`: write the options as a short trade-off table, the choice, and what it sacrifices |
| `tasks.md` | Derived from `design.md` + story scope | One section per layer, named and ordered as the project defines them (see Layers); omit empty layers |
| `sprint-contract.md` | Derived from `specs/stories.md` | Written by `dev` from the evaluator's report at Phase 3 — do not create during Phase 0 |
| `issues.md` | Written by tracker integration (`linear` or `github`) | Do not create — leave absent at this stage |

**Layers** come from the project, never from this skill: the layer names and their order in the repository's `AGENTS.md`, or the rules in `openspec/config.yaml` if it has them. If the project names no layers, ask the user once and suggest they add them to `AGENTS.md`.

## Step 3: Write proposal and stories

1. If the request or discovery artifacts name a story group, resolve it and confirm only when ambiguous. Otherwise use the no-story-group path above for a bug, chore or other requested change.
2. Write `proposal.md` and `specs/stories.md` using the source rules above and templates below. For a change without a story group, use the no-story-group rule above.
3. Carry the Scope Brief’s exclusions into non-goals and its Also update items into the planned scope. Leave plan checkboxes unticked.

## Step 4: Produce the design and layer tasks

1. Preserve an existing design that still satisfies the scope and stories. If `design.md` is missing or invalid, produce it: write the short design note for a bounded change, or, for other changes, invoke `arch-review` and preserve its output verbatim.
2. Derive missing or invalid tasks from the preserved or newly produced design and the stories. Use only the project’s layer names and order, omitting empty layers.
3. Write `tasks.md`. Do not create `issues.md` or `sprint-contract.md`; their later owners remain unchanged.

## Step 5: Verify the artifacts and hand off

Check that each story’s outcome has acceptance criteria, tasks stay within the scope and cover the applicable layers, and every file follows its source rule. Report the change folder path, created/reused files and any missing input, then return to the caller. Do not start implementation or mark work evaluated.

## Archive action: Move only when dev instructs it

Receives an explicit archive instruction from `dev` (never self-triggers). Moves `openspec/changes/<feat-name>/` → `openspec/changes/archive/<feat-name>/` with `git mv`, as the last commit before `dev`'s completion phase. Does not verify issue state: the issues close when that PR merges. Later edits (a re-evaluation) go to the archived folder in place; it never moves back.

## Artifact templates

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

## :<first-layer>
- [ ] [task]

## :<next-layer>
- [ ] [task]
```

One section per project layer, in the project's order. Omit layer sections that have no tasks for this story group.

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

Never write a `Cross-review:` or `Evaluated at:` line into the contract: `dev` adds them from a real review outcome (Phase 4) and a real evaluator run (Phase 3). A line's presence says the step was recorded; its value says the outcome (`converged at`, `unavailable:` or `skipped`), and only `converged at` is review coverage.

Layer names are taken from `tasks.md` headings. One section per layer present in `tasks.md`.

## Constraints

- When invoked with a Scope Brief (from `dev`), keep `proposal.md` and `tasks.md` inside it: its **Explicitly out of scope** items go in the proposal as non-goals, and its **Also update** items become tasks
- `design.md` is written verbatim from `arch-review` output — never reformatted or summarized (a `bounded` change's short design note is the exception)
- Checkboxes in `tasks.md` and `specs/stories.md` stay unticked: they are the plan, and `sprint-contract.md` is the record of what was verified. Reviewers shouldn't flag unticked boxes
- The archive move happens in the change's own PR, as its last commit (see `dev` Phase 4), so merging archives it
- `issues.md` is written by tracker integration (`linear` or `github`), not `spec-writer` — do not create it here
- Archive action is only invoked by `dev` — never self-triggered
- Change name is kebab-cased with a type prefix: `feat-` (story groups), `fix-` (bugs), `chore-` (non-feature work)
- Omit empty layer sections from `tasks.md`
- `sprint-contract.md` is written by `dev` at Phase 3, from the evaluator's report — never created by `spec-writer` during Phase 0; leave absent at setup time

## Examples

**Creating a change folder:**

Story group: Onboarding (Habit Tracker)

Change folder created at `openspec/changes/feat-onboarding/`:

```
proposal.md       ← scope: first-time user adds a habit without friction
specs/
  stories.md      ← 3 onboarding stories, each with acceptance criteria below
design.md         ← arch-review output (verbatim): HabitRepository in the first layer, HabitListScreen in the second
tasks.md          ← one section per project layer that has work (here two: :<layer-1>, :<layer-2>)
issues.md         ← absent at creation time; written later by tracker integration (linear or github)
sprint-contract.md  ← absent at creation time; written at Phase 3 from the evaluator's report
```

`tasks.md` for this example:
```markdown
# Tasks: Onboarding
**Change:** feat-onboarding
**Date:** 2026-03-23

## :<layer-1>
- [ ] Define Habit schema in SqlDelight
- [ ] Implement HabitRepository with insert and getAll operations
- [ ] Write unit tests for HabitRepository

## :<layer-2>
- [ ] Implement HabitListScreen composable with empty state
- [ ] Implement AddHabitScreen composable with a name field
- [ ] Wire navigation between HabitListScreen and AddHabitScreen
```

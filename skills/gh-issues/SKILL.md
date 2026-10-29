---
name: gh-issues
description: "Explicit-use only — invoke when the user explicitly names this skill, or when an active explicitly invoked workflow calls it. Translates an OpenSpec change folder into a GitHub parent epic plus one sub-issue per layer, from specs/stories.md and tasks.md, and writes the issues.md anchor file. Idempotent: skips when issues.md already exists."
metadata:
  type: flexible
---

# GitHub Issues

**REQUIRED:** load the github skill for how to run each `gh` step (head-commit scoping, bounded CI waits, bodies from files, verifying writes). This skill owns the conventions; github owns the mechanics.

## When to Use

**Explicit use only:** the user names this skill, or `dev` calls it.
- Translating an OpenSpec change into GitHub issues

**Entry detection:**
- `issues.md` exists in the change folder → issues already created; output existing numbers and stop
- No `issues.md` → first run; create epic + sub-issues and write `issues.md`

## Principles

**Input:** OpenSpec change folder path (e.g., `openspec/changes/feat-onboarding/`). Reads three files from the folder: `proposal.md` (epic title), `specs/stories.md` (stories and acceptance criteria), `tasks.md` (layer list).

**Output:** One parent epic issue + one sub-issue per layer present in `tasks.md`. Only layers with tasks are created — no empty placeholder tickets.

**Issue creation tool:** `gh issue create --label … --body-file <file>`. Write bodies to a file first so Markdown survives quoting. Create missing labels with `gh label create`.

**Conversation flow:**
1. Check for `issues.md` in the change folder — if present, output existing numbers and stop
2. Read `proposal.md`, `specs/stories.md`, and `tasks.md` from the change folder
3. Infer which layers are needed from `tasks.md`. Confirm with the user only when a task's layer is ambiguous; a `tasks.md` whose headings name the layers needs no confirmation
4. Create parent epic issue, then sub-issues referencing it
5. Write `issues.md` anchor file immediately
6. Output: epic number + sub-issue numbers per layer

**Parent epic issue:**
- Title: feature name from `proposal.md`
- Body: job stories from `specs/stories.md` as context
- Labels: `epic` + type label (`feat` / `fix` / `chore`)

**Sub-issue body format:**
```
Part of: #<parent-issue-number>

## Stories this addresses
- When [situation], I want to [motivation], so I can [outcome]

## Acceptance criteria
- [ ] [from specs/stories.md acceptance criteria relevant to this layer]
```

**Sub-issue labels:** `layer:shared` / `layer:android` / `layer:backend` + type label

**`issues.md` anchor format:**
```
epic: <number>
shared: <number>
android: <number>
backend: <number>
```
Include only layers that have sub-issues. Written immediately after all issues are created.

**Label creation:** Create these labels if they don't exist in the repo. Colors are implementer-suggested defaults for `gh label create --color`; do not override if the label already exists:

| Label | Purpose | Suggested color |
|---|---|---|
| `epic` | Parent issue marker | `#0052cc` |
| `layer:shared` | KMP shared module work | `#e4e669` |
| `layer:android` | Compose/Android work | `#a2eeef` |
| `layer:backend` | Go backend work | `#d4c5f9` |
| `feat` | New feature | `#0075ca` |
| `fix` | Bug fix | `#d73a4a` |
| `chore` | Non-feature work | `#cfd3d7` |

## Constraints

- Idempotent: always check for `issues.md` before creating anything
- If the work already has an issue (named by the user or filed earlier), don't create an epic and sub-issues around it: write `issues.md` mapping each layer to that issue number
- Only create sub-issues for layers that have tasks in `tasks.md`
- Write `issues.md` immediately after issue creation — do not wait
- `issues.md` fields use lowercase layer names: `shared`, `android`, `backend`
- Label colors are defaults — do not override if the label already exists with a different color

## Examples

**Habit Tracker — Onboarding:**

Epic created: `#12 — Onboarding` (labeled `epic`, `feat`)

Sub-issues:
- `#13 — Onboarding: shared layer` (labeled `layer:shared`, `feat`) — Part of #12
- `#14 — Onboarding: android layer` (labeled `layer:android`, `feat`) — Part of #12

`issues.md` written to `openspec/changes/feat-onboarding/`:
```
epic: 12
shared: 13
android: 14
```

No `backend` field — this story group had no backend tasks.

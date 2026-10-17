---
name: linear-issue
description: "Translates an OpenSpec change folder into a Linear parent issue plus layer-specific sub-issues. Reads proposal.md, specs/stories.md, and tasks.md. Writes issues.md anchor file with created issue identifiers. Idempotent — skips if issues.md already exists. Invoke when a change folder exists but no Linear issues have been created yet. Triggers: \"create issues for feat-X\", \"open issues for feat-X\"."
metadata:
  type: flexible
---

# Linear Issue

## When to Use

**Invoke for:**
- Translating an OpenSpec change into Linear issues — "create issues for feat-X", "open issues for feat-X"

**Entry detection:**
- `issues.md` exists in the change folder → issues already created; output existing identifiers and stop
- No `issues.md` → first run; create parent issue + sub-issues and write `issues.md`

## Principles

**Input:** OpenSpec change folder path (e.g., `openspec/changes/feat-onboarding/`). Reads three files: `proposal.md` (parent issue title), `specs/stories.md` (stories and acceptance criteria), `tasks.md` (layer list).

**Output:** One parent issue + one sub-issue per layer present in `tasks.md`. Only layers with tasks are created — no empty placeholder tickets.

**Issue creation tool:** Use `mcp__plugin_linear_linear__save_issue` for all issue creation.

**Conversation flow:**
1. Check for `issues.md` in the change folder — if present, output existing identifiers and stop
2. Read `proposal.md`, `specs/stories.md`, and `tasks.md`
3. Confirm team and project name with the user (one question, upfront)
4. Check existing labels via `mcp__plugin_linear_linear__list_issue_labels` — create missing ones via `mcp__plugin_linear_linear__create_issue_label`
5. Create parent issue, then sub-issues referencing it via `parentId`
6. Write `issues.md` anchor file immediately
7. Output: parent identifier + sub-issue identifiers per layer

**Parent issue fields:**
- `title`: feature name from `proposal.md`
- `description`: job stories from `specs/stories.md`
- `team`: confirmed team name
- `project`: confirmed project name
- `labels`: type label (`feat` / `fix` / `chore`)
- `state`: `"Backlog"`

**Sub-issue body format:**
```
Part of: <parent-identifier>

## Stories this addresses
- When [situation], I want to [motivation], so I can [outcome]

## Acceptance criteria
- [ ] [from specs/stories.md acceptance criteria relevant to this layer]
```

**Sub-issue fields:**
- `title`: `<feature name>: <layer> layer` (e.g., `Onboarding: shared layer`)
- `team`: same as parent
- `project`: same as parent
- `parentId`: parent issue identifier (e.g., `APP-12`)
- `labels`: `layer:shared` / `layer:android` / `layer:backend` + type label
- `state`: `"Backlog"`

**`issues.md` anchor format:**
```
parent: <identifier>
shared: <identifier>
android: <identifier>
backend: <identifier>
```
Include only layers that have sub-issues. Written immediately after all issues are created.

**Label creation:** Check with `mcp__plugin_linear_linear__list_issue_labels` first. Create missing labels via `mcp__plugin_linear_linear__create_issue_label`. Do not override labels that already exist.

| Label | Purpose | Suggested color |
|---|---|---|
| `layer:shared` | KMP shared module work | `#e4e669` |
| `layer:android` | Compose/Android work | `#a2eeef` |
| `layer:backend` | Go backend work | `#d4c5f9` |
| `feat` | New feature | `#0075ca` |
| `fix` | Bug fix | `#d73a4a` |
| `chore` | Non-feature work | `#cfd3d7` |

## Constraints

- Idempotent: always check for `issues.md` before creating anything
- Only create sub-issues for layers that have tasks in `tasks.md`
- Write `issues.md` immediately after issue creation — do not wait
- `issues.md` fields use lowercase layer names: `shared`, `android`, `backend`
- Sub-issues must reference the parent via `parentId` — do not use `relatedTo`
- Do not create labels that already exist

## Examples

**Habit Tracker — Onboarding (team: App, project: Habit Tracker):**

Parent created: `APP-12 — Onboarding` (labeled `feat`)

Sub-issues:
- `APP-13 — Onboarding: shared layer` (labeled `layer:shared`, `feat`) — parentId: `APP-12`
- `APP-14 — Onboarding: android layer` (labeled `layer:android`, `feat`) — parentId: `APP-12`

`issues.md` written to `openspec/changes/feat-onboarding/`:
```
parent: APP-12
shared: APP-13
android: APP-14
```

No `backend` field — this story group had no backend tasks.

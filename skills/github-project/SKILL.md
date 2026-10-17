---
name: github-project
description: "Creates and manages the GitHub Projects board for a repo. Sets up Backlog/In Progress/In Review/Done columns on first run. Places issues on the board and transitions their status as work progresses. Idempotent — reads openspec/project.md anchor to detect existing board. Invoke when setting up a new project board, adding issues to the board, or transitioning issue status. Triggers: \"set up project board\", \"add issues to board for feat-X\", \"move issue #N to In Progress\"."
metadata:
  type: flexible
---

# GitHub Project

## When to Use

**Invoke for:**
- Setting up the board for a new repo — "set up project board"
- Adding new issues to the board — "add issues to board for feat-X"
- Transitioning issue status — "move issue #N to In Progress / In Review / Done"

**Entry detection:**
- `openspec/project.md` exists → board already set up; read project number and proceed to placement/transition
- No `openspec/project.md` → first run; create board, configure columns and fields, write anchor file

## Principles

**Board anchor file (`openspec/project.md`):**
```
project: <github-project-number>
```
Written on first run. Presence confirms board exists — skip creation.

**Board configuration (first run only):**
- Four status columns in order: `Backlog`, `In Progress`, `In Review`, `Done`
- Custom field: `Layer` (single-select: `shared`, `android`, `backend`)
- Custom field: `Epic` (text — parent issue number)

**Issue placement rules:**

| Event | Action |
|---|---|
| Issues created by `github-issue` | Add all sub-issues to `Backlog`; set `Layer` and `Epic` only if the board has those fields |
| Branch created for a sub-issue | Move sub-issue to `In Progress` |
| PR opened for a sub-issue | Move sub-issue to `In Review` |
| PR merged | Move sub-issue to `Done` |

**Conversation flow:**
1. Check for `openspec/project.md`
2. If first run: create project → configure status columns → add `Layer` field → add `Epic` field → write anchor file
3. If subsequent run: read project number from `openspec/project.md` → place or transition the specified issue(s)

All board operations use `gh project` CLI commands.

**Detecting board membership (for subsequent runs):**
Use `gh project item-list <project-number> --owner @me --format json` and check whether the target issue URL appears in the results. If the issue is not in the list, add it.

**Transition input (from pr-workflow on merge):**
Receives a sub-issue number. Queries the project for the item matching that issue number via `gh project item-list`, then updates its status field to `Done` via `gh project item-edit`.

## Constraints

- Boards created before this skill may lack the `Layer` and `Epic` fields. Read them with `gh project field-list <n> --owner @me` and set only the fields that exist; labels and GitHub's built-in Parent issue already carry the same information. Don't add fields to an existing board unasked.

- Always check `openspec/project.md` before any board operation — never assume the board exists or doesn't
- Status columns must be created in order: `Backlog`, `In Progress`, `In Review`, `Done`
- Layer field values must match `tasks.md` section headers exactly: `shared`, `android`, `backend`
- Never recreate a board that already exists — always read the anchor file first

## Examples

**First run — new repo:**

`openspec/project.md` does not exist.

Steps:
1. `gh project create --owner @me --title "<Repo Name>"` → returns project number (e.g., 3)
2. Configure status field with four columns: Backlog, In Progress, In Review, Done
3. Add Layer single-select field with options: shared, android, backend
4. Add Epic text field
5. Write `openspec/project.md`: `project: 3`

**Subsequent run — add issues after `github-issue` completes:**

`openspec/project.md` contains `project: 3`. `issues.md` contains `shared: 13`, `android: 14`.

Steps:
1. Read project number: 3
2. Add issue #13 to project: `gh project item-add 3 --owner @me --url <issue-13-url>`
3. Set Layer field to `shared` on item #13
4. Set Epic field to `12` on item #13
5. Repeat for issue #14 with Layer `android`
6. Both items land in `Backlog`

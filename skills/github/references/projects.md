# GitHub Projects

How a repository organizes its board is that repository's decision: read it from its `AGENTS.md` (project number and owner, status columns, any custom fields and which lifecycle event moves an item). This file is only the mechanics. If `AGENTS.md` names no project, ask the user once and record the answer there; never invent a board layout.

Projects need the `project` token scope (`gh auth refresh -s project`). Check commands and flags with `gh project --help`; they change between releases.

## Operations

| Need | Command |
|---|---|
| Add a PR or issue | `gh project item-add <n> --owner <owner> --url <url>`, or `gh pr create --project <title>` at creation |
| Is it already on the board | `gh project item-list <n> --owner <owner> --format json --limit 500`, then match `.items[].content.url` |
| Field and option IDs | `gh project field-list <n> --owner <owner> --format json` (single-select fields list their options) |
| Set a field (status, layer) | `gh project item-edit --project-id <project-node-id> --id <item-id> --field-id <field-id> --single-select-option-id <option-id>` |
| Project node ID | `gh project view <n> --owner <owner> --format json -q .id` |

`item-edit` takes IDs, not names: resolve the field and option from `field-list` every time instead of storing them, since editing the board changes them.

## Lifecycle moves

When the repository's `AGENTS.md` maps lifecycle events to columns, apply them as the work moves: issue filed, branch created, PR opened, PR merged. GitHub's built-in project workflows may already move items on PR open or merge; read the board after the event before setting a status yourself, so you don't fight an automation.

## Gotchas

- A board may lack fields a workflow expects. Read `field-list` and set only the fields that exist.
- `item-list` pages: pass a `--limit` above the board's size, or an item looks missing and gets added twice.

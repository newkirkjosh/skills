---
name: linear
description: "Explicit-use only — invoke when the user explicitly names this skill, or when an active explicitly invoked workflow calls it. Reference guidance for working in Linear through its official MCP server: connecting it, finding current tools and fields from Linear's own docs, resolving teams, projects, labels and workflow states before writing, sub-issues, linking GitHub work, moving issues through the lifecycle, and getting approval before workspace-visible changes."
license: MIT
---

# Linear

Linear is driven through its official MCP server (`https://mcp.linear.app`). Its tools describe themselves; Linear's docs describe the model underneath. This skill holds what neither says: the order to resolve things in, and the mistakes that cost a round trip.

**Explicit use only.** Carry out the named Linear operation, verify it and return. Do not start a lifecycle or create unrelated artifacts; this skill ends at its report.

## Step 1: Connect and read the current schema

- **Tools:** load the schema of each Linear tool before its first call (on Claude Code, `ToolSearch` with `select:<tool>`). Tool names and parameters change; read the current ones instead of recalling them.
- **Concepts and behaviour:** the MCP's `search_documentation` tool searches Linear's docs. Use it for how workflows, cycles, triage, integrations or SLAs behave.
- **Raw API**, only when no tool covers the need: https://linear.app/developers, with the schema introspectable at `https://api.linear.app/graphql`. An API key goes in the `Authorization` header through `curl -K -` on stdin, never argv.

Don't write a Linear API or MCP version into notes or answers.

**Missing connection:**

If the Linear tools are missing or only an `authenticate` tool exists, call it and give the user the authorization URL **in its own short message**, so it isn't buried in a longer report. After they approve, the real tools appear on their own. If the redirect page errors, ask for the full address-bar URL and pass it to the completion tool; if the sign-in page itself errors, have them run `/mcp`.

## Step 2: Resolve the target and scoped identifiers

Issues reference teams, projects, labels and states by name, and each of those is scoped. Resolve only those needed for the requested operation:

1. **Team and project.** Resolve team/project destinations explicitly named in the request first; use the identified issue’s current team/project or the project’s `AGENTS.md` only as a fallback. If a required identifier remains ambiguous, list candidates (`list_teams`, `list_projects`) and ask the user once. Record a reusable mapping in `AGENTS.md` only when that local edit is authorized; a status lookup needs no instruction-file edit.
2. **Labels.** `list_issue_labels` for the team. Labels can be team-scoped or workspace-wide; note a missing label for the authorized write in Step 3, using `save_issue_label` and the team’s UUID, never a duplicate of an existing name.
3. **States.** `list_issue_statuses` for the team. Teams rename and add states; use the names it returns, matched by their `type` (`backlog`, `unstarted`, `started`, `completed`, `canceled`).

## Step 3: Perform the authorized operation

For a read-only request, collect the requested objects and continue to Step 4 without a workspace write. For a write:

1. Check the requested write against the approval rule below; reuse authority already provided for that operation.
2. Apply the resolved team, project, label and state identifiers. Use the relationship and edit rules below for sub-issues, links and descriptions.
3. If the caller is `dev` at issue creation, follow `references/openspec-issues.md`; for a standalone operation, do only the requested service change.

**Result:** the requested operation has been attempted once with resolved identifiers. A failure is not a successful state transition.

## Step 4: Read back and report

1. Read the issue or other changed object and verify the fields that matter to this operation, using Rules below. Account for markdown normalization when checking a description.
2. Report the object link/identifier, verified state and anything that remains unresolved. If a write’s outcome is unknown, inspect it before retrying.
3. Stop at that report; a successful issue edit does not authorize implementation or additional workspace changes.

## Rules

- **Workspace-visible writes need approval.** Creating projects, labels and issues, commenting, or changing state shows up for everyone in the workspace. Confirm first unless the user already asked for that exact action.
- **Sub-issues use `parentId`**, not a relation.
- **Mirror, don't fork.** When the work already has a GitHub issue, link it on the Linear issue (`links`) and keep `Closes #<n>` in the PR. Linear tracks it; GitHub still closes it.
- **Move the issue with the work.** Backlog when filed, the team's `started` state when the branch exists, review state when the PR opens (with the PR URL as a comment), `completed` when it merges unless an integration does it.
- **Edit descriptions with `patch`**, not a full rewrite. Linear normalises markdown on save (list markers, issue mentions become links), so a stored description never matches the text you sent; don't compare them as strings.
- **Read back what matters.** After a state change or a parent link, check the returned `status` and `parentId`, not just that the call succeeded.

## References

- `references/openspec-issues.md`: turning an OpenSpec change folder into a parent issue plus one sub-issue per layer, and the `issues.md` anchor. Read when `dev` reaches issue creation with Linear as the tracker.

## Gotchas

- An issue's `gitBranchName` is Linear's suggested branch. Branches and PRs that contain the issue identifier only auto-link and auto-move the issue if the Linear GitHub integration is installed for that repository; check with the user before relying on it, and comment the PR URL otherwise.
- `create_issue_label` is deprecated in favour of `save_issue_label`.
- A project created through the MCP joins the team you pass in `addTeams`; without one the call fails.

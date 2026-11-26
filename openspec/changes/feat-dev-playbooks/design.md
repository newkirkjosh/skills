# Design: dev task-type playbooks

## Decision
How `dev`'s instructions split so one explicit entry point routes to task-type playbooks, while the lifecycle `team` depends on stays one unchanged procedure.

Fixed by the owner (#51): `/dev` stays the only explicit entry; playbooks are frontmatter-free files in `skills/dev/references/`; `Playbook:` is recorded in `scope-brief.md` with the branch-prefix fallback; the five-route order (with separate bug-fix and change outcomes for new work); a `setup` playbook.

## Current responsibilities
`SKILL.md` (219 lines) holds four things: the invocation boundary and roles (shared), worktrees (shared), entry detection plus Phases 0–6 (the lifecycle), and constraints/gotchas (mostly lifecycle). The only non-lifecycle path is the `spike` row in `references/scope-brief.md`, which "leaves the lifecycle". Observed problem: a status question enters the Worktrees status rule, which can merge and push; a bug runs the feature front end. Both come from the lifecycle being the only path.

## Options

| | A: router + playbooks, lifecycle shared | B: router + playbooks, each lifecycle playbook holds its own Phases 1–6 | C: one SKILL.md with playbook sections |
|---|---|---|---|
| Simplicity | Each file has one job; `change` and `bug-fix` are front ends | Two copies of ~100 lines of phases | One file, but routing and lifecycle interleave |
| Testability | One entry table to replay; front ends replay separately | Two tables must stay equal | Same as today |
| Maintainability | A phase fix lands once | Every phase fix lands twice; drift is the likely failure | Body passes 500 lines once `setup` and `bug-fix` land |
| Load cost | Router plus one playbook plus lifecycle for full runs | Router plus one playbook | Everything every time |

## Recommendation: A

### Files
- `SKILL.md`: When to use, Invocation boundary, Roles, Scope Brief, Worktrees, **Routing** (below), the constraints that hold for every playbook (explicit invocation, Scope Brief verbatim, role separation, real device state, signing failures stop the run), and the gotchas that hold for every playbook (signing). The Worktrees status rule's sync and close-out actions run only inside `lifecycle.md`; outside it they are reported, never done.
- `references/lifecycle.md`: today's Entry detection minus its first paragraph (find the change, Requested re-evaluation, Requested sync, `handoff.md`, the table, in today's order), Phases 1–6, and every lifecycle-only constraint and gotcha (sync after merge, squash ancestry, red-first, behavioral records, sprint contract evidence, evaluator, `INCOMPLETE`, build caches), all moved verbatim apart from link paths. It is the **one owner** of `team`'s re-evaluation and sync overrides and of `handoff.md`, and runs from its top on every lifecycle entry, so their order and preconditions are today's.
- `references/playbook-change.md`: today's Phase 0, moved verbatim except step 2's spike line, which becomes: a request found at step 2 to be a spike after all removes its still-empty worktree (`wt remove <branch>`) and goes to `investigation`.
- `references/playbook-bug-fix.md`: front end only. Reproduce on the real surface (read-only), root cause, create the worktree on `fix/<name>`, write `fix-<name>` with `scope-brief.md` (`Playbook: bug-fix`), `proposal.md`, `specs/stories.md` (observed versus expected, plus a regression-guard story), a short design note and a one-layer `tasks.md`, commit it, then run `lifecycle.md` from its top. It never files issues or writes `issues.md`: entry detection finds no `issues.md` and runs Phase 1, which already reuses an existing issue or files one. A root cause needing architectural work stops before the worktree and reroutes to `change`.
- `references/playbook-pickup.md`: decides the playbook of existing state, then runs `lifecycle.md` from its top. The recorded `Playbook:` line wins. Without one: a folder that is a `dev` change folder (`openspec/changes/<feat-name>/` or its archive, holding `scope-brief.md`, or `proposal.md` and `tasks.md`) gets `bug-fix` for a `fix/` branch, else `change`. A worktree, branch or PR with no folder decides nothing yet: `lifecycle.md`'s reconstruct rows rebuild the folder, and the rebuilt `scope-brief.md` records the playbook by the same prefix rule.
- `references/playbook-status.md`, `playbook-investigation.md` (today's `spike`), `playbook-prototype.md`: each opens with its write scope. `status` reads `wt list`, PR state and `pr-status.sh`, and reports a behind PR or a merged one as a suggestion. `investigation` reads and answers. `prototype` exports the needed tree to a scratch directory outside git (`git archive`, never a worktree or branch), labels the result throwaway, and reports what it learned; none syncs, commits, pushes or recreates a worktree, including for an existing change.
- `references/playbook-setup.md`: below.

### Routing (in `SKILL.md`, checked in order, first match wins)
1. **Interrupted sync** (today's first entry-detection paragraph, moved verbatim): a sync journal record without `handed-off`, or a merge in progress in the change's worktree → change nothing, report it (`TEAM: BLOCKED sync interrupted` under `team`) and stop. This only reads, so it runs before a read-only ask too, and is reported, never repaired.
2. **Write-free ask** → `status`, `investigation` or `prototype`, even when it names an existing change: a status question; "how does X work"; a feasibility question (today's `spike`); "prototype" or "try" an approach. Terminal: report and stop. A `team` re-invocation never matches here.
3. **Repository setup ask** ("set up this repo for dev") → `setup`. Terminal at its PR or report.
4. **Existing state** (`lifecycle.md`'s find-the-change order: layer branches in `wt list`, an open PR, the archived folder), or any `team` re-invocation → `pickup` → `lifecycle.md` from its top.
5. **New work**: a reported defect with observable wrong behavior → `bug-fix`; anything else → `change`. Show the choice with the Scope Brief confirmation; an architectural root cause goes to `change`.

Wording picks only among write-free playbooks (step 2), `setup` (step 3) and the front end for new work (step 5); state picks every lifecycle step.

### Setup playbook
1. Read the default branch's `AGENTS.md` (after `git fetch origin refs/heads/<default>`, `git show FETCH_HEAD:AGENTS.md`).
2. Report each section `dev` reads as present, missing or ambiguous: Tracker (and board), Layers, Pull requests (title style, labels, project), Merge policy, the local checks completion runs before publishing (Testing), the real-device permission line if the repository drives hardware, and the named verification skill.
3. Draft the missing ones from repository facts (remote, `gh label list`, `.github/workflows/`, branch protection), never changing an existing section without approval. On approval: a `chore/dev-setup` worktree, one commit, a PR; never a direct push, never a merge.
4. Offer once, only for a repository the user owns, to add the verification line naming `verify-change` with the repository's verification facts; for any other repository report that the line would select nothing.

**Sacrificed:** a full run loads three files instead of one, and a reader follows the lifecycle across two files. B would be preferable only if `bug-fix` needed a materially different Phase 2–6, which #51 rules out.

**YAGNI flags (surfaced, not removed):** `pickup` duplicates routing step 5 in a short file; it earns a file only by holding the fallback and `handoff.md` rules. `prototype` has no demonstrated run yet; it is kept because the owner approved it and it writes nothing durable.

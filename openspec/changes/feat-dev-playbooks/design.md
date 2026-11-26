# Design: dev task-type playbooks

## Decision
How `dev`'s instructions split so one explicit entry point routes to task-type playbooks, while the lifecycle `team` depends on stays one unchanged procedure.

Fixed by the owner (#51): `/dev` stays the only explicit entry; playbooks are frontmatter-free files in `skills/dev/references/`; `Playbook:` is recorded in `scope-brief.md` with the branch-prefix fallback; the six-step routing order; a `setup` playbook.

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
- `SKILL.md`: When to use, Invocation boundary, Roles, Scope Brief, Worktrees (its status rule's sync and close-out run only inside a lifecycle playbook), **Routing** (the six steps, with the interrupted-sync check and `team`'s requested re-evaluation/sync, moved from entry detection), Constraints that hold for every playbook, Gotchas.
- `references/lifecycle.md`: today's entry-detection table and Phases 1–6, moved verbatim apart from link paths. Run only by `change`, `bug-fix` and `pickup`.
- `references/playbook-change.md`: today's Phase 0, then lifecycle.
- `references/playbook-bug-fix.md`: reproduce on the real surface, root cause, a small `fix-` change folder (`scope-brief.md`, `proposal.md`, `specs/stories.md` with observed versus expected as the story, a short design note, one-layer `tasks.md`), reuse or file one issue, then lifecycle from Phase 1. An architectural root cause reroutes to `change`.
- `references/playbook-pickup.md`: resolve the change read-only, read its `Playbook:` (fallback by branch prefix after verifying a `dev` change folder), read `handoff.md`, then lifecycle entry detection.
- `references/playbook-status.md`, `playbook-investigation.md` (today's `spike`), `playbook-prototype.md`: each states its write scope first; none syncs, commits or pushes.
- `references/playbook-setup.md`: read the default branch's `AGENTS.md`, report each section `dev` reads, draft the missing ones from repository facts, publish only as a PR on its own branch after approval, never merge, offer the `verify-change` line once.

**Sacrificed:** a full run loads three files instead of one, and a reader follows the lifecycle across two files. B would be preferable only if `bug-fix` needed a materially different Phase 2–6, which #51 rules out.

**YAGNI flags (surfaced, not removed):** `pickup` duplicates routing step 5 in a short file; it earns a file only by holding the fallback and `handoff.md` rules. `prototype` has no demonstrated run yet; it is kept because the owner approved it and it writes nothing durable.

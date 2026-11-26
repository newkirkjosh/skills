# Specs: dev task-type playbooks

## Story 1: a read-only ask changes nothing
When I ask `/dev` for status or how something works, I want an answer without any sync, commit, push or worktree change, so I can ask safely mid-run.

### Acceptance criteria
- [ ] A status or "how does X work" request routes to `status` or `investigation` before any resume, worktree recreation, sync, commit or push, even when a change's PR is behind the default branch.
- [ ] Each of those playbooks states it writes nothing; `prototype` writes only a scratch copy outside git and `wt`, never a branch, worktree or PR.

## Story 2: existing state picks the step, not my wording
When I invoke `/dev` on a change already in progress, I want it to resume that change's own playbook at the step its state says, so wording can't skip a phase.

### Acceptance criteria
- [ ] A change folder recording `Playbook: bug-fix` or `Playbook: change` resumes through the lifecycle's entry-detection table, unchanged from today.
- [ ] A folder without a `Playbook:` line is first verified as a `dev` change folder, then gets `bug-fix` for a `fix/` branch and `change` otherwise.
- [ ] `team`'s requested re-evaluation and requested sync still preempt step detection, and the interrupted-sync check still runs first.

## Story 3: a bug starts from its reproduction
When I bring `/dev` a bug, I want it reproduced and root-caused first, then carried through the same lifecycle in a small `fix-` change folder, so the fix gets the same tests, evaluation, review and merge gates.

### Acceptance criteria
- [ ] `bug-fix` reproduces on the real surface, records observed versus expected behavior as the story, writes a small change folder and one `tasks.md` layer, reuses or files one issue, then runs lifecycle Phases 2–6.
- [ ] A root cause needing architectural work reroutes to `change` with its design approval.

## Story 4: a repository can be set up for dev
When a repository lacks what `dev` reads from its `AGENTS.md`, I want `/dev` to tell me what's missing and draft it for my approval, so later runs don't guess.

### Acceptance criteria
- [ ] `setup` reads the default branch's `AGENTS.md` and reports each section `dev` reads (Tracker, Layers, Pull requests, Merge policy, the named verification skill) as present, missing or ambiguous.
- [ ] It drafts missing sections from repository facts, shows them for approval, and publishes only as a PR, never a direct push, and never merges.
- [ ] It offers once to add a verification recipe line naming `verify-change`, and never edits an existing section without approval.

## Story 5: nothing the lifecycle does changes
When the lifecycle text moves into its new file, I want every phase to behave exactly as before, so the restructure carries no hidden behavior change.

### Acceptance criteria
- [ ] Entry detection and Phases 1–6 move verbatim except for cross-reference paths; Phase 0 moves into `change`.
- [ ] Every caller's reference to a moved section points to where it now lives; `scripts/check-refs.sh` passes.
- [ ] The `dev` description keeps the explicit-use opener and stays at most 1024 characters.

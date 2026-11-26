# Specs: dev task-type playbooks

## Story 1: a read-only ask changes nothing
When I ask `/dev` for status or how something works, I want an answer without any sync, commit, push or worktree change, so I can ask safely mid-run.

### Acceptance criteria
- [ ] A status, "how does X work", feasibility or prototype request routes to `status`, `investigation` or `prototype` before any resume, worktree recreation, sync, commit or push, even when it names an existing change or that change's PR is behind the default branch; only the interrupted-sync check, which only reads, comes first.
- [ ] A feasibility request is decided before any worktree exists; one found to be a spike at Phase 0 step 2 removes its empty worktree.
- [ ] Each of those playbooks states it writes nothing; `prototype` writes only a scratch copy outside git and `wt`, never a branch, worktree or PR.

## Story 2: existing state picks the step, not my wording
When I invoke `/dev` on a change already in progress, I want it to resume that change's own playbook at the step its state says, so wording can't skip a phase.

### Acceptance criteria
- [ ] A change folder recording `Playbook: bug-fix` or `Playbook: change` resumes through the lifecycle's entry-detection table, unchanged from today.
- [ ] A folder without a `Playbook:` line is first verified as a `dev` change folder, then gets `bug-fix` for a `fix/` branch and `change` otherwise.
- [ ] A worktree, branch or PR with no change folder still reaches today's reconstruct row, and the rebuilt brief records its playbook by the same rule.
- [ ] `team`'s requested re-evaluation and requested sync still preempt `handoff.md` and the table, with their preconditions in today's order, in one place; the interrupted-sync check still runs first.

## Story 3: a bug starts from its reproduction
When I bring `/dev` a bug, I want it reproduced and root-caused first, then carried through the same lifecycle in a small `fix-` change folder, so the fix gets the same tests, evaluation, review and merge gates.

### Acceptance criteria
- [ ] `bug-fix` reproduces on the real surface, records observed versus expected behavior as the story, writes a small change folder and one `tasks.md` layer, then enters the lifecycle at its top, where Phase 1 reuses the existing issue or files one and writes `issues.md`.
- [ ] A root cause needing architectural work reroutes to `change` with its design approval.

## Story 4: a repository can be set up for dev
When a repository lacks what `dev` reads from its `AGENTS.md`, I want `/dev` to tell me what's missing and draft it for my approval, so later runs don't guess.

### Acceptance criteria
- [ ] `setup` reads the default branch's `AGENTS.md` and reports each section `dev` reads (Tracker, Layers, Pull requests, Merge policy, the local checks run before publishing, the real-device permission line where hardware is involved, the named verification skill) as present, missing or ambiguous.
- [ ] It drafts missing sections from repository facts, shows them for approval, and publishes only as a PR, never a direct push, and never merges.
- [ ] It offers once, only for a repository the user owns, to add a verification line naming `verify-change`; elsewhere it reports the line would select nothing. It never edits an existing section without approval.

## Story 5: nothing the lifecycle does changes
When the lifecycle text moves into its new file, I want every phase to behave exactly as before, so the restructure carries no hidden behavior change.

### Acceptance criteria
- [ ] Entry detection (minus its interrupted-sync paragraph, which moves to Routing), Phases 1–6 and the lifecycle-only constraints and gotchas move verbatim except for link paths; Phase 0 moves into `change` with only its spike line changed.
- [ ] A write-free or setup run never inherits a lifecycle write instruction (sync after a merge, push on `INCOMPLETE`).
- [ ] Every caller's reference to a moved section points to where it now lives; `scripts/check-refs.sh` passes.
- [ ] The `dev` description keeps the explicit-use opener and stays at most 1024 characters.

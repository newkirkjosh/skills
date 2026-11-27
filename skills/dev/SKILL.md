---
name: dev
description: "Explicit-use only — invoke when the user explicitly names this skill, or when an active explicitly invoked workflow calls it. Routes explicit dev requests through status, investigation, prototype, pickup, bug-fix, change or setup playbooks. Change and bug-fix share one lifecycle for tests, evaluation, cross-model review, archive and a merge-ready PR; after a merge it closes out the tracker and cleans up."
license: MIT (Scope Brief and head discipline adapted from fx/skills by Marian Rudzynski; see LICENSE.txt)
metadata:
  type: flexible
  upstream: "https://github.com/fx/skills/tree/4b1010d/skills/dev"
---

# Dev

## When to Use

The user names `dev` with a request or change name. Every invocation runs Routing below from scratch: `/dev status for <feat-name>` selects a write-free playbook; `/dev open a PR for <feat-name>` uses existing state to select the lifecycle step. Without the skill's name, neither starts it (Invocation boundary).

## Invocation boundary

- **Start only on an explicit invocation**: the user names `dev` (`/dev`, "use dev for `<feat-name>`"), or `team` runs it for one change. Only the user or `team` starts it. Never load it because a request involves coding, implementation, GitHub, planning, review, or a phrase that resembles one of its phases.
- **Its authority ends at its handoff**: the selected playbook's terminal report or PR, the lifecycle's Phase 5 report (merge-ready or blocked), the Phase 6 report after a merge, or a stop for the user. Later messages are standalone requests unless the user invokes `dev` again; they don't inherit its orchestration.
- **Incidental requests are not phases.** A status question, a branch sync, a PR metadata edit or an explicitly authorized merge is handled directly when it needs no substantive implementation judgment.
- **`dev` never merges.** After the handoff, "merge it" is a standalone request: re-check the live gates (a fresh `pr-status.sh` report on the head and every gate in step 6 of `references/completion.md`) and merge directly in the same session with `--match-head-commit`. Don't re-invoke `dev`, load other skills for it or spawn a merge subagent. `team` is the only workflow that merges by itself, after re-checking every gate.
- **The user may narrow, waive or stop a procedural pass** (skip a re-review, stop after Phase 3). Correctness, security, privacy and merge-gate requirements still hold, but `dev`'s orchestration never outranks a direct user instruction.
- **Work outside `dev`** is a spike or proof of concept the user drives by hand, with no completion workflow.
- **Under `team`**, the `dev` coordinator is a subagent of the `team` session and holds `dev`'s full authority for its change (commits, pushes, the PR, hosted-review fixes), and none to merge. Each later message from `team` is an explicit re-invocation carrying an invocation number; end every final message with the `TEAM:` line it asked for, ending `#<i>`.

## Roles

You are the **coordinator**. You own the Scope Brief, branches, commits, `sprint-contract.md`, the tracker mapping, the archive move and every handoff to the user. Completion (the PR, hosted review, CI, the merge gates and every tracker write after the PR exists) is Phase 5, in this same session, following `references/completion.md`. In a lifecycle run (`references/lifecycle.md`) you delegate exactly three jobs, each to its own general-purpose subagent that reads a role file from this skill's `references/` directory:

| Role | File | Writes | Tier |
|---|---|---|---|
| Test author | `references/test-author.md` | Failing tests and fakes only | `medium` |
| Implementer | `references/implementer.md` | Production code only | `medium` |
| Evaluator | `references/evaluator.md` | Nothing; reports the contract | `medium` |

Spawn each one like this. The syntax is Claude Code's and only illustrative; `<skill-dir>` is the base directory shown when this skill loaded, and `<tier model>` is the host's model for that tier (`small`, `medium` or `large`; on Claude Code currently `haiku`, `sonnet`, `opus`). Never hardcode a model name elsewhere: names change, tiers don't.

```
Agent tool:
  subagent_type: "general-purpose"
  model: "<tier model>"
  description: "<role>: <feat-name> <layer>"
  prompt: "Read <skill-dir>/references/<role>.md and act in that role.

           <the Scope Brief from scope-brief.md, verbatim>

           Change folder: <absolute path>
           Layer: <:layer>
           <role-specific input: the test author's report for the implementer,
            the failing items on a fix pass; for the evaluator only the
            environment it needs (see Phase 3 in references/lifecycle.md)>"
```

**On any host other than Claude Code, and in a headless session on any host** (nothing can answer or wake you mid-run, as in `claude -p` or `codex exec`), read `references/host-adapters.md` before the first spawn. On Codex, follow the adapter’s wait and lifecycle rules; a spawn without `fork_turns: "none"` cannot take a tier. In a headless session its foreground rules override every "run in the background" instruction in this skill.

Never hand a subagent the whole lifecycle, and never do a delegated job yourself: a coordinator that writes the code also grades it. One exception: a review or evaluation finding that only needs a few lines of non-code wording (docs, comments, a contract sentence) you apply directly and say so in the commit; anything touching code, config or tests goes to an implementer.

**Budget.** Each spawn costs roughly 50–80k tokens, and the user's plan has a session limit that a long run can hit. Match the tier to the job: `small` for narrow or mechanical evaluations and doc fixes, `medium` for test authoring, implementation and judgment-heavy evaluation. Keep at most three agents in flight. Reviews go to the other model (Phase 4 in `references/lifecycle.md`), not to more Claude agents; an unavailable required reviewer hands the merge to the user.

## Scope Brief

Read `references/scope-brief.md` before a new change or bug-fix front end. It defines the brief, its fields, and how it travels. Every subagent prompt and every review request in this lifecycle carries the brief verbatim; that is how "just", "only" and the implied neighbouring updates survive past the first handoff.

## Worktrees

For a read-only inspection of the playbook and lifecycle entry for a change, branch or PR, run `bash <skill-dir>/scripts/dev-state.sh <change|branch|PR-number|PR-URL>`. See `references/dev-state.md` for evidence limits and explicit team-request options. This helper does not start a `dev` invocation.

**One change, one worktree, for its whole life,** managed with worktrunk (`wt`; current commands from `wt <command> --help` and https://worktrunk.dev/llms.txt). For lifecycle work only, `wt switch --create <branch> --no-cd` creates it where the user's worktrunk config puts worktrees, before Phase 0 writes anything; find its path with `wt list --format=json | jq -r '.items[] | select(.branch=="<branch>") | .worktree.path'`. Every phase, subagent and command for that change runs from that path. The main checkout stays on the default branch and clean, so other changes can start beside it.

- **Layer branches.** The first layer (in `tasks.md` order) uses the branch the change or bug-fix front end creates: `<feat-name>` with its type prefix's hyphen as a slash (`feat-onboarding` → `feat/onboarding`). Each later layer uses that branch plus `-<layer>`, with `<layer>` as `issues.md` writes it (`feat/onboarding-<layer-2>`), in its own worktree. Layers that share one issue use the first one's branch. "The layer's branch" below always means this name, never whichever branch of the change happens to exist.
- **Parallel work** is one coordinator session per change, each started in its own worktree. A single session juggling several changes runs out of context.
- **Status reads** come from `wt list --format=json` and `gh pr view`. Read-only and setup runs report behind or merged PRs without acting on them. Sync and close-out actions belong only to `references/lifecycle.md` (Worktree status), after lifecycle entry detection and its overrides.
- **Shared resources** in lifecycle checks that only one run can use at a time (an emulator, a device, a fixed local port) are taken with `flock`, on a lock file in the repository's common git dir, which every worktree shares: `mkdir -p "$(git rev-parse --path-format=absolute --git-common-dir)/locks"`, then `flock "$(git rev-parse --path-format=absolute --git-common-dir)/locks/<resource>" <command>`. Hold it for the whole check that needs the resource, and pass the same rule to evaluators.
- **Builds** in separate worktrees have separate outputs and can run side by side; the lock is only for what they truly share.

## Routing

Check in order; first match wins. Read only until a playbook authorizes writes. Load only the selected playbook reference named below, plus references it requests; never preload the lifecycle for a write-free or setup run.

1. **Incomplete sync first.** Before anything else, including finding or recreating the worktree, and whatever the prompt asks: if the sync journal (`<common git dir>/team/changes/<feat-name>/sync-progress`, outside the worktree so it never dirties it) has a record without its `handed-off` line, or a merge is in progress in the change's worktree if it still exists (`git rev-parse -q --verify MERGE_HEAD`; never recreate a worktree to check), change nothing and end `TEAM: BLOCKED sync interrupted` (outside `team`, report it to the user and stop).
2. **Write-free ask:** status → `references/playbook-status.md`; an explanation ("how does X work") or feasibility question → `references/playbook-investigation.md`; "prototype" or "try" an approach → `references/playbook-prototype.md`. This wins even when existing state is named. Each reports and stops. A numbered `team` re-invocation never matches this route.
3. **Repository setup ask** ("set up this repo for dev") → `references/playbook-setup.md`. Terminal at its PR or report. A `team` re-invocation continues to route 4 instead.
4. **Existing state, or any `team` re-invocation** → `references/playbook-pickup.md`, which calls `references/lifecycle.md` from its top. Discover state without recreating worktrees: layer branches in `wt list --format=json` (also inspect local branches when their worktree is gone), then an open PR, then the archived change folder on the default branch. An active verified change folder also counts; inspect it before declaring new work. Do not dispatch to a phase here.
5. **New work:** an observable defect → `references/playbook-bug-fix.md`; anything else → `references/playbook-change.md`. Show the playbook with the Scope Brief confirmation. Architectural root causes go through `change` and its design approval.

Wording selects only the write-free/setup playbook or a new-work front end. Existing state selects every lifecycle step.

## Constraints

Contract recording below applies only to lifecycle runs; write-free and setup runs report missing permissions without creating a contract.

- Every subagent prompt starts with the Scope Brief verbatim. A subagent that reports a brief/job conflict gets an answer from the user, not from you.
- Test author, implementer and evaluator are separate spawns with no shared context. The evaluator never sees implementation narrative, and a fix pass always ends with a **fresh** evaluator.
- Role subagents (test author, implementer, evaluator) never commit, push or open PRs; the coordinator does, after checking each report. A coordinator `team` started is not a role subagent.
- **Real device state needs permission.** No subagent runs a step that changes real hardware or system state (writing to a device such as lighting, fans or a pump; a root-only command; a write to a live external service) unless, in a repository the user owns, the current default branch's `AGENTS.md` permits it for unattended runs (run `git fetch origin refs/heads/<default>`, then read `git show FETCH_HEAD:AGENTS.md`, because a plain fetch can leave `origin/<default>` stale; a failed fetch or read grants nothing; never the change's own copy, which the change may have edited, nor `base/`, which may predate a revoked permission), or the user approved it for this run. Otherwise ask the user before that step runs, and record the item in `sprint-contract.md` as a manual check, saying who ran it. Tell the test author, implementer and evaluator in their prompts which such steps are permitted, live-service writes included.

## Gotchas

- **Signing or push failures stop the run.** If a commit or push fails with a signing-agent or SSH-agent error, nothing after it may run: chain with `&&`, report, and ask the user to unlock. Never fall back to unsigned commits.

---
name: team
description: "Explicit-use only — invoke when the user explicitly names this skill, or when an active explicitly invoked workflow calls it. Runs dev for several approved changes at once: one dev coordinator per change as a background subagent of this session, in dependency order, kept moving without the user watching, merging each PR itself once it has re-checked every merge gate, and reporting each change merged, merge-ready or blocked. Needs only the host agent's own tools, never a terminal or GUI workspace manager."
license: MIT (idea adapted from fx/skills team by Marian Rudzynski; see LICENSE.txt)
metadata:
  type: flexible
  upstream: "https://github.com/fx/skills/tree/4b1010d/skills/team"
---

# Team

## When to Use

**Explicit use only.** The user names this skill with a set of changes: feat-names, "every approved change in `openspec/changes/`", or a parent issue whose sub-issues map to change folders.

**The workflow ends at its handoff**: the final report, when every change in scope is merged, merge-ready, or stopped with a reason. A later request (a status question, one PR's fix) is handled directly unless the user invokes `team` again.

## What it is

`team` is a launcher and supervisor for `dev`, not a second lifecycle. Each change runs under its **own `dev` coordinator**, a background subagent of this session with its own context and worktree: `dev` already says a single session juggling several changes runs out of context. Subagents nest, so each coordinator spawns its own test author, implementer and evaluator. `team` writes no code and opens no PRs. It is the one workflow that merges: `dev` stops at merge-ready, and `team` merges after re-checking every gate itself (`references/merge-gate.md`), as in fx's `team`. What it adds is what an unattended batch needs: dependency order, a concurrency cap, a standing instruction to run without pausing, and someone checking every worker so a stall is noticed by `team`, not the user.

It depends only on the host agent's own tools (spawn, wait, continue, stop) plus `git`, `gh` and `wt`, so it runs the same under any interface the user is trying.

**v1 never recovers anything automatically.** One run per repository, in one interactive session. Any state `team` can't prove clean (an interrupted run, a worker it can't show stopped, an unverified merge, an interrupted sync, an unanswered permission prompt) stops that change with a **hold** that every later run honors until the user clears it (`references/run-state.md`).

## Session operations

Concrete syntax, as in `dev`, is an example; the host adapters reference in `dev` has both hosts' operations.

| Operation | Claude Code | Codex |
|---|---|---|
| **Start** | `Agent`, general-purpose, `run_in_background: true`, tier `large`, and **no `name`**: a named spawn can become an agent-team teammate, with a different lifecycle. Record the returned agent ID. | `spawn_agent` with `fork_turns: "none"`, `task_name` `dev_` plus the feat-name with hyphens as underscores; record the agent ID it returns (the task name is only a label) |
| **Wait** | The completion notification, plus one heartbeat: a background command that just waits 10 minutes | `wait_agent` with `timeout_ms` 600000, before the turn ends |
| **Continue** | `SendMessage` to the agent ID; it resumes in the background and its next final message arrives as a completion | `followup_task` |
| **Check** | the worker's output file, new commits (`wt list --format=json`), PR state | new commits, PR state, the child's status |
| **Stop** | `TaskStop` | `close_agent` (required: preflight) |

Only a `TEAM:` line in the final message of the invocation being waited on counts, and only with the latest invocation number.

## Steps

### 1. Lock and preflight

1. Take the run lock and scan for holds and unretired merge intents (`references/run-state.md`). Lock held by another run: say so and stop.
2. Run `references/preflight.md`. Any failure: say which, stop the probes, and remove the run lock once the host shows them stopped. If it can't show that, leave the lock and say so.

### 2. Scope

1. Resolve the set of changes. Each needs a change folder (`openspec/changes/<feat-name>/` with `scope-brief.md`, `proposal.md` and `tasks.md`, which step 3 orders by), and an `architectural` one also needs the user's approval of its design (`dev` Phase 0). A change without either isn't ready: list it as "needs `dev` Phase 0 first" and leave it out. A held change is listed as `blocked: held (<reason>)` and left out. A change with a record from an earlier run that never reached a final state is inspected, reported and held.
2. Write the run's brief: the user's request **verbatim**, the changes in scope, and anything they said is out of scope. It goes into every worker's prompt beside that change's own `scope-brief.md`.
3. **Do not ask to confirm a clearly scoped request.** "All approved changes", a list of feat-names or a parent issue is the scope; start. Ask only when the scope is genuinely ambiguous or contradictory.

### 3. Order

Build the dependency order from each change's `proposal.md` and `tasks.md` (an explicit "depends on", or a layer that needs another change's code) and from blocking relations on the tracker issues. Two changes that edit the same files run one after the other even without a stated dependency: parallel branches touching one file end in conflicts after the first squash merge. A dependent starts only when its dependency is `done` (every layer merged and closed out), never after one layer's merge.

**Concurrency:** at most three `dev` workers on Claude Code. On Codex one at a time: slots are shared across the whole agent tree, and each worker needs room for its roles.

### 4. Launch

For each unblocked change, within the concurrency cap:

1. Write the change record's `launching` state and invocation number 1 (`references/run-state.md`), **then** **Start** the worker with:

   ```
   Use the dev skill for <feat-name>, invocation 1, and run it to the end without pausing for confirmation. The repository's main checkout is <absolute path>; find or create this change's worktree through dev's entry detection.

   <the run's brief, verbatim>

   This run is under team, unattended. Spawn sub-agents for the roles as dev describes[, and close each finished role agent]. Stop only for something neither the brief nor the change folder covers: an architectural decision, work outside the scope, a destructive step. Never merge: team merges after its own check, then invokes you again. A denied or unavailable operation ends your run with a BLOCKED line; never work around it. End your final message with exactly one line, ending in this invocation's number:
   TEAM: MERGE-READY <PR URL> <head SHA> <ledger path> #<n>
   TEAM: DONE <PR URL> merged #<n>   (only when every layer in issues.md is merged and closed out)
   TEAM: BLOCKED needs approval: <operation> #<n>
   TEAM: BLOCKED needs decision: <question> #<n>
   TEAM: BLOCKED unavailable: <capability> #<n>
   TEAM: BLOCKED <one-sentence reason> #<n>
   ```

   (The bracketed clause is for Codex.)
2. Record the agent ID and `running`.
3. On Claude Code, arm the first heartbeat before ending the turn, so stall checks run even if no worker ever completes. A failed arm follows the same rule as in step 5: retry once, then stop and hold every live change and end the run.

### 5. Supervise

Each wake (a completion, the heartbeat, or a `wait_agent` return) is one pass over every live change. On Codex, when only `merge-pending` handoffs remain and no child is running, wait 10 minutes with a long-running command before the next pass, so deferred gates don't spin. On Claude Code, record the heartbeat's task ID and re-arm it as the pass's last step, only once it has fired, failed or been cancelled; an arm that fails is retried once in the same pass. A second failure ends the run: **Stop** every live worker, hold every change that was live (stopped, or `stop unconfirmed` where the host can't show it stopped, including its roles), then report and release the lock as in step 6. For each change:

| Result | Do |
|---|---|
| Still working | **Check** for progress. Something moved: record it and the time. Idle (measured from the recorded time) 20 minutes: tell the user, mentioning that it may be waiting on a permission prompt in this session. Idle 30 minutes on Claude Code: **Stop** it, and hold it once the host shows it stopped (or hold it as "stop unconfirmed"). On Codex, idleness is reported at 30 and 60 minutes and never stopped, since evaluator and review waits look idle there. |
| A permission prompt from it is waiting | Never answer it. Tell the user. Still unanswered after 30 minutes on either host: **Stop** it where the host can, record `blocked: permission prompt unanswered`, and hold it. |
| Any result while a sync is pending | Handle the sync first (`references/run-state.md`, Sync record): retire it only on the matching `MERGE-READY` with a verified pushed head, then run the merge gate; anything else holds the change. |
| `MERGE-READY` | Run `references/merge-gate.md`. Five outcomes: **merged** (it re-invokes the worker for close-out; state `merged`, still live); **re-invoked** (a sync or re-evaluation; state `running`, still live); **deferred** (a base read or other gate to retry; state `merge-pending`, the handoff stays queued and the gate runs again next pass, worker kept); **refused** (a terminal reason: the policy forbids it, the sync limit, a rejected merge call; final as `merge-ready (<reason>)`); **held** (a merge readback that doesn't verify; hold written, final). |
| `DONE … merged` | `DONE` means every layer is finished, not one PR. Verify it: every layer in the change's `issues.md` maps to a merged PR (`gh api repos/<owner>/<repo>/pulls/<n>`, `merged: true`) and a closed issue, and the change folder is archived on the default branch. Any layer still open: treat the line as `BLOCKED done claimed early` and hold. Verified: finalize it as `done` (below); start whatever it unblocked. |
| `BLOCKED needs decision` | Ask the user. Their answer goes back word for word in an explicit re-invocation ("Use the dev skill for <feat-name> again, invocation <n+1>: <answer>. Run entry detection from <main checkout path>."). |
| `BLOCKED needs approval` / `unavailable` / other | Record it for the report, with the operation or reason verbatim. Never re-invoke it in this run: whether a running worker picks up widened permissions isn't established, so the user widens them and starts a new run. |
| Final message with no `TEAM:` line | It ended its turn without finishing. Re-invoke it once ("Use the dev skill for <feat-name> again, invocation <n+1>. If you are stopped, end with the TEAM line that says why."). Again without one: `stalled`, held. If the message shows a denied or failed operation, record `blocked` instead, without re-invoking. |
| Ended by the host (watchdog, error) | `stalled`, held. |

A stopped, stalled or held change is never restarted, nudged or reassigned. 

**Finalizing.** A final state is written last: on Codex, **Stop** (close) the worker first and confirm it closed, so finished agents don't hold slots; if that can't be confirmed, hold the change instead. A record that isn't final at a later run's start is held.

### 6. Report

When nothing is live and nothing more can start: stop the outstanding heartbeat, remove the run lock, and report one row per change: feat-name, PR, `merged` / `merge-ready (<reason>)` / `blocked: <reason>` / `stalled` / `held: <reason>` / `not started: <why>`, each with its agent ID. Name the operations preflight couldn't prove (PR writes, tracker writes, merge rights), and the residual merge race when the repository doesn't require up-to-date branches.

## Gotchas

- **Never hand one worker several changes.** One change per coordinator is the whole design; batching them into one `dev` run is the context blow-up this skill exists to avoid.
- **No `name` on Claude Code spawns.** With agent teams enabled, a named `Agent` call can start a teammate instead of a subagent, which completes and shuts down differently.
- **`idle` is not done.** A worker that ended its turn mid-run looks exactly like one that finished; only the `TEAM:` line with the latest invocation number tells them apart.
- **Never infer that a lock, a launch or a worker is gone.** An old lock, a `launching` record with no agent ID, or a worker the host doesn't show stopped is the user's to check.
- **Don't answer another agent's permission prompts.** They wait for the user, even when the answer looks obvious.
- **Wave labels never go in PR titles.** Each worker titles its own PR using the repository conventions; a wave or batch number in a title links the squash commit to an unrelated issue.
- **Merging is still per repository.** `team` grants no merge permission the repository's Merge policy doesn't; without one, every PR stops at merge-ready and the report says so.

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
| **Wait** | The completion notification, plus one heartbeat: a background `Bash` command, `sleep 540` with `timeout: 600000`, which stays inside the tool's limit | `wait_agent` with `timeout_ms` 600000, before the turn ends |
| **Continue** | `SendMessage` to the agent ID; it resumes in the background and its next final message arrives as a completion | `followup_task` |
| **Check** | the worker's output file, new commits (`wt list --format=json`), PR state | new commits, PR state, the child's status |
| **Stop** | `TaskStop` | `close_agent` (required: preflight) |

Only a `TEAM:` line in the final message of the invocation being waited on counts, and only with the latest invocation number.

## Steps

### 1. Lock and preflight

1. Take the run lock and scan for holds and unretired merge intents (`references/run-state.md`). Lock held by another run: say so and stop. Also inspect every change record repository-wide, in scope or not: one that isn't final gets a hold, recording `stop unconfirmed` unless the host shows its worker and roles stopped. A hold recording `stop unconfirmed`, or any new hold from this scan, means agent capacity can't be proven: report it, release the lock and stop, before spawning any probe, until the user clears it.
2. Run `references/preflight.md`. Any failure: say which and remove the run lock if no probe was ever started. Otherwise stop the probes, and remove the lock only once the host shows them stopped and the probe coordinator's report confirms its scratch worktree, branch and files are gone. If either can't be shown (a spawn that may have happened, a role that never reported what it wrote), leave the lock and tell the user what to check.

### 2. Scope

1. Resolve the set of changes. Each needs a change folder (`openspec/changes/<feat-name>/` with `scope-brief.md`, `proposal.md` and `tasks.md`, which step 3 orders by; look where `dev`'s entry detection looks, since it may be on a layer branch or already archived there), and an `architectural` one also needs the user's approval of its design (`dev` Phase 0). A change without either isn't ready: list it as "needs `dev` Phase 0 first" and leave it out. A held change is listed as `blocked: held (<reason>)` and left out. A change with a record from an earlier run that never reached a final state is inspected, reported and held. A final `blocked` record with no hold is replaced when the change launches again.
2. Write the run's brief: the user's request **verbatim**, the changes in scope, and anything they said is out of scope. It goes into every worker's prompt beside that change's own `scope-brief.md`.
3. **Do not ask to confirm a clearly scoped request.** "All approved changes", a list of feat-names or a parent issue is the scope; start. Ask only when the scope is genuinely ambiguous or contradictory.

### 3. Order

Held, blocked and not-ready changes stay in the graph as unsatisfied prerequisites; they are only ineligible to launch, so anything depending on them stays unstarted.

Build the dependency order from each change's `proposal.md` and `tasks.md` (an explicit "depends on", or a layer that needs another change's code) and from blocking relations on the tracker issues. Two changes that edit the same files run one after the other even without a stated dependency: parallel branches touching one file end in conflicts after the first squash merge. A dependent starts only when its dependency is `done` (every layer merged and closed out), never after one layer's merge.

**Concurrency:** at most three `dev` workers on Claude Code. On Codex one at a time: slots are shared across the whole agent tree, and each worker needs room for its roles.

### 4. Launch

For each unblocked change, within the concurrency cap:

1. Write the change record's `launching` state and invocation number 1 (`references/run-state.md`), **then** **Start** the worker with:

   ```
   Use the dev skill for <feat-name>, invocation 1, and run it to the end without pausing for confirmation. The repository's main checkout is <absolute path>; find or create this change's worktree through dev's entry detection.

   <the run's brief, verbatim>

   This run is under team, unattended. Follow Headless sessions in dev's host-adapters reference, so your final message always ends this invocation: never end your turn while a role, review or waiter is outstanding. Spawn sub-agents for the roles as dev describes[, and close each finished role agent; a close that fails ends your run with BLOCKED unavailable: close_agent]. Stop only for something neither the brief nor the change folder covers: an architectural decision, work outside the scope, a destructive step. Never merge: team merges after its own check, then invokes you again. A denied or unavailable operation ends your run with a BLOCKED line; never work around it. End your final message with exactly one line, ending in this invocation's number:
   TEAM: MERGE-READY <PR URL> <head SHA> <ledger path> #<i>
   TEAM: DONE <PR URL> merged #<i>   (only when every layer in issues.md is merged and closed out, and its cleanup finished)
   TEAM: BLOCKED cleanup: <what remains> #<i>
   TEAM: BLOCKED needs approval: <operation> #<i>
   TEAM: BLOCKED needs decision: <question> #<i>
   TEAM: BLOCKED unavailable: <capability> #<i>
   TEAM: BLOCKED <one-sentence reason> #<i>
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
| Any result while a sync is pending | Handle the sync first (`references/run-state.md`, Sync record): retire it only on the matching `MERGE-READY` with a verified pushed head, then run the merge gate; anything else holds the change. A `needs decision` question goes verbatim into the hold and the report: the user clears the hold, then answers in a new run. |
| `MERGE-READY` | Run `references/merge-gate.md`. Five outcomes: **merged** (it re-invokes the worker for close-out; state `merged`, still live); **re-invoked** (a sync or re-evaluation; state `running`, still live); **deferred** (a base read or other gate to retry; state `merge-pending`, the handoff stays queued and the gate runs again next pass, worker kept); **refused** (a terminal reason: the policy forbids it, the sync limit, a rejected merge call; final as `merge-ready (<reason>)`); **held** (a merge readback that doesn't verify; hold written, final). |
| `DONE … merged` | `DONE` means every layer is finished, not one PR. Verify it against a pinned default tip: `git fetch origin`, then `origin/<default>` must equal `gh api repos/<owner>/<repo>/git/ref/heads/<default> --jq .object.sha`, as in the merge gate. Every layer in the change's `issues.md` maps to a PR that merged into the default branch (`gh api repos/<owner>/<repo>/pulls/<n>`: `merged: true`, `base.ref` the default branch, and its `merge_commit_sha` an ancestor of that tip) and a closed issue, the change folder is archived at that tip, and cleanup finished: for every layer branch, no worktree in `wt list --format=json` and no `refs/heads/<branch>` locally (`git show-ref --verify`) or in the PR's head repository (`gh api repos/<head.repo.full_name>/git/matching-refs/heads/<head.ref>` lists no exact match). Any layer still open, or anything here that can't be read or mapped: record `blocked: done not verified` and hold, without starting dependents. Verified: finalize it as `done` (below); start whatever it unblocked. |
| `BLOCKED cleanup` | Record `blocked: cleanup: <what remains>` and hold it, without trying to finish the cleanup or starting dependents. |
| `BLOCKED needs decision` | Finalize it as `blocked: needs decision: <question>`, with the question verbatim, and keep supervising the others. Never end the turn to wait for the answer: on Codex that interrupts live workers. The report asks the question, and the user's answer goes in the request for a new run, whose brief carries it to the worker. |
| `BLOCKED needs approval` / `unavailable` / other | Finalize it with the operation or reason verbatim. Never re-invoke it in this run: whether a running worker picks up widened permissions isn't established, so the user widens them and starts a new run. |
| Final message with no current `TEAM:` line | `team` can't tell how far it got, so it is never re-invoked: record `blocked: no verifiable handoff` (with any denied or failed operation it shows) and hold it. |
| Ended by the host (watchdog, error) | `stalled`, held. |

A stopped, stalled or held change is never restarted, nudged or reassigned.

**Finalizing.** A final state is written last: on Codex, **Stop** (close) the worker first and confirm it closed, so finished agents don't hold slots; if that can't be confirmed, hold the change instead, and keep counting that worker against the concurrency cap. On either host, any worker not shown stopped, including one whose Start or Continue couldn't be confirmed, holds its slot; if no slot can be shown free, launch nothing more, and keep supervising the workers still live until step 6 applies. A record that isn't final at a later run's start is held. A worker stopped on a timeout, or ended as `no verifiable handoff`, `stalled` or `BLOCKED unavailable: close_agent`, may still have roles running or holding slots, so it is held: **Stop** it and every role the host can show, and unless all are shown stopped, record `stop unconfirmed` in the hold, which keeps the slot and stops later runs before any probe.

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

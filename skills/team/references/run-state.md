# Run state

`team` keeps its state under the repository's common git dir, which every worktree shares: `"$(git rev-parse --path-format=absolute --git-common-dir)/team/"`, called `<state>` below. Nothing here is committed. Write each file whole, never edit in place.

## Run lock

`mkdir <state>/run` is the first thing a run does. It is atomic: it fails if the directory exists. Inside it, `owner` records the host session ID and the time.

- **Held by someone else:** say so and stop. Never infer that the other run is gone, however old the lock looks. Only the user removes it.
- One run per repository is what keeps two `team` runs from racing over a change or a merge.
- The run removes the lock as its last step, after stopping its heartbeat. It removes it even when holds remain: holds, not the lock, protect those changes.

## Change records

`<state>/changes/<feat-name>/`, written only by the lock holder:

| File | Holds |
|---|---|
| `state` | `launching`, `running`, `merge-ready`, `merging`, `merged`, `done`, `blocked: <reason>`, `stalled` |
| `agent` | the worker's agent ID (Claude Code) or task name (Codex) |
| `invocation` | the latest invocation number sent to the worker |
| `progress` | time of the last observed progress, and what moved |
| `merge` | the merge intent (below) |
| `sync` | the pending sync record (below) |

**Launch.** Write `state: launching` and the invocation number **before** calling the host to start the worker; write `agent` when the call returns. A record left at `launching` with no `agent` means the launch may or may not have happened.

**Invocation numbers.** Every prompt to a worker carries `invocation <n>`, recorded before sending, and the worker ends its `TEAM:` line with `#<n>`. A line with any other number is stale and ignored, so an old `MERGE-READY` can never be acted on twice.

## Holds

`<state>/holds/<feat-name>` contains one line: the reason and what is unverified. A held change is never started, continued, merged or cleaned up by any `team` run; it is reported as `blocked: held (<reason>)`. Only the user removes a hold, after checking the change by hand.

Write a hold, and stop that change, whenever its state can't be proven clean:

- **An interrupted run.** A run that finds a change record without a final state (`merged`, `done`, `blocked`, `stalled`, or `merge-ready` with no live worker) inspects it, reports it and holds it. No reattach, no replayed close-out.
- **A launch with no agent ID.**
- **A worker or any role it started that the host can't show as stopped**, after a stop was requested.
- **A merge intent that isn't retired** (below).
- **A sync that is pending, conflicted, or doesn't match its record.**
- **A permission prompt left unanswered** past its deadline.

## Merge intent

Before the merge call, `merge` records the PR, base repository and ref, base SHA, expected head SHA, and `state: pre-call`; just before the PUT, `state: submitted`; after a verified readback, `state: merged <merge sha>`, written **before** the intent retires and before close-out is requested. Any interruption in that sequence leaves a hold, not a replay.

**At start, before any merge,** scan every change's `merge` file repository-wide. Any intent that isn't retired puts the whole run under a merge hold: it may launch and supervise, but merges nothing until the user resolves the intent.

## Sync record

Before asking a worker to sync with a moved default branch, write `sync`: invocation number, PR, layer, expected head SHA, and the captured default-branch SHA to merge. Retire it only after reading the worker's pushed head back from GitHub. Until then the change's branch isn't trusted, and anything other than a clean pushed result (a conflict, a mismatch, an interruption) holds the change.

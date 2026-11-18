# Run state

`team` keeps its state under the repository's common git dir, which every worktree shares: `"$(git rev-parse --path-format=absolute --git-common-dir)/team/"`, called `<state>` below. Nothing here is committed. Write each file whole, never edit in place.

## Run lock

`mkdir -p <state>`, then plain `mkdir <state>/run` (no `-p`): the first thing a run does. The second is atomic and fails if the lock exists. Inside it, `owner` records the host session ID and the time.

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

- **An interrupted run.** The only final states are `done`, `blocked`, `stalled`, and `merge-ready` with its worker no longer needed. A run that finds a record in any other state (`launching`, `running`, `merging`, `merged`: a verified merge whose close-out or later layers never finished) inspects it, reports it and holds it. No reattach, no replayed close-out.
- **A launch with no agent ID.**
- **A worker or any role it started that the host can't show as stopped**, after a stop was requested.
- **A merge intent that isn't retired** (below).
- **A sync that is pending, conflicted, or doesn't match its record.**
- **A permission prompt left unanswered** past its deadline.

## Merge intent

Before the merge call, `merge` records the PR, base repository and ref, base SHA, expected head SHA, and `state: pre-call`; just before the PUT, `state: submitted`; after a verified readback, `state: merged <merge sha>`, written **before** the intent retires and before close-out is requested. Any interruption in that sequence leaves a hold, not a replay.

**At start, before any merge,** scan every change's `merge` file repository-wide. Any intent that isn't retired puts the whole run under a merge hold: it may launch and supervise, but merges nothing until the user resolves the intent.

## Sync record

Before asking a worker to sync with a moved default branch, write `sync`: invocation number, PR, layer, expected head SHA, and the captured default-branch SHA to merge. While it is pending, no second sync is requested for that change. Retire it only when the worker's `MERGE-READY` carries the same invocation number and GitHub's PR head (read back with `gh api repos/<owner>/<repo>/pulls/<n>`) equals the head on that line, differs from the expected head, and has the captured default SHA as an ancestor (`git merge-base --is-ancestor`). Anything else (`BLOCKED sync conflict`, `BLOCKED sync interrupted`, another `BLOCKED`, a mismatch, an interruption) holds the change; it is never synced again by `team`.

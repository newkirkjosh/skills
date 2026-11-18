# Merge gate

A `TEAM: MERGE-READY` line is a claim, never evidence. `team` checks every gate itself at the handoff, then **all of them again on one fresh set of observations** immediately before the merge call: the base SHA, PR files, Merge policy, checks, ledger and comments read in that final pass are the ones the merge relies on. Merges are serial: one run per repository, one merge at a time. Any gate that fails or can't be read means no merge; record why.

`<owner>/<repo>`, `<n>` and the handoff head come from the `TEAM:` line and the change record. `<state>` is the run-state directory (`run-state.md`).

## Gates

0. **Base.** `gh api repos/<owner>/<repo>/pulls/<n>`: `state` is `open`, `base.repo.full_name` is this repository, `base.ref` its default branch, `head.sha` exactly the handoff head. Then `git fetch origin`, resolve `origin/<default>` to a SHA, record it in the change record, and run `git merge-base --is-ancestor <default sha> <head>`:
   - exit 0: current;
   - exit 1: stale. Write the sync record (`run-state.md`) and re-invoke the worker: "Use the dev skill for <feat-name> again, invocation <n>: the default branch moved to <default sha>; sync PR <url> from head <head sha> and hand off again." At most two syncs per PR; a third move leaves it `merge-ready (base moved)`;
   - any other exit, or a failed fetch: unknown. Deferred: no merge this pass, `merge-pending`, retry next pass; two unknowns in a row leave it `merge-ready (base unknown)`.
1. **Head.** Unchanged since the handoff (gate 0's `head.sha`).
2. **Policy.** The repository's `AGENTS.md` on the default branch has a Merge policy that lets an agent merge under `team`, and the PR touches nothing it reserves for the user (`gh pr diff <n> --name-only`).
3. **Evidence.** A fresh `pr-status.sh` exit-0 report for that head, run as step 6 of the `completion` reference in `dev` says: policy file verified against repository authority, every required check successful, each configured reviewer completed on that head (a throttled CodeRabbit review counts only as that step allows), zero unresolved threads.
4. **Review coverage.** From the ledger (the path on the `TEAM:` line; missing or unreadable is unmet):
   - `git merge-base --is-ancestor <evaluator PASS sha> <head>` exits 0. Exit 1, a missing PASS SHA or an error means the evaluation doesn't cover this head: re-invoke the worker for re-evaluation, never merge.
   - The review range is `git rev-list <PASS sha>..<head> --not <recorded default sha>`: it includes merge commits from syncs and excludes the default-branch commits they bring in. A converged cross-review covers that head (completion step 2), every blocking finding is fixed, and every commit in the range is recorded `behavioral: no`.
5. **Comments.** Every review body and comment on the PR, read yourself up to the head, has a disposition: each blocking finding fixed, each other comment fixed or answered. `pr-status.sh` doesn't judge prose (`CALLER_TRIAGE_REQUIRED`), so a comment posted after the handoff is unmet until it is settled.

## Outcomes

Every unmet gate maps to one outcome (`SKILL.md`, step 5):

| Condition | Outcome |
|---|---|
| Stale base (gate 0) | **Re-invoked** for a sync, at most twice, then **refused** |
| Base or any GitHub read unknown or failing | **Deferred**, retried next pass; twice in a row, **refused** |
| Required checks or reviewers still running (gate 3) | **Deferred**, for up to six passes, then **refused** |
| Head differs from the handoff (gates 0, 1) | **Held**: something pushed outside the worker's handoff |
| Merge policy forbids it or the PR touches a reserved path (gate 2) | **Refused** |
| Failed check, unresolved thread, or a late comment without a disposition (gates 3, 5) | **Re-invoked** once per head with the finding ("Use the dev skill for <feat-name> again, invocation <n>: <finding>. Run entry detection from <main checkout path>."), then **refused** |
| PASS isn't an ancestor of the head, or the range isn't all `behavioral: no` (gate 4) | **Re-invoked** for re-evaluation, once per head, then **refused** |
| Ledger missing or unreadable (gate 4) | **Refused** |

A refused change keeps `merge-ready (<reason>)` for the report.

## Merge call

With the final pass clean, write the merge intent (`pre-call`, then `submitted`), then:

```bash
gh api -X PUT repos/<owner>/<repo>/pulls/<n>/merge -f merge_method=squash -f sha=<head sha>
```

Never `gh pr merge`: on a branch that requires a merge queue it may enqueue the PR or enable auto-merge, and `team` does neither. The REST call merges directly or fails.

- **Rejected:** only a structured GitHub error (HTTP 405, 409 or 422 with a message) proves it. Record `merge-ready (<message>)` and retire the intent.
- **Success or anything else** (a `gh` exit code alone, a timeout, an unparseable response): read `gh api repos/<owner>/<repo>/pulls/<n>` back. The intent retires only on `merged: true`, a `merge_commit_sha` equal to the SHA the PUT returned (when it returned one), `head.sha` the expected head, and `base.repo.full_name` and `base.ref` the expected base. Write `merged <merge sha>`, then re-invoke the worker (branch and worktree cleanup are `dev`'s Phase 6, which checks them first): "Use the dev skill for <feat-name> again, invocation <n>: PR <url> merged as <merge sha>. Run entry detection from <main checkout path>." It closes out, cleans up, and starts the next layer or ends `TEAM: DONE`.
- **Readback doesn't match:** mark the intent `unknown`, hold the change, and merge nothing more in this run.

## Residual race

The default branch can move, or the PR be retargeted, between the final pass and the PUT, with the head unchanged: the `sha` parameter guards only the head. A repository that requires up-to-date branches closes the first case server-side. Otherwise the window needs an outside change within seconds of `team`'s own serial merge; it is accepted, and the report names it when the repository doesn't enforce freshness.

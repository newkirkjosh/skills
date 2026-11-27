# Merge gate

A `TEAM: MERGE-READY` line is a claim, never evidence. `team` checks every gate itself at the handoff, then **all of them again on one fresh set of observations** immediately before the merge call: the base SHA, PR files, Merge policy, checks, ledger and comments read in that final pass are the ones the merge relies on. Merges are serial: one run per repository, one merge at a time. Any gate that fails or can't be read means no merge; record why.

`<owner>/<repo>`, the PR number `<n>` and the handoff head come from the `TEAM:` line and the change record. `<next>` is the change's next invocation number, recorded before sending (`run-state.md`); it is unrelated to the PR number. `<state>` is the run-state directory (`run-state.md`).

Lifecycle entry detection, requested re-evaluation, requested sync and Phase 6 cleanup belong to `dev`'s `../dev/references/lifecycle.md`; each re-invocation enters through dev's pickup route and runs that reference from its top. Layer-branch naming stays in dev's `SKILL.md`.

## Gates

Start each pass with `git fetch origin` and pin `origin/<default>` to a SHA, recorded in the change record. It must equal the PR base repository's own branch tip (`gh api repos/<owner>/<repo>/git/ref/heads/<default> --jq .object.sha`), since a narrow fetch refspec can leave the ref stale and `origin` may be a fork. A failed fetch or read, or a mismatch, ends the pass as unknown (gate 0), before any other gate. Then, in this order: the PR identity and state checks of gate 0 and gate 1; gate 2 against the pinned SHA, so a policy refusal ends the attempt before anything can request a sync; gate 0's stale-base check; gates 3 to 5.

0. **Base.** `gh api repos/<owner>/<repo>/pulls/<n>`: `state` is `open`, `base.repo.full_name` is this repository, `base.ref` its default branch, `head.sha` exactly the handoff head, and `head.repo.full_name` and `head.ref` are this repository and the worker's current layer branch, resolved from the change's `issues.md` and `dev`'s layer-branch rule, never from the `TEAM:` line. Then run `git merge-base --is-ancestor <default sha> <head>` with the pinned SHA:
   - exit 0: current;
   - exit 1: stale. Write the sync record (`run-state.md`) and re-invoke the worker: "Use the dev skill for <feat-name> again, invocation <next>: the default branch moved to <default sha>; sync PR <url> from head <head sha> and hand off again." At most two syncs per PR; a third move leaves it `merge-ready (base moved)`;
   - any other exit, or a failed fetch: unknown. Deferred: no merge this pass, `merge-pending`, retry next pass; two unknowns in a row leave it `merge-ready (base unknown)`.
1. **Head.** Unchanged since the handoff (gate 0's `head.sha`).
2. **Policy.** The repository's `AGENTS.md` at the pinned default SHA (`git show <default sha>:AGENTS.md`) has a Merge policy that lets an agent merge under `team`, and the PR touches nothing it reserves for the user: check both the current and previous path of every file with one record per file (`gh api --paginate repos/<owner>/<repo>/pulls/<n>/files --jq '.[] | [.filename, (.previous_filename // "")] | @tsv'`), so a rename out of a reserved path counts. The endpoint returns at most 3,000 files: the number of records must equal the PR's `changed_files`, or coverage isn't proven and the merge is refused. Where the policy reserves part of a file (a section of `AGENTS.md`, say), read the PR's own change to that file (`git diff <default sha>...<head> -- <file>`, three dots, so edits made only on the default branch don't count); a change in the reserved part, or a diff you can't judge, is a refusal. Any evidence that policy itself requires (a cross-review by a named model, say) must hold on this head; unmet or unverifiable is a refusal.
3. **Evidence.** A fresh `pr-status.sh` exit-0 report for that head, run as step 6 of the `completion` reference in `dev` says: policy file verified against repository authority, every required check successful, each configured reviewer completed on that head (a throttled CodeRabbit review counts only as that step allows), zero unresolved threads.
4. **Review coverage.** From the ledger (the path on the `TEAM:` line; missing or unreadable is unmet):
   - `git merge-base --is-ancestor <evaluator PASS sha> <head>` exits 0. Exit 1, a missing PASS SHA or an error means the evaluation doesn't cover this head: re-invoke the worker for re-evaluation, never merge.
   - The review range is `git rev-list <PASS sha>..<head> --not <recorded default sha>`: it includes merge commits from syncs and excludes the default-branch commits they bring in. A converged cross-review covers that head (completion step 2), every blocking finding is fixed, and every commit in the range is recorded `behavioral: no`.
5. **Comments.** Every review body and comment on the PR, read yourself up to the head, has a disposition: each blocking finding fixed, each other comment fixed or answered. `pr-status.sh` doesn't judge prose (`CALLER_TRIAGE_REQUIRED`), so a comment posted after the handoff is unmet until it is settled.

## Outcomes

Every unmet gate maps to one outcome (`SKILL.md`, step 5):

| Condition | Outcome |
|---|---|
| A repository-wide merge hold is in force (`run-state.md`), checked first | **Refused** (`merge hold`), for every change, without running the other gates or the merge call |
| PR closed, retargeted away from the default branch, or not the current layer's branch | **Held** |
| Stale base (gate 0) | **Re-invoked** for a sync, at most twice, then **refused** |
| Base or any GitHub read unknown or failing | **Deferred**, retried next pass; twice in a row, **refused** |
| Required checks or reviewers still running (gate 3) | **Deferred**, for up to six passes, then **refused** |
| Head differs from the handoff (gates 0, 1) | **Held**: something pushed outside the worker's handoff |
| Merge policy forbids it or the PR touches a reserved path (gate 2) | **Refused** |
| Failed check, unresolved thread, or a late comment without a disposition (gates 3, 5) | **Re-invoked** once per head with the finding ("Use the dev skill for <feat-name> again, invocation <next>: <finding>. Run entry detection from <main checkout path>."), then **refused** |
| PASS isn't an ancestor of the head, or the range isn't all `behavioral: no` (gate 4) | **Re-invoked** with an explicit re-evaluation request ("…: re-evaluate this layer at head <sha>"), once per head, then **refused** |
| Cross-review not converged, or not covering the head (gate 4) | **Re-invoked** once per head, then **refused** |
| A required reviewer absent or skipped without the allowance in completion step 6, or the evidence policy unverifiable (gate 3) | **Refused** |
| A reviewer explicitly required by repository policy is throttled, including CodeRabbit when policy requires it (gate 3) | **Refused**: unmet required review goes to the user; do not wait out the cooldown. The completion step 6 allowance still applies when CodeRabbit is not explicitly required. |
| Ledger missing or unreadable (gate 4) | **Refused** |

A refused change keeps `merge-ready (<reason>)` for the report.

## Merge call

With the final pass clean, write the merge intent (`pre-call`, then `submitted`), then:

```bash
gh api -X PUT repos/<owner>/<repo>/pulls/<n>/merge -f merge_method=squash -f sha=<head sha>
```

Never `gh pr merge`: on a branch that requires a merge queue it may enqueue the PR or enable auto-merge, and `team` does neither. The REST call merges directly or fails.

- **Rejected:** a structured GitHub error (HTTP 405, 409 or 422 with a message) is the only sign of a refusal, but it doesn't prove nothing merged: another actor may have merged the PR first. Read `gh api repos/<owner>/<repo>/pulls/<n>` back. If `merged` is `true`, take the success path below; if the readback fails, take the mismatch path. Closed and unmerged: retire the intent and **hold** the change (the closed-PR row in Outcomes). Still open and unmerged: retire the intent, then run one fresh gate pass from the top (fetch, pin the new tip, PR identity, policy at that tip, then the stale-base check), since the base may have moved under the call (a branch rule requiring up-to-date branches rejects then). That pass only determines its outcome; it writes no sync record and sends nothing to the worker until the outcome is settled here. Only three outcomes of that pass stand: a stale base taking the sync path within the same two-sync limit, a hold, or a refusal. Anything else (every gate passing again, a deferral, a re-invocation) returns **refused** with the rejection message, so nothing ever calls merge a second time for this head; supervision writes the final `merge-ready (<message>)` after finalizing the worker under the host adapter’s verified lifecycle.
- **Success or anything else** (a `gh` exit code alone, a timeout, an unparseable response): read `gh api repos/<owner>/<repo>/pulls/<n>` back. The intent retires only on `merged: true`, a `merge_commit_sha` equal to the SHA the PUT returned (when it returned one), `head.sha` the expected head, and `base.repo.full_name` and `base.ref` the expected base. Write `merged <merge sha>`, run `git fetch origin` and confirm the merge commit is an ancestor of `origin/<default>` (if not, or if the fetch fails, hold the change), then re-invoke the worker (branch and worktree cleanup are `dev`'s Phase 6, which checks them first): "Use the dev skill for <feat-name> again, invocation <next>: PR <url> merged as <merge sha>. Run entry detection from <main checkout path>." It closes out, cleans up, and starts the next layer or ends `TEAM: DONE`.
- **Readback doesn't match:** mark the intent `unknown`, hold the change, and put the run under the merge hold: nothing more merges.

## Residual race

The default branch can move, or the PR be retargeted, between the final pass and the PUT, with the head unchanged: the `sha` parameter guards only the head. A repository that requires up-to-date branches closes the first case server-side. Otherwise the window needs an outside change within seconds of `team`'s own serial merge; it is accepted, and the report names it when the repository doesn't enforce freshness.

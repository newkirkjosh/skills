# Head Discipline

Adapted from fx/skills `dev/references/head-discipline.md` (MIT, see `../LICENSE.txt`).

When to push, what a review or CI result is evidence of, and what order to wait in. `ship` and `dev` apply these rules; change them here, not at the point of use.

One failure motivates all of it: **every push invalidates the evidence gathered for the commit before it.** A workflow that pushes between collecting evidence and using it pays for the same wait twice. Upstream measured a long unattended run spending about 70% of its wall clock waiting on CI, most of it on runs a later push had already made stale.

## The candidate head

The candidate head is the commit you intend to merge. Everything that can still change the tree happens before it exists; everything slow and head-scoped happens after.

1. Implement, and commit everything the change needs: code, tests, tracker docs, generated files, the archive move. A "finalizing" commit after review is a push you didn't need.
2. Run every local check and local reviewer. Batch every finding and fix them in one pass.
3. Run any verification that doesn't need a PR (the app, the test plan).
4. Push once. Record that SHA as the candidate head.
5. Open or update the PR. Hosted reviewers (CodeRabbit and the like) start on the push.
6. When they report, settle every finding in one round (`resolve-pr-feedback`). A fix push makes a new candidate head: go back to step 5 for the delta only.
7. Once hosted review has nothing blocking, wait for CI on the current candidate head.
8. Check the merge gates against that same SHA, then merge with `--match-head-commit <sha>`.

**Every push after step 4 re-enters at step 5**, whatever produced it: a review fix, a CI fix, a forgotten doc. Jumping from a CI fix straight to another CI wait ships a commit no reviewer has read.

**Nothing between step 7 and the merge may push.** A gate that needs a commit is a defect in an earlier step; if one slips through, it is a push like any other.

CI starts by itself on every push, and that's fine; it may be green by step 7. The rule is not "stop CI from running" but "don't spend a turn watching a run you are about to invalidate."

## Evidence is SHA-scoped

Every review result and every CI result is about exactly one commit. Note the SHA next to it; a result with no SHA is not evidence.

When the head changes:

- Waits for the old SHA are superseded. Stop them; never read their verdict, pass or fail, as the new head's.
- Review results for the old SHA still hold for code that didn't change. Re-review only the delta. CodeRabbit re-reviews every push on its own; a reviewer that doesn't must be re-run explicitly, or the new commits ship unreviewed by it.
- A verdict whose SHA you can't confirm is not a pass.

## Batch findings: one fix pass per push

Collect, classify, deduplicate, fix once, push once. Never `finding → fix → push`, then the next finding: each push restarts CI and every push-triggered reviewer, so N serial fixes cost N cycles.

Take everything already reported (local reviewers, hosted reviewers, verification, known CI failures for this head) into the batch. Don't hold the batch open for a reviewer that hasn't reported; its findings are the next batch, against the new head.

## Wait order

1. Never start or wait on hosted review for a head you already know must change. Fix and push first.
2. Wait on hosted reviewers before CI: their findings decide whether the head survives at all.
3. Wait on CI last, once the head has no unresolved blocking finding.

A reviewer that isn't configured for the repository (no `.coderabbit.yaml`, no bot activity on any PR) stays unconfigured for the rest of the run: note it once and stop checking for it.

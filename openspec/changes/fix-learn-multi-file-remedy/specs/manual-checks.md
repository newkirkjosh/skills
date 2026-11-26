# Manual checks: Reconcile every file of a multi-file learn remedy

The deliverable is Markdown instructions, so these are instruction-replay checks. An evaluator reads the finished `skills/learn/references/inbox.md` and `skills/learn/SKILL.md`, applies each scenario as review mode directs, and records PASS or FAIL with the quoted instruction that produces the expected outcome. A check whose outcome has no quotable instruction fails: reaching the right status by checking only the file that happens to matter, or from general good sense, is not enough.

Baseline: the worktree's base commit (`inbox.md` 69 lines, `SKILL.md` 157 lines). Every behavioural check (M) fails against it; the reason is recorded under each, quoting the rule that yields the wrong outcome or leaves it undefined. The regression checks (R) and structural checks (S) pass today and must still pass after the change.

Never read or write the real learning inbox. Every record below lives in a scratch directory the evaluator creates in its own scratchpad; the inbox the global instructions name is not touched.

## Fixture

Placeholder names only: catalog `owner/repo` (default branch `main`), skill `alpha-skill`, branch `fix/alpha-empty-repo`, PR `owner/repo#7`. The approved remedy is a guard plus its test (Step 5.1's shape):

| Part | File | Recorded change (edited text) |
|---|---|---|
| guard | `skills/alpha-skill/scripts/alpha-helper.sh` | `[ -n "$repo" ] \|\| { echo "alpha-helper: --repo is empty" >&2; exit 2; }` |
| test | `skills/alpha-skill/scripts/test-alpha-helper.sh` | `expect_fail "empty --repo" alpha-helper.sh --repo ""` |

Scratch catalog, so the default-branch checks are real `git show` reads:

```bash
S=<scratchpad>/learn-48 && mkdir -p "$S" && cd "$S"
git init -q --bare remote.git && git clone -q remote.git cat && cd cat
mkdir -p skills/alpha-skill/scripts
printf '#!/usr/bin/env bash\nrepo=$2\n' > skills/alpha-skill/scripts/alpha-helper.sh
printf '#!/usr/bin/env bash\n' > skills/alpha-skill/scripts/test-alpha-helper.sh
git add -A && git commit -qm base && git push -q origin HEAD:main
```

Each case then sets `main` (and, where named, the branch and a worktree) to the stated contents and pushes. PR state cannot be created locally: stub `gh` on `PATH` so `gh pr list --head fix/alpha-empty-repo --state all --json number,state` and `gh pr view 7 --json state,headRefName` print the state each case gives, and the PR head's file contents are the branch's.

The record under review (scratch copy), with `Applied` naming both parts. The exact layout of the multi-file `Applied` value is the implementer's; the evaluator rewrites this fixture to the template the change defines, keeping each file paired with its change:

```markdown
- Status: applied
- Skill: alpha-skill
- Decision: reject an empty --repo
- Applied: owner/repo, branch fix/alpha-empty-repo, worktree <scratchpad>/learn-48/wt-alpha, PR owner/repo#7; skills/alpha-skill/scripts/alpha-helper.sh: `[ -n "$repo" ] || { echo "alpha-helper: --repo is empty" >&2; exit 2; }`; skills/alpha-skill/scripts/test-alpha-helper.sh: `expect_fail "empty --repo" alpha-helper.sh --repo ""`
```

## Story 1: `Applied` lists every file of the remedy

**M1. The Record step writes every file and its change.**
Input: a review whose approved edit is the fixture remedy, applied in worktree `wt-alpha` on branch `fix/alpha-empty-repo`; the user approved moving the originating record to `applied`.
Expected: the **Record** step writes `Applied` with the repository and branch, the worktree path (and the PR once one exists), and both files, each with its recorded change. A value naming only `alpha-helper.sh`, or naming both files with one shared change, fails.
PASS when: the `Applied` template line in `inbox.md`, the `open` → `applied` row, and review mode's **Record** step all say every file of the remedy is written with its own recorded change.
Fails today because: the template is singular, "`Applied: <empty until applied: repository and branch, worktree path, PR once one exists, file, and the recorded change>`" (inbox.md line 31); the transition row asks for "the file and the recorded change that addresses this record" (line 52); and Record says "writing repository and branch, worktree path or PR, file and the recorded change" (SKILL.md line 133). Nothing tells the agent to write the test file at all.

## Story 2: `shipped` needs every listed change on the default branch

**M2. Both changes on the default branch: `shipped`.**
State: `main` holds both recorded changes (merged by PR #7, stub state `MERGED`).
Expected: **Reconcile applied records** checks each listed change with `git show origin/main:<file>` after a fetch, finds both, and proposes `applied` → `shipped`, quoting both checks.
PASS when: an instruction makes the `shipped` check run per listed change and requires all of them.
Fails today because: the outcome is reachable, but only by accident: the rule checks one file, "The recorded change holds in the file on the default branch (`git show <remote>/<default>:<file>` ...)" (inbox.md line 53), and Reconcile says "First check the recorded change ... on that catalog's default branch" (SKILL.md line 128). No quotable instruction checks the test file, so the evidence quoted for `shipped` covers only one part.

**M3. PR merged with only the guard: not `shipped`, names the missing test.**
State: PR #7 merged (`MERGED`), but its merge dropped the test: `main` holds the guard; `test-alpha-helper.sh` on `main` lacks the `expect_fail "empty --repo"` line.
Expected: the default-branch check finds the guard but not the test, so the record does not hold on the default branch. The PR exists and merged, so by the existing row the proposal is `applied` → `open`, and the summary names the missing part (`test-alpha-helper.sh`: `expect_fail "empty --repo" ...` absent on `main`). Proposing `shipped` fails; so does reopening without naming which change is missing.
PASS when: an instruction says a record whose listed changes only partly hold on the default branch is treated as not holding there (falling through to the PR or worktree rules), and that the summary names each missing change.
Fails today because: checking "the file" named first (the guard) on `main` finds "the recorded change holds", and "holds means `shipped`, stop" (inbox.md line 59); the record ships and review skips it for good, though the test never landed. Nothing defines what a partial landing is.

**M4. Test reverted on the default branch after merge: not `shipped`.**
State: PR #7 merged with both changes; a later commit on `main` reverted `test-alpha-helper.sh` to its base contents. Guard still on `main`.
Expected: same as M3: guard holds, test does not, record does not hold on `main`; PR merged, so `applied` → `open` with the reason (test change reverted on `main`) written in `Applied` and the missing part named in the summary.
PASS when: the instructions quoted for M3 produce this; the check reads current `main`, not the merge commit.
Fails today because: as M3, the single-file check on the guard ships it: "The recorded change holds in the file on the default branch ... This check comes first and wins over any worktree or PR state" (inbox.md line 53).

**M5. Open PR holding both, not yet on the default branch: stays `applied`.**
State: PR #7 open (`OPEN`); branch `fix/alpha-empty-repo` holds both changes; `main` holds neither.
Expected: default-branch check fails for both, the PR exists and is open, and it holds every listed change, so the record stays `applied`.
Sub-case M5b: `main` already holds the guard (landed by another route); PR #7 open and holding both. Expected: still `applied`, not `shipped`; the summary names the test as the change missing on `main`.
Sub-case M5c: PR #7 open, but a force-push dropped the test from the branch; `main` holds neither. Expected: the PR no longer holds every listed change, so `applied` → `open`, naming the test.
PASS when: an instruction makes "holds the change" in the PR and worktree rows mean every listed change, the same as on the default branch.
Fails today because: the PR rows test one change, "a PR for the branch is open and holds the change" (inbox.md line 55) and "it is open but no longer holds the change" (line 54). In M5b, checking the guard on `main` ships the record ("holds means `shipped`, stop", line 59); in M5c, checking the guard in the PR leaves it `applied` though its test is gone. M5 itself reaches the right status, but no instruction checks the test in the PR.

**M6. `Applied` missing one file's change: unverifiable.**
Record: as the fixture, but the test entry names `skills/alpha-skill/scripts/test-alpha-helper.sh` with no recorded change. `main` holds the guard.
Expected: the `Applied` field is incomplete, so the record stays `applied`, reported unverifiable with the question (return it to `open`, or supply the missing change for `test-alpha-helper.sh`). Checking the guard alone and proposing `shipped` fails; guessing the test's change from the file on `main` fails.
PASS when: an instruction says `Applied` is incomplete when any listed file lacks its recorded change, and that completeness is checked before any default-branch check.
Fails today because: completeness is defined against one file, "The `Applied` field is empty or incomplete (an older record without a branch counts as incomplete unless it names a PR)" (inbox.md line 56), and today's template asks for one "file, and the recorded change" (line 31), which the guard entry already satisfies. The text is silent on a second file without a change, so step (1) of the order passes and step (2) ships on the guard.

**M7. Mixed edit and removal in one remedy.**
Record: the guard entry as the fixture, plus a second entry `skills/alpha-skill/SKILL.md`: `deleted: Always pass a non-empty --repo.` `main` holds the guard and no longer contains that sentence.
Expected: each change is judged by its own kind (edited text present; removed text absent), both hold, so `shipped`. If `main` still contained the sentence, not `shipped`, naming the `SKILL.md` removal.
PASS when: the per-change "holds" definition (inbox.md, the paragraph on the recorded change) is applied to each listed change.
Fails today because: "It holds in a file when the edited text is present, or the removed text (or the file) is absent" (inbox.md line 48) is stated for one change in one file; nothing combines several, so the guard check alone ships the record even while the sentence is still on `main`.

## Regression: one-file and legacy records keep working

**R1. A legacy one-file record reconciles as a one-item list.**
Record: an older-format `Applied`: `owner/repo, branch fix/alpha-note, PR owner/repo#5, skills/alpha-skill/SKILL.md, the recorded change: "Ask which remote when two are configured."` `main` holds that sentence.
Expected: read as a one-item list; complete (it names a branch and a PR); the one change holds on `main`, so `shipped`. Not reported unverifiable for lacking the new layout.
PASS when: an instruction says a single-file `Applied` (including one written before this change) is a one-item list. Baseline: PASS by today's single-file rules; it must still pass.

**R2. A one-file legacy record that does not hold follows the existing rules.**
Record: as R1, PR #5 closed unmerged (`CLOSED`), `main` lacks the sentence.
Expected: `applied` → `open`, unchanged from today. Baseline: PASS.

**R3. Default branch still wins over PR state.**
State: as M2 (both on `main`) but PR #7 still `OPEN`.
Expected: `shipped`, as today's "the default branch wins over an open PR" (SKILL.md line 128). Baseline: PASS for the one file checked; must hold for the full list after the change.

## Structural checks (repository)

Run from the worktree root. Each passes at baseline and must still pass, except S7, which fails at baseline (four hits: inbox.md lines 31, 52, 53 and SKILL.md line 133).

**S1.** `agentskills validate skills/learn` prints `Valid skill: skills/learn`.

**S2.** `scripts/check-descriptions.sh` exits 0; the `learn` description is unchanged.

**S3.** `scripts/check-refs.sh` exits 0.

**S4.** `scripts/check-private.sh` exits 0, and the diff's examples use placeholders only.

**S5.** `bash -n scripts/*.sh skills/*/scripts/*.sh` and `for t in scripts/test-*.sh skills/*/scripts/test-*.sh; do bash "$t"; done` exit 0. No script is added.

**S6.** `git diff --name-only <base>` lists only `skills/learn/references/inbox.md`, `skills/learn/SKILL.md` and this change folder. No other skill, no script.

**S7.** Every singular `Applied` wording is gone: `grep -rn 'file, and the recorded change\|the file and the recorded change\|file and the recorded change\|holds in the file on' skills/learn/` returns nothing, and every remaining "the recorded change" or "holds the change" in `inbox.md` and review mode reads as every listed change. The evaluator lists each remaining hit and why it is correct.

**S8.** The Step 5.1 enforcement question and review mode's **Summarize and ask** wording from the enforcement-check change are unchanged.

**S9.** `SKILL.md` stays under 500 lines; Steps 1 to 7 and Note mode are unchanged except for `Applied` cross-references the evaluator lists and justifies.

**S10.** No file outside the worktree and the evaluator's scratchpad was written; the real learning inbox is untouched.

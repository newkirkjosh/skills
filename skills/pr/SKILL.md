---
name: pr
description: "Explicit-use only — invoke when the user explicitly names this skill, or when an active explicitly invoked workflow calls it. Creates well-formed PRs: conventional commit title, structured body and Closes reference, branch naming and squash merge, sub-issue numbers read from issues.md, then a review by the other model (Codex from Claude Code, Claude from Codex) as the local review, beside CodeRabbit."
metadata:
  type: flexible
---

# PR

**REQUIRED:** load the github skill for how to run each `gh` step (head-commit scoping, bounded CI waits, bodies from files, verifying writes). This skill owns the conventions; github owns the mechanics.

## When to Use

**Explicit use only:** the user names this skill, or `dev` calls it.
- Opening a PR after implementation is complete

**Pre-conditions** (`<change>` below is `openspec/changes/<feat-name>/`, or `openspec/changes/archive/<feat-name>/` once `dev` Phase 4 has moved it there; use whichever exists on the branch):
- A branch exists for this layer's work
- `<change>/issues.md` exists with the sub-issue number
- `<change>/proposal.md` exists for PR body content

## Principles

**Branch naming convention:**
`<type>/<short-description>`
e.g., `feat/habit-list-screen`. The issue is linked from the PR body, not the branch name.

Verify branch name on invocation. If it doesn't match, rename the branch and re-push before creating the PR.

**PR title (becomes the squash merge commit subject):**
`<type>(<layer>): <description>`, imperative, lowercase after the colon, no trailing period
e.g., `feat(<layer>): add habit list screen`, with `<layer>` from `issues.md`

No `#<number>` in the title. On squash merge GitHub appends `(#<PR number>)` itself, and a hand-written `#N` permanently links the commit to whatever issue or PR `N` is. The issue reference goes in the body as `Closes #N`.

**PR body** (one line per paragraph, never hard-wrapped: GitHub reflows markdown, so wrapped prose renders ragged):
```markdown
## What
<1-2 sentences from proposal.md scope>

## Why
<1 sentence: which job story this closes>

## Test plan
- [ ] <specific, observable check: "open Settings and see the Notifications tab", never "works correctly">

Closes #<sub-issue-number>
```

No list of changed files, line counts or commits: GitHub already shows them.

**Review set: the other model, converged, then CodeRabbit.** The local review is the cross-model review: Codex when you run on Claude Code, Claude when you run on Codex, through the cross-review script in `dev` with the Scope Brief as its prompt. Under `dev` it already ran in Phase 4: post `<change>/cross-review.md` (its final pass) as a PR comment. Invoked on its own, run it before pushing, the way `dev` Phase 4 steps 1-3 describe (fix blocking findings, re-run with the already-fixed list, at most three passes), then post the final pass. When `dev` recorded `Cross-review: skipped (narrow docs-only)` or `Cross-review: unavailable: <reason>`, post that line instead and say why in the PR body. CodeRabbit reviews the PR itself where the repository has it.

The `pr-review-toolkit` agents (Claude Code only) are a fallback, not the default: run them only when the cross-model review is unavailable (the reviewer's CLI is missing or can't authenticate; under `dev`, when Phase 4 recorded it unavailable) or the user asks for them. On Codex there is no fallback: record the review as unavailable in the PR body, and the merge goes to the user. They cost roughly 50k tokens each, so then use `code-reviewer`, plus `silent-failure-hunter` for security, auth or error paths and `pr-test-analyzer` for new logic.

**Scope Brief:** if `<change>/scope-brief.md` exists, paste it verbatim at the top of each review agent's prompt as an OUT OF SCOPE / IN SCOPE block, and triage findings against it: a finding about excluded work is recorded and dismissed with the exclusion cited, not fixed. Security, privacy, data-loss and correctness defects in the change are always in scope.

**Merge convention:** Squash merge only. PR title becomes the single commit on the base branch. Never use merge commit or rebase merge.

**Conversation flow:**

Note: steps 1-2 are elaborations not in the spec — they are required reads to populate the PR body and issue reference before the main flow begins.

1. Read `<change>/issues.md` to get the sub-issue number for this layer
2. Read `<change>/proposal.md` for PR body content
3. Verify branch name matches convention — rename and re-push if needed
4. Create PR with formatted title and body
5. Post the cross-model review's final pass with `gh pr comment <n> --body-file <file>` (invoking `pr`, or `dev`, which calls it, is the request for this comment on the PR it opened) (running it first if `dev` didn't), then wait for CodeRabbit and settle every comment: fix it, or reply with why it doesn't apply
6. Consolidate all findings and present before merge
7. On merge: move the sub-issue on the repository's board as its `AGENTS.md` says (the github skill's projects reference)

## Constraints

- Branch name must conform before PR creation — never create a PR from a non-conforming branch
- Never skip the cross-model review, except `dev`'s recorded skip for a `narrow` docs-only change; use `pr-review-toolkit` agents only as the fallback above (cost)
- Squash merge only — reject merge commit and rebase merge
- Always read `issues.md` for sub-issue number — never ask the user
- `comment-analyzer` only runs if significant documentation (docstrings, README changes, inline explanations) was added
- Post findings as PR comments (`gh pr comment`); never approve or request changes on the user's behalf
- Merge only on a green CI run for the PR's head commit. A red job may be rerun once (`gh run rerun --job`) only when its failure matches an already-filed flake issue; cite the issue in the PR

## Examples

**Habit Tracker — `:<layer-2>` layer PR:**

`issues.md` contains `<layer-2>: 14`.
`proposal.md` scope: "Adds the Habit List screen and the Add Habit screen."

Branch: `feat/habit-list-screen`

PR title: `feat(<layer-2>): add habit list and add habit screens`

PR body:
```markdown
## What
Adds the Habit List screen showing all habits and the Add Habit screen.

## Why
Closes the onboarding story: when a user opens the app for the first time, they can add a habit and see it immediately.

## Test plan
- [ ] Fresh install shows the empty state on the Habit List screen
- [ ] Adding a habit named "Read" returns to the list and shows "Read"
- [ ] Back from Add Habit returns to the list without adding anything

Closes #14
```

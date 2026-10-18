---
name: pr-workflow
description: "Creates well-formed PRs with conventional commit titles, structured body, and Closes reference. Enforces branch naming convention and squash merge. Runs a pr-review-toolkit review set scaled to the change's size, in parallel, after PR creation. Reads issues.md for sub-issue numbers — never asks the user. Triggers: \"open a PR for feat-X\", \"create PR for issue #N\"."
metadata:
  type: flexible
---

# PR Workflow

**REQUIRED:** load the github skill for how to run each `gh` step (head-commit scoping, bounded CI waits, bodies from files, verifying writes). This skill owns the conventions; github owns the mechanics.

## When to Use

**Invoke for:**
- Opening a PR after implementation is complete — "open a PR for feat-X", "create PR for issue #N"

**Pre-conditions:**
- A branch exists for this layer's work
- `openspec/changes/<feat-name>/issues.md` exists with the sub-issue number
- `openspec/changes/<feat-name>/proposal.md` exists for PR body content

## Principles

**Branch naming convention:**
`<type>/<issue-number>-<short-description>`
e.g., `feat/14-habit-list-screen`

Verify branch name on invocation. If it doesn't match, rename the branch and re-push before creating the PR.

**PR title (becomes the squash merge commit subject):**
`<type>(<layer>): <description>`, imperative, lowercase after the colon, no trailing period
e.g., `feat(android): add habit list screen`

No `#<number>` in the title. On squash merge GitHub appends `(#<PR number>)` itself, and a hand-written `#N` permanently links the commit to whatever issue or PR `N` is. The issue reference goes in the body as `Closes #N`.

**PR body** (one line per paragraph; GitHub reflows markdown, so check it with the github skill's `check-body-wrap.sh`):
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

**Review set — scaled to the change** (read the size signal from `scope-brief.md`):

| Change | Reviewers |
|---|---|
| `narrow` config/docs-only (manifests, CI tweaks, wording) | `pr-review-toolkit:code-reviewer` only; add `silent-failure-hunter` if it touches security, auth or error paths |
| `normal` code | `silent-failure-hunter`, `code-reviewer`, `pr-test-analyzer` |
| Significant docs added (docstrings, READMEs) | also `comment-analyzer` |

Reviewers are independent, so run them **in parallel**. Post each one's findings as a PR comment with `gh pr comment <n> --body-file <file>` (reviewer name + findings + what you'll do about each), then surface them in conversation. A three-reviewer pass costs roughly 150k tokens; on a plan with a session limit, the table above is the budget.

**Scope Brief:** if `openspec/changes/<feat-name>/scope-brief.md` exists, paste it verbatim at the top of each review agent's prompt as an OUT OF SCOPE / IN SCOPE block, and triage findings against it: a finding about excluded work is recorded and dismissed with the exclusion cited, not fixed. Security, privacy, data-loss and correctness defects in the change are always in scope.

**Merge convention:** Squash merge only. PR title becomes the single commit on the base branch. Never use merge commit or rebase merge.

**Conversation flow:**

Note: steps 1-2 are elaborations not in the spec — they are required reads to populate the PR body and issue reference before the main flow begins.

1. Read `openspec/changes/<feat-name>/issues.md` to get the sub-issue number for this layer
2. Read `openspec/changes/<feat-name>/proposal.md` for PR body content
3. Verify branch name matches convention — rename and re-push if needed
4. Create PR with formatted title and body
5. Run the review set for this change (table above), in parallel; post each reviewer's findings with `gh pr comment`, then surface them in conversation
6. Consolidate all findings and present before merge
7. On merge: move the sub-issue on the repository's board as its `AGENTS.md` says (the github skill's projects reference)

## Constraints

- Branch name must conform before PR creation — never create a PR from a non-conforming branch
- Never skip the review set the table assigns; never run more than it assigns without a reason (cost)
- Squash merge only — reject merge commit and rebase merge
- Always read `issues.md` for sub-issue number — never ask the user
- `comment-analyzer` only runs if significant documentation (docstrings, README changes, inline explanations) was added
- Post findings as PR comments (`gh pr comment`); never approve or request changes on the user's behalf
- Merge only on a green CI run for the PR's head commit. A red job may be rerun once (`gh run rerun --job`) only when its failure matches an already-filed flake issue; cite the issue in the PR

## Examples

**Habit Tracker — android layer PR:**

`issues.md` contains `android: 14`.
`proposal.md` scope: "Adds the Habit List screen and the Add Habit screen."

Branch: `feat/14-habit-list-screen`

PR title: `feat(android): add habit list and add habit screens`

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

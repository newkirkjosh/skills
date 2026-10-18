---
name: development-workflow
description: "Orchestrates the full development arc from approved job stories to merged PR and archived change folder. Detects existing state and enters at the right phase — no repeated ceremony. Sequences scope brief → openspec → linear → test author and implementer subagents → isolated evaluator → pr-workflow → review → archive. Triggers: \"start work on feat-X\", \"what's next for feat-X\", \"open a PR for feat-X\"."
license: MIT (Scope Brief adapted from fx/skills by Marian Rudzynski; see LICENSE.txt)
metadata:
  type: flexible
  upstream: "https://github.com/fx/skills/tree/4b1010d/skills/dev"
---

# Development Workflow

## When to Use

**Trigger phrases (all three re-run entry detection from scratch):**
- "start work on `<feat-name>`"
- "what's next for `<feat-name>`"
- "open a PR for `<feat-name>`"

All three behave identically: entry detection runs first and decides the phase, whatever the wording. "Open a PR for feat-X" does not skip to Phase 4; it may enter Phase 3 if `sprint-contract.md` is absent or has unchecked items.

**Not auto-triggered**: always an explicit invocation with a feat-name.

## Roles

You are the **coordinator**. You own the Scope Brief, branches, commits, `sprint-contract.md`, the PR and every handoff to the user. You delegate exactly three jobs, each to its own general-purpose subagent that reads a role file from this skill's `references/` directory:

| Role | File | Writes | Model |
|---|---|---|---|
| Test author | `references/test-author.md` | Failing tests and fakes only | `sonnet` |
| Implementer | `references/implementer.md` | Production code only | `sonnet` |
| Evaluator | `references/evaluator.md` | Nothing; reports the contract | `sonnet` |

Spawn each one like this (Claude Code syntax; `<skill-dir>` is the base directory shown when this skill loaded):

```
Agent tool:
  subagent_type: "general-purpose"
  model: "sonnet"
  description: "<role>: <feat-name> <layer>"
  prompt: "Read <skill-dir>/references/<role>.md and act in that role.

           <the Scope Brief from scope-brief.md, verbatim>

           Change folder: <absolute path>
           Layer: <:layer>
           <role-specific input: the test author's report for the implementer,
            the failing items on a fix pass; nothing else for the evaluator>"
```

Never hand a subagent the whole lifecycle, and never do a delegated job yourself: a coordinator that writes the code also grades it. One exception: a review or evaluation finding that only needs a few lines of non-code wording (docs, comments, a contract sentence) you apply directly and say so in the commit; anything touching code, config or tests goes to an implementer.

**Budget.** Each spawn costs roughly 50–80k tokens, and the user's plan has a session limit that a long run can hit. Match the model to the job: `haiku` for narrow or mechanical evaluations and doc fixes, `sonnet` for test authoring, implementation and judgment-heavy evaluation. Keep at most three agents in flight. Scale the review set to the change (see `pr-workflow`).

## Scope Brief

Read `references/scope-brief.md` before Phase 0. It defines the brief, its fields, and how it travels. Every subagent prompt and every review request in this lifecycle carries the brief verbatim; that is how "just", "only" and the implied neighbouring updates survive past the first handoff.

## Entry detection

Checked in order, first match wins. Work proceeds one layer at a time, in `tasks.md` order; "the layer" below is the first layer whose sub-issue in `issues.md` is still open. When several layers map to the **same** issue (a small fix tracked by one issue), treat them as one unit: one branch, one test author/implementer/evaluator pass covering all of them, one PR.

| Existing state | Entry point |
|---|---|
| No `openspec/changes/<feat-name>/` folder | Phase 0: Scope Brief and OpenSpec setup |
| Change folder exists, no `scope-brief.md` | Reconstruct the brief (see `references/scope-brief.md`), then re-run detection |
| Change folder exists, no `issues.md` | Phase 1: Issue creation |
| `issues.md` exists, no branch for the layer | Phase 2: Implementation |
| Branch exists, no open PR, no `sprint-contract.md` section for the layer | Phase 3: Evaluation (start) |
| Branch exists, no open PR, the layer's contract has unchecked items | Phase 3: Evaluation (fix pass) |
| Branch exists, no open PR, the layer's contract is all checked | Phase 4: PR creation |
| PR open for the layer | Phase 5: Review |
| All sub-issues in `issues.md` are closed | Phase 6: Archive |

## Phases

**Phase 0 — Scope Brief and OpenSpec setup**
1. Build the Scope Brief from the user's own words. Grep for every file the change will touch to fill **Also update**.
2. Invoke the `openspec` skill, passing the brief and its size signal. A `narrow` change gets a short design note instead of a full `architecture-review` (see `openspec`).
3. Save the brief as `openspec/changes/<feat-name>/scope-brief.md`.
4. Show the user the **Interpreted scope**, **Also update** and **Explicitly out of scope** fields in a few lines, so a wrong reading is caught now.

**Phase 1 — Issue creation**
Invoke `linear` (default tracker) for its OpenSpec-to-issues workflow. Output: `issues.md` with the parent identifier and one sub-issue per layer. If the work already has an issue (the user named one, or it was filed earlier), don't create new ones: write `issues.md` mapping each layer to that issue, add it to the board, and comment there if the diagnosis changed.

*GitHub alternate:* for a GitHub-tracked project, invoke `github-issue` then `github-project` instead. They write `issues.md` with GitHub issue numbers; the rest of the pipeline is unchanged.

**Phase 2 — Implementation**
If the user says they will implement it themselves, surface the layer's `tasks.md` section, say "When the tasks are done, invoke `development-workflow` again for `<feat-name>`", and stop.

Otherwise, for the layer:
1. Create the branch from the default branch, named per `pr-workflow`: `<type>/<issue-number>-<short-description>`. If the project's `AGENTS.md` has a worktree convention (e.g. `.worktrees/<branch>`), create it as a worktree there and run everything for this layer from it. Move the uncommitted change folder onto the branch and commit it first (`docs(openspec): …`), so the default branch stays clean.
2. Spawn the **test author**, unless checks that fail for this exact bug already exist (a broken build, an existing test that fails today). Then skip it, name those checks in the implementer's prompt and in `sprint-contract.md`, and say why.
   Otherwise spawn it. Check its report: every story has a test or a named manual check, and every test fails for the stated reason. Commit the tests (`test(<scope>): …`).
3. Spawn the **implementer** with the test author's report. Check its report: tests and build clean, every **Also update** item accounted for, nothing outside the brief. Commit (`feat(<scope>): …`). If it reports a wrong test, surface its evidence to the user and stop.
4. Continue to Phase 3 in the same run.

**Phase 3 — Evaluation**
1. If the change's evidence only exists on a PR (a CI workflow that triggers on `pull_request`), push and open the PR as a **draft** first, wait for its run, and give the evaluator the PR number as environment. Phase 4 then marks it ready instead of creating it.
2. Spawn the **evaluator** with only the brief, the change-folder path and the layer. Never pass implementation context: no diff, no summary, no "should pass because".
3. Write the layer's section of `sprint-contract.md` from its report (template in the `openspec` skill), checking only PASS items. Commit it with the change folder (`docs(openspec): …`).
4. On `VERDICT: PASS`, go to Phase 4.
5. On `VERDICT: FAIL`, run **one** fix pass: GAP items to a fresh test author, then FAIL items (and the new tests) to a fresh implementer, each given only those items. Commit, then spawn a **fresh** evaluator and rewrite the section from its report.
6. On `INCOMPLETE`, first check whether you can provide what's missing on this machine (boot an existing emulator AVD headless, start a local daemon or database), keeping its PID per the `shell` skill. Evaluators can message you to change shared environment mid-run (e.g. "stop the backend now"); do it, then reply with what changed. Never hand an evaluator input control of the user's live desktop (`xdotool`, `ydotool`, or a real `DISPLAY`): they may be using it. GUI checks run on an off-screen display instead (e.g. Xvfb; the machine's recipe belongs in the global CLAUDE.md); hand the evaluator that display and nothing else. If so, spawn a **fresh** evaluator and tell it only what's now available. Stop it afterwards.
7. If it still fails after the fix pass, or is still `INCOMPLETE`, surface the open items with the evaluator's evidence and stop. Don't loop further. For `INCOMPLETE`, name what's needed (a device, a running daemon) so the user can provide it and re-invoke.

**Phase 4 — PR creation**
Once `sprint-contract.md` is final and review is done, make the archive move the PR's last commit: `git mv openspec/changes/<feat-name> openspec/changes/archive/<feat-name>`. Merging then closes the issue (`Closes #<n>`) and archives the change together, with no follow-up PR to `main`.
Invoke `pr-workflow`, passing the Scope Brief for the PR body and the reviewers. After the PR exists, link it to the layer's sub-issue from `issues.md`: on Linear, comment the PR URL on the sub-issue and move it to the team's review state (the `linear` skill); on GitHub, the PR body's `Closes #<n>` links it, and the board item moves to In Review via `github-project`. Output: PR URL.

**Phase 5 — Review**
`pr-workflow` runs the review sequence; pass each review agent the brief as an OUT OF SCOPE / IN SCOPE block. Triage findings against the brief, fix what is in scope, and surface the consolidated result before merge.

**Merging** is the user's call unless the project's `AGENTS.md` has a **Merge policy** that grants it. With that grant, merge yourself only when every gate holds on the PR's current head, re-checked right before merging (the github skill's `head-status.sh`):

1. CI green on the head commit.
2. The layer's `sprint-contract.md` section is all checked from an evaluator `VERDICT: PASS`.
3. Every review finding is fixed or dismissed with a reason in the PR comment; none is open or blocking.
4. Zero unresolved review threads.
5. Nothing the policy excludes (it may exclude, for example, migrations, auth or release PRs).

Squash-merge with `--match-head-commit <sha>` so a later push can't slip in, then move the tracker issues to done and run Phase 6. Any gate failing hands the merge back to the user with the reason. Without a policy, stop at the merge-ready report.

**Phase 6 — Archive**
1. Read `issues.md`.
2. Check each identifier's state: Linear via the `linear` skill (`get_issue`, `statusType`), GitHub via `gh issue view <n> --json state`.
3. If any issue is not closed (`completed`/`cancelled` on Linear, `CLOSED` on GitHub), surface the open identifiers and stop. Don't archive.
4. If all are closed, confirm the change folder is under `openspec/changes/archive/` (Phase 4 moved it in the PR). Only a change merged before that rule needs a separate archive commit; batch those into one chore PR.

## Constraints

- All three trigger phrases run entry detection; never jump to a phase based on wording.
- Entry detection reads the filesystem; never ask the user what phase they're in.
- `<feat-name>` is the change folder name exactly: kebab-case with a type prefix (`feat-`, `fix-`, `chore-`; see `openspec`).
- Every subagent prompt starts with the Scope Brief verbatim. A subagent that reports a brief/job conflict gets an answer from the user, not from you.
- Test author, implementer and evaluator are separate spawns with no shared context. The evaluator never sees implementation narrative, and a fix pass always ends with a **fresh** evaluator.
- Subagents never commit, push or open PRs; the coordinator does, after checking each report.
- Phase 4 is only reached when the layer's `sprint-contract.md` section exists and every item is checked.
- Phase 4 always links the PR to its sub-issue (Linear comment, or `Closes #<n>` on GitHub); never skip it.
- Phase 6 archive is blocked while any sub-issue is open; no partial archive.

## Gotchas

- **The sprint contract cites runs, not memories.** Write it only from the evaluator's report, with the run or job ID behind each checked item. Evidence you supplied yourself (a rerun you triggered, a CI run ID) is labelled as yours. Timings from a different run are not evidence.
- **After any merge to `main`, merge `main` into every in-flight branch and push**, so each PR's CI tests what will actually merge. Land CI/workflow changes first; branches created before the workflow existed get no checks until then.
- **Squash merges break ancestry.** A branch built on top of another PR's branch hits add/add conflicts after that PR is squash-merged. Check that `main`'s copy equals the branch's base (`git show origin/main:<f>` vs `git show <base>:<f>`); if so, keep the branch's version.
- **Signing or push failures stop the run.** If a commit or push fails with a signing-agent or SSH-agent error, nothing after it may run: chain with `&&`, report, and ask the user to unlock. Never fall back to unsigned commits.
- **An implementer that didn't show red first** (tests failing before the fix) leaves you without red-to-green evidence. Ask the evaluator to prove it: run the new tests against the pre-fix code in a scratch worktree.

- A subagent's "tests pass" is a claim. Check its report names the command and shows the result; if it doesn't, the evaluator will find out the hard way.
- Evaluators that read `design.md` or code before writing the contract grade the code instead of the stories. The role file forbids it; if a report's contract items mirror implementation names rather than story language, rerun with a fresh evaluator.
- `INCOMPLETE` is a normal outcome, not a failure. Don't fake the missing condition (a seeded login, a stubbed device) to reach PASS; record what's NOT RUN in `sprint-contract.md`, file anything pre-existing that blocked it as its own issue, push the branch, and stop.
- Build tools cache test results. An evaluator that reports "0 tests run" or an instant pass did not run anything; the role file tells it to force execution.

## Example

User says: "start work on feat-onboarding, just the empty state for now"

Entry detection: no change folder → Phase 0. The brief quotes the request verbatim, size signal `narrow`, out of scope "populated list and add-habit flow: later story group". `openspec` creates the folder; the brief is saved and its scope shown to the user.

Phase 1: `linear` → parent APP-12, sub-issues APP-13 (`:shared`), APP-14 (`:android`).

Phase 2 (`:shared`): branch `feat/13-onboarding-empty-state`; test author writes two failing repository tests; implementer makes them pass and wires DI; both commits made.

Phase 3: a fresh evaluator derives four contract items from `specs/stories.md`, runs the tests, reports `VERDICT: PASS`. `sprint-contract.md` gets a `:shared` section, all checked.

Phase 4: `pr-workflow` opens the PR and the URL is commented on APP-13. The next invocation picks up `:android`.

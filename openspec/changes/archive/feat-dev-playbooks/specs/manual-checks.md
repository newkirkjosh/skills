# Manual checks: dev playbooks

This is an instruction change. Replay each input against the worktree copy of `skills/dev/SKILL.md` and only the references it tells the reader to load. Record PASS, FAIL or NOT RUN with the file and quoted instruction that determines the next action and allowed writes. An action inferred from general good sense, without an instruction supporting it, fails. These are paper replays: do not push, create a PR, change hardware, remove a worktree or run a workflow against a live repository to test them. A separate real-session replay uses a disposable local fixture and records its transcript; external actions remain simulated.

Baseline: `eb1c5f7de0d6a3c23dc4bada981e1730cb17ebc9`. Read it with `git show <base>:<path>`, rather than the installed skill, which may change independently. Fixtures below use `owner/repo`, `feat-example`, `fix-example`, `feat/example`, `fix/example`, and symbolic SHAs H (expected branch head), D (default head), E (evaluated head). “Verified folder” means active or archived `openspec/changes/<name>/` with `scope-brief.md`, or both `proposal.md` and `tasks.md`.

## Story 1: write-free asks and routing precedence

| ID | Input and state | Expected action and writes | Baseline result |
|---|---|---|---|
| R1 | `/dev status for feat-example`; open PR behind default, clean existing worktree | Interrupted-sync read check, then `status`; read `wt list`, PR state and `pr-status.sh`, report behind and suggest sync; no merge, push, commit or worktree recreation | FAIL: Worktrees **Status** orders merging default and pushing an open behind PR; no status playbook exists |
| R2 | Same request, PR merged and worktree removed | Report merged and suggest close-out; do not recreate the worktree or enter Phase 6 | FAIL: Status and entry detection lead to Phase 6 and cleanup |
| R3 | `/dev how does the parser work for feat-example?`; branch exists but worktree is gone | `investigation`, answer from reads; no recreation, folder reconstruction, issues or commits | FAIL: entry detection recreates the worktree before answering; no investigation playbook exists |
| R4 | `/dev is this approach feasible?`; no existing state | `investigation` before any worktree, change folder or issue; answer and stop | FAIL: Phase 0 step 0 creates a worktree before step 2 recognizes a spike |
| R5 | `/dev prototype an alternative for feat-example`; existing branch and ready PR | `prototype`; only throwaway scratch files outside git and `wt`, exported with `git archive`; report learning and stop; no branch, worktree, commit, push or PR | FAIL: no prototype playbook or scratch-only write scope exists |
| R6 | R1, R3 and R5 separately, with an unfinished sync-journal record; repeat with `MERGE_HEAD` in an existing worktree | Interrupted-sync check wins over all write-free routes; report and stop, changing nothing; never recreate a missing worktree merely to check | Existing safeguard PASS; preservation check, not evidence of new behavior |
| R7 | A new request first appears to be a change, but Phase 0 step 2 establishes feasibility only; first worktree contains no work | Remove that still-empty worktree with the approved `wt remove <branch>` path, then enter `investigation`; no durable change folder or issue | FAIL: old Phase 0 spike line only answers and stops; it does not remove the empty worktree |

For R1–R5, follow every reachable shared instruction too. An unconditional Worktrees Status action, sync-after-merge gotcha, or `INCOMPLETE` push rule that still applies makes the case FAIL even if a playbook says “read-only.” Repeat R5 with no existing state to prove that scratch creation does not first create a branch. Read each of the three playbooks' opening write scope; it must match the allowed writes above.

## Story 2: existing state and pickup

| ID | Input and state | Expected action and writes | Baseline result |
|---|---|---|---|
| P1 | `/dev open a PR for fix-example`; verified folder says `Playbook: bug-fix`, branch is `feat/example`, no `issues.md` | `pickup` honors recorded playbook over prefix and wording; enter lifecycle from its top, then Phase 1; no new bug reproduction/front end | FAIL: no recorded-playbook selection exists |
| P2 | `/dev fix this for feat-example`; verified folder says `Playbook: change`, branch is `fix/example`, issue exists and implementation is absent | Honor `change`, enter lifecycle from top, select Phase 2; wording and prefix cannot restart the bug front end | FAIL: no recorded-playbook selection exists |
| P3 | Existing verified folder has no Playbook field | On `fix/example`, select `bug-fix`; on `feat/example` and `chore/example`, select `change`; repeat for archived folder and for a folder with proposal plus tasks but no brief | FAIL: no verified-folder prefix fallback or Playbook field exists |
| P4 | Directory named `openspec/changes/fix-example/` contains only an unrelated README; a `fix/example` branch exists | Do not treat directory name or branch prefix alone as proof of a dev change folder; take the missing-folder recovery path before deciding the playbook | FAIL: no validation rule gates a playbook prefix fallback |
| P5 | Existing worktree, branch, or PR, each separately, but no verified folder | Reach the unchanged reconstruct row; rebuild brief/proposal/stories/design/tasks from commits there, commit, rerun detection; reconstructed brief records `bug-fix` for `fix/`, otherwise `change`; never fall through to new-work Phase 0 | FAIL on new Playbook recording; existing reconstruction is a preservation condition |
| P6 | No layer worktree is found; an open PR identifies change; repeat with only archived folder on default | Preserve find order: layer branches in `wt list`, then open PR, then archived folder; find existing state and use pickup | FAIL on pickup route; discovery order already exists |

**T1. Re-evaluation override (preservation).** A numbered `team` re-invocation requests evaluation at H. Give it an existing `handoff.md` pointing to Phase 5 and a checked contract that otherwise selects completion. At matching H, lifecycle enters Phase 3 with a fresh evaluator and reuses the existing PR without changing its draft state. With a different layer head it stops `TEAM: BLOCKED head mismatch`. A word such as “status” in this team request must not send it to the write-free route. The override precedes handoff/table, but follows the interrupted-sync check. Baseline: override behavior exists; FAIL on separation into one shared lifecycle and explicit team routing exemption.

**T2. Requested-sync validation (preservation).** A numbered `team` request names PR, H and D; handoff and table would otherwise select completion. Replay closed PR, non-default target, wrong PR head, wrong local branch head, missing worktree with head mismatch, and dirty worktree/index as separate cases. Each stops with the existing blocked outcome, without merge, push, or premature worktree recreation. Valid heads allow missing-worktree recreation only after PR/head checks. Baseline: safeguards exist; FAIL on the new shared lifecycle placement and team exemption from write-free routing.

**T3. Requested-sync completion (preservation).** With valid open PR, matching heads and clean worktree, record three SHAs and merge exactly D; conflict aborts an in-progress merge and stops with sync failed. A behavioral merge needs re-evaluation plus delta review; PR-only evaluation evidence blocks without a push for this entire invocation, including Phase 5's fix loop. Otherwise completion publishes the sync, writes `handed-off <head sha>` immediately before merge-ready, and leaves journal retirement to team. Baseline: behavior exists and must remain word-for-word except link paths.

**T4. Single owner and ordering (new structure).** Locate Requested re-evaluation, Requested sync and handoff/table procedure. Only `lifecycle.md` owns these instructions; router and pickup call it from the top, never dispatch directly to a phase. Confirm order: interrupted-sync read guard; find existing change; requested re-evaluation; requested sync; handoff; table. Baseline FAIL: all instructions remain in `SKILL.md` and lifecycle/pickup files do not exist. Replay T1–T3 again with incomplete journal or an existing merge in progress: guard stops before overrides.

## Story 3: reproduce-first bug fix

**B1. Observable defect, no existing state.** Input `/dev fix the parser returning an empty result for valid input`. State: no journal, worktree, branch, PR or folder. Expected: select `bug-fix` and show that choice with Scope Brief confirmation; reproduce on real surface through read-only actions, establish root cause before creating `fix/example`; create `fix-example` brief with `Playbook: bug-fix`, proposal, observed-versus-expected story, regression-guard story, short design note, and one-layer tasks; commit the folder, then call lifecycle from its top. The front end does not file an issue or write `issues.md`; Phase 1 reuses a named issue, or files one if absent. Replay both issue states. Baseline FAIL: all new work enters the feature Phase 0; no reproduce-first bug front end or recorded bug-fix playbook exists.

**B2. Architectural root cause.** Same input, diagnosis requires changing a component interface. Expected: stop bug front end before creating the worktree; reroute to `change`, retain brief context and require architectural design approval before Phase 1. If reproduction would change hardware or a live service without permission, stop for authorization rather than treating “reproduce” as permission. Baseline FAIL on bug-to-change routing; existing permission requirement is a preservation condition.

**B3. New non-defect.** Input `/dev add an optional parser mode`, no existing state. Expected: `change`, visible Scope Brief selection, today's Phase 0, `Playbook: change`, then lifecycle; architectural request requires design approval. A second replay with existing bug-fix state must take pickup, not this front end. Baseline FAIL on explicit playbook selection/field, not on existing Phase 0 behavior.

## Story 4: repository setup and ownership

**U1. Audit the authoritative file.** Input `/dev set up this repo for dev`; no interrupted sync. Local branch claims complete setup; default branch lacks Tracker and Testing, has ambiguous Layers, and has all other required sections. Expected: `setup` before existing-state pickup; fetch `origin refs/heads/<default>`, read `git show FETCH_HEAD:AGENTS.md`; report each section as present, missing or ambiguous: Tracker and board, Layers, Pull requests/title/labels/project, Merge policy, local pre-publish checks (Testing), hardware permission where relevant, named verification skill. Existing sections are not silently rewritten. Replay hardware and non-hardware repos; failed fetch/read cannot be replaced with trust in the edited local file. Baseline FAIL: no setup route, section audit or default-branch setup procedure.

**U2. Approval gates and write scope.** Missing sections can be drafted from remote, labels, workflows and branch protection. Before approval, show draft and facts versus unknowns without editing repository instructions or creating a worktree. No answer or a rejection leaves it a report/draft only. After explicit approval, use `chore/dev-setup`, one commit and a PR; never write directly to default or merge. Existing sections need explicit approval to change. A complete repo ends with a report rather than an empty setup PR. Baseline FAIL: no setup playbook or its write limits. A draft is reviewable text until approval, not an edited `AGENTS.md` on a work branch.

**U3. Verification offer belongs to the owner.** Replay owner and third-party repos, including forks where ownership must be established rather than assumed from the checkout path. Owner: offer once to add one concrete task line naming the bare `verify-change` skill, using this repo's verified verification facts; do not activate it without approval. Third party: report that this line would select nothing, no such offer. Repeat setup within the same interaction after an accepted or declined offer: no duplicate offer. No ownership or verification facts available: establish them or report unknown rather than inventing them. Baseline FAIL: no setup verification-offer procedure.

## Story 5: unchanged lifecycle and caller contracts

**L1. Compare moved text (preservation).** Extract Entry detection from baseline `skills/dev/SKILL.md`; compare to new lifecycle after excluding the interrupted-sync paragraph now in Routing. Compare Phase 1 through Phase 6 word-for-word; compare lifecycle-only Constraints/Gotchas as moved paragraphs. Normalize only file-link paths for their new directory. Show each changed token, if any: a behavior change or other rewording fails, even if considered an improvement. Phase 0 must move unchanged to `playbook-change.md` except its spike line and the required playbook recording; identify those exceptions explicitly. Compare the interrupted-sync paragraph to Routing verbatim. Baseline lacks all destination files: FAIL for relocation; original phase behaviors are preservation controls.

**L2. Lifecycle ownership of writes (new isolation).** Search shared router rules, Worktrees Status and Gotchas for sync-after-merge, cleanup, push on `INCOMPLETE`, unconditional Phase 0/worktree instructions, and lifecycle-only guards. Prove each is either owned by lifecycle or explicitly conditional on lifecycle entry. Replay R1–R5 and U1 after reading all shared sections; no lifecycle write becomes reachable. Baseline FAIL: Worktrees Status and gotchas apply lifecycle writes to every invocation.

**L3. Every caller follows its target (new structure).** Read changed references in `skills/team/SKILL.md`, team `references/merge-gate.md`, `skills/spec-writer/SKILL.md`, github and linear `references/openspec-issues.md`, dev `references/completion.md`, `head-discipline.md`, and `host-adapters.md`. Follow each reference to moved phases or entry detection to its new owner; verify table rows and phase numbers still mean the same thing. Team continues to accept only change folders from either lifecycle front end; it does not acquire setup/write-free behavior. Baseline FAIL for relocated targets, since no lifecycle file exists. Run `scripts/check-refs.sh`, but do not use an exit 0 alone as proof a prose phase reference is correct.

**L4. Packaging and invocation.** Expect exactly seven frontmatter-free, flat `references/playbook-<name>.md` files for status, investigation, prototype, pickup, bug-fix, change and setup, plus one shared lifecycle reference. Each playbook opens with its write scope. The router loads the selected reference, preserves explicit invocation/handoff rules and shared role separation, and does not turn an unrelated status message into `/dev`. README's dev row and dev description describe playbooks; description retains the exact explicit-use opener and stays at most 1024 characters. Brief format includes Playbook independently of Path, and spike points to investigation. Baseline FAIL: no playbook files/field/description; explicit-use boundary already exists and must remain.

## Baseline evidence and final repository checks

Observed against the baseline before implementation:

```text
$ git rev-parse HEAD
eb1c5f7de0d6a3c23dc4bada981e1730cb17ebc9
$ git ls-tree -r --name-only HEAD skills/dev/references
skills/dev/references/completion.md
skills/dev/references/evaluator.md
skills/dev/references/head-discipline.md
skills/dev/references/host-adapters.md
skills/dev/references/implementer.md
skills/dev/references/scope-brief.md
skills/dev/references/test-author.md
```

Reading baseline `SKILL.md` confirms Worktrees Status says an open behind PR must merge default and push; Phase 0 creates a worktree at step 0 and recognizes spike at step 2. Baseline brief Format has Path but no Playbook. These are concrete failing conditions for R1, R4, P1–P5, B1 and L4; absent references establish that new setup/routing contracts cannot be followed. T1–T3's existing safeguards are intentionally preservation checks, not claimed red tests.

After implementation run catalog validation, descriptions, references and privacy checks, shell syntax and existing script tests using `AGENTS.md` commands. Record actual outputs rather than assuming success. Use `git diff --name-only <base>` to verify no script, CI, project `AGENTS.md`, review-rule or lifecycle-behavior change slipped into this restructure. Inspect `git diff --word-diff <base> -- skills/dev` for L1 and all named callers for L3. Record all deviations and replay failures; do not bless a moved-text change merely because repository validators pass.

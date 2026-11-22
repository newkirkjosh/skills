# Manual checks: Batched learning review

The deliverable is Markdown instructions, so these are replay checks. An evaluator reads the finished `skills/learn/SKILL.md` and `skills/learn/references/inbox.md`, applies each scenario, and records PASS or FAIL with the quoted instruction that produces the action. Every check fails against the current skill (no modes, no inbox reference).

Fixtures: `specs/fixtures/inbox/` is a placeholder inbox of 14 records. The field layout in the fixtures is illustrative; checks bind to field content and behavior, not to the exact layout the implementer chooses in `inbox.md`. Placeholder names only (`alpha-skill`, `owner/repo`, `example-repo`). Fixture inbox contents are never copied into the catalog.

Fixture index:

| Record | Status | Role |
|---|---|---|
| a1, a2 | open | same skill and decision (alpha-skill step 3), recurrence 2 |
| s1 | open | alpha-skill, no demonstrated cause (suspicion) |
| o1 | open | alpha-skill step 1, oldest, did not recur |
| b1 | open | beta-skill, single, high severity |
| p1 | open | project-specific lesson |
| m1 | open | personal preference |
| r1 | open | concerns step 9 of epsilon-skill; assume step 9 no longer exists in the skill |
| d1 | applied | PR merged into default branch, text present |
| d2 | applied | PR closed unmerged |
| d3 | applied | worktree gone |
| d4 | applied | PR merged but recorded text absent on default branch |
| d5 | applied | worktree present, PR open, text present |
| h1 | shipped | already shipped |

## Capture (Story 1)

**C1. Note writes one record.** Input: after an unrelated task, user says "learn note: alpha-skill ended without a handoff; I corrected it." Global instructions name an inbox directory. Expected: exactly one new record file in that directory with skill, date, Observed, Cause, Change, Evidence, a source pointer and status `open`; the file name follows the naming rule in `inbox.md`. No Step 1 catalog resolution beyond naming the owning skill, no worktree, no edit, no commit, no PR.

**C2. No inbox named.** Input: same request, global instructions name no inbox location. Expected: skill reports that no inbox is named and writes nothing, anywhere (including the catalog, the repository root, the current directory).

**C3. Never in the catalog.** Input: inbox location resolves inside the catalog checkout. Expected: instructions say to refuse or report and write nothing; `inbox.md` and `SKILL.md` contain no concrete inbox path (grep for `/home`, `~`, `.claude`, `memory` gives no path to an inbox).

**C4. Unsupported lesson.** Input: "learn note: the skill seemed odd" with no correction or outcome. Expected: record is not written as a fact; either asks for or records only what the conversation demonstrates, with Cause marked unestablished rather than guessed (Step 2 rule carried into capture).

**C5. Evidence-free duplicate of an existing open record.** Input: note repeating a1. Expected: a new record is still written (recurrence is data) or the existing record is cited per `inbox.md`; instructions state which, and never silently drop it.

## Review (Story 2)

**R1. Inputs read.** Input: "learn review" against the fixture inbox. Expected: reads all open and applied records (a1, a2, s1, o1, b1, p1, m1, r1, d1 to d5); does not need to re-process h1 (shipped).

**R2. Grouping.** Expected groups: alpha-skill step 3 (a1, a2); alpha-skill step 1 (o1); alpha-skill s1 separate or attached to the step 3 group as unestablished; beta-skill (b1); each other record its own group. Grouping is by owning skill and decision, not by date or by file name.

**R3. Recurrence orders, does not prove.** Expected: the alpha-skill step 3 group (recurrence 2) is investigated before o1, and b1 (single, high severity) is also early. A group is never marked "valid" or "to fix" only because it recurred; the summary shows each group's cause established through the Step 2 evidence fields and the Step 3 owner and duplicate search before any edit is proposed. Counter-case: a group with recurrence 3 and no demonstrated cause must not yield a proposed edit.

**R4. No demonstrated cause.** Input: s1. Expected: stays open; the summary states what to watch for next time; no edit proposed.

**R5. Routing outside the catalog.** Input: p1 (project convention) and m1 (personal preference). Expected: summary routes p1 to that project's own instructions and m1 to the user's preference or memory source (per Step 3 table), proposes no public-catalog edit, and edits those outside destinations only if the request authorizes them. Whether these records close is decided by the inbox.md rule: they close only with evidence the outside fix landed.

**R6. Close only on evidence.** Input: r1 (step 9 gone) and o1 (did not recur). Expected: r1 may close with evidence (the step no longer exists, shown by reading the skill at the default branch); o1 stays open even though months passed with no recurrence. A reviewer asked "o1 hasn't come back, close it?" must refuse: non-recurrence is not evidence.

**R7. Ranked summary and approval gate.** Expected: before any worktree is created or file edited, the user sees patterns, weakest skills, and a ranked list of proposed edits each with its evidence, and approves. Replay with the user answering "approve 1 and 3 only": only those two edits proceed; the rest stay open. Replay with no answer: nothing is edited.

**R8. One worktree, existing steps.** After approval: one worktree from the default branch for the whole approved set; Steps 4 to 7 run once (edit, verify the originating cases and a nearby valid case per edit, diff and handoff). Not one worktree or PR per record. Records covered by the edit are set to `applied` with worktree or PR, file and edited text (R9).

**R9. Applied record fields.** Expected: each record moved to `applied` names the worktree or PR, the file and the edited text that address it. A record updated to `applied` without those fields fails.

**R10. Review makes no publish decision.** Expected: review ends at the diff and report like Step 7; commit, push, PR are done only if the request separately authorizes them; `shipped` is never set because a PR was opened.

**R11. Counterexample, single correction still routes.** Input: "learn review" with an empty inbox or only shipped records. Expected: reports nothing to review and stops; no worktree, no edits.

## Release tracking (Story 3)

**T1. d1 to shipped.** Facts: PR merged and its text is on the default branch. Expected: d1 becomes `shipped`, with the evidence checked (command or file read) shown.

**T2. d2 back to open.** Facts: PR closed without merging. Expected: d2 returns to `open`, and the summary says why.

**T3. d3 back to open.** Facts: worktree not on disk, no PR recorded. Expected: d3 returns to `open`.

**T4. d4 back to open.** Facts: PR merged, but the recorded edited text is absent from the file on the default branch. Expected: d4 returns to `open` (recorded edit no longer present); it is not marked shipped on the strength of the merge alone.

**T5. d5 stays applied.** Facts: worktree present, PR open, text present, not on the default branch. Expected: d5 stays `applied`; it is not shipped and not returned to open.

**T6. No unverified transitions.** Expected: a status change without checked evidence (the instructions require the git or PR check) fails; "assume merged" fails.

**T7. Shipped is terminal for review.** Expected: h1 untouched.

**T8. Removal ships.** Facts: an applied record's change is `deleted: <a stale sentence>` (or `deleted file`); after a fetch the sentence (or file) is absent on the default branch. Expected: the record becomes `shipped`; it is not left unverifiable for lack of text to find.

**T9. Closed PR beats a live worktree.** Facts: the PR closed unmerged, the change is not on the default branch, and the worktree still holds it. Expected: the record returns to `open`; exactly one rule applies.

**T10. Open PR beats a stale worktree.** Facts: the PR for the branch is open and holds the change; the local worktree switched branches and no longer holds it. Expected: the record stays `applied`; the worktree is not consulted.

**T11. PR opened after the record.** Facts: the record names a repository, branch and worktree path but no PR; the worktree was later removed and a PR for that branch is open and holds the change. Expected: the review finds the PR by branch and the record stays `applied`; it is not reopened because the worktree is gone.

## Existing flow (Story 4)

**E1. Single correction unchanged.** Input: "use learn: this skill leaves the agent guessing what to do next." Expected: mode selector picks the default path with no inbox read or write; Steps 1 to 7 run as today, including edit worktree, verification and diff handoff. Diff the Steps 1 to 7 text between `main` and the finished skill: no wording changes to step behavior except cross-references to the new modes (any change is listed and justified).

**E2. Selector precedence.** Input: "learn note" and "learn review" select their modes; a bare correction selects default; an ambiguous request ("learn from these five corrections") is treated as the default flow or asks, per the selector's stated rule, never silently as review.

## Static checks (repository)

**S1.** `skills/learn/SKILL.md` description starts with the exact explicit-use opener, names the note and review modes, and is at most 1024 characters (`scripts/check-descriptions.sh`, `agentskills validate skills/learn`).

**S2.** `skills/learn/references/inbox.md` exists, SKILL.md says to load it in both modes, `scripts/check-refs.sh` passes, SKILL.md body is under 500 lines.

**S3.** `scripts/check-private.sh` passes; no concrete inbox path, home path, hostname or private name appears in `SKILL.md`, `inbox.md`, README row or commit message. The inbox is named only as "the learning inbox the global instructions name".

**S4.** README `learn` row mentions capturing lessons and batched review and is still one table row.

**S5.** Explicit-use rule holds: no wording in the new modes lets review or capture auto-trigger or start by reminder; a reminder, if mentioned, only suggests the user run review.

**S6.** `grep -rn` for references to learn's step numbers in other skills shows none broken by the change.

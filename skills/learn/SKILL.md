---
name: learn
description: "Explicit-use only — invoke when the user explicitly names this skill, or when an active explicitly invoked workflow calls it. Turns demonstrated corrections from the current conversation into small, verified improvements to the authoritative skill catalog. Finds the right source and policy owner, avoids duplicate or project-specific rules, and leaves an isolated diff for review. Also has a note mode that records one lesson in a private inbox without editing the catalog, and a review mode that groups recorded lessons by skill and decision, applies the approved set in one worktree and tracks each to release."
license: MIT (learning-loop concept adapted from fx/skills by Marian Rudzynski; see LICENSE.txt)
metadata:
  upstream: "https://github.com/fx/skills/tree/3de675e365e6eecbfbf7c89018e15a96d91859de/skills/learn"
---

# Learn

Turn a demonstrated correction from the current conversation into a targeted skill improvement. Follow the steps in order. A plausible lesson without evidence stays a proposal.

**Explicit use only.** This invocation authorizes targeted catalog edits and local validation. It ends at the diff and report. Commit, push, PR, install and writes outside the owning catalog require authority from the user’s request; this skill supplies none on its own. Later requests do not inherit this workflow.

## Choose the mode

| Request | Mode |
|---|---|
| "learn note" (record a lesson, no edit) | Note: see Note mode |
| "learn review" (review recorded lessons) | Review: see Review mode |
| A correction, or anything else, including "learn from these corrections" | Default: Steps 1-7 below, no inbox read or write |

An ambiguous request is the default flow, never review. Note and review load `references/inbox.md` first. Neither starts on its own: a reminder may suggest the user run review, nothing more.

## Step 1: Locate the source catalog

1. Take the directory this skill was loaded from, resolve its symlinks, and find its Git root:
   ```bash
   readlink -f <loaded-skill-directory>
   git -C <resolved-directory> rev-parse --show-toplevel
   ```
2. Read that root’s `AGENTS.md`. Inspect its remote, branch, worktree list and status to establish which catalog and checkout you found.
3. Locate the skill implicated by the correction and resolve its source too. If it belongs to a different catalog, use that catalog’s instructions and source; never redirect its fix into this one.

Edit source checkouts, never copied installs, plugin caches or generated bundles. If no source can be established, report the candidates and ask for the missing source location before writing. A symlink identifies a source; it does not authorize editing the default checkout that installed skills point to.

**Result:** the owning catalog root and target skill path, or a specific source-location blocker.

## Step 2: Extract the demonstrated lesson

1. Read the user’s correction and the relevant earlier messages or artifacts. Do not invent omitted history.
2. Summarize the lesson in four short fields:
   - **Observed:** what the skill did or failed to do.
   - **Cause:** the instruction or missing decision that produced it.
   - **Change:** what the agent should decide differently next time.
   - **Evidence:** the user correction, actual outcome or verified capability supporting that change.
3. Separate a demonstrated cause from a suspicion. If unresolved, investigate what can be verified; report the remaining question instead of encoding a guess.

**Result:** one evidence-backed lesson per requested correction. No evidence-backed catalog lesson means no catalog edit.

## Step 3: Choose the policy owner and check for duplicates

1. Route the lesson by what it changes:

   | Lesson | Destination |
   |---|---|
   | Reusable skill decision or missing step | The skill or reference owning that decision |
   | Verified project convention or review misunderstanding | That project’s designated instructions or review rules; `cross-review` owns convention learning |
   | Machine recipe, personal preference or private project fact | The existing machine, memory or project source, outside the public catalog |
   | Transient outage, run status or unverified suspicion | The run’s report; no permanent rule |

2. Search that owner, its callers and available in-flight fixes for the same correction. If already present before this edit, or pending in another change, identify the source/change and report a no-op. The selected worktree’s own learning edit still proceeds through verification and handoff. Distinguish pending from released.
3. For an outside-catalog destination, report the proposed correction and where it belongs. Edit it only if the request also authorizes that destination. Do not turn a project exception into a global prohibition or use a reviewer’s false premise to weaken a real requirement.

**Result:** a named file and decision to change, or an explained no-op/outside-scope proposal.

## Step 4: Prepare an isolated edit

1. Follow the owning repository’s worktree rules. In this catalog, create a worktree from the default branch for a new learning, or use the change’s explicitly selected worktree.
2. Read the target file and the references/callers that govern the same decision before changing it.
3. Preserve unrelated dirty work. Use a fresh worktree instead of resetting, stashing or mixing it into the learning. If the requested change depends on dirty work whose ownership is unclear, stop that edit and explain the dependency.

**Result:** the exact edit worktree and relevant files, with unrelated work preserved. Never edit the default checkout used by installed symlinks.

## Step 5: Make the smallest complete correction

1. Before writing any instruction text, ask whether a check can make the demonstrated mistake fail: a catalog check script, a skill's bundled test, or a guard in the helper script that owns the step. If one can, the correction is that check plus a test that fails on the demonstrated mistake; write instruction text only for the judgment the check can't decide, or none. Put the check in the skill or script that owns the decision, never in a central list of rules and their enforcers. If only judgment can catch the mistake (which file owns a lesson, when to ask the user), say why no check applies and make the instruction edit below. Ask only for a demonstrated mistake: the catalog rule "Don't add a script for something an agent gets right inline" (`AGENTS.md`, Layout) still holds.
2. Rewrite or remove the failing instruction before adding another warning. Put policy in its owner and mechanics in the applicable reference/helper.
3. State the condition, required action and reason. For a procedure that left the agent guessing, write ordered actions and an explicit completion or stop condition; broad principles alone are insufficient.
4. Search for equivalent instances in scope and update callers whose contracts changed. Avoid duplicating the same policy across skills.
5. Remove private details from the patch and examples. Use placeholders; never copy credentials, personal details, machine paths, private project names or session/run notes into public guidance, fixtures or commit messages. Preserve required licenses and provenance.

New prerequisites must reflect verified capabilities, not a remembered tool name or CLI version. Do not import another catalog wholesale to solve a narrow learning.

**Result:** one coherent diff addressing the demonstrated cause and its related in-scope instances: a check with its failing test where one can decide the mistake, instruction text for the rest, and the reason when no check applies.

## Step 6: Verify the changed decision

1. Run the catalog’s required validators and reference/privacy checks. Run meaningful helper tests when executable behavior changes.
2. If Step 5 added a check, run its test on an input that reproduces the demonstrated mistake against the unfixed behavior, and show it fail on the test's assertion about that mistake, not on setup (a missing helper, file or command). Then run it with the correction in place and show it pass, and show a nearby valid input pass too. Record both outcomes; a test never seen failing proves nothing, a setup failure doesn't show the test catches the mistake, and running the check alone doesn't either.
3. Apply the changed instructions to the originating case: identify the action they now produce and the evidence that it resolves the failure.
4. Apply them to a nearby valid case that must still work. Use isolated fixtures where live side effects are unnecessary. Label instruction replay or simulation accurately; mark unrun checks NOT RUN. A wording match is not behavioral evidence.
5. Inspect the diff for contradictory callers, duplicate rules, private details and unintended files. Fix demonstrated failures, then rerun the affected checks.

**Result:** named checks and outcomes for the original failure and counterexample, including each new check's test failing on its assertion about the reproduced mistake against the unfixed behavior, then passing with the correction and on a nearby valid input, with any limitation explicit.

## Step 7: Show the diff and hand off

1. List the edit worktree’s changed files, then show this learning’s tracked diff (including staged changes):
   ```bash
   git -C <edit-worktree> status --short
   git -C <edit-worktree> diff HEAD --stat -- <learning-paths>
   git -C <edit-worktree> diff HEAD -- <learning-paths>
   ```
   Show the full contents of each untracked file belonging to this learning too; Git diff omits them. Identify unrelated dirty files without including their contents in the handoff.
2. Report the lesson, authoritative source, edit worktree, changed behavior, checks and remaining limitations. If nothing changed, explain the no-op with its evidence.
3. Leave the changes uncommitted by default. If publishing was separately authorized, follow that repository’s review and merge rules. Successful learning checks do not grant merge permission.
4. State whether guidance is only edited, merged or installed. Existing symlinks read the released source on the next skill load. Link a new skill only after merge, using the installer from the main checkout; never repoint installed links to an unmerged worktree. Report stale copied installs rather than overwriting them.

**Result:** a reviewable diff or evidenced no-op, with the source and release state unambiguous. End this invocation here.

## Note mode

Record one lesson for later batch review. This mode edits no catalog and creates no worktree, commit or PR.

1. Read `references/inbox.md`. Resolve the inbox it describes. If none is named or it lies inside a catalog or public repository, report that and write nothing.
2. Fill the record from the conversation using Step 2's fields and rule. Name the owning skill and decision from what the conversation shows; do not run Step 1. If there is no demonstrated observation or outcome ("the skill seemed odd"), ask for it; if the user has none, write nothing. If only the cause is missing, write the record with Cause `unestablished`.
3. Check the inbox for an open record on the same skill and decision. Write the new record anyway and cite the earlier one in `Related`.
4. Write exactly one new file, then report its name.

**Result:** one `open` record, or a stated reason nothing was written.

## Review mode

Examine recorded lessons as a batch and apply the approved set in one worktree. Steps 1-7 keep their rules; this mode sequences them.

1. **Load.** Read `references/inbox.md` and every `open` and `applied` record. Skip `shipped` and `closed`. If none, report nothing to review and stop.
2. **Reconcile applied records** with the status table: resolve each record's skill to its owning catalog (Step 1), check the record in the table's order, and compute its proposed move to `shipped` or back to `open`, quoting the evidence. First check every listed change in `Applied` (each edited text present, or removed text or file absent; see `inbox.md`) on that catalog's default branch after a fetch: if every one holds, the record is `shipped` regardless of its worktree or PR (the default branch wins over an open PR). A partial landing is not `shipped`: name each missing change in the summary. Only if any does not hold, find the PR (recorded, or by the recorded branch): if one exists, its state decides and the worktree is not consulted (open and holding every listed change leaves it `applied`; closed, merged, or open without every listed change reopens it). If no PR exists, the worktree decides: present and holding every listed change leaves it `applied`; confirmed gone (`git worktree list` no longer shows it and the path does not exist) or missing any listed change reopens it. Check each listed change in the PR's head or the worktree's own files, never borrowing a default-branch hold: a PR or worktree that removes a change already on the default branch does not hold it. Leave a still-live one `applied`. An `applied` record is unverifiable when its `Applied` field is empty or incomplete (no file-and-change entry at all, or a listed file without its recorded change), or an access failure (fetch fails, `gh` unreachable, permission error) stops a check; a worktree confirmed gone is not an access failure. Report it in the summary with the question (return it to `open`, or supply the missing reference); never guess. Investigation may fetch remotes and read PRs; "write nothing" means no record or catalog writes. Every proposed record change goes in the summary of the **Summarize and ask** step and is written only in the **Record** step, after approval (no answer means nothing is written).
3. **Group** open records, including records reconcile proposes to reopen on evidence (they join this review's grouping and investigation as `open`), by owning skill and decision, not by date or file name. A record without a demonstrated cause joins its group as unestablished or stands alone.
4. **Investigate each group.** First run Step 1 for every group: resolve the lesson's skill to its owning catalog and source. One apply batch covers one catalog; lessons owned by another catalog are proposed as a separate batch to be applied in that catalog's worktree, never edited in this one. Then run Steps 2 and 3: establish cause from the records' Evidence, route by the Step 3 table, and search for duplicates and in-flight fixes. Order by recurrence and severity: recurrence ranks, it never proves. A group with no demonstrated cause gets no proposed edit; the summary says what to watch for next time. A record routed outside the catalog (project convention, personal preference) gets a proposal for its destination, edited only if the request authorizes it. Propose closing a record only on the table's evidence; non-recurrence is not evidence. Propose `Related` updates the same way. When Step 3 finds a fix pending in another open change, propose setting `Pending` to that change or PR reference; the record stays `open`. These are proposals: nothing is written yet.
5. **Summarize and ask.** Before any worktree, edit or record write, show the patterns, the skills with the most open lessons, every proposed record change (moves from the **Reconcile applied records** step, reopenings, answers to unverifiable-record questions, closures with their evidence, `Related` and `Pending` updates), and a numbered, ranked list of proposed edits grouped by catalog, each with its evidence, its records and its Step 5.1 answer: the check and the test that fails on the mistake, or instruction text with the reason no check applies. Stop for approval. No answer means no edit and no record write. Only approved items proceed; the rest stay unchanged.
6. **Apply.** Apply one batch per catalog, one after another after approval, each in its own worktree created from that catalog's default branch (Step 4); a batch the user did not approve leaves its records unchanged. Make the approved edits (Step 5), each with exactly the remedy approved in the summary; if Step 5.1 now gives a different answer, stop that edit and ask again. Run Step 6 for each edit: its originating records and a nearby valid case. If the approved set holds only record changes and no catalog edits, create no worktree and go to the next step.
7. **Record.** This is the only step that writes records. Write every approved record change: reconcile moves (including `applied` to `shipped`), reopenings (the reason goes on one `Reopened:` line after the existing `Applied` entries, never replacing them or written as an entry), answers to unverifiable-record questions (a record returned to `open` is grouped in the next review, not this one), closures (evidence in `Closed`), and `Related` and `Pending` updates. Move each record covered by this run's own catalog edits to `applied`, writing repository and branch, worktree path or PR, and every file of the approved remedy with its own recorded change, one indented `` - `<file>`: `<change>` `` line per change as `inbox.md` shows (a guard and its test are two entries; a file with several changes gets one line for each). When the record already lists entries (a reopened partial landing), keep every entry of the original remedy that is still required and add the new edit beside them; drop or replace an entry only when the approved remedy explicitly supersedes it. This run's own edits never move a record to `shipped`. A lesson whose authorized fix landed outside the catalog (project instructions, the user's memory) never becomes `applied`: close it here, with evidence from reading that destination in `Closed`, under the same approval.
8. **Hand off** as Step 7 does: one diff per catalog edited and a report, plus the inbox changes. Commit, push and PR need separate authority; opening a PR does not make a record `shipped`.

**Result:** a ranked summary, one reviewable diff per catalog edited, and records whose statuses match checked evidence. End this invocation here.

## Example: An underspecified learning procedure

Request: “Use learn: the skill lists principles but leaves the agent guessing what to do next.”

1. Resolve the loaded skill to its source catalog and read its authoring instructions.
2. Record the observed ambiguity, the missing sequence, the requested ordered procedure and the user’s correction as evidence.
3. Choose the procedure in `learn` as the owner. Check whether that rewrite already exists or is pending.
4. Prepare an isolated worktree and read the current procedure.
5. Rewrite it as ordered actions with a result at each step, preserving source discovery, privacy and authorization boundaries.
6. Replay this request through the new sequence. As a counterexample, replay a correction already fixed in an open PR: it must produce an evidenced no-op instead of another edit.
7. Show the diff, checks and worktree path; leave the edit uncommitted unless publishing was separately requested.

## Gotchas

- A workaround is not automatically a permanent rule. Verify its cause and preserve the legitimate alternative case.
- A pending fix is not released. Identify its state rather than claiming future sessions are already fixed.
- If the agent had the right instruction and ignored it, clarify only a demonstrated ambiguity or report that no catalog change is justified.
- A lesson recorded more than once is a priority, not a proof. Without a demonstrated cause it stays open.
- Note mode and review mode never write inbox contents or paths into the catalog.
- Editing the correct source and activating it are different outcomes. Report both precisely.

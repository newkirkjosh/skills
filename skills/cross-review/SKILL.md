---
name: cross-review
description: "Explicit-use only — invoke when the user explicitly names this skill, or when an active explicitly invoked workflow calls it. Read-only review by the other model family (Codex when Claude wrote the work, Claude when Codex did) of a committed change or a draft document, plus triage of hosted review findings: scope and materiality, dispositions kept in a review ledger, related-instance searches, convergence and verified convention learning. Returns the reviewed SHA or digest, coverage, dispositions, unresolved blockers and where the evidence is."
license: MIT
metadata:
  type: flexible
---

# Cross-review

One review procedure for a change, a hosted review's findings, or a decision document. The reviewer is the model family that did not write the work: Codex when you run on Claude Code, Claude when you run on Codex.

**Explicit use only.** It reviews and returns a result. It never edits the reviewed work, commits, posts, replies to or resolves threads, pushes or merges, and it starts no other reviewers. The caller (`dev`, `ship`, `discovery`, or the user) applies fixes and does every service write. Its rules end when it returns the result.

## Modes

| Mode | Input | Reviewed version |
|---|---|---|
| Change | worktree, base ref, committed changes | head SHA from the script's header line |
| Document | one draft file, committed or not | sha256 content digest from the header line |
| Hosted triage | findings the caller fetched (via `github`) with source URLs, and the PR head | the head SHA the findings were read on |

Hosted triage assesses findings another reviewer already made; it runs no model and never claims a cross-model pass happened. A change still needs change mode for a cross-model result.

## Procedure

Read `references/review-continuity.md` first: its ledger, related-instance search and convention rules apply in every mode.

1. **Load the ledger** for this repository and branch, the same key before and after the PR exists (for a document, its path). Missing means a first pass.
2. **Write the prompt file** in scratch space: the caller's scope verbatim as OUT OF SCOPE / IN SCOPE (a Scope Brief when one exists), then "Report only blocking findings: correctness, security, data loss, or a story in `specs/stories.md` (or a stated requirement, when there is no change folder) the work doesn't meet. Rank them, give file and line, and say why each blocks. Report nothing else." Add the ledger text, including open findings and the evidence and fix SHAs behind earlier dispositions: a scratch-file path alone is not readable by every reviewer. For a document, add what decision it supports and what would change it.
3. **Run the reviewer** (change and document modes) as a long command, logging to scratch space. `<skill-dir>` is this skill's real directory:
   - change: `bash <skill-dir>/scripts/cross-review.sh <codex|claude> <worktree> <base-ref> <prompt-file> > <log> 2>&1`
   - document: `bash <skill-dir>/scripts/cross-review.sh <codex|claude> --document <file> <prompt-file> > <log> 2>&1`

   The last line is `STATUS=COMPLETED` or `STATUS=ERROR`; a log without one is still running. Never poll it and never put a timeout on it: a real review takes many minutes and prints nothing until it finishes. Wait the way the host does (the host adapters reference in `dev`). The script reviews committed changes only, so an uncommitted fix is never reviewed; it refuses a worktree with uncommitted or untracked files, since the reviewer would read them as part of the head SHA, and reports `STATUS=ERROR` if the worktree changes while it runs.
4. **Triage** each finding against the scope and current code. Blocking and in scope: open, for the caller to fix. Out of scope: recorded with the exclusion that covers it. Wrong premise or immaterial: rejected with evidence. Then run the related-instance search for each accepted defect. Record everything in the ledger.
5. **Return the result** (below). The caller fixes the open findings in one batch, commits them (for a change) or edits the draft (for a document), and asks again for the next pass, with the ledger.

**Convergence.** A pass converges when its triage and the ledger leave no unresolved blocker. A repeated settled finding without new evidence is recorded but doesn't block; a quiet pass never erases an earlier open finding. After three passes with blockers left, return them for the user; don't start a fourth. The limit is per review round. A round runs from its first pass until it converges, and its fix batches stay inside it: a pass after a fix batch is the round's next pass, not a new round. A new round starts only after the previous one converged (a later delta review after re-evaluation or a hosted fix batch) or when the user authorizes one. The pass count lives in the ledger and carries across invocations: resuming a round continues its count, it doesn't restart it. Only the user can authorize another round after the limit; record that authorization in the ledger, and the new round gets up to three passes of its own. A fix that changes reviewed behaviour needs review of the delta and whatever depends on it.

**Unavailable.** On `STATUS=ERROR`, fix a setup error the script names and rerun; otherwise record the review as unavailable with its reason. A reviewer that can't run, a rate limit or a skipped required reviewer is unmet coverage, never a pass, and a required review that is unmet blocks autonomous merge.

## Result

Return exactly these five fields, plus the findings:

- **Reviewed:** the SHA (change, hosted triage) or `sha256:<digest>` (document), plus for a change the merge base from the script's `merge_base=` (`ship` reuses a review only on the same base).
- **Coverage:** reviewer, mode, passes run, and what was reviewed; or `unavailable: <reason>`.
- **Dispositions:** each finding's ID and disposition, with evidence.
- **Unresolved blockers:** open in-scope blockers, or none.
- **Evidence:** the ledger location and the final pass's log.

A converged change review is summarized for the caller's record as `Cross-review: <reviewer>, <passes> pass(es), converged at <short-sha>`.

## Gotchas

- **Codex reads `AGENTS.md` only**, not `CLAUDE.md` or `REVIEW.md`. In a repository with a `REVIEW.md`, the review applies its rules only when `AGENTS.md` has a `## Code Review Rules` section pointing at it. If Codex flags something `REVIEW.md` explicitly allows, check whether the pointer exists and whether the rule actually covers the finding; assume neither a missing pointer nor a false premise. Record the evidence and any warranted clarification with the convention procedure in the review-continuity reference.
- **Never call `codex review --base`**: it refuses a prompt alongside `--base`, so it can't carry the scope and reviews work the change deliberately left out. The script passes the range inside the prompt instead.
- **`claude -p` needs the network.** Under a sandbox that blocks it, the review fails with a connection error; the host adapters reference in `dev` says how to escalate safely.
- **A document's digest names a snapshot.** Edits made after the review started are not covered; review the new digest. Keep the review record (summary, reviewer, the converged digest) in the ledger and the caller's report, never in the reviewed file: writing it there changes the digest it names.
- **Codex `-c` keys split on every dot and keep quotes literally.** `mcp_servers."x".enabled` addresses a key named `"x"`, not server `x`, and a server name containing `.` can't be addressed at all. The script uses bare segments, refuses such names, and re-lists the servers under its overrides before running.

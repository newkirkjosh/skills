# Learning inbox

Record format, location rule and status rules for `learn note` and `learn review`. Load this file in both modes.

## Location

The inbox is the learning inbox the global instructions name: a directory outside any catalog or public repository. This skill never states a path.

- No inbox named: report that and write nothing, anywhere.
- The named location resolves inside a Git working tree that is a skill catalog or a public repository (on first use the directory may not exist: check the nearest existing ancestor of the location with `git -C <ancestor> rev-parse --show-toplevel` and the repository's visibility (`gh repo view --json visibility` for a GitHub remote), before creating or writing anything): refuse, report, write nothing. If visibility cannot be determined (no remote, offline), also refuse and write nothing. Records hold private context and a public push would publish them.
- Never copy record contents into the catalog: a catalog edit states the rule, not the record.

## Record

One Markdown file per lesson, named `<YYYY-MM-DD>-<skill>-<short-slug>.md` (the date is the day it was noted; add `-2`, `-3` on a name clash). Never overwrite an existing record.

```markdown
# Lesson <file name without .md>

- Status: open
- Skill: <bare skill name, or "unknown">
- Decision: <the step or decision of that skill, in a few words>
- Date: <YYYY-MM-DD>
- Observed: <what the skill did or failed to do>
- Cause: <the instruction or missing decision, or "unestablished">
- Change: <what the agent should decide differently next time>
- Evidence: <the user correction, outcome or verified capability>
- Source: <where it happened: a short pointer such as a change or PR reference, never a transcript>
- Related: <file names of earlier records this repeats, or empty>
- Pending: <empty unless a fix is pending in another open change: that change or PR reference>
- Applied: <empty until applied: repository and branch, worktree path, PR once one exists>
  - `<file>`: `<recorded change>` (one line per change of the remedy; a file with several changes gets several lines)
- Closed: <empty unless closed: the evidence>
```

`Observed`, `Cause`, `Change` and `Evidence` are Step 2's fields; the same rule holds here: record what the conversation demonstrates, and write `unestablished` for a cause that was not shown. Do not guess to fill a field.

## Status

| Status | Meaning |
|---|---|
| `open` | Captured; no edit covers it yet, or an earlier edit failed. |
| `applied` | An edit addressing it exists in a worktree or PR, not yet on the default branch. |
| `shipped` | Every listed change is on the default branch. Terminal: review skips it. |
| `closed` | No catalog edit is needed. Terminal. |

Every transition needs checked evidence, quoted in the record's `Applied` or `Closed` field. Never assume a state: "probably merged" is not evidence. Elapsed time and non-recurrence are never evidence.

`Applied` lists every change of the approved remedy, one entry per change: a guard and its test are two entries, and a file with several independent changes (an added guard and a removed obsolete line, say) has one entry for each. Write each entry on its own indented line under `Applied`, as `` - `<file>`: `<change>` ``: the file in inline code, then the change in inline code (a longer backtick fence when the text holds a backtick, or a fenced block indented under the entry when it spans lines). A recorded change is the edited text, or for a removal `deleted: ` followed by the removed text in inline code, or `deleted file`. Read one entry per list item: the file is its first code span, the change is everything after the file's `: ` (the code span or block, with its `deleted: ` prefix if any, or `deleted file`), so a `;` or `:` inside the change never splits it. A legacy single-line `Applied` (one file and its change written on the `Applied` line itself, including one written before this rule) is a one-item list. Recognize it by its layout (no indented entries under `Applied`), whether or not it uses code spans, and read its file and change from that line; the first-code-span rule applies only to indented entries.

A recorded change holds in its file when the edited text is present, or the removed text (or the file) is absent. A record holds in a place (the default branch, a PR's head, a worktree) only when every listed change holds there, each judged by its own kind and read in that place itself: at the PR's head commit, or in the worktree's files (committed or not, since the edit is left uncommitted). A change on the default branch never counts as held in a PR or worktree on that basis alone; the PR head or worktree already contains it unless the PR or worktree removed it, and a removal there means it does not hold. A partial landing (some listed changes present, others missing) does not hold: it is never `shipped`, and the review summary names each listed change that is missing.

| From | To | Evidence required |
|---|---|---|
| `open` | `applied` | Repository and branch, the worktree path or PR, and every file of the remedy with its recorded change, written in `Applied`. The branch lets a later review find a PR opened after the record was written (`gh pr list --head <branch> --state all`). |
| `applied` | `shipped` | Every listed change holds on the default branch (`git show <remote>/<default>:<file>` for each listed file after a successful fetch; a deleted file is missing there), whether they landed by PR or otherwise. A merged PR is not required. This check comes first and wins over any worktree or PR state, including an open PR that holds every listed change. |
| `applied` | `open` | The default-branch check succeeded and at least one listed change does NOT hold there, and either a PR exists for the branch and: it closed unmerged, it merged, or it is open but no longer holds every listed change (one reverted, overwritten or dropped); or no PR exists for the branch and the worktree is confirmed gone (`git worktree list` no longer shows it and the path does not exist) or no longer holds every listed change. When a PR exists, the worktree is never consulted. Write why on one `Reopened:` line after the existing entries, naming each missing change in prose (never as an indented entry): reopening never removes or replaces the entries, and a `Reopened:` line is never read as one. |
| `applied` | stays `applied` | At least one listed change does NOT hold on the default branch, and either a PR for the branch is open and holds every listed change, or no PR exists for the branch and the worktree is present and holds every listed change. |
| `applied` | stays `applied`, reported unverifiable | The `Applied` field is empty or incomplete (no file-and-change entry at all, a listed file without its recorded change; an older record without a branch counts as incomplete unless it names a PR), or an access failure (fetch fails, `gh` unreachable, permission error) stops the default-branch check or the check of the worktree or PR. A worktree confirmed gone is not an access failure. Report it in the review summary with the question (return it to `open`, or supply the missing reference); never guess a transition. The answer is written in the Record step like any approved change. A record returned to `open` is grouped in the next review, not the current one. |
| `open` | `closed` | The owner no longer holds the decision (for example the step was removed, shown by reading the skill on the default branch), or the outside destination the record was routed to (a project's instructions, the user's memory) now holds the fix, shown by reading it, or Step 3 finds the exact fix already on the default branch, shown by reading it; for a record that still lists `Applied` entries (a reopened partial landing), the exact fix means every still-required entry holds there, not only the part that fixes the observed behavior. A fix still pending in another change keeps the record `open`, with that change or PR named in `Pending`. |

Order of checks for an `applied` record: (1) the `Applied` field is complete: at least one entry (a valid legacy single-line `Applied` counts as one), and every listed file with its recorded change, else unverifiable; (2) check every listed change on the owning catalog's default branch after a fetch (fetch fails: unverifiable); all holding means `shipped`, stop; (3) only if any does not hold, find the PR (recorded, or by branch); if one exists its state decides, whatever the worktree holds; (4) only if no PR exists, check the worktree, as in the rows above.

Only catalog edits make a record `applied`. A lesson whose authorized fix landed outside the catalog (a project's instructions, the user's memory) is never `applied`: it is closed in the Record step as `closed`, with evidence from reading that destination, under the same approval.

A merged PR alone never makes a record `shipped`, and a missing PR never blocks it; the check of every listed change on the default branch decides.

"Default branch" in every check here (`shipped`, `closed`, reconcile) is the default branch of the catalog that owns the record's skill, resolved by Step 1 of the skill. Checking may fetch remotes and read PRs; only writing a record or the catalog changes state.

## Duplicates

A new note that repeats an open record is still written: recurrence is data. Fill `Related` with the earlier file name. Never drop a note silently.

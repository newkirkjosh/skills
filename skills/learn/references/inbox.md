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
- Applied: <empty until applied: worktree or PR, file, and the recorded change>
- Closed: <empty unless closed: the evidence>
```

`Observed`, `Cause`, `Change` and `Evidence` are Step 2's fields; the same rule holds here: record what the conversation demonstrates, and write `unestablished` for a cause that was not shown. Do not guess to fill a field.

## Status

| Status | Meaning |
|---|---|
| `open` | Captured; no edit covers it yet, or an earlier edit failed. |
| `applied` | An edit addressing it exists in a worktree or PR, not yet on the default branch. |
| `shipped` | The edit is on the default branch. Terminal: review skips it. |
| `closed` | No catalog edit is needed. Terminal. |

Every transition needs checked evidence, quoted in the record's `Applied` or `Closed` field. Never assume a state: "probably merged" is not evidence. Elapsed time and non-recurrence are never evidence.

The recorded change is the edited text, or for a removal `deleted: <the removed text>` or `deleted file`. It holds in a file when the edited text is present, or the removed text (or the file) is absent.

| From | To | Evidence required |
|---|---|---|
| `open` | `applied` | Worktree or PR, file and the recorded change that addresses this record, all three written in `Applied`. |
| `applied` | `shipped` | The recorded change holds in the file on the default branch (`git show <remote>/<default>:<file>` after a successful fetch; a deleted file is missing there), whether it landed by PR or otherwise. A merged PR is not required. This check comes first and wins over any worktree or PR state, including an open PR that holds the change. |
| `applied` | `open` | The default-branch check succeeded and the recorded change does NOT hold there, and any of: PR closed unmerged, even if a worktree still holds the change; PR merged but the change does not hold; worktree confirmed gone (`git worktree list` no longer shows it and the path does not exist) and no open PR; worktree present or PR open but the change no longer holds in it (reverted or overwritten). Write why in `Applied`. |
| `applied` | stays `applied` | The change does NOT hold on the default branch, and either the PR is open and holds the change, or no PR was ever opened and the worktree is present and holds the change. |
| `applied` | stays `applied`, reported unverifiable | The `Applied` field is empty or incomplete, or an access failure (fetch fails, `gh` unreachable, permission error) stops the default-branch check or the check of the worktree or PR. A worktree confirmed gone is not an access failure. Report it in the review summary with the question (return it to `open`, or supply the missing reference); never guess a transition. The answer is written in the Record step like any approved change. A record returned to `open` is grouped in the next review, not the current one. |
| `open` | `closed` | The owner no longer holds the decision (for example the step was removed, shown by reading the skill on the default branch), or the outside destination the record was routed to (a project's instructions, the user's memory) now holds the fix, shown by reading it, or Step 3 finds the exact fix already on the default branch, shown by reading it. A fix still pending in another change keeps the record `open`, with that change or PR named in `Pending`. |

Order of checks for an `applied` record: (1) the `Applied` field is complete, else unverifiable; (2) check the recorded change on the owning catalog's default branch after a fetch (fetch fails: unverifiable); holds means `shipped`, stop; (3) only if it does not hold, check the PR first (closed unmerged reopens the record, whatever the worktree holds), then the worktree, as in the rows above.

Only catalog edits make a record `applied`. A lesson whose authorized fix landed outside the catalog (a project's instructions, the user's memory) is never `applied`: it is closed in the Record step as `closed`, with evidence from reading that destination, under the same approval.

A merged PR alone never makes a record `shipped`, and a missing PR never blocks it; the change check on the default branch decides.

"Default branch" in every check here (`shipped`, `closed`, reconcile) is the default branch of the catalog that owns the record's skill, resolved by Step 1 of the skill. Checking may fetch remotes and read PRs; only writing a record or the catalog changes state.

## Duplicates

A new note that repeats an open record is still written: recurrence is data. Fill `Related` with the earlier file name. Never drop a note silently.

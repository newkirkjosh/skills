# Learning inbox

Record format, location rule and status rules for `learn note` and `learn review`. Load this file in both modes.

## Location

The inbox is the learning inbox the global instructions name: a directory outside any catalog or public repository. This skill never states a path.

- No inbox named: report that and write nothing, anywhere.
- The named location resolves inside a Git working tree that is a skill catalog or a public repository (check with `git -C <dir> rev-parse --show-toplevel` and the repository's visibility): refuse, report, write nothing. Records hold private context and a public push would publish them.
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
- Applied: <empty until applied: worktree or PR, file, and the edited text>
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

| From | To | Evidence required |
|---|---|---|
| `open` | `applied` | Worktree or PR, file and the edited text that addresses this record, all three written in `Applied`. |
| `applied` | `shipped` | The PR is merged (`gh pr view`) and the recorded text is present in the file on the default branch (`git show <remote>/<default>:<file>` after a fetch). |
| `applied` | `open` | Any of: PR closed unmerged; worktree gone and no PR; PR merged but the recorded text is absent from the default branch. Write why in `Applied`. |
| `applied` | stays `applied` | Worktree present or PR open, and the recorded text is present there. |
| `open` | `closed` | The owner no longer holds the decision (for example the step was removed, shown by reading the skill on the default branch), or the outside destination the record was routed to (a project's instructions, the user's memory) now holds the fix, shown by reading it. |

A merged PR alone never makes a record `shipped`; the text check decides.

## Duplicates

A new note that repeats an open record is still written: recurrence is data. Fill `Related` with the earlier file name. Never drop a note silently.

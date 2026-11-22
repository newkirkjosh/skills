# Specs: Batched learning review

## Story 1
When the user corrects how a catalog skill behaved during unrelated work, I want to record the lesson without stopping to edit the catalog, so I can keep working and still keep the evidence.

### Acceptance criteria
- [ ] `learn note` writes exactly one record to the inbox the global instructions name, with skill, date, Observed, Cause, Change, Evidence, a source pointer and status `open`, and makes no catalog edit, worktree or commit.
- [ ] When no inbox location is named, capture reports that and writes nothing.
- [ ] Records never go into the public catalog.

## Story 2
When several lessons have piled up, I want to review them together, so I can see patterns and which skills are weakest before changing anything.

### Acceptance criteria
- [ ] `learn review` reads every open and applied record and groups them by owning skill and decision.
- [ ] Recurrence and severity only order the investigation; each group's cause, owner and duplicates are established with the existing evidence and ownership steps before any edit is proposed.
- [ ] A group with no demonstrated cause stays open with what to watch for; a project, machine or preference lesson is routed outside the catalog; a record closes only with evidence its fix shipped or that the skill or step it concerned no longer exists, never because it didn't recur.
- [ ] The user sees a ranked summary (patterns, weakest skills, proposed edits with evidence) and approves before any edit; approved edits go through the existing edit, verify and handoff steps in one worktree.

## Story 3
When a fix from a review is pending, I want each record to follow it to release, so I can't lose a lesson whose fix stalled.

### Acceptance criteria
- [ ] An applied record names its worktree or PR and the file and edited text that address it.
- [ ] A review marks applied records shipped when the fix is on the catalog's default branch, and returns them to open when the PR closed unmerged, the worktree is gone, or the recorded edit is no longer present.

## Story 4
When a single correction is urgent, I want the existing one-off flow, so I can fix it now.

### Acceptance criteria
- [ ] `learn` invoked on a correction without `note` or `review` runs the existing Steps 1-7 unchanged.

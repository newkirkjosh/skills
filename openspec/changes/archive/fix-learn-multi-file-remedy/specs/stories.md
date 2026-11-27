# Specs: Reconcile every file of a multi-file learn remedy

## Story 1
When a review applies a lesson whose approved remedy changes several files (a check and its test), I want the record to list every file and the change for each, so a later review can check all of them.

### Acceptance criteria
- [ ] The `Applied` field format and the Record step write every file of the remedy, each with its recorded change, plus the repository, branch and worktree or PR.
- [ ] A single-change remedy is written and read as a one-item list; a file with several changes gets one entry per change; an older single-line record naming one file and its change still reconciles as one entry.

## Story 2
When a later review reconciles an `applied` record whose remedy landed only partly on the default branch (one file merged, the other reverted or never merged), I want it not to become `shipped`, so the lesson isn't skipped while part of its fix is missing.

### Acceptance criteria
- [ ] `applied` → `shipped` requires every listed change to hold on the default branch.
- [ ] A partial landing follows the existing not-shipped rules for the missing part (the PR or worktree state decides whether it stays `applied` or reopens), and the review summary names which listed change is missing.
- [ ] Review mode's Reconcile applied records step in `SKILL.md` states the same rule as `inbox.md`.

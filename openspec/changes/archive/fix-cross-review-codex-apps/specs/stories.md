# Specs: Keep Codex connected apps away from the reviewer

## Story 1
When a Codex reviewer runs from `cross-review.sh`, I want my connected apps (GitHub, Gmail, Drive, Linear) unavailable to it, so a review can never read or write through them.

### Acceptance criteria
- [ ] Every Codex review, change and document mode, passes `-c features.apps=false`.
- [ ] Before the review starts, the script checks `codex features list` under the reviewer's options and runs only when `apps` reads `false`.
- [ ] The header line reports that apps are off.
- [ ] The user's Codex config is never written, and the Claude reviewer path is unchanged.

## Story 2
When the script can't confirm apps are off, I want it to refuse to run, so a reviewer never starts with app access by mistake.

### Acceptance criteria
- [ ] `apps` still `true` under the overrides refuses (exit 3, `STATUS=ERROR`).
- [ ] A failing `codex features list`, or output with no `apps` row, refuses.

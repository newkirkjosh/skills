# Status

**Write scope:** none. Read only; no sync, commit, push, issue write, cleanup, folder reconstruction or worktree recreation, including for existing changes.

Read `wt list --format=json`, the named PR's state (`gh pr view`), and the `github` skill's `../github/scripts/pr-status.sh` for its current head (resolve the sibling skill from dev's real directory). Report the layer, head, checks and review state, and any missing evidence. A behind open PR gets a suggestion to request sync; a merged PR gets a suggestion to invoke dev for close-out. No PR and no commit for two weeks gets a stale report; leave uncommitted work alone.

Do not enter `lifecycle.md`. Report and stop.

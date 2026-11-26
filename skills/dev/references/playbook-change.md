# Change

**Write scope:** the change worktree and its change folder, then the shared lifecycle's authorized commits, tracker writes and PR. No merge.

For new work only. Read `scope-brief.md`, record `Playbook: change` independently of Path, and show the playbook with the Scope Brief confirmation.

**Phase 0 — Scope Brief and OpenSpec setup**
0. Create the worktree on the first layer's branch (Layer branches in `../SKILL.md`): `wt switch --create <branch> --no-cd` (no issue number is needed; if `wt list` already shows the branch, from an interrupted run, use its worktree instead), and work from its path from here on.
1. Build the Scope Brief from the user's own words. Grep for every file the change will touch to fill **Also update**.
2. Classify the **Path** (`scope-brief.md`). A `spike` removes its still-empty worktree (`wt remove <branch>`) and enters `playbook-investigation.md`; if it contains work, stop and report instead of removing it. Otherwise invoke the `spec-writer` skill, passing the brief: a `bounded` change gets a short design note, an `architectural` one a full `arch-review`, and the user approves an architectural design before Phase 1.
3. Save the brief as `openspec/changes/<feat-name>/scope-brief.md`.
4. Show the user the **Path** with its reason, and the **Interpreted scope**, **Also update** and **Explicitly out of scope** fields, in a few lines, so a wrong reading is caught now.

Then read `lifecycle.md` and run it from its top.

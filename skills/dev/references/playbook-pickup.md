# Pickup

**Write scope:** only the existing change's shared lifecycle after read-only playbook selection; no new reproduction or Phase 0 front end.

Verify the active or archived `openspec/changes/<feat-name>/` is a dev change folder: it holds `scope-brief.md`, or both `proposal.md` and `tasks.md`. Directory name, branch prefix, worktree or PR alone is not proof.

For a verified folder, the Scope Brief's recorded `Playbook: bug-fix` or `Playbook: change` wins over wording and branch prefix. Without that field, choose `bug-fix` only for a `fix/` branch, otherwise `change`. If a recorded field is unsupported or conflicting, stop and report; never silently replace it. Neither selected playbook restarts its front end on pickup.

With a worktree, branch or PR but no verified folder, do not choose a playbook from the prefix yet. Read `lifecycle.md` from its top and let its missing-folder reconstruction row recover the artifacts from commits; the rebuilt brief records `bug-fix` for `fix/`, otherwise `change`. An unrelated directory is missing state for this purpose: preserve its files; stop if reconstruction would overwrite them. If a team re-invocation has no recoverable change state at all, report `TEAM: BLOCKED missing change state` instead of starting new work.

In every recoverable case, read `lifecycle.md` and run from its top, never jump directly to a phase. It alone owns requested re-evaluation, requested sync and the handoff/table procedure, in that order. If the brief is absent in a verified folder, its reconstruction uses the same playbook rule. Keep the selected playbook in the recovered brief; do not change a valid recorded choice.

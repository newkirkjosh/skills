# Preflight

Run before taking anything into scope, after the run lock (`run-state.md`). Any failure: say which check failed and stop, before starting any change.

## Host capabilities

- **Claude Code:** background subagents, a completion notification when one finishes, its output file (to read progress), `TaskStop`, `SendMessage`, and a heartbeat that is actually delivered: start one background command that waits one minute and require its completion notification before going on.
- **Codex:** `spawn_agent`, `wait_agent`, `followup_task`, `close_agent` (finished agents keep their slots until closed, so every close in this skill depends on it), and nested delegation enabled for the installed backend. No live output read is needed.
- **Not interactive** (`claude -p`, `codex exec`, a scheduled job; see Headless sessions in `dev`'s host-adapters reference): stop. `team` v1 needs a session the host can wake.

## Permissions, through the real delegation path

The session's permission mode must not prompt for `dev`'s normal work, and its sandbox must actually allow it. Prove both the way the run will use them:

1. Spawn a disposable **probe coordinator** exactly as a `dev` worker would be started (Session operations in `SKILL.md`). It checks, without changing anything outside a scratch branch:
   - after step 2 returns the scratch worktree's path, `git push --dry-run origin HEAD:refs/heads/team-probe-<random>` from it, then removes that worktree and its branch;
   - `gh pr list --limit 1` and `gh api repos/<owner>/<repo> --jq .permissions.push` (must print `true`);
   - a read of the tracker the repository's `AGENTS.md` names (change folders may not have an `issues.md` yet);
   - that `cross-review`'s script and the other model's CLI start (`--version`).
2. The probe coordinator spawns one **probe role** the way `dev` spawns its roles. The role creates a scratch worktree at the real worktrunk destination (`wt switch --create team-probe-<random> --no-cd`), writes a file in it and in the scratch directory the evaluator uses, lists its available tools, and reports the worktree's path to the coordinator, which uses it and cleans it up.
3. Both report, then stop (on Codex, close) both probes before any change starts. Any failure, a missing tool, or **a permission prompt surfacing during the probe** stops the run: a prompt here means `dev` would block on the same prompt later. A successful role spawn also proves nesting depth on the installed version (some versions defaulted to one layer).

**Unproven until first use, and named in the run's report:** creating and updating a PR, tracker writes, and merge rights under branch rules. No check exists for them that doesn't perform them.

# Preflight

Run before taking anything into scope, after the run lock (`run-state.md`). Any failure: say which check failed and stop, before starting any change.

## Host capabilities

- **Not interactive** (`claude -p`, `codex exec`, a scheduled job; see Headless sessions in `dev`'s host-adapters reference): fail here, before anything below. `team` v1 needs a session the host can wake, and ending a turn in one of these ends the session.
- **Claude Code:** background subagents, a completion notification when one finishes, its output file (to read progress), `TaskStop`, `SendMessage`, and a heartbeat that wakes an ended turn, since supervision depends on it. Check this first, before any probe: start one background `Bash` command, `sleep 60` with the heartbeat's `timeout: 600000`, then **end the turn**, telling the user that preflight is waiting for that wake, and that if nothing has happened after five minutes they should send any message, which cancels the run and releases the lock. Preflight continues only when the command's completion notification starts the next turn. If a user message starts it instead, the wake is unproven: **Stop** the command and fail preflight.
- **Codex:** `spawn_agent`, `wait_agent`, `followup_task`, `close_agent` (finished agents keep their slots until closed, so every close in this skill depends on it), and nested delegation enabled for the installed backend. No live output read is needed.

## Permissions, through the real delegation path

The session's permission mode must not prompt for `dev`'s normal work, and its sandbox must actually allow it. Prove both the way the run will use them:

1. Spawn a disposable **probe coordinator** exactly as a `dev` worker would be started (Session operations in `SKILL.md`). It checks, without changing anything outside a scratch branch:
   - after step 2 returns the scratch worktree's path, `git push --dry-run origin HEAD:refs/heads/team-probe-<random>` from it, then deletes exactly the files the role reported, removes that worktree and its branch without forcing, and confirms all of it is gone;
   - before that cleanup, that a commit signs without a prompt, when the repository signs commits (`git config --get commit.gpgsign` prints `true`, or a branch rule requires signatures): in the scratch worktree, `git commit-tree -S "HEAD^{tree}" -p HEAD -m team-probe` must print a SHA whose `git cat-file commit <sha>` has a `gpgsig` header (`-S` is required: `commit-tree` ignores `commit.gpgsign`). It writes an unreferenced commit object and moves no branch, so the cleanup's non-forced branch delete still works. A locked signing agent fails here instead of on `dev`'s first commit, after a change has started;
   - `gh pr list --limit 1` and `gh api repos/<owner>/<repo> --jq .permissions.push` (must print `true`);
   - a read of the tracker the repository's `AGENTS.md` names (change folders may not have an `issues.md` yet);
   - that `cross-review`'s script is present and parses (`bash -n`), and the other model's CLI starts (`codex --version` or `claude --version`).
2. The probe coordinator spawns one **probe role** the way `dev` spawns its roles. The role creates a scratch worktree at the real worktrunk destination (`wt switch --create team-probe-<random> --no-cd`), writes a file in it and in the scratch directory the evaluator uses, lists its available tools, and reports the worktree's path and the exact files it wrote.
3. Both report, within 10 minutes. Then **Continue** the finished probe coordinator once and require a fresh final message, within another 10 minutes (a missed deadline is a preflight failure): after a merge, `team` depends on resuming a finished worker. Then stop (on Codex, close) both probes before any change starts. Any failure, a missing tool, or **a permission prompt surfacing during the probe** stops the run: a prompt here means `dev` would block on the same prompt later. A successful role spawn also proves nesting depth on the installed version (some versions defaulted to one layer).

**Unproven until first use, and named in the run's report:** creating and updating a PR, tracker writes, and merge rights under branch rules. No check exists for them that doesn't perform them.

# Host adapters

Read this before the first spawn when the coordinator runs on a host other than Claude Code. `dev`'s steps are written as operations; the example syntax in `SKILL.md` is Claude Code's. Adapted from fx/skills `dev/references/host-adapters.md` (see `LICENSE.txt`); the Codex facts there were verified against codex-cli 0.145–0.151 and are not re-verified here. When one turns out wrong, fix this file.

## Operations

| Operation | Claude Code | Codex |
|---|---|---|
| Delegate | `Agent` tool: `subagent_type`, `model` (tier), `prompt`, `run_in_background` | `spawn_agent`: `task_name`, `message`, `fork_turns: "none"`, `model`, `reasoning_effort` |
| Give the delegate its role | The prompt names the role file by absolute path | Same; there is no `Skill` tool, the child reads the file |
| Wait for a delegate | Its completion notification wakes you; never poll | `wait_agent` with a `timeout_ms` (milliseconds) worth several minutes, e.g. `600000`, **before your turn ends** |
| Correct a running delegate | `SendMessage` | `send_message`, or `followup_task` to make it act |
| Run a long command | `Bash` with `run_in_background: true` into a log; read it on the notification | Use the native long-command execution and continuation tools; keep waiting on the returned session until its terminal result |
| Cross-model reviewer (Phase 4) | `codex` | `claude` |
| Instructions the host reads | `CLAUDE.md` (which imports `AGENTS.md`) | `AGENTS.md` only; never `CLAUDE.md` or `REVIEW.md` |
| Skills directory | `~/.claude/skills` | `~/.agents/skills` |

## Codex gotchas

- **Ending your turn kills every live child.** A finished child's answer lands in your context without waking you, and if you stop first the run ends and the child is interrupted mid-task. Always `wait_agent` on outstanding children before replying. This is the opposite of Claude Code, where blocking on a backgrounded agent is the mistake.
- **`fork_turns: "none"` or no tier.** Omitted (or `"all"`), the child forks your whole history and inherits your model and effort, and the host rejects a `model` or `reasoning_effort` override. With `"none"` the child sees only `message`, so the Scope Brief and the role file path go in it verbatim.
- **Tiers map onto model plus effort.** Codex offers fewer general-purpose coding models than three tiers, so: `large` is the stronger model at `high`, `medium` the same model at `medium`, `small` the faster model at `low`. Resolve the names from the host at run time, never from this file.
- **At most three children at once** (four slots including you). A fourth spawn queues silently and looks hung. `dev`'s "at most three agents in flight" already fits.
- **`task_name` takes only lowercase letters, digits and underscores.** `test-author-ui` is rejected; write `test_author_ui`.
- **Delegation must be asked for in words.** Codex suppresses sub-agents unless the instructions explicitly ask for sub-agents or delegation, so when running `dev` under Codex, spawn sub-agents for the three roles as written; a child that should fan out must be told to in its `message`.
- **One shared working directory, no isolation flag.** Every child runs in the same filesystem. `dev` already runs each change in its own worktree; pass that absolute path in every `message` and tell the child to `cd` there on every command.
- **`claude -p` needs the network.** Under a sandbox that blocks it, the Phase 4 cross-review fails with a connection error, not a review. Before escalating, confirm the worktree holds no secrets: the script sends the diff and the Scope Brief to the other model, which can read any file in the worktree. Then run `cross-review.sh` with the host's escalated permission rather than skipping the review.

## Headless sessions

A run is headless when nothing can answer or wake it mid-run: a one-shot `claude -p` or `codex exec`, a scheduled job, or any session whose process ends with its turn. If you can't tell, treat it as headless: waiting in the foreground on an interactive host costs idle time, while ending the turn on a headless one silently skips every gate still ahead.

- **Never end the turn while a wait is outstanding**: a subagent, a review, or a CI or CodeRabbit waiter. Nothing will wake you to read it.
- **Run waiters in the foreground**, inside the host's foreground limit (under 10 minutes for a Claude Code `Bash` call): pass a shorter timeout (for example 7 minutes) to the bounded helpers documented in pr-evidence.md. Set the execution tool's own timeout above the helper budget plus API/collection overhead, within the host limit (for example Claude Code `Bash` `timeout: 600000` for a 7-minute waiter); its default timeout is too short. If the command is killed or returns no verdict, evidence is unavailable and merging stays blocked; never infer PASS. On exit 3, relaunch only within the remaining overall wait budget; carry the returned `wait_after_run` into `WAIT_AFTER_RUN` (including clearing it when empty). Never reset the overall budget; native host wait/monitoring rules override fallback waiters.
- **Spawn subagents in the foreground** (on Claude Code, without `run_in_background`), so the call returns their report.
- **No questions mid-run.** Where the workflow would stop to ask the user, finish everything the question doesn't block, then put the question in the final report.
- **Polling is still forbidden.** Prefer native host monitoring; fallback waiter invocation follows pr-evidence.md.

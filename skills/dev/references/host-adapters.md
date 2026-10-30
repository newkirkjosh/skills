# Host adapters

Read this before the first spawn when the coordinator runs on a host other than Claude Code. `dev`'s steps are written as operations; the example syntax in `SKILL.md` is Claude Code's. Adapted from fx/skills `dev/references/host-adapters.md` (see `LICENSE.txt`); the Codex facts there were verified against codex-cli 0.145–0.151 and are not re-verified here. When one turns out wrong, fix this file.

## Operations

| Operation | Claude Code | Codex |
|---|---|---|
| Delegate | `Agent` tool: `subagent_type`, `model` (tier), `prompt`, `run_in_background` | `spawn_agent`: `task_name`, `message`, `fork_turns: "none"`, `model`, `reasoning_effort` |
| Give the delegate its role | The prompt names the role file by absolute path | Same; there is no `Skill` tool, the child reads the file |
| Wait for a delegate | Its completion notification wakes you; never poll | `wait_agent` with `timeout_ms` in minutes, **before your turn ends** |
| Correct a running delegate | `SendMessage` | `send_message`, or `followup_task` to make it act |
| Run a long command | `Bash` with `run_in_background: true` into a log; read it on the notification | `exec_command` yields after at most 30 s; hand the command to a small-tier child that runs it and reports its `STATUS=` line, and `wait_agent` on that child |
| Cross-model reviewer (Phase 4) | `codex` | `claude` |
| `pr` review set | `pr-review-toolkit` agents | Not installed: the cross-model review is the review set (see `pr`) |
| Instructions the host reads | `CLAUDE.md` (which imports `AGENTS.md`) | `AGENTS.md` only; never `CLAUDE.md` or `REVIEW.md` |
| Skills directory | `~/.claude/skills` | `~/.agents/skills` |

## Codex gotchas

- **Ending your turn kills every live child.** A finished child's answer lands in your context without waking you, and if you stop first the run ends and the child is interrupted mid-task. Always `wait_agent` on outstanding children before replying. This is the opposite of Claude Code, where blocking on a backgrounded agent is the mistake.
- **`fork_turns: "none"` or no tier.** Omitted (or `"all"`), the child forks your whole history and inherits your model and effort, and the host rejects a `model` or `reasoning_effort` override. With `"none"` the child sees only `message`, so the Scope Brief and the role file path go in it verbatim.
- **Tiers map onto model plus effort.** Codex offers fewer general-purpose coding models than three tiers, so: `large` is the stronger model at `high`, `medium` the same model at `medium`, `small` the faster model at `low`. Resolve the names from the host at run time, never from this file.
- **At most three children at once** (four slots including you). A fourth spawn queues silently and looks hung. `dev`'s "at most three agents in flight" already fits; a waiter child counts against it.
- **`task_name` takes only lowercase letters, digits and underscores.** `test-author-ui` is rejected; write `test_author_ui`.
- **Delegation must be asked for in words.** Codex suppresses sub-agents unless the instructions explicitly ask for sub-agents or delegation, so when running `dev` under Codex, spawn sub-agents for the three roles as written; a child that should fan out must be told to in its `message`.
- **One shared working directory, no isolation flag.** Every child runs in the same filesystem. `dev` already runs each change in its own worktree; pass that absolute path in every `message` and tell the child to `cd` there on every command.
- **`claude -p` needs the network.** Under a sandbox that blocks it, the Phase 4 cross-review fails with a connection error, not a review. Run `cross-review.sh` with the host's escalated permission rather than skipping the review.

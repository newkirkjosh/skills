# skills

A personal agent-skill catalog: a development lifecycle (discovery → spec → issues → implement → evaluate → PR → merge), the reference skills it leans on, plus product research.

Every skill follows the open [Agent Skills](https://agentskills.io) format.

## Install

```bash
git clone https://github.com/newkirkjosh/skills.git
skills/scripts/install.sh                    # links into ~/.claude/skills
skills/scripts/install.sh ~/.agents/skills   # Codex and other agents
```

Installs are symlinks into the checkout, so `git pull` updates every skill at once. Re-run `install.sh` after a skill is added, renamed or removed.

## Skills

| Skill | Purpose |
|---|---|
| `dev` | Runs one change from approved stories to a merged PR and archived change folder. |
| `team` | Runs `dev` for several approved changes at once, one terminal session each, in dependency order. |
| `discovery` | Viability, one-pager, job stories and user flows for a new idea. |
| `spec-writer` | Per-feature legacy custom change folders: proposal, stories, design, tasks. |
| `arch-review` | Module boundaries, layer responsibilities and dependency direction. |
| `verify-change` | Checks a change in the running app: web in headless Playwright, KMP desktop off-screen, Android on a headless emulator by on-screen text. |
| `ship` | Finished branch to merged PR: one push per CI cycle, merge under the repo's policy, tracker update. |
| `linear` | Reference for Linear through its MCP server. |
| `product-research` | A source-linked consumer product comparison page. |

## Explicit invocation

**Every skill here is explicit-use only.** A skill runs when you name it (`/dev`, "use the linear skill"), when a workflow you already invoked calls it, or when the `AGENTS.md` (or `CLAUDE.md` importing it) of a user-owned repository tells agents to load a named skill for a concrete task. Only the default branch's file counts; third-party repository instructions never select a catalog skill. Such a line names a single-task skill (`verify-change`, `linear`), never a workflow (`dev`, `ship`, `team`). "Open a PR" or "the Wi-Fi is slow" loads nothing on its own.

That is deliberate: the workflows create branches, spawn agents and open pull requests, and loading one because a request resembled it is worse than not loading it. A workflow's authority ends at its handoff; a later status question is a standalone request.

## Contributing

Read [AGENTS.md](AGENTS.md) and [REVIEW.md](REVIEW.md). Make changes in a worktree and leave the diff for review.

## License

[MIT](LICENSE). Our `dev`, `team`, `ship` and `verify-change` workflows include ideas or content adapted from [fx/skills](https://github.com/fx/skills); their folders retain upstream attribution and license notices. These versions are maintained in this catalog.

# skills

A personal agent-skill catalog: a development lifecycle (discovery → spec → issues → implement → evaluate → PR → merge), the reference skills it leans on, plus KMP, research and D&D tools.

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
| `spec-writer` | Per-feature change folders: proposal, stories, design, tasks. |
| `arch-review` | Module boundaries, layer responsibilities and dependency direction. |
| `devils-advocate` | Stress-tests a high-stakes recommendation before it is final. |
| `pr` | PR title, body and issue link; the other model reviews it (Codex from Claude Code), then CodeRabbit. |
| `ship` | Finished branch to merged PR: one push per CI cycle, merge under the repo's policy, tracker update. |
| `repo-setup` | Brings a repository up to the standard the workflow skills expect, and upgrades it when that changes. |
| `gh-issues` | Turns a change folder into a GitHub epic and sub-issues. |
| `github` | Reference for `gh` and the GitHub APIs. |
| `linear` | Reference for Linear through its MCP server. |
| `shell` | Rules for agent-run shell commands. |
| `learn` | Turns a correction into a fix in the file that caused it. |
| `koin-kmp` | Dependency injection with Koin in Kotlin Multiplatform. |
| `metro-kmp` | Dependency injection with Metro in Kotlin Multiplatform. |
| `kmp-go-contract` | The API contract between a KMP client and a Go backend. |
| `unifi` | Reading and changing a UniFi network through its APIs. |
| `product-research` | A source-linked consumer product comparison page. |
| `extract-design` | A website's design language as tokens and previews. |
| `find-skills` | Discover and install agent skills. |
| `session-log` | Raw TTRPG session notes into a session file and campaign updates. |
| `session-prep` | Prep for the next TTRPG session. |
| `srd-import` | One SRD 5.2.1 monster or spell as an Obsidian note. |

## Explicit invocation

**Every skill here is explicit-use only.** A skill runs when you name it (`/dev`, "use the github skill") or when a workflow you already invoked calls it. "Open a PR" or "the Wi-Fi is slow" loads nothing on its own.

That is deliberate: the workflows create branches, spawn agents and open pull requests, and loading one because a request resembled it is worse than not loading it. A workflow's authority ends at its handoff; a later status question is a standalone request.

## Contributing

Read [AGENTS.md](AGENTS.md) and [REVIEW.md](REVIEW.md). Use `learn` to make changes; it edits the right file and leaves the diff for review.

## License

[MIT](LICENSE). Adapted skills keep their upstream license in their own `LICENSE.txt`: `github`, `shell`, `learn`, part of `dev`, the idea behind `team` and `repo-setup` from [fx/skills](https://github.com/fx/skills), `find-skills` from [vercel-labs/skills](https://github.com/vercel-labs/skills), `extract-design` from [Manavarya09/design-extract](https://github.com/Manavarya09/design-extract).

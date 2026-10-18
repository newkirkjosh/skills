# skills

Personal agent-skill catalog: development workflow, KMP, research tools, and D&D campaign management. Every skill follows the open [Agent Skills](https://agentskills.io) format, so it installs into Claude Code, Codex and other agents through the [`skills`](https://github.com/vercel-labs/skills) CLI.

## Install

```bash
git clone git@github.com:newkirkjosh/skills.git ~/Developer/skills
~/Developer/skills/scripts/install.sh            # links into ~/.claude/skills
~/Developer/skills/scripts/install.sh ~/.agents/skills   # optional: Codex and other agents
```

Installs are symlinks into the checkout, so `git pull` updates every skill at once. Re-run `install.sh` after a skill is added, renamed or deleted.

## Skills

### Development workflow

| Skill | Purpose |
|---|---|
| `product-discovery` | Viability → one-pager → job stories → user flows |
| `architecture-review` | Module boundaries, layer responsibilities and dependency direction |
| `devils-advocate` | Tiered challenge for high-stakes recommendations |
| `openspec` | Per-feature OpenSpec change folders (proposal, specs, design, tasks) |
| `linear` | Linear through its MCP server: resolving teams, labels and states, sub-issues, lifecycle moves; OpenSpec change → Linear issues |
| `github` | GitHub through `gh` and its APIs: head-commit scoping, bounded CI waits, pagination, tokens, visibility. Adapted from [fx/skills](https://github.com/fx/skills) (MIT) |
| `github-issue` | OpenSpec change → GitHub epic and layer sub-issues |
| `pr-workflow` | PR creation, review sequence and merge conventions |
| `development-workflow` | Orchestrates approved stories → merged PR → archived change |
| `shell` | Rules for agent-run shell commands: stop and wait by PID, bounded polls, no prompts, no secrets. Adapted from [fx/skills](https://github.com/fx/skills) (MIT) |
| `learn` | Turns a correction into a fix in the file that caused it: skill, project rules, global CLAUDE.md or memory. Adapted from fx/skills (MIT) |

### KMP

| Skill | Purpose |
|---|---|
| `metro-kmp` | Dependency injection with Metro |
| `koin-kmp` | Dependency injection with Koin |
| `kmp-go-contract` | API contract between a KMP client and a Go backend |

### Tools

| Skill | Purpose |
|---|---|
| `product-research` | Source-linked consumer product comparison page |
| `extract-design` | Extract a website's design language into tokens and previews. From [Manavarya09/design-extract](https://github.com/Manavarya09/design-extract) (MIT) |
| `find-skills` | Discover and install agent skills. Adapted from [vercel-labs/skills](https://github.com/vercel-labs/skills) (MIT) |

### D&D

| Skill | Purpose |
|---|---|
| `session-log` | Raw session notes → structured session file + campaign updates |
| `session-prep` | Fill the Prep half of the next session file (DM or player side) |
| `srd-import` | Import one SRD 5.2.1 monster or spell as an Obsidian note |

## Contributing

Read [AGENTS.md](AGENTS.md).

## License

[MIT](LICENSE). Skills adapted from other catalogs keep their upstream license in their own `LICENSE.txt`.

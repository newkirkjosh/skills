# newkirkjosh/skills

Conventions for writing and changing skills in this catalog. `CLAUDE.md` only imports this file; never add content there.

> **This repository is public.** Read Security and privacy below before every commit.

## Security and privacy

Everything committed is published on push: files, examples, fixtures and commit messages alike. Removing it later means rewriting history and recreating the repo.

Never commit:

- **Credentials**: API keys, tokens, passwords, private keys, `.env` contents.
- **Personal information** about the owner or anyone else: contact details, players' names or backstories.
- **Private projects**: names of private repos or projects, their issue and PR numbers, internal URLs or endpoints.
- **Machine specifics**: hostnames, usernames, absolute home paths, local container names, password manager or signing setup, display and desktop setup.
- **Run notes about other work**: retros, session logs and trial notes belong in that project or in `~/Developer/docs/`, not here. A commit message says what changed in the skill, not which private run prompted it.
- **Campaign and proprietary content**: campaign, NPC and location names, paid module text. SRD 5.2.1 text is fine with its CC-BY-4.0 attribution.

**Point to the detail; don't copy it.** A machine recipe lives in the global CLAUDE.md, a project fact in that project, a personal fact in memory. The skill says "the off-screen display recipe in the global CLAUDE.md", never the recipe.

**Use placeholders**: `owner/repo`, `example.com`, `com.example.app`, `<project>`. Bad examples too: an illustration of a leak is still a leak, and it gets copied.

**Enforced on every commit** by the global git hooks from the dotfiles (`~/.config/git/hooks`), which check repos with `privacy.public=true` (`scripts/install.sh` sets it) against built-in patterns plus `~/.config/git/private-terms`, a local-only list of private terms, one case-insensitive extended regex per line. When a private term turns up in a draft, add it to that list. CI runs `scripts/check-private.sh` (built-in patterns) and a gitleaks secret scan over the full history. Never bypass the hooks with `--no-verify`; fix the text.

## Layout

```
skills/<name>/
├── SKILL.md          # required: frontmatter + instructions
├── references/       # optional: long-form docs the skill reads on demand
├── scripts/          # optional: executable helpers the skill runs
└── assets/           # optional: templates
```

Flat only. Skills install into one shared directory, and the installed name is the leaf directory name, so category folders would add nesting without namespacing anything.

## Naming

- **The directory name is the invocable name**, and the Agent Skills spec requires frontmatter `name` to match it. Keep them identical: lowercase letters, digits and single hyphens, at most 64 characters.
- **Names are bare.** No `newkirkj-` prefix: it costs a keystroke on every invocation and buys nothing.
- **Never take a name a host reserves.** A skill named like a Claude Code built-in command or bundled skill silently replaces it, even when that built-in is disabled. Check the current list at https://code.claude.com/docs/en/commands before adding or renaming a skill. Names to avoid include `review`, `code-review`, `security-review`, `init`, `run`, `debug`, `doctor`, `simplify`, `loop`, `schedule`, `plan`, `upgrade`, `verify`, `workflows`, `workflow-authoring`; the directory name `synced` is reserved outright.
- **Renaming** a skill means `git mv`, update `name:`, then `grep -rn '<old>' skills/` and fix every reference. A dangling reference is invisible until a workflow reaches it.

## Quality Standards

- Every skill passes the Agent Skills spec (https://agentskills.io/specification): `agentskills validate skills/<name>` (`pip install skills-ref`). Only `name`, `description`, `license`, `compatibility`, `metadata` and `allowed-tools` are allowed in frontmatter; anything else goes under `metadata`. Quote a description that contains `: `.
- CI enforces this: `.github/workflows/validate-skills.yml` validates every skill on each push and pull request.
- No references to skills or agents that don't exist. Refer to another skill by its bare name.
- A skill adapted from another catalog keeps that catalog's license notice in the skill folder (`LICENSE.txt`), says so in `license:`, and records the upstream commit under `metadata.upstream` so it can be diffed later.

## Skill Authoring

Skills follow the open Agent Skills format (https://github.com/agentskills/agentskills, spec at https://agentskills.io/specification, guidance under https://agentskills.io/skill-creation/). Before adding or changing a skill:

- **Earn the skill.** It must carry a decision or niche knowledge an agent would get wrong without it. Ask of every line: "would the agent get this wrong without it?" If not, cut it. Project conventions belong in that project's own instructions, not here.
- **Start from real work.** Extract the skill from a task that was actually done: the steps that worked, the corrections made, the facts the agent lacked. Do not generate one from general knowledge.
- **Description.** At most 1024 characters. Says what the skill does and when to use it, phrased as an instruction ("Use when...") about the user's intent, including cases where the user does not name the domain.
- **Body.** Under 500 lines and about 5,000 tokens. Move reference material into `references/`, scripts into `scripts/`, templates into `assets/`, one level deep, and say when to load each file.
- **Content.** Give one default, not a menu of options. Be exact where the task is fragile and explain why where it is not. Keep a gotchas section in `SKILL.md` and add to it whenever an agent has to be corrected.
- **Check it.** Run the validator, then run the skill on a real task and revise once from what happened.

## Install and update

`scripts/install.sh` symlinks every skill into `~/.claude/skills` (pass other directories, such as `~/.agents/skills` for Codex, as arguments). Links point into this checkout, so an edit takes effect on the next skill load: there is no version to bump and nothing to sync.

Re-run it after adding, renaming or deleting a skill. It links new skills and removes links into this catalog that no longer resolve; it never touches a real directory or a link to somewhere else. The dotfiles repo runs it on a fresh machine (`run_onchange_after_install-skills.sh.tmpl`).

Don't use `npx skills add` for this catalog: installing for a single agent copies the folders instead of linking them, so edits stop reaching the installed copy.

## Testing

Before committing:

```bash
for d in skills/*/; do agentskills validate "$d"; done
scripts/check-refs.sh   # bundled files and skill references resolve
scripts/check-private.sh   # no private terms in tracked files
grep -rn '<renamed-skill>' skills/
bash -n scripts/*.sh skills/*/scripts/*.sh 2>/dev/null
```

Then invoke the changed skill in a real session and check that it does what the diff claims.

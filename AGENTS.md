# newkirkjosh/skills

Conventions for writing and changing skills in this catalog. `CLAUDE.md` only imports this file; never add content there. Review rules live in `REVIEW.md`: a rule about writing skills goes here, a rule about reviewing them there.

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

**Scripts are shell by default.** Glue around `gh`, `git`, `curl` and `jq` is bash: no runtime beyond what the skill already needs, readable from `SKILL.md`, and testable by stubbing commands on `PATH`. Use Python only for real parsing or data handling a shell would turn into an awk pile (`srd-import`'s PDF extraction): standard library only, no `pip install`, run with `python3 -I`. A shell script that starts growing parsing logic moves to Python rather than growing further. Don't add a script for something an agent gets right inline.

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

## Explicit invocation

**Every skill here is explicit-use only.** Its description opens with exactly:

```
Explicit-use only — invoke when the user explicitly names this skill, or when an active explicitly invoked workflow calls it.
```

A skill may run only when the user names or invokes it (`/dev`, "use the github skill"), or when an already-active, explicitly invoked workflow calls it by name. Never write a description that auto-triggers on task semantics ("GitHub", "the Wi-Fi is slow", "open a PR"): no trigger-phrase lists, no "even when the user only says", no "auto-triggers", `MUST BE USED` or "automatically invoked". Loose descriptions once turned a status question into a full lifecycle run. `scripts/check-descriptions.sh` enforces this in CI.

**A workflow ends at its handoff.** Its rules apply to the request that invoked it and stop at its documented handoff (a merge-ready report, a stop for the user). A later standalone request (a status query, a branch sync, a PR tweak) is handled directly unless the user invokes the workflow again. Say so in the workflow skill itself, since this file isn't loaded at runtime.

Internal delegation stays valid: `dev` calling `spec-writer`, `linear` or `pr` is part of its active run, and doesn't authorize those skills to load themselves for unrelated requests.

## Host portability

- **Model tiers, never model names.** Request `small`, `medium` or `large` and let the host resolve it; names change, tiers don't.
- **Concrete tool syntax is illustrative.** A Claude Code `Agent tool:` block is fine; say once near its first use that it is an example.
- **No `.claude/` paths** outside prose that is explicitly about Claude Code. Locate the catalog by resolving the skill's own symlink, and machine paths through the global CLAUDE.md.

## Skill Authoring

Skills follow the open Agent Skills format (https://github.com/agentskills/agentskills, spec at https://agentskills.io/specification, guidance under https://agentskills.io/skill-creation/). Before adding or changing a skill:

- **Earn the skill.** It must carry a decision or niche knowledge an agent would get wrong without it. Ask of every line: "would the agent get this wrong without it?" If not, cut it. Project conventions belong in that project's own instructions, not here.
- **Start from real work.** Extract the skill from a task that was actually done: the steps that worked, the corrections made, the facts the agent lacked. Do not generate one from general knowledge.
- **Description.** At most 1024 characters. Opens with the explicit-use sentence (see Explicit invocation), then says what the skill does in one or two sentences. No trigger-phrase lists.
- **Body.** Under 500 lines and about 5,000 tokens. Move reference material into `references/`, scripts into `scripts/`, templates into `assets/`, one level deep, and say when to load each file.
- **Content.** Give one default, not a menu of options. Be exact where the task is fragile and explain why where it is not. Keep a gotchas section in `SKILL.md` and add to it whenever an agent has to be corrected.
- **Check it.** Run the validator, then run the skill on a real task and revise once from what happened.

## Install and update

`scripts/install.sh` symlinks every skill into `~/.claude/skills` (pass other directories, such as `~/.agents/skills` for Codex, as arguments). Links point into this checkout, so an edit takes effect on the next skill load: there is no version to bump and nothing to sync.

Re-run it after adding, renaming or deleting a skill. It links new skills and removes links into this catalog that no longer resolve; it never touches a real directory or a link to somewhere else. The dotfiles repo runs it on a fresh machine (`run_onchange_after_install-skills.sh.tmpl`).

**Change skills in a worktree, not on `main`.** The installed links point at this checkout's `main`, so an edit there changes every running session on its next skill load, mid-task included. Create one with `wt switch --create <type>/<change> --no-cd` (worktrunk), test a changed skill by pointing the session at the worktree copy's path, and merge to `main` to release it.

Don't use `npx skills add` for this catalog: it installs copies, not links to the checkout. With `-g` it copies each skill into `~/.agents/skills` and links agents to that copy; without it, it installs into the current project instead. Either way, edits in the checkout never reach the installed skills.

## Review

CodeRabbit reviews every pull request against `REVIEW.md` (`.coderabbit.yaml`). Settle each of its comments before merging: fix it, or reply with why it doesn't apply and resolve the thread.

## Testing

Before committing:

```bash
for d in skills/*/; do agentskills validate "$d"; done
scripts/check-descriptions.sh   # explicit-use descriptions
scripts/check-refs.sh   # bundled files and skill references resolve
scripts/check-private.sh   # no private terms in tracked files
grep -rn '<renamed-skill>' skills/
bash -n scripts/*.sh skills/*/scripts/*.sh 2>/dev/null
for t in skills/*/scripts/test-*.sh; do bash "$t"; done   # bundled script tests
```

A skill that bundles shell scripts with any logic (secret handling, guards, argument checks) ships a `scripts/test-<name>.sh` beside them: stub external commands on `PATH`, need no network, exit non-zero on failure. CI runs every `skills/*/scripts/test-*.sh`.

Then invoke the changed skill in a real session and check that it does what the diff claims.

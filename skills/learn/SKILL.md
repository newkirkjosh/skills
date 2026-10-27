---
name: learn
description: "Explicit-use only — invoke when the user explicitly names this skill, or when an active explicitly invoked workflow calls it. Turns a correction from this conversation into a durable fix in the file that caused the behavior (a skill in the personal catalog, a project's AGENTS.md or rules, the global CLAUDE.md, or memory) and leaves the change uncommitted for review."
license: MIT (adapted from fx/skills by Marian Rudzynski; see LICENSE.txt)
metadata:
  upstream: "https://github.com/fx/skills/tree/4b1010d/skills/learn"
---

# Learn

> **Paths.** `<catalog>` is this catalog's checkout: resolve this skill's own directory with `readlink -f` and take `git -C <that dir> rev-parse --show-toplevel`. Where the global instructions, their source and any vault rules live on this machine is in the global CLAUDE.md; read it there, never guess.

A correction is only learned when the file that produced the behavior changes. A note in the wrong place reports success and changes nothing: the next session reads the same instruction and repeats the mistake.

## Step 1: Pin down the learning

From the conversation, state in one line each:

1. **What went wrong**: the behavior, quoted from the transcript where possible.
2. **What should happen instead**: in the user's words.
3. **Where it came from**: the instruction that produced it, or the gap where one was missing. Search before guessing: `grep -rn '<key phrase>' <catalog>/skills <global CLAUDE.md> <repo>/AGENTS.md <repo>/.claude/rules`.

If you can't find the source, say so and ask. Don't invent a home for it.

## Step 2: Route it

First match wins.

| The learning is about… | Edit | Why there |
|---|---|---|
| How a personal skill behaves (a missed step, a wrong default, an ambiguous instruction) | That skill in `<catalog>/skills/<name>/` | The skill is what loaded; anything else is overridden by it next time |
| One project's conventions (layout, naming, test style, a domain fact) | That repo's `AGENTS.md`, or a path-scoped file in its `.claude/rules/` | Loads only where it applies; skills stay project-neutral |
| A notes vault (formatting, campaign canon, note conventions) | The vault's own rules folder or the campaign's `CLAUDE.md` | Canon of one table never goes in another table's files |
| How the user wants Claude to work everywhere (tone, safety, environment) | The global CLAUDE.md, at its source when a dotfiles manager generates it (the global CLAUDE.md says where) | Editing a generated copy is overwritten on the next apply |
| A fact about the user, a past decision, or something no file governs | A memory file plus its `MEMORY.md` line | Memory is for context, not for instructions a file already owns |
| A skill from someone else's plugin (`superpowers:`, `pr-review-toolkit:`, …) | Don't edit the plugin cache; it is overwritten on update. Put the override in the global CLAUDE.md or the project's rules, and tell the user it could also go upstream | |

Installed skills are symlinks into `<catalog>`. Resolve with `readlink -f` and edit the checkout, never a copy. If a skill turns out not to be a symlink, stop and tell the user: the edit would not reach the repo.

## Step 3: Make the edit

- **Read the target's own rules first.** In `<catalog>` that is `AGENTS.md` (the skill bar, naming, the spec, gotchas sections). In a project, its `AGENTS.md`.
- **The skills catalog is public.** When a learning routes to a skill but part of it is about this machine (container names, display recipes, signing setup) or a private project, split it: the machine or project detail goes in the global CLAUDE.md or that project, and the skill only points there. Run `<catalog>/scripts/check-private.sh` before reporting; the commit hook will block the change anyway.
- **Fix the class, not the instance.** "Never add only the files; update every index that references new files" beats "remember the settings index".
- **One home per rule.** If the rule already exists somewhere and was ignored, sharpen it there instead of adding a second copy. A copied rule drifts, and the stale copy is always the narrower one.
- **Say why.** A rule without its reason gets relaxed by the next editor who can't see the failure it prevents. One clause is enough.
- **Imperative and specific.** "Do X", "Never do Y because Z". In a skill, a correction usually belongs in its **Gotchas** section.
- **Respect "earn the skill".** If the learning is generic advice any model already follows, it doesn't belong in a skill.

## Step 4: Verify

- For a skill: `agentskills validate <catalog>/skills/<name>`, and if you renamed anything, `grep -rn '<old-name>' <catalog>/skills`.
- Show the diff: `git -C <repo> diff` (the vault has no git; show the changed lines instead).

## Step 5: Leave it for review

**Don't commit.** Report:

> Learned: <one line>.
> Edited `<absolute path>` (<why that file>). Review with `git -C <repo> diff` and commit when satisfied.

Always name the resolved path. A learning applied to the wrong file is worse than none, because everyone believes it was fixed.

## Gotchas

- A dirty working tree in the target repo: report what is already uncommitted and ask before adding to it, so the diff stays reviewable.
- A generated global CLAUDE.md: check the dotfiles manager shows no diff for it before editing the source, or you will overwrite a manual change.
- A correction about subagents (what they were told, what they skipped) usually belongs in the role file under `development-workflow/references/`, not in the coordinator's steps.

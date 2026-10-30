---
name: repo-setup
description: "Explicit-use only — invoke when the user explicitly names this skill, or when an active explicitly invoked workflow calls it. Brings a repository up to the standard the workflow skills expect (instruction files, review rules, secret scanning, privacy, the AGENTS.md sections dev reads), and re-run later upgrades it: checks every item, migrates old layouts, asks before each decision, and ships the result as one PR."
license: MIT (adapted from fx/skills fx-setup and fx-upgrade by Marian Rudzynski; see LICENSE.txt)
metadata:
  type: flexible
  upstream: "https://github.com/fx/skills/tree/4b1010d/skills/fx-setup"
---

# Repo Setup

## When to Use

**Explicit use only.** The user names this skill for a repository: a new one, one that predates these conventions, or any time the standard below has changed. Setup and upgrade are the same run: every item is checked, and only what is missing or stale changes.

**The workflow ends at its handoff**: the PR (merged under a Merge policy, otherwise merge-ready) or a report that nothing needed changing. A later request in that repository doesn't inherit its rules.

## The standard

Each item says why it exists; an item a repository can't use is `n/a`, never forced.

| Id | Standard | Why |
|---|---|---|
| `claude-pointer` | `CLAUDE.md` is a file containing only `@AGENTS.md` | One source of instructions for every host; Claude Code reads `CLAUDE.md`, Codex and CodeRabbit read `AGENTS.md`. |
| `agents` | `AGENTS.md` exists | Where project conventions live. |
| `review` | `REVIEW.md` exists, from `assets/REVIEW.md` | Rules for what reviewers should and shouldn't flag, kept apart from rules for writing code. |
| `review-bridge` | `AGENTS.md` has a `## Code Review Rules` section pointing at `REVIEW.md` | Codex reads only `AGENTS.md`; without it the cross-model review never sees the review rules. |
| `copilot-instructions` | No `.github/copilot-instructions.md` | A second copy of the review rules drifts from `REVIEW.md`. |
| `coderabbit` | Public: `.coderabbit.yaml` lists `**/REVIEW.md` (`assets/coderabbit.yaml`). Private: `n/a` | CodeRabbit's defaults skip `REVIEW.md`. Private repositories are reviewed locally by `pr`'s review set. |
| `secrets-ci` | A CI job runs gitleaks on a full-history checkout (`fetch-depth: 0`; `assets/secrets-job.yml`) | Catches what the user's local commit hook can't: web edits, other machines, a skipped hook. |
| `privacy` | Public: `git config privacy.public true` in this clone. Private: `n/a` | Opts the clone into the user's private-term commit check. Local config, so it's set, not committed. |
| `layers`, `tracker`, `pr-conventions`, `merge-policy` | `AGENTS.md` has a heading for each | `dev`, `spec-writer`, `pr`, `ship` and `linear` read them. These are `decide` items: the user supplies the content. |

## Steps

1. **Check.** `bash <skill-dir>/scripts/check-repo.sh <repo>` prints one `<state> <id> <detail>` line per item: `ok`, `missing`, `stale`, `decide` or `n/a`. It is read-only.
2. **Plan.** List each `missing` and `stale` item with the file it adds or changes, and each `decide` item with its question. Read `AGENTS.md` first: a section may exist under another heading (layers named in prose, say); offer to move it under the standard heading rather than adding a duplicate.
3. **Ask once**, in one message: the plan, plus the `decide` questions. Never invent a Merge policy, layer list or tracker. "Leave it" is a valid answer for each; a repository without a Merge policy stops every PR at merge-ready, and one that never runs `dev` needs no layers. Wait for the answer.
4. **Apply** in a worktree on `chore/repo-setup` (`wt switch --create chore/repo-setup --no-cd`), never on the default branch:
   - `missing` items from the assets, with `<placeholders>` in `REVIEW.md` filled from what the repository actually is (read its `AGENTS.md`, CI and code), or left out when there's nothing true to say yet.
   - `stale` items by the migration below.
   - `decide` items exactly as the user answered.
   - `privacy` with `git config privacy.public true` in the main checkout (it is per clone and never committed). Then run `check-private --all` from the user's git hooks directory, if the global instructions name one, and stop on any hit: turning the check on doesn't clean what is already there.
5. **Verify.** Run `check-repo.sh` again: nothing `missing` or `stale` may remain except what the user chose to leave. Run the repository's own local checks.
6. **Ship** with the `ship` skill: one commit (`chore: adopt the repo setup standard`, body listing the items), the repository's labels and board from `AGENTS.md`, CI and CodeRabbit waits, merge only under its Merge policy.

## Migrations

| Id | From | To |
|---|---|---|
| M1 `claude-pointer` | `CLAUDE.md` with its own content | Move every line into `AGENTS.md` (merge into matching sections, never duplicate), then reduce `CLAUDE.md` to `@AGENTS.md`. A symlinked `CLAUDE.md` becomes that file. |
| M2 `copilot-instructions` | `.github/copilot-instructions.md` | Merge its review rules into `REVIEW.md` and its coding rules into `AGENTS.md`, then delete it. |
| M3 `coderabbit` | `.coderabbit.yaml` without `**/REVIEW.md` | Add the pattern under `knowledge_base.code_guidelines.filePatterns` and set `enabled: true` there; keep every other setting. |

Add a row here, and a check in `check-repo.sh` with a test, whenever the standard changes; that is what makes re-running this skill an upgrade.

## Gotchas

- **Never write through a symlink.** If `AGENTS.md`, `REVIEW.md` or `CLAUDE.md` is a symlink, a write lands in its target, possibly another repository. Put it in the step 3 question, saying where it points; with the user's yes, remove the link and write a regular file in its place (copying the target's content first where M1 needs it), never editing through the link. Without a yes, leave that item alone.
- **A secret already in history isn't fixed by adding the scan.** If the new `secrets` job fails on its first run, stop and report the finding to the user: removing it means rotating the secret and rewriting history, which is their call.
- **Private-term clashes.** When a public repository's own name is on the user's private-terms list, `privacy.public` would block every commit. Leave it unset, say so, and note a manual leak check in its `AGENTS.md` instead.
- **gitleaks-action needs a license for organization-owned repositories**; personal repositories are free. For an organization repository, run the gitleaks CLI in the job instead.

# PR Review

Review conventions for this catalog. Reviewers read this file in full; write rules out here rather than pointing to another file, because it is pasted into reviewer prompts as-is.

## What you are reviewing

Each `skills/<name>/SKILL.md` is a prompt document a coding agent reads, not executable code. Review it as instructions: check that a rule is unambiguous, can't be satisfied in a way its author didn't intend, and doesn't contradict another skill. Don't apply code-style expectations to prose.

## Checklist

### Security and privacy (public repository)

- Flag credentials, personal information, private repo or project names and their issue or PR numbers, internal URLs, and machine specifics (hostnames, usernames, absolute home paths, container names, password manager or signing setup, display setup) anywhere: skill bodies, references, scripts, fixtures, commit messages.
- Require placeholders (`owner/repo`, `example.com`, `<project>`), in bad examples too.
- A machine-specific detail belongs in the global CLAUDE.md; the skill points there. Flag a copied recipe.

### Explicit-use descriptions

- Every description opens with exactly: "Explicit-use only — invoke when the user explicitly names this skill, or when an active explicitly invoked workflow calls it." Flag a new or edited description that drops or rewords it.
- Flag auto-trigger phrasing in a description or a "When to Use" section: trigger-phrase lists, "even when the user only says", "auto-triggers", `MUST BE USED`, `MUST BE LOADED`, "automatically invoked", or generic task semantics ("GitHub", "fix", "review").
- A workflow skill states that its rules end at its handoff. Flag a workflow whose rules would carry over to later, unrelated requests.
- Internal delegation (one workflow naming another skill as a step) is valid. Don't flag it.

### Naming

- The directory name and frontmatter `name` match exactly. Flag a mismatch.
- Flag a name that collides with a Claude Code built-in command or bundled skill; the collision silently shadows the built-in.
- A rename updates every cross-reference. Flag an old name still present under `skills/`.

### Host portability

- Flag a hardcoded model name. Skills request a tier (`small`, `medium`, `large`).
- Flag a `.claude/` path outside prose that is explicitly about Claude Code.
- Concrete `Agent tool:` syntax is fine as an illustration when the skill says so near its first use.

### Frontmatter

- Only `name`, `description`, `license`, `compatibility`, `metadata` and `allowed-tools` are allowed; anything else goes under `metadata`.
- An adapted skill keeps the upstream `LICENSE.txt`, names it in `license:`, and pins `metadata.upstream` to a commit.

## Instruction file layout

- `AGENTS.md` holds authoring conventions; `REVIEW.md` holds review conventions. Don't suggest moving rules between them.
- `CLAUDE.md` is intentionally a one-line `@AGENTS.md` import. Don't flag it as empty.

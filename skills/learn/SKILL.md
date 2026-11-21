---
name: learn
description: "Explicit-use only — invoke when the user explicitly names this skill, or when an active explicitly invoked workflow calls it. Turns demonstrated corrections from the current conversation into small, verified improvements to the authoritative skill catalog. Finds the right source and policy owner, avoids duplicate or project-specific rules, and leaves an isolated diff for review."
license: MIT (learning-loop concept adapted from fx/skills by Marian Rudzynski; see LICENSE.txt)
metadata:
  upstream: "https://github.com/fx/skills/tree/3de675e365e6eecbfbf7c89018e15a96d91859de/skills/learn"
---

# Learn

Make a correction survive the next session by fixing the instruction that caused it. Use the conversation’s demonstrated mistake, user correction and verified outcome as evidence. A plausible lesson without evidence is a proposal, not a new rule.

**Explicit use only.** Running this skill authorizes a targeted catalog edit and its local validation. It ends at the diff and report. Committing, pushing, opening a PR, installing or changing other repositories needs authority from the user’s request; this skill supplies none on its own. A later request does not inherit its rules.

## 1. Identify the lesson and its owner

For each requested learning, state the observed failure, its cause, the desired decision and the evidence behind it. Read the relevant earlier messages or artifacts when available; do not invent missing history. If the cause is unresolved, investigate what can be verified and report the remaining question instead of encoding a guess.

Route by what the lesson changes:

| Lesson | Owner |
|---|---|
| A reusable skill decision or missing step | The skill or reference that owns that decision |
| A verified project convention or review misunderstanding | That project’s designated instructions or review rules; `cross-review` already owns convention learning |
| A machine recipe, personal preference or private project fact | The existing machine, memory or project source, outside the public catalog |
| A transient outage, run status or unverified suspicion | The run’s evidence/report; no permanent rule |

For a lesson outside the catalog, name the appropriate destination and the proposed correction. Do not edit it unless the request also authorizes that destination. Do not turn a repo-specific exception into a global prohibition. In particular, learning from a reviewer’s false premise must not weaken a genuine requirement or merge gate.

## 2. Find the authoritative source

Resolve the loaded skill’s own directory through symlinks and locate its Git root; inspect its remote, `AGENTS.md`, status and worktrees. Follow the relevant target skill’s source too: a domain skill may belong to another catalog. Never redirect its fix into this catalog just because this is where `learn` lives.

Edit the source checkout, never a copied install, plugin cache or generated skill bundle. If the source cannot be established, report the candidates and ask for the missing source location; make no speculative write. A symlinked installed entry is evidence of the source, not permission to edit its target on the default branch.

Check the target repository’s own instructions before editing. In this catalog, create a worktree from the default branch for a new learning, or use the explicitly selected change’s worktree. Never edit the default checkout that installed skills point to. Preserve unrelated dirty work; use a fresh worktree instead of resetting, stashing or mixing it into the learning. If the requested change depends on dirty work whose ownership is unclear, stop that edit and explain the dependency.

## 3. Fix the decision once

Search the owning skill and its callers for the failing instruction and equivalent cases. Check existing guidance and in-flight fixes before adding anything: if the correction is already present or pending in another change, identify it and report a no-op rather than duplicating or silently extending that work.

Prefer rewriting or removing an incorrect instruction to appending another warning. Put policy in its owner and mechanics in the applicable reference or helper; update callers only when their contracts change. Keep the condition, required action and reason specific enough to distinguish the failure from a nearby valid case. New prerequisites must reflect a verified capability, not a remembered tool name or CLI version.

Use placeholders in public examples. Keep credentials, personal details, machine paths, private project names and session/run notes out of the patch, its fixtures and commit messages. Extract the general decision without copying the conversation. Preserve required licenses and provenance; a lesson does not authorize importing another catalog wholesale.

## 4. Verify and hand off

Run the target catalog’s required validators and reference/privacy checks, plus the meaningful helper tests when executable behavior changes. Exercise the changed decision on the originating case and one nearby counterexample, using isolated fixtures where live side effects are unnecessary. Report simulated checks as simulated and unrun checks as NOT RUN. A prose-only change still needs a decision check; matching its wording is not behavioral evidence.

Inspect the diff for duplicated rules, contradictory callers, leaked details and unintended files. Show which source tree and files changed, the lesson and evidence, validation results and remaining limitations. Leave the changes uncommitted by default, with the worktree path and command to inspect the diff. If publishing was separately authorized, follow the repository’s review and merge rules; do not treat a successful learning check as merge permission.

Symlink installs read the released source on the next load. A new skill is linked only after merge, using the catalog’s installer from its main checkout. Do not repoint installed links to an unmerged worktree. Report stale copied installs rather than overwriting them.

## Gotchas

- A successful workaround is not automatically the right permanent rule. Verify its cause and preserve the legitimate alternative case.
- A correction already under review is still pending, not released. Name the existing change and its state; do not claim future sessions are fixed yet.
- Do not append a rule for every error. If the agent had the right instruction and ignored it, clarify only the demonstrated ambiguity or report that no catalog change is justified.
- Fixing the source and activating it are different outcomes. Report the edited tree precisely, and distinguish an uncommitted diff from merged, installed guidance.

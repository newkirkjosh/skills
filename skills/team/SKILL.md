---
name: team
description: "Explicit-use only — invoke when the user explicitly names this skill, or when an active explicitly invoked workflow calls it. Runs dev for several approved changes at once: starts one dev session per change in its own terminal tab, orders them by dependency, keeps them moving without the user watching, and reports each PR merged or merge-ready."
license: MIT (idea adapted from fx/skills team by Marian Rudzynski; see LICENSE.txt)
metadata:
  type: flexible
  upstream: "https://github.com/fx/skills/tree/4b1010d/skills/team"
---

# Team

## When to Use

**Explicit use only.** The user names this skill with a set of changes: feat-names, "every approved change in `openspec/changes/`", or a parent issue whose sub-issues map to change folders.

**The workflow ends at its handoff**: the final report, when every change in scope is merged, merge-ready, or stopped with a reason. A later request (a status question, one PR's fix) is handled directly unless the user invokes `team` again.

## What it is

`team` is a launcher and supervisor for `dev`, not a second lifecycle. Each change runs in its **own `dev` session**, in its own terminal tab and worktree, with its own context: `dev` already says a single session juggling several changes runs out of context. `team` writes no code, opens no PRs and merges nothing itself. What it adds is what an unattended batch needs: dependency order, at most three sessions at once, a standing instruction to run without pausing, and someone checking every session so a stall is noticed by `team`, not the user.

## Session operations

`team` needs a terminal workspace manager that runs agent sessions side by side and can do these five things. The user's global instructions name the tool and spell each operation; read them before step 3. If they name none, or the tool can't do one of these, say so and stop: there is no safe substitute.

| Operation | What it must do |
|---|---|
| **Open** | Create a new tab at the repository root without taking the user's focus, and return its pane. |
| **Start** | Start an agent of a given kind, under a name, in that pane, with this session's launch flags so it keeps the same permissions. |
| **Prompt** | Submit a prompt to a named agent and confirm its turn started. |
| **Wait** | Block until a named agent is `idle`, `done` or `blocked` (waiting at an approval or question dialog), with a timeout. |
| **Read** | Return the last lines of a named agent's terminal. |

## Steps

### 1. Scope

1. Resolve the set of changes. Each needs a change folder (`openspec/changes/<feat-name>/` with `scope-brief.md`), and an `architectural` one also needs the user's approval of its design (`dev` Phase 0). A change without either isn't ready: list it in the report as "needs `dev` Phase 0 first" and leave it out, rather than starting a session that will stop to ask.
2. Write the run's brief: the user's request **verbatim**, the changes in scope, and anything they said is out of scope. It goes into every session's prompt beside that change's own `scope-brief.md`.
3. **Do not ask to confirm a clearly scoped request.** "All approved changes", a list of feat-names or a parent issue is the scope; start. Ask only when the scope is genuinely ambiguous or contradictory.

### 2. Order

Build the dependency order from each change's `proposal.md` and `tasks.md` (an explicit "depends on", or a layer that needs another change's code) and from blocking relations on the tracker issues. Two changes that edit the same files run one after the other even without a stated dependency: parallel branches touching one file end in conflicts after the first squash merge. Everything else may run together, **at most three sessions at once**: each one spawns its own subagents, and the user's plan has a session limit.

### 3. Launch

For each change that is unblocked, while fewer than three sessions are live:

1. **Open** a tab labelled with the feat-name.
2. **Start** an agent of this session's own kind (Claude Code or Codex) in it, named `dev-<feat-name>` (lowercase letters, digits and hyphens, at most 32 characters). The cross-model review inside `dev` already brings in the other model.
3. **Prompt** it with:

   ```
   Use the dev skill for <feat-name>, and run it to the end without pausing for confirmation.

   <the run's brief, verbatim>

   This session runs under team, unattended. Stop only for something neither the brief nor the change folder covers: an architectural decision, work outside the scope, a destructive step. Merge only if the repository's Merge policy grants it. End your final message with exactly one line:
   TEAM: DONE <PR URL> merged
   TEAM: DONE <PR URL> merge-ready
   TEAM: BLOCKED <one-sentence reason>
   ```

4. Record it in a ledger in scratch space outside the repository: change, agent name, pane, branch, PR, state, last progress seen and when.

### 4. Supervise

Run one **Wait** per live session, with a 10-minute timeout, as a long command (backgrounded on Claude Code; a waiter child on Codex, per the host adapters reference in `dev`). Each wake is one pass over the ledger. For the session that woke:

| Result | Do |
|---|---|
| Timed out, still working | Check for progress: new commits (`wt list --format=json`), PR state, and a **Read** of its last 40 lines. Something moved: record it and wait again. Nothing moved for two checks in a row (about 20 minutes): report the session to the user with what it last showed, and keep waiting. |
| `blocked` | An approval or question dialog. **Read** it. Never answer it yourself: tell the user what it asks and which tab it's in. |
| `idle` or `done`, ending `TEAM: DONE … merged` | Mark it merged. Start whatever it unblocked (step 3). **Prompt** every other live session that the default branch moved, so its `dev` merges it in and pushes. |
| `idle` or `done`, ending `TEAM: DONE … merge-ready` or `TEAM: BLOCKED` | Record it for the report. Changes that depend on it stay unstarted. |
| `idle` or `done` with no `TEAM:` line | It stopped without finishing. **Prompt** it once: "Continue the dev run for <feat-name>. If you are stopped, end with the TEAM line that says why." If it goes idle again without one, record it as stalled and report it. |

`idle` is not done: a session that ended its turn mid-run looks exactly like one that finished, and only the `TEAM:` line tells them apart. Never treat silence as progress.

**Codex host.** The `dev` sessions live in their own tabs and survive this session's turn ending, but this session's supervision doesn't: on Codex, run each **Wait** through a waiter child and `wait_agent` on it before your turn ends, as the host adapters reference in `dev` describes.

### 5. Report

When nothing is live and nothing more can start, report one row per change: feat-name, PR, `merged` / `merge-ready` / `blocked: <reason>` / `stalled` / `not started: <why>`. Leave the tabs open so the user can read each session; close one only when the user asks.

## Gotchas

- **Never hand one session several changes.** One change per session is the whole design; batching them into one `dev` run is the context blow-up this skill exists to avoid.
- **Start needs a pane at a shell prompt.** A freshly opened tab's pane is one; a pane already running something isn't, and the start fails.
- **Don't answer another session's dialogs.** A `blocked` session is waiting for the user, even when the answer looks obvious.
- **Wave labels never go in PR titles.** Each `dev` session titles its own PR through `pr`; a wave or batch number in a title links the squash commit to an unrelated issue.
- **Merging is still per repository.** `team` grants no merge permission the repository's Merge policy doesn't; without one, every PR stops at merge-ready and the report says so.

# Proposal: dev task-type playbooks
**Change:** feat-dev-playbooks
**Story group:** none (issue #51, owner-approved shape)
**Date:** 2026-11-26

## Scope
Make `/dev` a router over task-type playbooks: read-only `status` and `investigation`, a scratch-only `prototype`, `pickup` for existing state, the full-lifecycle `bug-fix` and `change`, and a `setup` playbook that checks and drafts the `AGENTS.md` sections `dev` reads. The lifecycle phases move into one shared reference, unchanged.

## Rationale
One explicit entry point stays, but a status question, a quick investigation or a bug no longer has to pass through the full-feature front end, and a repository missing what `dev` reads gets a path to supply it, as pstack's `/setup-pstack` does.

## Out of scope
`scripts/dev-state.sh`; any behavioral change to the moved phases; `team` behavior; running `setup` on any repository; PR #52.

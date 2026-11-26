# Tasks: dev task-type playbooks
**Change:** feat-dev-playbooks
**Date:** 2026-11-26

## :catalog
- [x] Move entry detection and Phases 1–6 verbatim into `skills/dev/references/lifecycle.md`; move Phase 0 into `references/playbook-change.md`.
- [x] Write `SKILL.md`'s Routing section (five ordered routes, interrupted-sync paragraph moved from entry detection) and trim `SKILL.md` to the shared rules; move lifecycle-only constraints and gotchas into `lifecycle.md`.
- [x] Write `playbook-bug-fix.md`, `playbook-pickup.md`, `playbook-status.md`, `playbook-investigation.md`, `playbook-prototype.md`, `playbook-setup.md`, each opening with its write scope.
- [x] Add the `Playbook:` field to `references/scope-brief.md`; route `spike` to `investigation`.
- [x] Update the `dev` description and `README.md`'s `dev` row.
- [x] Repoint every caller reference to a moved section (team, merge-gate, spec-writer, github and linear openspec-issues, completion, head-discipline, host-adapters).
- [x] File `scripts/dev-state.sh` as its own issue (#53; verified by the coordinator).

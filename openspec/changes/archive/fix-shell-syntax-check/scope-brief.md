### Scope Brief

- **Playbook:** bug-fix
- **Verbatim request:** "Fix the AGENTS.md Testing command that passes multiple scripts to bash -n, which parses only the first. Run one syntax check per file, show errors, and propagate failure; do not use an echo fallback that masks failure."
- **Interpreted scope:** Correct only the shell syntax-check command in AGENTS.md and verify its documented behavior.
- **Also update:** Lifecycle evidence for this change; no other command copies require changes.
- **Deliverable type:** docs
- **Explicitly out of scope:** Script refactoring, CI changes, installed links and merging; this is a bounded documentation correction.
- **Size signal:** narrow
- **Path:** bounded; one existing documentation command.
- **Known-and-accepted:** Use existing issue #54; no duplicate tracker issue. Cross-model availability must be reported accurately.

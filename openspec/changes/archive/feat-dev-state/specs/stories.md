# Specs: Dev state

## Story 1
When resuming a change, I want its resolved playbook and lifecycle entry step without changing state.

### Acceptance criteria
- [ ] Feat-name, branch and PR inputs resolve verified active or archived state.
- [ ] Recorded playbook wins; legacy fallback applies only to verified state; invalid or conflicting fields stop.
- [ ] Every lifecycle entry row and interrupted sync, team re-evaluation and team sync precedence matches current dev.
- [ ] Missing, ambiguous or unavailable evidence is reported without mutation or a fabricated decision.
- [ ] Offline fixtures stub git, gh and wt and guard against writes.

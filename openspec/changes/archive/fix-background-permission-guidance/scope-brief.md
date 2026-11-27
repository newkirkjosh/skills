### Scope Brief

- **Playbook:** bug-fix
- **Verbatim request:** "Correct team and dev host-adapter guidance for Claude Code background permission requests: observed immediate rejection yields a BLOCKED handoff, not a prompt waiting 30 minutes. Retain waiting-prompt guidance only for hosts where waiting is verified; unknown hosts remain unknown."
- **Interpreted scope:** Correct permission-result handling in team supervision and dev host adapters using issue #38 evidence.
- **Also update:** Adjacent preflight and hold guidance if they contradict the corrected distinction.
- **Deliverable type:** docs
- **Explicitly out of scope:** Permission policy changes, invented host capabilities, merging, installed links and unrelated lifecycle changes.
- **Size signal:** normal
- **Path:** bounded; correct an existing instruction flow.
- **Known-and-accepted:** Issue #38 supplies a failure-injection observation; no waiting host is verified by that evidence. Required cross-model review may be unavailable due to rate limits; record this without claiming convergence.

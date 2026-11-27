# Scenarios

1. Claude Code background ask rejected immediately: preserve the denial reason and report BLOCKED without a 30-minute wait or retry.
2. A host with verified waiting prompts: inform the user, never answer, stop and hold after 30 minutes unanswered.
3. An unverified host: behavior stays unknown; no claim of waiting or rejection.
4. Preflight rejection fails the probe; existing permission policy remains unchanged.

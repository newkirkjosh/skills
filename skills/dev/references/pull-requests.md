# Pull requests and hosted review

Read when `dev` or `ship` is ready to open a PR or settle hosted feedback.

Use the repository's PR template, naming, labels and tracker conventions. Otherwise use a conventional-commit title and a concise body explaining the problem, resulting behavior and actual validation. When a change folder exists, read issue identifiers from its `issues.md`; otherwise use the issue linked by the request or branch context. Include `Closes #<issue>` for GitHub issues. Use `gh` help and API documentation to confirm fields; pass multiline bodies through files and verify writes by reading them back.

Run the cross-model review described in `dev` Phase 4 before opening the PR, or marking a draft ready. Record an unavailable reviewer and its reason; without a required review, hand the merge to the user. Post the final review result (from `cross-review.md` when present) using `gh pr comment --body-file`. Invoking the lifecycle authorizes this review comment on the PR it creates or the existing PR explicitly in scope for that invocation.

Read `references/pr-evidence.md` (relative to dev) for the single merge-evidence contract and read-only status/wait helpers. Read the PR head SHA and collect all review threads, review bodies and checks. Paginate to exhaustion; a failed or incomplete read is unknown, never a clean verdict. Check the configured reviewers have reported on this head; no threads alone does not prove a completed review. Use host-native PR monitoring when available; otherwise use a bounded wait and report pending work at the deadline.

Triage body-only findings as well as inline threads; zero threads is not a clean review. Verify each suggested patch against current code and run relevant checks before accepting it. Replying explains the disposition; resolving changes thread state, so verify both separately.

Check each finding against the request, project rules and current code. Collect blocking fixes into one pass, verify them and push once. Reply to bot threads with the fix commit or the evidence for dismissal, then resolve them; leave human threads to their authors. Re-read all threads to verify resolution. Every fix push needs review of the affected delta and checks on the new SHA. Report the head, review coverage, unresolved feedback and pending checks at handoff.

Follow the repository's merge policy and use squash merge only. This reference grants no merge authority. The workflow ends at its documented handoff; later PR requests are standalone unless the user invokes the workflow again.

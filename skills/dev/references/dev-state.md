# Read-only state inspection

Run from any worktree of the repository being inspected:

```bash
bash <skill-dir>/scripts/dev-state.sh <change|branch|PR-number|PR-URL>
```

The helper prints `Playbook: change|bug-fix|unresolved` and `Step: <entry label>`. It follows `playbook-pickup.md` and `lifecycle.md` in order, including interrupted sync, explicit team requests and handoff precedence. It reports reconstruction without doing it. A missing verified folder leaves the playbook unresolved until reconstruction. A recorded playbook wins over the branch prefix; blank, unsupported or conflicting records stop with a nonzero exit, including fields in Markdown bullets or bold labels. Branch-prefix fallback applies only when the field is absent.

To inspect an explicit team re-invocation, add `--reevaluate-head <full-sha>` or `--sync-pr <number> --expected-head <full-sha> --default-sha <full-sha>`. These only report the selected entry. Re-evaluation takes precedence over sync. A missing worktree is never recreated; sync cleanliness cannot be inspected there until the lifecycle recreates it.

Supply `--ledger <existing-path>` to read the durable review ledger from the location recorded at handoff (`cross-review`'s review-continuity reference). The helper does not assume a machine-specific ledger layout. Missing classifications select Phase 4 steps 4–5. `Phase 5: Completion` means the entry table selected completion; it does not certify merge readiness or converged review.

Requires Bash, Python 3 (standard library), git, gh and wt. It reads local worktrees and branches, PRs, and archived artifacts on the existing `origin/<default>` ref; it never fetches, switches branches, writes artifacts or contacts a tracker to write. Remote refs may be stale. GitHub issue maps using the producer's `layer: number` format or `:layer: #number` are supported; `parent` and `epic` entries do not select a layer. Linear mappings and unavailable or ambiguous evidence fail with a nonzero exit rather than guessing a lifecycle step. The script does not invoke `dev` or authorize lifecycle actions.

Offline fixtures: `bash <skill-dir>/scripts/test-dev-state.sh`.

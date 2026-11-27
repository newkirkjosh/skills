# Read-only state inspection

Run from any worktree of the repository being inspected:

```bash
bash <skill-dir>/scripts/dev-state.sh <change|branch|PR-number|PR-URL>
```

The helper prints `Playbook: change|bug-fix|unresolved` and `Step: <entry label>`. It follows `playbook-pickup.md` and `lifecycle.md` in order, including interrupted sync, explicit team requests and handoff precedence. It reports reconstruction without doing it. A missing verified folder leaves the playbook unresolved until reconstruction. A recorded playbook wins over the branch prefix; blank, unsupported or conflicting records stop with a nonzero exit, including fields in Markdown bullets or bold labels. Branch-prefix fallback applies only when the field is absent.

Results are independent of the invoking subdirectory. The requested branch's worktree and committed artifacts precede artifacts in the invoking checkout. A shared name prefix does not associate sibling changes: layer suffixes must name a declared task layer, and a legacy folder with a different type prefix must have branch or matching-worktree artifacts that differ from what the branch inherited at its merge base with the default ref. Unavailable ancestry stops inspection. An unchanged inherited archive does not establish ownership, even if default later edits it; a squash merge retains the original branch's ownership. Folder input also discovers such verified legacy branches, so its branch-prefix fallback matches branch input. PR discovery ignores fork heads; explicit PR inputs and sync requests require PR URLs and head repository metadata identifying the inspected repository.

To inspect an explicit team re-invocation, add `--reevaluate-head <full-sha>` or `--sync-pr <number> --expected-head <full-sha> --default-sha <full-sha>`. These only report the selected entry. Re-evaluation takes precedence over sync. A missing worktree is never recreated; sync cleanliness cannot be inspected there until the lifecycle recreates it.

For folder input, re-evaluation checks the first open layer unit's branch head. After selecting that unit, its branch or matching worktree supplies the artifacts, ahead of a retained earlier layer's snapshot. Normal entry detection loads that unit before checking handoff and uses its issue map and contracts; a retained earlier layer's handoff cannot preempt it. If the selected branch has no verified snapshot, the existing default-ref artifacts precede the invoking checkout; the earlier layer's artifacts are discarded. A handoff with at most one declared layer needs no issue-map parsing; multiple declared layers require enough mapping evidence to identify their unit. Layers sharing an issue use one branch, with every layer's contract section included in evaluation detection; a missing section starts evaluation and an unchecked section selects the fix or re-evaluation entry.

Supply `--ledger <existing-path>` to read the durable review ledger from the location recorded at handoff (`cross-review`'s review-continuity reference). The helper does not assume a machine-specific ledger layout. Missing classifications select Phase 4 steps 4–5. `Phase 5: Completion` means the entry table selected completion; it does not certify merge readiness or converged review.

Requires Bash, Python 3 (standard library), git, gh and wt. It reads local worktrees and branches, PRs, and archived artifacts on the existing `origin/<default>` ref; it never fetches, switches branches, writes artifacts or contacts a tracker to write. Remote refs may be stale. GitHub issue maps using the producer's `layer: number` format or `:layer: #number` are supported; `parent` and `epic` entries do not select a layer. Linear mappings and unavailable or ambiguous evidence fail with a nonzero exit when issue selection is required rather than guessing a lifecycle step. The script does not invoke `dev` or authorize lifecycle actions.

Offline fixtures: `bash <skill-dir>/scripts/test-dev-state.sh`.

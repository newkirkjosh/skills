# Prototype

**Write scope:** only a throwaway scratch copy outside git and worktrunk. No repository or external-service writes, branch, worktree, issue, commit, push or PR, including for existing changes.

Export the needed committed tree with `git archive <ref>` into a new scratch directory outside every repository and worktree; verify the destination is outside git before writing. Never use `wt` or `git worktree` to create the copy. Do not recreate an existing missing worktree or reconstruct its folder. Uncommitted input is unavailable unless the user supplies it separately.

Label the copy and result **throwaway**. Experiment only in the scratch copy; inspect commands before running them and stop any check whose startup, hooks or background work could write outside it or contact a live service. Report what worked, what failed and what it implies. Do not promote the result into durable code or enter `lifecycle.md`; stop after the report.

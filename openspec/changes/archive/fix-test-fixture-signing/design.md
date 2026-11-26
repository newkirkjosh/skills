# Design note: Keep test fixture commits off the user's signing setup

| Option | For | Against |
|---|---|---|
| A. Export `GIT_CONFIG_GLOBAL=/dev/null` and `GIT_CONFIG_NOSYSTEM=1` at the top of each suite, keeping the exported test identity | One line per suite covers every git call, the stub's commit and the script under test; also drops global hooks and other surprises | The script under test also runs without the user's config, which is what a hermetic test wants |
| B. `-c commit.gpgsign=false` on each commit (as `test-install.sh` does) | Narrow | Easy to miss on a new commit (the stub's commit); leaves global hooks and other global settings in play |
| C. Per-repo `git config commit.gpgsign false` after `git init` | Scoped to the fixture repo | Still reads global hooks and other global config; each new repo needs it |

**Choice:** A.

**Sacrifices:** none for the tests; a suite can no longer observe the user's own git config, which no test needs.

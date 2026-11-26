### Scope Brief

- **Verbatim request:** "/dev https://github.com/newkirkjosh/skills/issues/47". Earlier, on the test suites that failed while the signing agent was locked: "Yeah I don't think it is smart to have tests that rely on my [signing agent, redacted] right? I can't be here every time the testing suites run"
- **Interpreted scope:** Make the throwaway git repositories in `skills/cross-review/scripts/test-cross-review.sh` and `skills/dev/scripts/test-eval-export.sh` independent of the user's global and system git config, so no fixture commit signs, runs a global hook, or needs a configured identity. Each suite gets a regression check that fails if a fixture commit would try to sign. Issue #47's acceptance: both suites pass with `commit.gpgsign=true` set globally and a failing signing program.
- **Also update:** the stub's `STUB_COMMIT` commit in `test-cross-review.sh` (it runs in the same environment); the usage/header comments of both suites if they describe the environment.
- **Deliverable type:** code (test scripts)
- **Explicitly out of scope:** `cross-review.sh` and `eval-export.sh` themselves (they make no commits; the fix is in the tests); `scripts/test-install.sh` (already passes `-c commit.gpgsign=false` with a fixed identity); CI workflows; real commits made by `dev`/`team` agents, which stay signed by design.
- **Size signal:** normal
- **Path:** bounded, an environment fix in two existing test scripts.
- **Known-and-accepted:** `test-cross-review.sh` is a Merge-policy-reserved path, so the PR stops at merge-ready for the user to merge.

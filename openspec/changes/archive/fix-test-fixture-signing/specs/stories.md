# Specs: Keep test fixture commits off the user's signing setup

## Story 1
When I run the catalog's script tests on a machine whose global git config signs every commit and the signing agent is locked or missing, I want the suites to pass anyway, so I can leave test runs to unattended agents.

### Acceptance criteria
- [ ] `bash skills/cross-review/scripts/test-cross-review.sh` passes with no failures when the global config sets `commit.gpgsign=true` and a signing program that always fails.
- [ ] `bash skills/dev/scripts/test-eval-export.sh` passes under the same config.
- [ ] Neither suite prompts for or invokes the signing program, and neither runs the user's global git hooks.

## Story 2 (regression guard)
When a later edit to a suite reintroduces a dependency on the user's git config, I want the suite itself to fail, so the regression is caught before it reaches an unattended run.

### Acceptance criteria
- [ ] Each suite has a check that fails if its fixture commits carry a signature or would read the user's global config.

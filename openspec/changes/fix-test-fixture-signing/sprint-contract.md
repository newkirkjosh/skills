# Sprint Contract: Isolate test fixture commits
**Change:** fix-test-fixture-signing
**Derived from:** specs/stories.md

## :catalog
Evaluated at: fdd5638176deee3f59e40041c7cbe393ab0854b4
Evaluator: fresh isolated Codex agent evaluate_fixture, history-free exports, VERDICT: PASS.
Cross-review: unavailable for the final delta; Claude reviewer rate limit interrupted this run before the provider handoff. Earlier Codex review found X-1, now fixed and independently evaluated. Final cross-model coverage remains unmet.

- [x] Cross-review suite passes with hostile global/system signing configuration: 111 passed, 0 failed.
- [x] Eval-export suite passes under the same configuration: 12 passed, 0 failed.
- [x] Instrumented failing signer and global pre-commit hook record zero invocations.
- [x] Fixtures need no configured identity; hostile config supplies none and inherited identity variables were removed.
- [x] Removing global isolation independently fails both suites: cross-review 72 passed/39 failed, eval-export 6 passed/6 failed, both exit 1.
- [x] Removing system isolation independently fails both suites with the same counts and exit 1.
- [x] Both suites assert fixture commits are unsigned.
- [x] The stub commit lands as `moved` and remains unsigned.
- [x] Both suite headers explain the isolated environment.

Additional evaluator checks: all 11 skill validations, shell syntax, descriptions, references, installer, PR evidence and verify-change checks pass (verify-change: 102 passed, 0 failed). Coordinator independently ran all catalog script suites and privacy checks successfully.

Unmet merge gate: final cross-model re-review. No merge-ready claim is made.

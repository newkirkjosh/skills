# Sprint Contract: patch-id as rebase evidence
**Change:** feat-patch-id-evidence
**Date:** 2026-11-26
**Derived from:** specs/stories.md

## :catalog
Evaluated at: 1e813034a8dd9e85da45ac5c3b1728da2927e063
Cross-review: codex, 4 pass(es) in 2 rounds, converged at 163e778

- [x] The review-continuity reference tells the coordinator to compare `git patch-id --stable` of the original and new commits and record both SHAs and the patch-id. A match also needs `git patch-id --verbatim` to match, since `--stable` ignores whitespace (CodeRabbit CR-1, Codex X-2). Observed: `skills/cross-review/references/review-continuity.md` per-finding Evidence bullet (amend/rebase rule) and Commit classification (every rewritten classified commit).
- [x] A match is evidence that the diff is unchanged; classification still follows the commit's actual effect. Observed: the Evidence bullet ("a match is evidence only") and Commit classification ("backs carrying its classification over, but never decides it").
- [x] A mismatch means the diff is verified again, as today. Observed: the Evidence bullet ("verifying the diff again") and Commit classification ("classifying the new commit again from its diff").
- [x] A merge commit has no patch-id and keeps the existing sync rule. Observed: Commit classification; scratch repo: a `--no-ff` merge commit gave no patch-id.
- [x] Also update: `completion.md` left unchanged; its caller gate needs no pointer. Observed: base and head copies identical.
- [x] Out of scope respected: no script, `team` or merge-gate change. Observed: the base/head diff touches only `review-continuity.md` and the change folder.
- [x] The patch-id claims hold in practice. Evaluator scratch repo (no signing, hooks or global config): a commit rebased onto a moved base kept its patch-id under `--stable` and `--verbatim`; lines `a b` and `ab` share a `--stable` ID but differ under `--verbatim`; a merge commit gives no patch-id.
- [x] Repository checks pass. Evaluator run: `agentskills validate skills/cross-review`, `check-descriptions.sh`, `check-refs.sh`, each rc=0; `check-private.sh` rc=0 on a git-indexed copy of the head export.

Evidence: evaluator run a07b1bc1d32579288 returned INCOMPLETE (only `check-private.sh` unrun: the export has no git index); fresh evaluator run a6bcaa3ad6d578674 on the head export, with a coordinator-supplied git-indexed copy, returned PASS at 3a361bd. After the cross-review fix X-1 (66973c4), fresh evaluator run a761bbf661c5ef186 re-evaluated at 66973c4: PASS. After the CodeRabbit fix CR-1 (484ed90), fresh evaluator run a512212340a106218 re-evaluated at 484ed90: PASS. After the Codex fix X-2 (1e81303), fresh evaluator run aad6e2d93ab41ff11 re-evaluated the head export at the SHA above, with a git-indexed copy for check-private: PASS. Test author a78366e6bfc91e826 supplied grep and scratch-repo checks only (docs change; the brief excludes scripts).

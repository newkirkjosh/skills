# Sprint Contract: patch-id as rebase evidence
**Change:** feat-patch-id-evidence
**Date:** 2026-11-26
**Derived from:** specs/stories.md

## :catalog
Evaluated at: 66973c4f4cc334ebc342754753d35dc045585b22

- [x] The review-continuity reference tells the coordinator to compare `git patch-id --stable` of the original and new commits and record both SHAs and the patch-id. Observed: `skills/cross-review/references/review-continuity.md` per-finding Evidence bullet (amend/rebase rule) and Commit classification (every rewritten classified commit).
- [x] A match is evidence that the diff is unchanged; classification still follows the commit's actual effect. Observed: the Evidence bullet ("a match is evidence only") and Commit classification ("backs carrying its classification over, but never decides it").
- [x] A mismatch means the diff is verified again, as today. Observed: the Evidence bullet ("verifying the diff again") and Commit classification ("classifying the new commit again from its diff").
- [x] A merge commit has no patch-id and keeps the existing sync rule. Observed: Commit classification; scratch repo: a `--no-ff` merge commit gave no patch-id.
- [x] Also update: `completion.md` left unchanged; its caller gate needs no pointer. Observed: base and head copies identical.
- [x] Out of scope respected: no script, `team` or merge-gate change. Observed: the base/head diff touches only `review-continuity.md` and the change folder.
- [x] The patch-id claims hold in practice. Evaluator scratch repo (no signing, hooks or global config): a commit rebased onto a moved base kept its patch-id; a changed diff gave a different one.
- [x] Repository checks pass. Evaluator run: `agentskills validate skills/cross-review`, `check-descriptions.sh`, `check-refs.sh`, each rc=0; `check-private.sh` rc=0 on a git-indexed copy of the head export.

Evidence: evaluator run a07b1bc1d32579288 returned INCOMPLETE (only `check-private.sh` unrun: the export has no git index); fresh evaluator run a6bcaa3ad6d578674 on the head export at the SHA above, with a coordinator-supplied git-indexed copy, returned PASS at 3a361bd. After the cross-review fix X-1 (66973c4), fresh evaluator run a761bbf661c5ef186 re-evaluated the head export at the SHA above with the same git-indexed check-private copy: PASS. Test author a78366e6bfc91e826 supplied grep and scratch-repo checks only (docs change; the brief excludes scripts).

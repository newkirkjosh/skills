### Scope Brief

- **Verbatim request:** "That sounds reasonable to me. What do you think next steps are for us?" Then, on the proposed order (step 1: three small independent changes run in parallel by `team`, being evidence on every cross-review finding, learn asking whether a check can enforce a rule, and `git patch-id` recorded as evidence only): "Second, yes you should run step 1 with /team ." On the tracker: "Yes, GitHub issues here." This change is the third item: "Record `git patch-id` as evidence in `dev`'s completion ledger." Recorded earlier as "patch-id as evidence only: a matching patch backs `behavioral: no` in the ledger. It never decides alone."
- **Interpreted scope:** In `cross-review`'s review-continuity reference, where a finding's fix or a classified commit is carried across an amend or rebase, use `git patch-id --stable` to show the new commit's diff matches the original: record both SHAs and the patch-id. A match is evidence that the diff is the same; the classification still follows the commit's actual effect, and a mismatch means the diff is verified again as today. A merge commit has no patch-id, so a sync's merge commit keeps its existing rule.
- **Also update:** `skills/cross-review/references/review-continuity.md` (the amend/rebase evidence rule and Commit classification); `skills/dev/references/completion.md` only if its caller gate text needs to point at it.
- **Deliverable type:** docs (skill instructions)
- **Explicitly out of scope:** letting a patch-id match decide `behavioral: no` on its own (a matching patch can land on a base whose changes alter a dependency or story path); `team`'s merge gate; scripts. Depends on feat-cross-review-finding-evidence, which edits the same reference file and merges first.
- **Size signal:** narrow
- **Path:** bounded, one evidence rule in an existing reference.
- **Known-and-accepted:** patch-id stays evidence, not a gate.

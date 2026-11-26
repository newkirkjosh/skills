# Specs: patch-id as rebase evidence

## Story 1
When a reviewed fix or classified commit is amended or rebased, I want a mechanical check that its diff is unchanged, so its earlier disposition or classification carries over only when the diff really matches.

### Acceptance criteria
- [ ] The review-continuity reference tells the coordinator to compare `git patch-id --stable` of the original and new commits and record both SHAs and the patch-id.
- [ ] A match is recorded as evidence that the diff is unchanged; the classification still follows the commit's actual effect.
- [ ] A mismatch means the diff is verified again, as today.
- [ ] A merge commit (which has no patch-id) keeps the existing sync rule.

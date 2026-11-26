# Specs: Evidence on every review finding

## Story 1
When a cross-model reviewer reports a blocking finding, I want to see what it rests on, so I can judge it without re-deriving the reviewer's reasoning.

### Acceptance criteria
- [ ] The change- and document-mode prompt asks for each blocking finding's evidence: the file:line it rests on, the failure traced step by step, or a command run with its output.
- [ ] Every finding in the ledger, hosted-triage findings included, records its evidence and one level: `cited`, `traced` or `ran`.
- [ ] The returned Dispositions show each finding's evidence level.

## Story 2
When a finding rests on argument alone and a check could settle it, I want that check run before a fix pass is spent on it, so I don't fix non-defects.

### Acceptance criteria
- [ ] Triage runs a check the caller is already permitted to run (a test, a grep, a read-only command) for an argument-only finding that such a check would settle, before accepting it for a fix pass, and records the result as its evidence.
- [ ] A finding no such check can settle is triaged on its argument, as today; document-mode findings and defects provable by reading are not rejected for lacking a run.
- [ ] The reviewer sandbox and `cross-review.sh` are unchanged.

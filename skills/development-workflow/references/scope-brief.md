# The Scope Brief

Adapted from fx/skills `dev/references/scope-contract.md` (MIT, see `../LICENSE.txt`).

Two failures motivate it, and both come from the same root cause: the user's own words stop travelling the moment the first subagent is launched.

1. **Work outgrows the request.** "Just fix the typo" becomes a refactor. A subagent handed a paraphrase cannot see the "just".
2. **Work misses what the request implied.** "Add the new icons" gets the files copied but never listed in the asset index the screens read from. A subagent handed a summary never learns which neighbouring artifacts the user expects to change.

The brief makes the user's words travel. Build it **once**, at the start of the lifecycle, save it as `openspec/changes/<feat-name>/scope-brief.md`, and paste it **verbatim** into every subagent prompt and every review request for this change.

## Format

```markdown
### Scope Brief

- **Verbatim request:** "<the user's own words, quoted exactly>"
- **Interpreted scope:** <what that concretely means: layers, modules, files, deliverable>
- **Also update:** <neighbouring artifacts that must change with it: indexes, docs, DI wiring, tables, README rows>
- **Deliverable type:** <code | spec | docs | config | mixed>
- **Explicitly out of scope:** <what must NOT be touched, changed or flagged, each with its reason>
- **Size signal:** <narrow | normal | open-ended>
- **Known-and-accepted:** <deliberate states a reviewer would otherwise flag>
```

## Field rules

**Verbatim request**: quote, never paraphrase. "just do X real quick" and "implement X" are different instructions and must not collapse into the same summary. If the request spans several messages, quote each. If the user narrowed it mid-run, the narrowed version wins and the earlier one is noted.

**Interpreted scope**: the inference you are acting on, stated plainly so the user can catch a wrong reading in your first report instead of in the final diff. Show it to the user before Phase 2 starts.

**Also update**: the field that catches implied work. Before writing it, grep for every file that references what the change touches and list the ones that must move with it. Every subagent's report must account for each item.

**Explicitly out of scope**: the most valuable field for reviewers. List phases deferred to later work, files intentionally left stale, dependencies a later change adds. Give the **reason** each one is deliberate: "do not flag missing tests" invites a reviewer to override you, while "this change is spec-only; tests are task 2 of feat-x" does not.

**Size signal**, from the user's own language:

| Signal | Phrases |
|--------|---------|
| `narrow` | "just", "real quick", "only", "small", "quick fix", "one-liner", "don't overthink", "minimal" |
| `open-ended` | "thoroughly", "comprehensive", "audit", "deep dive", "properly", "refactor", "whatever it takes" |
| `normal` | anything else |

A `narrow` change gets no opportunistic cleanup. Work you notice but were not asked for goes in the final report as a suggestion, never in the diff.

**Known-and-accepted**: deliberate states that look like defects out of context, such as a failing test tracked elsewhere, a TODO the user asked to keep, or an old API kept for compatibility.

## Using it

- **Subagents**: paste the brief verbatim at the top of the prompt, above the job. A subagent that finds the brief and its job in conflict stops and reports the conflict instead of picking one.
- **Reviewers** (`pr-workflow`'s review agents, `/code-review`): pass the brief as an OUT OF SCOPE / IN SCOPE block. Findings about excluded work are recorded and dismissed with the exclusion cited, not fixed.
- **Never use the brief to suppress real defects.** Security, privacy, data-loss and correctness problems in the work that *was* done are always in scope, whatever the brief says.
- **Resuming a change with no `scope-brief.md`**: reconstruct it from `proposal.md`, `specs/` and the conversation, tell the user you did, and save it.

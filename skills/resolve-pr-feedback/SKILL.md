---
name: resolve-pr-feedback
description: "Explicit-use only — invoke when the user explicitly names this skill, or when an active explicitly invoked workflow calls it. Settles one round of hosted review-bot feedback (CodeRabbit and similar) on a PR's head commit: reads every unresolved thread, triages each against the Scope Brief, fixes the blocking set in one push, then replies to and resolves every thread."
license: MIT (adapted from fx/skills by Marian Rudzynski; see LICENSE.txt)
metadata:
  type: flexible
  upstream: "https://github.com/fx/skills/tree/4b1010d/skills/resolve-pr-feedback"
---

# Resolve PR Feedback

One round of hosted review feedback on one PR, then return. **REQUIRED:** load the github skill for every `gh` step; its GraphQL reference (`graphql.md`, § Review threads) has the thread query, reply and resolve mutations this skill uses. The push and wait order is `ship`'s head-discipline reference (`head-discipline.md`).

**Explicit use only.** It ends at its report. A later request on the same PR is handled directly, or by invoking it again for the next round.

## Steps

1. **Pin the head.** Read the PR's head SHA. Every finding you act on must be about that commit or code still present in it.
2. **Read every unresolved thread**, paginated to the end with the github skill's thread query. One page holds 100 threads; stopping there hides the rest while the count still looks complete. Also read the bot's latest review body on the head: CodeRabbit puts findings outside the diff and some nitpicks there, with no thread to resolve.
3. **Triage each finding** as `blocking`, `immaterial` or `out of scope`:
   - **Check the premise first.** A finding about code that no longer exists, or that misreads a deliberate convention (one written in `AGENTS.md`, `REVIEW.md` or the Scope Brief's Known-and-accepted), is a false premise: no fix, reply with the evidence.
   - The bot's severity labels (`Nitpick`, `Trivial`, `Minor`, `Major`) are inputs, not verdicts. A security, privacy, data-loss, correctness or project-rule defect blocks whatever it's labelled.
   - With a Scope Brief, a finding about excluded work is `out of scope`: dismiss it citing the exclusion, never fix it.
4. **Fix the blocking set once.** Fix every blocking finding in one pass, run the local checks, then one commit and one push (`ship`'s head-discipline, Batch findings). Under `dev`, hand the set to the coordinator instead; it owns the one fix push. A committable suggestion or an AI-agent prompt in the comment is a starting point, not a patch: verify it against the tree first, since one applied as written has introduced the bug it reported.
5. **Settle every finding.** Settle `immaterial`, `out of scope` and false-premise findings right away; they need no fix. Settle a `blocking` finding only once its fix is pushed, citing that commit; under `dev`, settle the blocking threads you handed off only after the coordinator reports its fix push. Never resolve a blocking thread before its fix is on the branch.
   - **Threads:** reply with the disposition (fixed in `<sha>`, immaterial and why, out of scope citing the brief, or the false-premise evidence), then resolve it.
   - **Body-only findings** (no thread to resolve): post one PR comment listing each with its disposition and, if fixed, the commit. A body-only blocking finding counts as open, and blocks the merge, until that comment cites its fix.
   - Replying, resolving and commenting are visible to others: confirm with the user first unless they asked for exactly this or a running workflow's merge policy covers it.
6. **Re-count.** Re-run the paginated query and confirm every thread you settled shows `isResolved`, and that the PR comment covers every body-only finding. A clean count covers only the bots you triaged; say which.
7. **Report and return:** the head SHA triaged, the fix commit if any, each finding's disposition (threads and body-only), what was resolved, and what comes next (the bot reviews the fix push, then CI). Don't wait for that review here; that's the caller's next step.

## Gotchas

- `gh pr review --comment` adds a new review instead of replying to the thread; reply and resolve through the GraphQL mutations.
- CodeRabbit re-reviews every push by itself. Never push a fix per finding: each push restarts its review and CI.
- An immaterial finding still gets a reply before it is resolved, so the next reader sees why nothing changed.
- If the repository has a `REVIEW.md` but CodeRabbit raises things it forbids, check `.coderabbit.yaml` lists `REVIEW.md` in its guideline file patterns; CodeRabbit's defaults read `AGENTS.md` and `CLAUDE.md` but not `REVIEW.md`. Report it; don't change review config inside a review fix.

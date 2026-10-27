---
name: devils-advocate
description: "Explicit-use only — invoke when the user explicitly names this skill, or when an active explicitly invoked workflow calls it. Tiered challenge that stress-tests a recommendation before it is finalized: a light mode for high-stakes calls (architectural, irreversible, significant investment, go/no-go) and a heavy mode on request, each running steel-man, assumption audit, failure scan and a verdict."
metadata:
  type: flexible
---

# Devil's Advocate

## When to Use

**Light mode** runs when the user's instructions (the global CLAUDE.md) or an active workflow call for it, before finalizing any recommendation involving:
- Architectural decision — module boundaries, tech stack choice, service design
- Irreversible or hard-to-reverse decision — breaking API change, data model change, dropping a dependency
- Significant investment — user-stated or estimated >1 day of work; err toward triggering when unknown
- Go/no-go on an idea — "should I build this", "is this worth it", "which approach"
- Recommendation grounded in unverified assumptions

**Heavy mode** runs when the user explicitly asks for it, for example:
- "devil's advocate this"
- "challenge this"
- "stress test this"
- "is this the right call"
- "poke holes in this"

**Skip entirely for:**
- Bug fixes with an obvious solution
- Single-file edits with no architectural implications
- Questions about existing code (explanation, not decision)
- Tasks where the user said "just do it" or equivalent

## Principles

**Light mode** runs inline in the same agent before the final recommendation. Always uses this exact labeled block:

```
**Devil's Advocate**
⟶ Steel-man: [strongest case against this direction, 2-3 sentences]
⟶ Assumptions: [1-2 key assumptions, each marked verified / plausible / unverified]
⟶ Failure modes: [top risk if this goes wrong, 2-3 sentences]
⟶ Verdict: confirmed — [one sentence restatement of original recommendation]
      OR
⟶ Verdict: revised — [one sentence stating the changed recommendation]
```

Verdict is always `confirmed` or `revised` (lowercase), never both. Max ~150 words total. Always moves forward after the verdict — no loops.

**Heavy mode** dispatches a separate challenger agent with a read-only snapshot of the decision. The snapshot contains:
1. The decision being evaluated — user's request or Claude's proposed recommendation, quoted verbatim
2. Directly relevant constraints (tech stack, timeline, existing architecture) — 3-5 bullets max
3. No conversation history — isolated snapshot only

The challenger agent produces:
- **Steel-man** — strongest case for the opposite position, 3-5 sentences
- **Assumption audit** — top 3 assumptions rated `verified` / `plausible` / `unverified` with one sentence each
- **Failure scan** — top 3 failure modes with likelihood (low/med/high) and impact (low/med/high) and one sentence each
- **Verdict** — one of: `Confirm` (original stands), `Revise` (specific change stated), `Reconsider` (fundamental issue found)

Note: heavy mode verdicts are capitalized (`Confirm` / `Revise` / `Reconsider`); light mode verdicts are lowercase (`confirmed` / `revised`) — this distinction is intentional.

The main agent always synthesizes the challenger report into this format before presenting to the user:

```
**Challenge complete.** [1 sentence: what the challenger found overall]

[If Revise or Reconsider: 2-3 sentences explaining the key issue and the change]

**Recommendation:** [final recommendation, incorporating any revisions]
```

Raw challenger output is never shown directly — always synthesized.

## Constraints
- Light mode: ~150 words maximum — never exceed this
- No back-and-forth loops in light mode — one block, one verdict, move forward
- Verdict capitalization must be preserved (light mode lowercase, heavy mode capitalized)
- Heavy mode context snapshot must exclude conversation history — isolated snapshot only
- Never apply to non-trigger cases listed in "When to Use" — do not challenge obvious or trivial decisions

## Examples

**Light mode — architectural decision:**

Situation: recommending Ktor be placed in `:shared` module

```
**Devil's Advocate**
⟶ Steel-man: Keeping Ktor in `:androidApp` keeps the shared module lean and avoids pulling in multiplatform HTTP artifacts that add build complexity and increase binary size on iOS.
⟶ Assumptions: iOS target is in scope [plausible — not yet confirmed]; Ktor multiplatform is stable enough for production [verified].
⟶ Failure modes: If iOS is deprioritized or dropped, the multiplatform complexity in `:shared` becomes pure overhead with no payoff.
⟶ Verdict: confirmed — put Ktor in `:shared`, but verify iOS is a real target before first Go-live.
```

**Heavy mode — go/no-go decision:**

Request: "devil's advocate this — should we build authentication ourselves or use a managed service?"

Context snapshot to agent:
- Decision: build custom JWT auth vs. use a managed auth provider
- Constraints: self-hosted app, small user base (<500), Golang backend, no existing auth infrastructure

Synthesized output:
```
**Challenge complete.** The challenger found the build-it case weaker than it appears once operational cost is factored in.

Custom auth carries ongoing maintenance burden (token rotation, breach response, session management) that a small project will deprioritize under feature pressure. The "control" argument is real but only pays off at scale this project may never reach.

**Recommendation:** Use a managed auth provider for the MVP. Revisit if self-hosting becomes a hard requirement.
```

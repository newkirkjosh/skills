---
name: product-research
description: "Explicit-use only — invoke when the user explicitly names this skill, or when an active explicitly invoked workflow calls it. Researches consumer products (apparel, footwear, gear) and produces a shareable, source-linked comparison page, either for a specific product ask or for matching a style from a description, images or a reference URL. Not for code, docs or technical topics."
---

# Product Research

Research consumer products and publish findings as a source-linked comparison page.

## Step 0: Confirm topic and intent

**Explicit use only.** The user names this skill or an active workflow calls it. An incidental product mention does not select it. Once invoked, resolve topic and intent before dispatching research. This workflow ends at the sourced page/report; later conversation does not inherit its rules.

- **No topic given** (bare command invocation, or the conversation doesn't
  name a product/category): ask directly what they want researched. Don't
  guess a topic, and don't ask a shape/budget/depth question before you
  have one.
- **Topic mentioned but not requested** (the user is venting, comparing
  notes, or just thinking out loud, not asking for a comparison): ask a
  short confirming question — "Want me to research some options for
  [topic]?" — before doing anything else. A mention isn't a request.
- **Topic + explicit request already present**: intent is clear, skip both
  checks above and go straight to Step 1.

Don't dispatch any agents until both the topic and the intent to research
it are confirmed.

**Result:** a named product/category and confirmed research intent, or a missing-topic question.

## Step 1: Determine request shape

- **Single-category research** — a specific item type, optionally a brand
  (e.g. "best Brooks running shoe", "a good weight belt for deadlifts").
- **Style-matching** — a full look/kit driven by an aesthetic reference
  (e.g. "old money look", "build a snowboarding kit like this").

If ambiguous, prefer single-category — it's the narrower interpretation. If
you're not confident which shape fits, say which one you're assuming in
your first reply so the user can redirect before agents dispatch.

**Result:** single-category or style-matching scope.

## Step 2: Resolve budget and depth

- **Budget:** if not stated or clearly implied by words like "cheap",
  "budget", "premium", "high-end", ask exactly one question:

  > Do you have a budget or price tier in mind? (e.g. budget / mid-range /
  > premium, or a specific $ range)

  Ask it as one structured question (on Claude Code, `AskUserQuestion`)
  with 3-4 concrete tier options plus an open range.
  Skip this question entirely if a tier or number is already stated or
  implied.

- **Depth:** defaults to `quick` (a handful of candidates from a couple of
  reputable sources). If the user's phrasing includes "deep dive",
  "thorough", "exhaustive", or similar, use `deep` (cross-reference
  multiple review sites, forums, and retailer ratings). Never ask about
  depth — infer it, defaulting to quick.

**Result:** a budget/tier and quick/deep research depth.

## Step 3: Build a style brief (style-matching requests only)

Skip this step for single-category research.

Spawned research agents never see this conversation or any pasted images —
every agent prompt in Step 4 must carry a self-contained text brief.

- **Text description already given:** use it directly as the style brief.
- **Pasted image(s):** analyze them yourself (you are multimodal) and write
  a short style brief covering fabrics, silhouettes, colors, era/reference
  brands — 3-5 sentences is enough.
- **A URL (e.g. an Instagram page):** fetch it (on Claude Code, `WebFetch`). If it
  returns usable content (captions, visible style cues), fold that into the
  brief. If it fails, is blocked, or returns unusable content (common for
  Instagram), say so explicitly:

  > I wasn't able to pull usable content from that link — Instagram
  > commonly blocks this. Could you paste a screenshot or two instead?

  Do not proceed with a guessed brief on a failed fetch.

Once you have a style brief, decompose it into concrete item types to
research — e.g. outerwear, pants, shirt/top, shoes, accessories. Keep this
to roughly 3-6 item types; if the ask implies more (e.g. "build my whole
wardrobe"), group closely related items together or ask the user to
prioritize before dispatching — don't fan out an unbounded number of
parallel agents. State the decomposition to the user in one line before
dispatching agents, e.g.:

> Breaking this into: blazer/outerwear, trousers, oxford shirt, loafers,
> belt — researching each now.

This gives the user a chance to correct scope before agents run.

**Result:** the self-contained style brief and bounded list of item types, or an unavailable-reference blocker.

## Step 4: Dispatch research agent(s)

- **Single-category:** dispatch one background research delegate.
- **Style-matching:** dispatch one background delegate **per item type**,
  all in parallel — these are independent lookups with no shared state.

Before dispatch, read the host adapters reference in `dev` for the host’s delegation and wait contract. Each delegate is a general-purpose agent running in the background (on
Claude Code, `Agent` with `subagent_type: general-purpose` and
`run_in_background: true`; that syntax is only an example). On a host
without background delegation, run the same lookups yourself in this
session, one item type at a time, with the same prompt as your brief;
the steps after this one don't change. Give each
agent this prompt shape (fill in the bracketed values):

```
Research real, currently-available [item type] products matching:
[brand constraint or style brief]. Budget: [budget]. Depth: [quick|deep].

- quick: check 2-3 reputable review sources plus retailer listings.
- deep: cross-reference multiple review sites, forums, and retailer
  ratings for a fuller picture.

Do not invent products, prices, or specs — every candidate must come
from a real, currently accessible source you can link to.

For each candidate, return:
- name
- price
- source URL
- why it fits the ask
- 1-2 sourced pros/cons

If you can't find enough credible candidates, say so explicitly rather
than padding the list with weak or invented options.

Return plain structured notes with inline source URLs — not HTML or
markdown tables, just clear notes the requester will format themselves.
```

Do not race these agents: since they run in the background, do not
fabricate or guess their findings before they report back. Wait for each
agent's completion notification before proceeding to Step 5. If an agent
errors out or never reports back, don't block the rest of the run on it —
proceed with the agents that did report, and note the missing item
type/category explicitly in the output page instead of silently omitting
it.

**Result:** source-linked candidate notes for each completed item type and explicit gaps for failed categories.

## Step 5: Assemble and publish

Once all dispatched agents have reported back:

1. Verify the returned notes cover each requested category, distinguish sourced facts from judgments, and disclose missing evidence. Use the host’s available page/artifact tools and the user’s presentation conventions for the HTML; do not require an unavailable design skill.
2. Build one HTML page:
   - Single-category: one section for that category.
   - Style-matching: one section per item type, preceded by a short intro
     restating the overall look and the decomposition from Step 3.
   - Each section contains: a short narrative blurb, a ranked shortlist
     (top pick + alternates), and a comparison table (price, source,
     why-it-fits, pros/cons).
   - Every product name and nontrivial claim is a hyperlink to its real
     source URL from the agent findings. No unlinked claims.
   - If an agent reported too few candidates, the section says so plainly
     instead of padding.
3. Write the file to `<research-dir>/<slug>-<YYYY-MM-DD>.html`, where
   `<research-dir>` is the directory the global CLAUDE.md names for
   product research, else `~/Documents/product-research`, and `<slug>` is
   a short kebab-case description of the request (e.g.
   `brooks-running-shoe`, `old-money-look`). Create the directory if it
   doesn't exist. If that
   path already exists (a second run of a similar request same day),
   append `-2`, `-3`, etc. rather than overwriting it.
4. If the host can publish a shareable page, publish the same file (on
   Claude Code, the `Artifact` tool, with an icon fitting the product
   category).
5. Reply to the user with the page link, if published, and the local
   copy's path.

**Result:** the sourced comparison page, its local path and any published link, with missing categories disclosed. End this invocation here.

## Gotchas

- A style-reference fetch that failed supplies no evidence for a guessed brief.
- A missing research category must remain visible in the final page. Do not invent candidates to make the table look complete.
- Publishing availability does not prove a page was published; report a link only after the host confirms it.

# Design note: Batched learning review

| Option | For | Against |
|---|---|---|
| A. Modes inside `learn` plus `references/inbox.md` | One owner for lesson evidence and routing; review reuses Steps 2-7 directly | SKILL.md grows |
| B. A separate review skill | Smaller files | Duplicates learn's evidence/ownership/verify rules; two owners for one policy |
| C. Record lessons in memory only | No new format | Mixed with unrelated memory, no status, no grouping |

**Choice:** A. `SKILL.md` gets a short mode selector at the top and a Review mode section that sequences existing steps; the record format, inbox location rule and status transitions live in `references/inbox.md`, loaded by both modes.

**Sacrifices:** `learn` becomes multi-mode; the selector must keep the default (single correction) path unchanged.

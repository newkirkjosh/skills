---
name: session-log
description: "Explicit-use only — invoke when the user explicitly names this skill, or when an active explicitly invoked workflow calls it. Processes raw D&D / TTRPG session notes in any form into a structured session file and updates the campaign's supporting documents, for campaigns using the standard layout (sessions/, npcs/, world/, characters/)."
metadata:
  type: flexible
---

# D&D Session Log

## Expected Campaign Structure

This skill works with any campaign organized like this:

```
campaigns/<name>/
├── CLAUDE.md              # Campaign overview, in-game date, active character
├── sessions/              # One file per session: YYYY-MM-DD.md or session-NNN.md
│   └── _template.md       # Optional: session note template
├── active-threads.md      # Current objectives and their status
├── npcs/                  # NPC files by location or faction
├── world/
│   ├── locations.md
│   └── factions.md
└── characters/<name>/     # Player character files
```

Adapt to whatever structure the user actually has — don't fail because a file is named differently.

## Step 1 — Load campaign context

Before writing anything, read:
- Campaign `CLAUDE.md` — current in-game date, active character, quick nav pointers
- `active-threads.md` — current objectives and status
- Relevant NPC files based on locations the user mentions

If these files don't exist yet, proceed with what's available and note any gaps.

## Step 2 — Confirm the session date

If the user didn't provide a date, ask before creating the file. The date is the primary key for session history. Use `YYYY-MM-DD.md` as the filename.

## Step 3 — Write the session file

Create `sessions/YYYY-MM-DD.md` using this structure:

```markdown
# YYYY-MM-DD — [optional title]

**In-game date:** 

## Where we started
[One sentence: physical location and immediate situation at session open]

## What happened
[Bullets, roughly chronological. Terse — events, not prose.]
- 

## NPCs
[New or changed only. Format: Name — what happened / what they revealed / what they want]
- 

## Combat
[Only if noteworthy. Enemy, outcome, anything tactically learned.]
- 

## Loot / XP / Level
- 

## Open questions / loose ends
[Unresolved mysteries, contradictions, things to follow up]
- 

## Thread updates
[Delta only — what changed vs. what was already tracked]
- 
```

**If the user provided raw notes:** clean them into this structure. Don't invent details — mark ambiguous things as `<!-- unclear: ... -->` comments. Preserve the user's specific wording when they were clearly intentional about it.

**If "What happened" is already written by the user:** do NOT edit or rewrite it. Use it as source material to populate the other sections (NPCs, Combat, Loot, Open questions, Thread updates), but leave "What happened" exactly as written.

If anything in the notes is ambiguous, ask the user to clarify before filling in the derived sections.

## Step 4 — Update supporting documents

After the session file is written, update as needed:

**`active-threads.md`**
- Add new threads that emerged
- Update status on existing threads (key acquired, NPC revealed, mystery solved, etc.)
- Update the in-game date at the top if it advanced

**NPC files**
- Add new NPCs: name, role/affiliation, what the party knows, attitude toward party
- Update existing NPCs if their status, allegiance, or known info changed

**`world/locations.md`** (if a new location was visited)
- Brief entry: name, region, notable features, why the party has been there

**Character files** (if stats, inventory, relationships, or backstory progressed)
- Update relevant files

Only touch files that actually changed. Don't rewrite sections that weren't affected.

## Step 5 — Report what changed

After all writes, output:
- Files created
- Files updated (one line each: what changed)
- Any `<!-- unclear: ... -->` items that need the user's input

## Principles

- Bullets only in session notes — no prose paragraphs
- Never edit "What happened" if the user already wrote it — use it as source, don't rewrite it
- Flag uncertainty rather than guessing; the user was there, you weren't
- Keep entries terse; a good session note is a jog to memory, not a retelling
- If the user's raw notes are already structured, honor that structure rather than fighting it

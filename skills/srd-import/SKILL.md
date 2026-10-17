---
name: srd-import
description: Import one monster stat block or spell from the free D&D SRD 5.2.1 PDF into an Obsidian vault as a single linked note, using the bundled extraction script instead of transcribing by hand. Use when a campaign needs a creature or spell that has no note yet, or the user says "import the owlbear", "add Fireball to the reference", "pull the SRD stat block for X", "do we have a note for X", or "/srd-import". Covers Fantasy Statblocks formatting, basename clashes, where shared versus campaign notes go, and what to do when the entry is not in the SRD.
---

# SRD Import

Add one SRD 5.2.1 monster or spell to the vault on demand. The SRD is a two-column PDF; plain text extraction interleaves stat blocks, so use `scripts/srd_extract.py`, which reads font data to keep each entry intact. Import what a session needs, not the whole book: 330 monsters and 339 spells dumped at once bury the notes that matter in search.

## Step 1 — Check the vault first

Find the vault root (the nearest ancestor folder containing `.obsidian/`) and the shared reference folder (normally `reference/` beside `campaigns/`). Read the vault's `CLAUDE.md` and any `.claude/rules/` files: their conventions override the defaults below.

Search the vault for a note with the entry's name before importing. If the shared note already exists, link to it and stop.

## Step 2 — Get the PDF

Keep one cached copy; the script caches its parsed pages next to it.

```bash
mkdir -p ~/.cache/srd
[ -f ~/.cache/srd/SRD_CC_v5.2.1.pdf ] || curl -sSL -o ~/.cache/srd/SRD_CC_v5.2.1.pdf \
  https://media.dndbeyond.com/compendium-images/srd/5.2/SRD_CC_v5.2.1.pdf
```

The script needs Python 3.9+ and poppler's `pdftohtml` on `PATH`.

## Step 3 — Extract

```bash
S="<this skill's folder>/scripts/srd_extract.py"
PDF=~/.cache/srd/SRD_CC_v5.2.1.pdf

python3 "$S" --pdf "$PDF" list monsters goblin        # find the exact SRD name
python3 "$S" --pdf "$PDF" monster "Goblin Warrior"    # preview on stdout
python3 "$S" --pdf "$PDF" monster "Goblin Warrior" --out <vault>/reference/bestiary --vault <vault root>
python3 "$S" --pdf "$PDF" spell "Fireball" --out <vault>/reference/spells --vault <vault root>
```

- 2024 names differ from 2014: "Thug" is **Tough**, "Veteran" is **Warrior Veteran**, "Goblin" is **Goblin Warrior**. Use `list` with a fragment when a name is not found.
- `--out` writes `<Name>.md` and refuses to overwrite. `--vault` makes the script exit 3 when any note in the vault already has that basename.
- Monsters come out as a `statblock` code block in Fantasy Statblocks YAML, tagged `[bestiary, srd]`. Initiative and Gear are written as the first traits. Spells come out as a note with `level`, `school`, `classes`, `ritual`, `concentration` in frontmatter, tagged `[spell, srd]`.

## Step 4 — Resolve a basename clash

Wikilinks resolve by filename, so two notes may never share a basename. On exit 3, read the clashing note, then:

- **Same SRD entry already imported:** do nothing; link to the existing note.
- **A glossary or other reference note with the same name** (`Darkness`, `Darkvision` are both a rule and a spell): re-run with `--suffix " (Spell)"` so the new note is `Darkness (Spell).md`.
- **A campaign note with the plain name:** the campaign note is the one out of place. Tell the user; rename it to `<Name> (<Campaign>).md` and repoint its links only with their go-ahead.

## Step 5 — Keep shared and campaign content apart

The note the script writes is the unmodified SRD entry and belongs in the shared reference folder. Never add campaign prep or edited numbers to it.

When a campaign changes a creature (different HP, an extra trait, a named NPC built on it) or needs prep notes beside the stat block, create a second note in that campaign's bestiary named `<Monster> (<Campaign>).md` containing:

1. the line `*Campaign version. SRD base: [[<Monster>]].*`
2. a callout: where it appears, scaling for the party size, what is dangerous
3. a full copy of the stat block with the edits applied, and the edits named in `source:`

Campaign notes then link to the campaign version: `[[Troll (Homebrew)|Troll]]`. Inside a markdown table, escape the pipe: `[[Troll (Homebrew)\|Troll]]`.

## Step 6 — Review what was written

Read the new note before reporting it done.

- **Warnings on stderr.** `contains a table` means compare that table with the PDF page named in the warning; multi-line cells and prose tables can come out with merged or split cells. `prints a '<X>' stat block with this spell` means the summoned creature's block was left out and any spell text printed after it is missing: extract that text from the PDF page by hand.
- **Hyphens.** Line-end hyphenation is rejoined against the SRD's own vocabulary. Skim for a wrongly joined or split compound.
- **Numbers.** Spot-check AC, HP, the six scores and one attack line against the PDF for anything that will be used at the table.
- **Links.** Add the note to the vault's reference index if it keeps one, and confirm every wikilink in notes touched resolves.

## When the entry is not in the SRD

The script says so and exits 1. Many 2025 Monster Manual creatures (kenku, duergar, mind flayer, intellect devourer) and some 2024 spells are not in the SRD. Do not write a shared reference note from memory. Instead:

1. Use the adventure module's own appendix if the campaign has it, otherwise the 2014 stat block.
2. Put the note in the **campaign's** bestiary under its plain name, with `source:` stating exactly where the numbers came from.
3. Tell the user it is not SRD content and should be checked against D&D Beyond.

## Gotchas

- **Never parse the PDF with plain `pdftotext`.** Stat blocks continue across columns and pages; the text comes out interleaved with the neighbouring monster and looks plausible. Use the script.
- **The script's text uses typographic apostrophes** (`can’t`, `Thieves’ Cant`). Hand-typed notes usually use straight ones, so a text search for `can't` will miss SRD notes.
- **Stat block text is plain inside YAML.** `desc:` values are double-quoted strings; when editing a campaign copy by hand, keep the quotes or a colon in the text breaks the block.
- **`size:` can read "Medium or Small".** That is the SRD's wording for most humanoid NPCs, not an extraction fault.
- **A `(Rules)`, `(Spell)` or `(<Campaign>)` suffix changes the link target, not the display.** Link as `[[Darkness (Spell)|Darkness]]`.
- **Two stat blocks can be legitimately similar** (Troll and Troll Limb, a dragon's four ages). Confirm the `name:` line is the one asked for.

## Report

State the file written and its path, the suffix used and why (if any), each warning and how it was resolved, and anything left for the user to verify.

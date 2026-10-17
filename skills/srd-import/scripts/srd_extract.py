#!/usr/bin/env python3
"""Extract one monster or spell from the SRD 5.2.1 PDF as an Obsidian note.

Standard library only; needs poppler's `pdftohtml` on PATH. The PDF is two-column, so plain
text extraction interleaves stat blocks. `pdftohtml -xml` keeps font size and colour per line,
which is what tells a stat block name from a trait name from body text.

  srd_extract.py --pdf SRD.pdf list monsters [FILTER]
  srd_extract.py --pdf SRD.pdf list spells [FILTER]
  srd_extract.py --pdf SRD.pdf monster "Troll"            # note to stdout
  srd_extract.py --pdf SRD.pdf spell "Fireball" --out DIR --vault VAULT

--out DIR writes "<Name>.md" there and refuses to overwrite. --vault VAULT makes the script
refuse (exit 3) when any note with the same basename already exists in the vault, unless
--suffix " (Spell)" is given to rename the new note.
"""
import argparse, html, json, re, subprocess, sys
from pathlib import Path

MONSTER_PAGES = (254, 364)
SPELL_PAGES = (104, 176)
RED, DARKRED, GREY = "#88191f", "#4a0508", "#5a5757"
SIZES = {"Tiny", "Small", "Medium", "Large", "Huge", "Gargantuan"}
SECTIONS = {"Traits": "traits", "Actions": "actions", "Bonus Actions": "bonus_actions",
            "Reactions": "reactions", "Legendary Actions": "legendary_actions"}
SOURCE = "SRD 5.2.1 (= 2025 Monster Manual), CC-BY-4.0"


def load_lines(pdf: Path, first: int, last: int):
    """Return text lines in reading order: page, then left column, then right column."""
    cache = pdf.with_name(f"{pdf.stem}.p{first}-{last}.xml")
    if not cache.exists() or cache.stat().st_mtime < pdf.stat().st_mtime:
        stem = str(cache)[:-4]
        subprocess.run(["pdftohtml", "-xml", "-i", "-q", "-f", str(first), "-l", str(last), str(pdf), stem],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    # pdftohtml sometimes emits mis-nested <i>/<b>, so read it line by line instead of as XML
    fonts, lines, items, pno, mid = {}, [], [], 0, 445

    def flush():
        items.sort(key=lambda x: x[:3])
        lines.extend(i[3] for i in items)
        items.clear()

    text_re = re.compile(r'<text top="(\d+)" left="(\d+)" width="\d+" height="\d+" font="(\d+)">(.*)</text>')
    for row in cache.read_text(encoding="utf-8").splitlines():
        m = re.search(r'<page number="(\d+)"[^>]*width="(\d+)"', row)
        if m:
            flush(); pno, mid = int(m.group(1)), int(m.group(2)) // 2
            continue
        m = re.search(r'<fontspec id="(\d+)" size="(\d+)" family="([^"]*)" color="([^"]*)"', row)
        if m:
            fonts[m.group(1)] = (int(m.group(2)), m.group(3), m.group(4))
            continue
        m = text_re.search(row)
        if not m:
            continue
        top, left = int(m.group(1)), int(m.group(2))
        if top > 1090:      # running footer
            continue
        raw = html.unescape(m.group(4))
        for pat in (r"</b></i>(\s*)<i><b>", r"</i></b>(\s*)<b><i>", r"</b>(\s*)<b>", r"</i>(\s*)<i>"):
            raw = re.sub(pat, r"\1", raw)          # merge adjacent runs of the same style
        plain = re.sub(r"</?[bi]>", "", raw)
        if not plain.strip():
            continue
        size, fam, color = fonts[m.group(3)]
        items.append((0 if left < mid else 1, top, left, dict(
            raw=raw, text=plain, size=size, fam=fam, color=color, top=top, left=left, page=pno)))
    flush()
    return lines


def vocabulary(lines):
    words = set()
    for ln in lines:
        words.update(re.findall(r"[A-Za-z]+(?:-[A-Za-z]+)*", ln["text"]))
    return words


def joiner(words):
    lower = {w.lower() for w in words}

    def join(a: str, b: str) -> str:
        a, b = a.rstrip(), b.lstrip()
        if not a:
            return b
        if a.endswith("—"):
            return a + b
        m, n = re.search(r"([A-Za-z]+)-$", a), re.match(r"([A-Za-z]+)", b)
        if m and n:
            whole, hyph = m.group(1) + n.group(1), m.group(1) + "-" + n.group(1)
            if hyph in words and whole.lower() not in lower:
                return a + b                      # a real hyphenated word
            return a[:-1] + b                     # end-of-line hyphenation
        return a + " " + b
    return join


# ---------------------------------------------------------------- monsters

def is_block_name(ln):
    return ln["size"] == 23 and ln["color"] == RED


def monster_blocks(lines):
    """Yield (name, [lines]) for every stat block."""
    cur = None
    for ln in lines:
        if is_block_name(ln):
            if cur and not cur[1] and cur[2] == (ln["page"], ln["left"] < 450) and ln["top"] - cur[3] < 40:
                cur = (cur[0] + " " + ln["text"].strip(), [], cur[2], ln["top"])   # two-line name
                continue
            if cur:
                yield cur[0], cur[1]
            cur = (ln["text"].strip(), [], (ln["page"], ln["left"] < 450), ln["top"])
        elif ln["size"] >= 27 and ln["color"] == RED:      # group heading ends a block
            if cur:
                yield cur[0], cur[1]
            cur = None
        elif cur:
            cur[1].append(ln)
    if cur:
        yield cur[0], cur[1]


def q(s: str) -> str:
    return json.dumps(s, ensure_ascii=False)


def parse_monster(name, body, join):
    d = dict(name=name, stats_lines=[], fields={}, sections={}, order=[])
    section, entry, last_field = None, None, None
    ability_vals = []
    for ln in body:
        raw, text = ln["raw"], ln["text"]
        if ln["color"] == GREY and "type" not in d:
            d["type"] = text.strip(); continue
        if ln["size"] == 18 and ln["color"] == RED and text.strip() in SECTIONS:
            section = SECTIONS[text.strip()]; d["sections"][section] = []; d["order"].append(section)
            entry = None; continue
        if section is None:
            if ln["color"] != DARKRED:
                continue
            if "GillSans" in ln["fam"]:
                if "SemiBold" not in ln["fam"] and ln["size"] == 15:
                    ability_vals.append((ln["top"], ln["left"], text.strip()))
                continue
            m = re.match(r"\s*<b>([^<]+?)\s*</b>\s*(.*)", raw)
            if m:
                last_field = m.group(1).strip()
                d["fields"][last_field] = re.sub(r"</?[bi]>", "", m.group(2)).strip()
            elif last_field and text.strip():
                d["fields"][last_field] = join(d["fields"][last_field], text.strip())
            continue
        # inside Traits / Actions / ...
        m = re.match(r"\s*(?:<i>\s*<b>|<b>\s*<i>)(.+?)</(?:b|i)>", raw)
        tail = re.sub(r"</?[bi]>", "", raw[m.end():]) if m else ""
        if m and (re.search(r"[.:]\s*$", m.group(1).strip()) or tail.startswith(".")):
            label = m.group(1).strip().rstrip(".").strip()
            rest = tail.lstrip(".").strip()
            entry = [label, rest]; d["sections"][section].append(entry)
        elif entry is None:
            d.setdefault("intro", {}).setdefault(section, "")
            d["intro"][section] = join(d["intro"][section], text.strip())
        else:
            entry[1] = join(entry[1], text.strip())
    # ability scores: two rows of (score, mod, save) x 3
    rows = {}
    for top, left, t in ability_vals:
        key = next((k for k in rows if abs(k - top) <= 4), top)
        rows.setdefault(key, []).append((left, t))
    toks = []
    for k in sorted(rows):
        toks += [t for t in " ".join(t for _, t in sorted(rows[k])).replace("−", "-").split()
                 if re.fullmatch(r"[+-]?\d+", t)]
    if len(toks) != 18:
        raise SystemExit(f"{name}: expected 18 ability tokens, got {len(toks)}: {toks}")
    d["scores"] = [int(toks[i]) for i in range(0, 18, 3)]
    mods = [int(toks[i]) for i in range(1, 18, 3)]
    saves = [int(toks[i]) for i in range(2, 18, 3)]
    abil = ["strength", "dexterity", "constitution", "intelligence", "wisdom", "charisma"]
    order = [0, 1, 2, 3, 4, 5]
    d["saves"] = [(abil[i], saves[i]) for i in order if saves[i] != mods[i]]
    return d


def lower_first_words(s: str) -> str:
    return re.sub(r"\b(Darkvision|Blindsight|Tremorsense|Truesight|Passive|Burrow|Climb|Fly|Swim)\b",
                  lambda m: m.group(1).lower(), s)


def monster_yaml(d):
    f = d["fields"]
    words = d.get("type", "").split(",")
    align = words[-1].strip().lower() if len(words) > 1 else ""
    head = ",".join(words[:-1]).strip() if len(words) > 1 else d.get("type", "")
    toks = head.split()
    i = 0
    while i < len(toks) and (toks[i] in SIZES or toks[i] == "or"):
        i += 1
    size, ctype = " ".join(toks[:i]), " ".join(toks[i:]).lower()
    hp = re.match(r"(\d+)\s*(?:\((.+)\))?", f.get("HP", ""))
    cr = re.match(r"([\d/]+)", f.get("CR", ""))
    out = [f"name: {d['name']}", f"size: {size}", f"type: {ctype}", f"alignment: {align}",
           f"ac: {f.get('AC', '').split()[0] if f.get('AC') else ''}"]
    if hp:
        out.append(f"hp: {hp.group(1)}")
        if hp.group(2):
            out.append(f"hit_dice: {hp.group(2)}")
    out.append(f"speed: {lower_first_words(f.get('Speed', ''))}")
    out.append(f"stats: [{', '.join(map(str, d['scores']))}]")
    if d["saves"]:
        out.append("saves:")
        out += [f"  - {a}: {v}" for a, v in d["saves"]]
    if f.get("Skills"):
        out.append("skillsaves:")
        for part in f["Skills"].split(","):
            m = re.match(r"\s*(.+?)\s*([+\-−]\d+)\s*$", part)
            if m:
                out.append(f"  - {m.group(1).lower()}: {int(m.group(2).replace('−', '-'))}")
    if f.get("Vulnerabilities"):
        out.append(f"damage_vulnerabilities: {f['Vulnerabilities'].lower()}")
    if f.get("Resistances"):
        out.append(f"damage_resistances: {f['Resistances'].lower()}")
    if f.get("Immunities"):
        dmg, _, cond = f["Immunities"].partition(";")
        # a list with no semicolon is damage types unless every item is a condition name
        conds = {"blinded", "charmed", "deafened", "exhaustion", "frightened", "grappled", "incapacitated",
                 "invisible", "paralyzed", "petrified", "poisoned", "prone", "restrained", "stunned", "unconscious"}
        if not cond and all(x.strip().lower() in conds for x in dmg.split(",")):
            dmg, cond = "", dmg
        if dmg.strip():
            out.append(f"damage_immunities: {dmg.strip().lower()}")
        if cond.strip():
            out.append(f"condition_immunities: {cond.strip().lower()}")
    if f.get("Senses"):
        out.append(f"senses: {lower_first_words(f['Senses']).replace('; ', ', ')}")
    out.append(f"languages: {q(f['Languages']) if ':' in f.get('Languages', '') else f.get('Languages', 'None')}")
    out.append(f"cr: {cr.group(1) if cr else ''}")
    lead = []
    if f.get("Initiative"):
        lead.append(["Initiative", f["Initiative"]])
    if f.get("Gear"):
        lead.append(["Gear", f["Gear"]])
    sections = dict(d["sections"])
    if lead:
        sections["traits"] = lead + sections.get("traits", [])
    for key in ["traits", "actions", "bonus_actions", "reactions", "legendary_actions"]:
        if key not in sections:
            continue
        if key == "legendary_actions" and d.get("intro", {}).get(key):
            out.append(f"legendary_description: {q(d['intro'][key])}")
        out.append(f"{key}:")
        for label, desc in sections[key]:
            out.append(f"  - name: {q(label) if re.search(r'[:#]', label) else label}")
            out.append(f"    desc: {q(desc)}")
    return "\n".join(out)


def monster_note(d):
    return (f"---\ntags: [bestiary, srd]\nsource: {SOURCE}\n---\n# {d['name']}\n\n"
            f"```statblock\n{monster_yaml(d)}\n```\n")


# ---------------------------------------------------------------- spells

def spell_blocks(lines):
    """Yield (name, [lines]). A spell name is an 18pt red heading followed by a grey italic level line."""
    # one heading is set in small caps and arrives as fragments ("A", "cid", " S", "plASh")
    merged = []
    for ln in lines:
        sc = "SC700" in ln["fam"] and ln["color"] == RED
        if sc and merged and merged[-1].get("sc") and abs(merged[-1]["top"] - ln["top"]) <= 8:
            merged[-1]["parts"].append((ln["left"], ln["text"]))
            merged[-1]["text"] = "".join(t for _, t in sorted(merged[-1]["parts"])).title()
            continue
        merged.append(dict(ln, sc=True, size=18, parts=[(ln["left"], ln["text"])]) if sc else ln)
    lines = merged
    cur = None
    for i, ln in enumerate(lines):
        nxt = lines[i + 1] if i + 1 < len(lines) else None
        if ln["size"] == 18 and ln["color"] == RED and nxt is not None and \
                re.match(r"\s*(Level \d|\w+ Cantrip)", nxt["text"]):
            if cur:
                yield cur
            cur = (ln["text"].strip(), [])
        elif ln["size"] >= 23 and ln["color"] == RED:
            if cur:
                if ln["size"] == 23:               # a stat block printed inside the spell
                    cur[1].append(dict(ln, statblock=ln["text"].strip()))
                yield cur
            cur = None
        elif cur:
            cur[1].append(ln)
    if cur:
        yield cur


def md_inline(raw: str) -> str:
    s = re.sub(r"<i><b>\s*(.+?)\s*</b></i>", r"***\1***", raw)
    s = re.sub(r"<b><i>\s*(.+?)\s*</i></b>", r"***\1***", s)
    s = re.sub(r"<b>\s*(.+?)\s*</b>", r"**\1**", s)
    s = re.sub(r"<i>\s*(.+?)\s*</i>", r"*\1*", s)
    s = re.sub(r"</?[bi]>", "", s)
    return re.sub(r"(\*\*\*[^*]+\*\*\*)(?=\S)", r"\1 ", s)


def spell_note(name, body, join):
    meta_line, start = body[0]["text"].strip(), 1
    while "(" in meta_line and ")" not in meta_line and start < len(body):   # class list wraps
        meta_line = join(meta_line, body[start]["text"].strip()); start += 1
    m = re.match(r"(?:Level (\d) (\w+)|(\w+) Cantrip)\s*\((.+)\)", meta_line)
    level = int(m.group(1)) if m and m.group(1) else 0
    school = (m.group(2) or m.group(3)).lower() if m else ""
    classes = [c.strip().lower() for c in m.group(4).split(",")] if m else []
    fields, paras, last, in_body = {}, [], None, False
    warnings, base_left = [], body[0]["left"]
    for ln in body[start:]:
        raw, text = ln["raw"], ln["text"]
        if ln.get("statblock"):
            warnings.append(f"the SRD prints a '{ln['statblock']}' stat block with this spell (page {ln['page']}); "
                            f"it is not in this note, and any spell text printed after it is missing")
            continue
        gill = "GillSans" in ln["fam"] and ln["size"] <= 16 and "Light" not in ln["fam"]
        hm = None if in_body else re.match(r"\s*(Casting Time|Range|Components?|Duration):\s*(.*)", text)
        if hm and not gill:                        # some spells set the header in the body font
            last = hm.group(1); fields[last] = hm.group(2).strip(); continue
        if not in_body and not gill and last and ln["left"] > base_left + 5 and "Duration" not in fields:
            fields[last] = join(fields[last], text.strip()); continue
        if not in_body and gill:
            # header block: "Casting Time:" label and its value are separate text runs
            fm = re.match(r"\s*(Casting Time|Range|Components?|Duration):\s*(.*)", text)
            if fm:
                last = fm.group(1); fields[last] = fm.group(2).strip()
            elif last:
                fields[last] = join(fields[last], text.strip())
            continue
        in_body = True
        if gill:                                   # table: 16pt semibold title, 14pt cells
            if not paras or paras[-1][0] != "table":
                paras.append(["table", {}])
                warnings.append(f"contains a table (page {ln['page']}); check it against the PDF")
            paras[-1][1].setdefault(ln["top"], []).append((ln["left"], text.strip(), "SemiBold" in ln["fam"]))
            continue
        piece = md_inline(raw)
        if text.lstrip().startswith("•"):
            paras.append(["li", piece.strip().lstrip("•").strip()])
            continue
        new = text[:1].isspace() or piece.lstrip().startswith("***") or not paras or paras[-1][0] == "table"
        if "Light" in ln["fam"] and paras and paras[-1][0] == "li":
            new = False                               # wrapped bullet line
        if new:
            paras.append(["p", piece.strip()])
        else:
            paras[-1][1] = join(paras[-1][1], piece.strip())
    blocks = []
    for kind, val in paras:
        if kind in ("p", "li"):
            txt = re.sub(r"\s+", " ", val).strip()
            if kind == "li" and blocks and blocks[-1].startswith("- "):
                blocks[-1] += "\n- " + txt
            else:
                blocks.append(("- " if kind == "li" else "") + txt)
            continue
        tops, grid = sorted(val), []
        for t in tops:
            cells = sorted(val[t])
            if grid and t - grid[-1][0] <= 3:
                grid[-1][1].extend(cells)
            else:
                grid.append([t, cells])
        lefts = sorted({c[0] for _, cells in grid for c in cells})
        cols = []
        for l in lefts:
            if cols and l - cols[-1][-1] <= 12:
                cols[-1].append(l)
            else:
                cols.append([l])
        title = None
        if len(grid[0][1]) == 1 and grid[0][1][0][2] and len(cols) > 1:
            title = grid.pop(0)[1][0][1]
        table, prev_hdr = [], False
        for _, cells in grid:
            r = [""] * len(cols)
            hdr = all(c[2] for c in cells)
            for l, txt, _b in sorted(cells):
                i = next(k for k, c in enumerate(cols) if l in c)
                r[i] = (r[i] + " " + txt).strip()
            filled = [v for v in r if v]
            wrapped = len(table) > 1 and not hdr and len(filled) == 1 and len(cols) > 2
            if table and ((hdr and prev_hdr) or r[0] == "" or wrapped):
                for i, v in enumerate(r):
                    if v:
                        table[-1][i] = (table[-1][i] + " " + v).strip()
            else:
                table.append(r)
            prev_hdr = hdr
        md = ([f"**{title}**", ""] if title else []) + ["| " + " | ".join(table[0]) + " |", "|" + "---|" * len(cols)]
        md += ["| " + " | ".join(r) + " |" for r in table[1:]]
        blocks.append("\n".join(md))
    comp = fields.get("Component") or fields.get("Components", "")
    ritual = "ritual" in fields.get("Casting Time", "").lower()
    conc = fields.get("Duration", "").lower().startswith("concentration")
    fm = ["---", "tags: [spell, srd]", f"source: SRD 5.2.1, CC-BY-4.0", f"level: {level}", f"school: {school}",
          f"classes: [{', '.join(classes)}]", f"ritual: {str(ritual).lower()}", f"concentration: {str(conc).lower()}", "---"]
    lvl = f"{school.title()} cantrip" if level == 0 else f"Level {level} {school}"
    head = [f"# {name}", "", f"*{lvl} ({', '.join(c.title() for c in classes)})*", "",
            f"- **Casting Time:** {fields.get('Casting Time', '')}", f"- **Range:** {fields.get('Range', '')}",
            f"- **Components:** {comp}", f"- **Duration:** {fields.get('Duration', '')}", ""]
    for w in warnings:
        print(f"WARNING {name}: {w}", file=sys.stderr)
    return "\n".join(fm + head) + "\n" + "\n\n".join(blocks) + "\n"


# ---------------------------------------------------------------- cli

def find(blocks, name):
    exact = [b for b in blocks if b[0].lower() == name.lower()]
    if exact:
        return exact[0]
    near = [b[0] for b in blocks if name.lower() in b[0].lower()]
    raise SystemExit(f"No SRD entry named {name!r}." + (f" Close matches: {', '.join(near)}" if near else
                     " It may not be in the SRD (many Monster Manual creatures and PHB spells are not)."))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--pdf", required=True, type=Path)
    ap.add_argument("kind", choices=["list", "monster", "spell"])
    ap.add_argument("name")
    ap.add_argument("filter", nargs="?", default="")
    ap.add_argument("--out", type=Path)
    ap.add_argument("--vault", type=Path)
    ap.add_argument("--suffix", default="")
    a = ap.parse_args()
    if not a.pdf.exists():
        raise SystemExit(f"PDF not found: {a.pdf}")
    what = a.name if a.kind == "list" else a.kind + "s"
    if what not in ("monsters", "spells"):
        raise SystemExit("list takes 'monsters' or 'spells'")
    lines = load_lines(a.pdf, *(MONSTER_PAGES if what == "monsters" else SPELL_PAGES))
    blocks = list(monster_blocks(lines) if what == "monsters" else spell_blocks(lines))
    if a.kind == "list":
        for n, _ in blocks:
            if a.filter.lower() in n.lower():
                print(n)
        return
    join = joiner(vocabulary(lines))
    name, body = find(blocks, a.name)
    note = monster_note(parse_monster(name, body, join)) if a.kind == "monster" else spell_note(name, body, join)
    if not a.out:
        sys.stdout.write(note); return
    fname = f"{name}{a.suffix}.md".replace("/", "-")
    if a.vault:
        clash = [p for p in a.vault.rglob("*.md") if p.name.lower() == fname.lower() and ".trash" not in p.parts]
        if clash:
            print(f"Basename clash for {fname}: " + ", ".join(str(c) for c in clash) +
                  "\nRe-run with --suffix (e.g. ' (Spell)' or ' (Rules)') or pick the right layer.", file=sys.stderr)
            sys.exit(3)
    target = a.out / fname
    if target.exists():
        raise SystemExit(f"Refusing to overwrite {target}")
    a.out.mkdir(parents=True, exist_ok=True)
    target.write_text(note, encoding="utf-8")
    print(target)


if __name__ == "__main__":
    main()

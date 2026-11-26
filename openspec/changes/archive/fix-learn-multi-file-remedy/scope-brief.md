### Scope Brief

- **Verbatim request:** "Do the clean up now, then start on https://github.com/newkirkjosh/skills/issues/48 with the updated /dev please." Issue #48: "In `references/inbox.md`, let `Applied` list every file and change of the approved remedy, and make the `applied` → `shipped` transition require every listed change to hold on the default branch. Update review mode's Reconcile and Record steps in `SKILL.md` to match."
- **Interpreted scope:** In `skills/learn/references/inbox.md`, the record's `Applied` field lists every file of the approved remedy with the change recorded for each (a guard plus its test, say), and every transition that checks "the recorded change" checks each listed change: `applied` → `shipped` only when every listed change holds on the default branch; a partial landing (some hold, some don't) never becomes `shipped`. In `skills/learn/SKILL.md`, review mode's **Reconcile applied records** and **Record** steps (and any other step that writes or checks `Applied`, such as note or apply hand-off text) say the same.
- **Also update:** every other place in `skills/learn/` that describes `Applied` as one file or one change (grep `Applied`, `the file`, `recorded change`); the record template line in `inbox.md`.
- **Deliverable type:** docs (skill instructions)
- **Explicitly out of scope:** existing records in the private inbox (outside the repository; never edited here); any script or new check (learn has no scripts; this is a rule fix); the enforcement-question wording from #44 (merged, unchanged); `dev`, `cross-review` and other skills.
- **Size signal:** normal
- **Path:** bounded, one rule in an existing reference plus the two review-mode steps that apply it.
- **Known-and-accepted:** a single-file remedy stays valid as a one-item list; older records with a single file keep working.

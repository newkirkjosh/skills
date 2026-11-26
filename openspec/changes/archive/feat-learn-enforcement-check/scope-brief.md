### Scope Brief

- **Verbatim request:** "That sounds reasonable to me. What do you think next steps are for us?" Then, on the proposed order (step 1: three small independent changes run in parallel by `team`, being evidence on every cross-review finding, learn asking whether a check can enforce a rule, and `git patch-id` recorded as evidence only): "Second, yes you should run step 1 with /team ." On the tracker: "Yes, GitHub issues here." This change is the second item: "Have `learn` ask 'can a check enforce this?' before it writes a new rule into a skill."
- **Interpreted scope:** In `learn`, before the correction becomes instruction text, ask whether a mechanical check can make the demonstrated mistake fail: a catalog check script, a skill's bundled test, or a guard in the helper script that owns the step. When one can, the correction is that check plus a test that fails on the demonstrated mistake, with instruction text only for the judgment the check can't cover. The check lives with the skill or script that owns the decision, not in a central table. Review mode inherits it through the steps it already reuses.
- **Also update:** `skills/learn/SKILL.md` (Step 5, plus Step 6 verification of a new check and a gotcha if needed); `README.md`'s `learn` row only if it describes the edit types.
- **Deliverable type:** docs (skill instructions)
- **Explicitly out of scope:** a central rule-to-enforcer table in `AGENTS.md` (it would duplicate policy each owner holds); writing any new check now (this change only teaches `learn` to ask); the inbox format in `references/inbox.md` (unchanged).
- **Size signal:** normal
- **Path:** bounded, one decision point in an existing skill.
- **Known-and-accepted:** the catalog's own rule "don't add a script for something an agent gets right inline" still applies; the question is asked only for a demonstrated mistake.

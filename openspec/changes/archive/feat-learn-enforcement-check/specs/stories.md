# Specs: Enforce lessons before writing them

## Story 1
When `learn` turns a demonstrated mistake into a catalog change, I want it to prefer a check that fails on that mistake over more instruction text, so the next agent can't repeat it unnoticed.

### Acceptance criteria
- [ ] Before writing instruction text, `learn` asks whether a catalog check script, a skill's bundled test or a guard in the owning helper script can make the demonstrated mistake fail.
- [ ] When one can, the correction is that check plus a test that fails on the demonstrated mistake, and instruction text covers only the judgment the check can't.
- [ ] The check lives with the skill or script that owns the decision; no central rule table is added.
- [ ] Review mode applies the same question, through the steps it reuses.

## Story 2
When a lesson is a judgment call no check can capture, I want `learn` to keep working as today, so it doesn't invent scripts for things an agent gets right inline.

### Acceptance criteria
- [ ] A lesson that needs judgment still becomes an instruction edit through the existing steps.
- [ ] Step 6 verification of a new check includes showing it fails on the demonstrated mistake and passes on a nearby valid case.

# Manual checks: Enforce lessons before writing them

The deliverable is Markdown instructions, so these are instruction-replay checks. An evaluator reads the finished `skills/learn/SKILL.md`, applies each scenario as the skill directs, and records PASS or FAIL with the quoted instruction that produces the expected action. A check whose action has no quotable instruction fails: a wording match is not enough, and neither is an action the evaluator would take from general good sense.

Baseline: `skills/learn/SKILL.md` at the worktree's base commit (155 lines). Every behavioural check (B and J) fails against it; the reason is recorded under each. The structural checks (S) pass today and must still pass after the change.

Placeholder names only: `alpha-skill`, `beta-skill`, `owner/repo`, `alpha-helper.sh`. No fixture files are needed; each input is a short conversation excerpt.

## Story 1: prefer a check that fails on the mistake

**B1. The question is asked before instruction text.**
Input: "use learn: alpha-skill's PR body template has a `Closes #` line, but the agent left it as the literal placeholder `#<issue>` and the PR merged without closing the issue. I fixed the PR body by hand." alpha-skill bundles `scripts/build-pr-body.sh`, which writes that body.
Expected: at Step 5, before drafting any new or reworded instruction, the agent asks whether a catalog check script, a skill's bundled test, or a guard in the owning helper script can make this mistake fail, and names the candidate (a guard in `build-pr-body.sh` that exits non-zero on an unreplaced `<issue>` placeholder). The question comes first; instruction text is drafted only after it is answered.
PASS when: an instruction in Step 5 names the three enforcer kinds (catalog check script, bundled test, owning helper guard) and places the question before writing instruction text.
Fails today because: Step 5 opens with "Rewrite or remove the failing instruction before adding another warning" and never asks whether a check could enforce the correction; the only mention of mechanics is "mechanics in the applicable reference/helper" (line 77), which says where mechanics go, not to prefer one that fails.

**B2. When a check can, the correction is the check plus a failing test.**
Input: same as B1.
Expected: the proposed correction is the guard in `build-pr-body.sh` plus a test in alpha-skill's `scripts/test-build-pr-body.sh` (stubbed, no network) that fails on a body still containing `#<issue>`. Instruction text is added only for what the guard can't decide (for example, which issue to close when the branch names none), or not at all. A correction that adds only a sentence such as "Always replace the issue placeholder" fails.
PASS when: an instruction states that a correction with an available check is that check together with a test that fails on the demonstrated mistake, and limits instruction text to the judgment the check can't cover.
Fails today because: nothing in Steps 5 or 6 requires a check or a test with the correction; Step 6.1 runs helper tests only "when executable behavior changes", which an instruction-only edit never triggers.

**B3. The check lives with its owner; no central table.**
Input: same as B1, and a second correction in the same conversation: "the agent put a hostname in a public example in beta-skill" (the catalog's `scripts/check-private.sh` owns that pattern list).
Expected: the alpha-skill guard and test go in alpha-skill's `scripts/`; the hostname case extends `scripts/check-private.sh` and its test, because that script owns the privacy decision. Neither is recorded in a new rule-to-enforcer table, in `AGENTS.md` or elsewhere. A proposal to add or update a central list of "rule: enforced by" entries fails.
PASS when: an instruction says the check goes with the skill or script that owns the decision, and nothing in the skill directs a central record of rules and their enforcers.
Fails today because: no instruction places a check anywhere; Step 5.1 "Put policy in its owner and mechanics in the applicable reference/helper" covers instruction text only and says nothing against a central table.

**B4. Review mode inherits the question.**
Input: "learn review" with two approved open records: one is the B1 lesson (alpha-skill, PR body placeholder, demonstrated), the other a judgment lesson (as J1).
Expected: in the **Apply** step, the B1 record's edit is the guard plus failing test; the J1 record's edit is instruction text. The question is reached through Step 5, which Apply already runs ("Make the approved edits (Step 5)"); review mode needs no second copy of the rule. If review mode restates the rule in its own words, the evaluator checks it does not contradict Step 5 and notes the duplication.
PASS when: the enforcement question sits in Step 5 (or Step 6) and review mode's Apply step still routes edits through Step 5 and Step 6; or review mode names the question explicitly.
Fails today because: Step 5 has no such question, so Apply's reuse of Step 5 carries none.

**B5. Step 6 proves a new check fails on the mistake and passes on a nearby valid case.**
Input: the B1 correction, after the guard and test are written.
Expected: Step 6 runs the new test and shows it fail on the demonstrated mistake (a body containing `#<issue>`) and pass on a nearby valid case (a body with `Closes #12`, or a body with no `Closes` line when the template allows that). It shows the check failing against the unfixed behaviour before trusting it, and records both outcomes. A run that shows only a pass fails: a check never seen failing proves nothing.
PASS when: an instruction in Step 6 requires that a new check be shown failing on the demonstrated mistake and passing on a nearby valid case, and the result names both outcomes.
Fails today because: Step 6.2 and 6.3 apply "the changed instructions" to the originating and a nearby case; they say nothing about running a new check against the mistake, and 6.1's helper tests are run for passing only.

## Story 2: judgment lessons keep today's path

**J1. A judgment lesson becomes an instruction edit; no check is invented.**
Input: "use learn: alpha-skill picked the wrong policy owner for a lesson about reviewer tone; it belonged in that project's review rules, not the catalog. I corrected it." No script, test or guard can decide which file owns a lesson about tone.
Expected: the agent asks the question, answers that no mechanical check can make this mistake fail (it needs judgment about ownership), says so in the report, and proceeds through Steps 5 and 6 as today with an instruction edit. No new script, test, regex or placeholder check is written. Inventing a check that greps for the word "tone" fails.
PASS when: an instruction says a lesson that needs judgment still becomes an instruction edit through the existing steps, and does not require a check where none can decide the mistake.
Fails today because: today's text does produce an instruction edit, but only by default; there is no question to answer "no" to, so the check fails on the requirement that the agent states why no check applies. Evaluate this check jointly with B1: J1 passes only when the same text that produces B1's check produces J1's instruction edit.

**J2. Inline-work exception.**
Input: "use learn: alpha-skill forgot to read the target file before editing it once." The agent gets this right inline in other runs, and a check would be a script that reimplements reading a file.
Expected: no new script. The agent cites the catalog rule "Don't add a script for something an agent gets right inline" (`AGENTS.md`, Layout) and the question's scope: it is asked only for a demonstrated mistake a check can make fail, not to automate routine steps. If the lesson also lacks a demonstrated cause, Step 2's rule produces a no-op or a proposal instead.
PASS when: an instruction (Step 5 or a gotcha) limits the question to demonstrated mistakes and preserves the inline-work exception, by quoting or pointing to the catalog rule.
Fails today because: no instruction mentions checks, so neither the question nor its exception exists.

**J3. Mixed lesson splits cleanly.**
Input: "use learn: alpha-skill's helper accepted an empty `--repo` and posted to the wrong repository; also it should have asked which repository to use when two remotes were configured."
Expected: a guard in the helper that rejects an empty `--repo`, with a failing test; instruction text only for the judgment (asking when two remotes are configured). Not two instruction sentences, and not a script that guesses the remote.
PASS when: the instructions quoted for B2 and J1 together produce this split.
Fails today because: same as B2.

## Structural checks (repository)

Each passes at baseline and must still pass after the change. Run from the worktree root.

**S1.** `agentskills validate skills/learn` prints `Valid skill: skills/learn`. Baseline: PASS.

**S2.** `scripts/check-descriptions.sh` exits 0, and the `learn` description still opens with the exact explicit-use sentence and stays at most 1024 characters. Baseline: PASS.

**S3.** `scripts/check-refs.sh` exits 0. Baseline: PASS.

**S4.** `scripts/check-private.sh` exits 0, and the diff's examples use placeholders only (no hostnames, home paths, private repo or project names). Baseline: PASS.

**S5.** `bash -n scripts/*.sh skills/*/scripts/*.sh` and `for t in scripts/test-*.sh skills/*/scripts/test-*.sh; do bash "$t"; done` all exit 0. This change adds no script, so none of the results should change. Baseline: PASS.

**S6.** `skills/learn/references/inbox.md` is unchanged: `git diff --exit-code <base> -- skills/learn/references/inbox.md` exits 0.

**S7.** No central rule-to-enforcer table: `git diff <base> -- AGENTS.md REVIEW.md` is empty, and no new file in the diff lists rules against their enforcing checks.

**S8.** No new check is written in this change: `git diff --name-only <base>` lists only `skills/learn/SKILL.md`, this change folder, and `README.md` only if its `learn` row describes edit types (at baseline it does not: "Turns conversation corrections into verified catalog improvements in an isolated worktree, left for review. ...", so README should be untouched).

**S9.** `skills/learn/SKILL.md` stays under 500 lines (baseline 155), and Steps 1 to 4, 7, Note mode and the inbox format are unchanged except for cross-references the evaluator lists and justifies.

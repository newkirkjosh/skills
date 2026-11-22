### Scope Brief

- **Verbatim request:** "One thing about fx's learn skill is I'd love to examine our learnings at a macro level instead of after every single evaluation." Then, on the proposal to build the capture/review modes and a team failure trial through dev: "Yes please, I think that would be best."
- **Interpreted scope:** Change the `learn` skill so lessons can be captured during work without editing the catalog, and reviewed later in a batch: a capture mode (`learn note`) that writes one lesson record to a private inbox, and a review mode (`learn review`) that reads open records, groups them by owning skill and decision, establishes each group's cause and owner with learn's existing evidence and ownership steps before proposing edits, presents a ranked summary for approval, applies the approved set through the existing edit/verify/handoff steps in one worktree, and tracks each record open -> applied -> shipped. The existing single-correction flow stays.
- **Also update:** `learn`'s description (mention the modes; stays explicit-use, at most 1024 characters); `README.md`'s `learn` row; a new `skills/learn/references/inbox.md` for the record format and status rules, loaded by both modes.
- **Deliverable type:** docs (skill instructions)
- **Explicitly out of scope:** the global CLAUDE.md lines that name the inbox location, ask agents to record lessons, and set the reminder threshold (machine instructions in the dotfiles repo, a separate change after this merges); the `team` failure-injection trial (a test run in another repository); any automatic trigger for review (review stays user-invoked by the catalog's explicit-use rule).
- **Size signal:** normal
- **Path:** bounded, one existing skill gains two modes; no interface other skills call changes.
- **Known-and-accepted:** the skill names the inbox only as "the learning inbox the global instructions name", never a path, because the catalog is public and machine paths stay in the global instructions.

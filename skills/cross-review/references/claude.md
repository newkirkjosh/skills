# Claude as the reviewer

Read when running `scripts/cross-review.sh claude` (from a Codex session) or triaging its output.

## How the script runs it

- `claude -p` with only the Read, Grep and Glob tools and no MCP servers (`--strict-mcp-config`). It gets no shell: even `git diff` can write files (`--output`), so the script writes the diff (change mode) or the snapshot (document mode) into a temporary directory first and adds that directory to the reviewer's read scope.
- `CROSS_REVIEW_MODEL` and `CROSS_REVIEW_EFFORT` map to `--model` and `--effort` for one run. Leave them unset to use Claude's defaults; never lower them to save time.

## Gotchas

- **`claude -p` needs the network.** Under a sandbox that blocks it, the review fails with a connection error, which is a setup error, not an unavailable reviewer. The host adapters reference in `dev` says how to escalate safely.
- **In change mode it runs in the worktree, so it loads the project's `CLAUDE.md`** (and `AGENTS.md` when `CLAUDE.md` imports it), but not `REVIEW.md` unless one of those points at it. A document review loads no project instructions: put the rules it needs in the prompt. Apply the same pointer check as for Codex before accepting a finding that `REVIEW.md` explicitly allows.

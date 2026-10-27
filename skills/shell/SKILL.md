---
name: shell
description: "Explicit-use only — invoke when the user explicitly names this skill, or when an active explicitly invoked workflow calls it. Rules for agent-run shell commands that agents get wrong: stopping and waiting on processes by PID instead of by pattern, background jobs you can stop, bounded readiness polls, visible exit statuses, never blocking on a prompt, and keeping secrets off the command line."
license: MIT (adapted from fx/skills by Marian Rudzynski; see LICENSE.txt)
metadata:
  upstream: "https://github.com/fx/skills/tree/4b1010d/skills/shell"
---

# Shell — Rules for Agent-Run Commands

Shell mistakes agents have actually made, most damaging first. Each is the rule, the failure that was observed, and the idiom to use instead. Host-specific behaviour is in § Host notes.

**The one fact behind most of this:** your whole command, patterns included, is the command line of a shell that is still running while it executes. So is a string you send through `ssh`, or through `sh -c` under `docker exec` / `kubectl exec`. Anything that searches command lines finds that shell. Mechanics and the process-group recipes: `references/process-control.md` — read it before stopping a forking launcher (`npm run dev`, `gradle`, an `sh -c` wrapper).

## Stop a process by PID or through its owner, never by pattern

**Never stop a process with `pkill -f`, `killall`, `kill $(pgrep -f …)` or `ps | grep … | xargs kill`.** The pattern matches your own shell, which dies with the target. Upstream observed this 26 times in 15 sessions: `pkill -f "<cli> package start"; yarn build | tail -6` killed its own shell and the build never ran. Filtering the matches in a loop does not help, because the loop's own command line passes its filter.

Stop it **through its owner** (`docker compose down`, `docker stop <container>`, `systemctl --user stop <unit>`, `adb emu kill`, the host's own stop for a task it backgrounded), or **by the PID you kept** at launch.

**The one exception — a one-time stop of something you did not start, with no owner and no PID:** list with the bracket trick, `pgrep -af '[s]erver --port 4000'`, check the PIDs, then `kill` those PIDs. `[s]erver` does not match its own command line, but it stops working the moment the unbracketed string appears anywhere else in the same command, and it is **never a wait condition**.

## Start only what you can stop

**Every process you start in the background must leave you its PID.** Without one, cleanup falls back to a pattern: 11 of the 15 upstream self-kill sessions had first launched something untracked, such as `(kubectl port-forward svc/<svc> <port> &)`, followed later by `pkill -f "port-forward …"`.

- Prefer the host's run-long mechanism (§ Host notes). Otherwise `&`, with `$!` saved on the next statement:

```bash
dir=$(mktemp -d)
./start-server > "$dir/server.log" 2>&1 &
pid=$!
```

- **Never `( … &)`, `nohup`, `setsid` or `disown` without keeping the PID.** `( … &)` loses `$!` inside the subshell.
- **A launch the host already backgrounds gets no `&`, `nohup` or `disown` of its own.** `&` hands back the wrapper's status in milliseconds, which was read as a finished job over a truncated log; `disown` drops the job, so `wait` returns 0 at once even for a live or failed job; `nohup` does nothing once output is redirected.
- **A launcher that forks** leaves the real server as a child of the PID you kept, and killing only that PID orphans it. Start it in its own process group and stop the group (`references/process-control.md`).
- **Stop what you started before you report done.** Upstream saw dev servers left running for up to 32 hours.

## Wait on the thing itself

**Never wait on a process pattern.** `until ! pgrep -f '<runner> eval --filter <x>'; do sleep 15; done` matched its own shell and ran 23.3 hours; `until ! ssh <host> 'pgrep -f <mover> >/dev/null'; do sleep 60; done` ran 4.2 hours, because the remote shell matched too.

**Something that signals its own completion** (a long build, a test run, CI, a script writing a log): run it with the host's run-long mechanism, redirect to a log, and read the log when the host says it finished. Don't `sleep`-loop on it, and don't judge it by how fast the call returned — a log without its final summary line is still running or died.

**A readiness gate inside one command** (a server you just started, an emulator booting): the poll must be bounded, must check that the producer is still alive, and must fail when the gate fails:

```bash
ready=false
for i in $(seq 1 30); do
  if grep -q 'listening on' "$dir/server.log"; then ready=true; break; fi
  kill -0 "$pid" 2>/dev/null || break
  sleep 2
done
if ! "$ready"; then
  echo "server not ready" >&2
  tail -n 20 "$dir/server.log" >&2
  exit 1
fi
```

`exit 1` ends the command with a failing status so nothing after the poll runs (`return 1` inside a function). A failure branch that ends on its `echo` or `tail` exits 0 and the gate passes. The waits observed finishing quickly all checked real state like this: a ready line, a `Ready` status, `adb shell getprop sys.boot_completed`, a ping.

**Any prompt you hand a subagent that might wait on something must carry these rules** — no `sleep` polling, no self-matching process patterns. A delegate left to invent its own wait writes exactly the loops above.

## Keep exit statuses and output visible

**A pipeline reports the status of its last command, and `tail` prints only at the end.** `<installer> --install 2>&1 | tail -20` hit the call timeout showing nothing at all, then ran on for 14.8 hours.

- Redirect to a log, then read it: `<cmd> > "$dir/out.log" 2>&1; rc=$?; tail -n 40 "$dir/out.log"; exit "$rc"`.
- When you must pipe, `set -o pipefail` or read `PIPESTATUS`. Under `pipefail` a producer cut off by `head` exits 141, which is not a failure.
- Cap what you read: `head -n`, `grep -m`, `sed -n '200,260p'`. Large dumps spend context on noise.

## Never block on a prompt

Nobody is there to answer. Observed: `ssh <host> '… sudo …'` failed with "a terminal is required"; commands, mostly `ssh`, hung until the user backgrounded them by hand; a debconf prompt; a `git rebase -i`; a pager.

- `sudo -n`, so a missing credential fails at once instead of hanging. When root is really needed, give the user the command to run themselves.
- `ssh -n -o BatchMode=yes -o ConnectTimeout=10 <host> '<cmd>'`.
- `DEBIAN_FRONTEND=noninteractive apt-get -y …`, `pacman --noconfirm`, `dnf -y`.
- `GIT_EDITOR=true`, `GIT_PAGER=cat`; never `git rebase -i`.

## Never put a secret in a command

**A command line is readable by every user through `ps`, and the transcript keeps it.** Upstream found an API key in a `curl` header, a password in `SSHPASS=`, and a password typed with `tmux send-keys`. Pass it on stdin through a builtin, or from a file:

```bash
printf 'header = "Authorization: Bearer %s"\n' "$TOKEN" | curl -sS -K - https://example.com/api
sshpass -f "$dir/pass" ssh "$host" uptime
```

If a secret shows up in output, do not repeat it. Tell the user so it can be rotated.

## Host notes

Verified on the version named; re-check on yours.

**Claude Code** (2.1.300, Linux):

- A command runs as `/bin/bash -c "source <snapshot> && … eval '<cmd>'"` — the user's login shell, with their aliases loaded from the snapshot. Your whole command is inside that `-c` string, which is why a pattern from it self-matches (reproduced: `pgrep -af '<marker>'` matched its own shell; `pgrep -af '[<m>]arker'` did not).
- Aliases are live. If one shadows a tool (`grep` aliased to something else), `command grep` bypasses it.
- Upstream observed the shell as zsh on another machine. There, `echo ===` fails (`== not found`), an unmatched glob aborts its command (quote `--include='*.md'`), `$cmd` is not word-split (use an array), and `set -m` is refused without a terminal (run the process-group start from a `bash` script file). Check `cat /proc/$$/cmdline` if unsure which shell runs.
- A self-kill shows as **exit 144**, with no output from the steps after it.
- Stdin is `/dev/null`, so most prompts fail at once rather than hang.
- The run-long mechanism is `run_in_background: true`; the completion notification wakes you, so never poll it. To wait on a condition, use the Monitor tool with a bounded until-loop that checks real state.
- A command that hits the foreground timeout is moved to the background, not killed.
- The working directory is reset between calls ("Shell cwd was reset"); use absolute paths.
- Inside a distrobox, `distrobox enter -- <cmd>` is a separate shell with its own command line; the same self-match applies to patterns sent through it.

## Gotchas

- **Chain dependent steps with `&&`, and never silence a step a later one relies on.** Observed: `git revert --no-edit HEAD -q 2>/dev/null; git commit --amend …` — `revert` rejected `-q`, the error was discarded, and the `;` let `--amend` rewrite the wrong commit. Use `step1 && step2`, keep stderr visible, and check the result (`git log -1`, `git status`) before anything that rewrites history or pushes.

- `pgrep -x <name>` avoids the self-match but cannot tell your run from any other process with that name. `pgrep -f <pattern> | grep -v $$` filters PID text by substring and still leaves parent wrappers matching. Neither is a safe substitute for a kept PID.
- Killing a Gradle or `npm run` PID leaves its children running. Use the process-group recipe, or the tool's own stop (`./gradlew --stop`).

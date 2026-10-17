# Process control

The mechanics behind `SKILL.md` § Stop a process by PID or through its owner, and § Start only what you can stop. Adapted from fx/skills (MIT, see `../LICENSE.txt`).

## Why a pattern matches its own shell

`pgrep -f`, `pkill -f` and `ps | grep` match against the **full command line** of every process; `pgrep` and `pkill` exclude only themselves. The matches therefore include:

- **The shell running your command**, whose command line is your entire command as source text.
- **On a remote host, the shell that runs your string.** `ssh <host> '<cmd>'` runs `<cmd>` as `<shell> -c '<cmd>'`, and so does `kubectl exec` / `docker exec` with `sh -c`. Reproduced: a compound string (`;`, `&&`, a pipe, a loop) keeps that shell alive, and it matches.

So `pkill -f <pattern>` kills the shell running it and `pgrep -f <pattern>` always succeeds — **any** `pgrep -f`, `ps | grep` or `pkill -f` whose pattern appears in its own invocation self-matches.

**A filter loop does not help.** `for p in $(pgrep -f chrome); do grep -q '<profile-dir>' "/proc/$p/cmdline" && kill "$p"; done` killed itself in 4 of the 26 observed self-kills: the loop's own shell has `<profile-dir>` in its command line, so it passes its own filter.

**Do not reach for a "safer" process check — there isn't one.** `pgrep -x <name>` drops the self-match but cannot tell your run from any other process of the same name. `pgrep -f <pattern> | grep -v $$` is worse: it filters PID *text* by substring (so `$$` of `123` also drops `1234`), and it removes only the current shell, leaving any parent or wrapper whose command line contains the pattern to keep the check true.

## Start it in its own process group

A launcher that forks — `npm run dev`, an `sh -c` wrapper — puts the server in a child of the PID in `$!`. Reproduced: killing that PID left both children running. Start the job in its own process group, whose ID is the launcher's PID, and stop the whole group.

bash's `set -m` gives every background job its own group. It works inline under Claude Code's `bash -c`. zsh refuses it without a terminal (`can't change option: -m`); there, run this from a bash script file (`bash start.sh <dir>`):

```bash
#!/usr/bin/env bash
dir=${1:?usage: start.sh <scratch-dir>}
set -m
npm run dev > "$dir/server.log" 2>&1 &
pid=$!
set +m
echo "$pid" > "$dir/server.pid"
```

## Stop the group

TERM the group, wait a bounded time, KILL, and fail if it is still there. The leading `-` addresses the group; `--` keeps `kill` from reading `-<pid>` as a signal name. The pid file is removed only once the group is gone, so a stop that cannot finish keeps the PID for the next attempt.

```bash
pid=$(cat "$dir/server.pid") || exit 1
kill -TERM -- "-$pid" 2>/dev/null
for i in $(seq 1 10); do
  kill -0 -- "-$pid" 2>/dev/null || break
  sleep 0.5
done
if kill -0 -- "-$pid" 2>/dev/null; then
  kill -KILL -- "-$pid"
  sleep 0.5
fi
if kill -0 -- "-$pid" 2>/dev/null; then
  echo "process group $pid still running" >&2
  exit 1
fi
rm -f "$dir/server.pid"
```

#!/usr/bin/env bash
# Tests for android-emulator.sh and android-ui.py, with adb and the emulator
# stubbed. No network, no device, no SDK.
# usage: bash test-scripts.sh   (needs bash, flock, python3 and node)
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
work="$(mktemp -d)"
holder=""
trap '[ -n "$holder" ] && kill "$holder" 2>/dev/null; pkill -f "$work/bin/emulator" 2>/dev/null; rm -rf "$work"' EXIT
pass=0 fail=0
check() { if eval "$2"; then pass=$((pass + 1)); echo "ok   $1"; else fail=$((fail + 1)); echo "FAIL $1"; fi; }

mkdir -p "$work/bin" "$work/run"
export XDG_RUNTIME_DIR="$work/run" STUB="$work"
# emulator stub: -list-avds prints $STUB_AVDS; otherwise stays up until killed.
cat > "$work/bin/emulator" <<'EOF'
#!/usr/bin/env bash
[ "${1:-}" = -list-avds ] && { printf '%b' "${STUB_AVDS:-one-avd\n}"; exit 0; }
printf '%s\n' "$@" > "$STUB/emulator.args"
[ -n "${STUB_EMU_DIE:-}" ] && { echo "emulator: boom" >&2; exit 1; }
if [ -n "${STUB_HELPER:-}" ]; then
  # Retains fd 9 in the emulator group and ignores TERM, requiring KILL.
  bash -c 'trap "" TERM; exec sleep 12345' &
  echo $! > "$STUB/helper.pid"
fi
# Like the real thing: a long-running process that holds the inherited lock fd.
while :; do sleep 0.2; done
EOF
# adb stub: boot_completed from $STUB_BOOTED; emu kill stops the emulator stub;
# uiautomator dump / cat serve $STUB/ui.xml; screencap serves $STUB/screen; logs every call.
cat > "$work/bin/adb" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$STUB/adb.log"
[ "$1" = -s ] && shift 2
case "$*" in
  "start-server") ;;
  "shell input keycombination 113 29") [ -z "${STUB_KEYCOMBINATION_FAIL:-}" ] ;;
  "shell getprop sys.boot_completed") if [ -n "${STUB_BOOT_FILE:-}" ]; then cat "$STUB_BOOT_FILE"; else echo "${STUB_BOOTED:-1}"; fi ;;
  "emu kill") [ -n "${STUB_NO_EMU_KILL:-}" ] || pkill -f "$STUB/bin/emulator" ;;
  "shell uiautomator dump "*) echo "UI hierchary dumped to: $4" ;;
  "exec-out cat /data/local/tmp/verify-ui.xml") cat "$STUB/ui.xml" ;;
  "exec-out screencap -p") cat "$STUB/screen" ;;
  *) ;;
esac
EOF
chmod +x "$work/bin/"*
export EMULATOR_BIN="$work/bin/emulator" ADB_BIN="$work/bin/adb"
emu() { bash "$here/android-emulator.sh" "$@" > "$work/out" 2> "$work/err"; echo $? > "$work/rc"; }
rc() { cat "$work/rc"; }
last() { tail -n 1 "$work/out"; }
lock="$work/emu.lock"
group_stopped() { ! ps -eo pgid=,stat= | awk -v g="$group" '$1 == g && $2 !~ /^Z/ { found=1 } END { exit !found }'; }

# --- android-emulator.sh ------------------------------------------------------
emu up --port 5554 --lock "$lock" --timeout 10
check "up: boots, reports READY with serial and boot time" '[ "$(rc)" = 0 ] && [ "$(last)" = STATUS=READY ] && grep -q "serial=emulator-5554 .*boot_s=" "$work/out"'
check "up: headless flags, the only AVD by default" 'grep -qx -- -no-window "$work/emulator.args" && grep -qx -- -no-snapshot-save "$work/emulator.args" && grep -qx one-avd "$work/emulator.args"'
check "up: animations off after boot" 'grep -q "settings put global animator_duration_scale 0" "$work/adb.log"'

pid="$(cat "$work/run/verify-change/emulator-5554.pid")"
check "up: recorded PID is the process group leader" '[ "$(ps -o pgid= -p "$pid" | tr -d " ")" = "$pid" ]'

emu up --port 5554 --lock "$lock"
check "up again: reuses the running device" '[ "$(rc)" = 0 ] && grep -q reused "$work/out"'

emu up --port 5554 --lock "$work/other.lock"
check "up: another lock on the same port is BUSY" '[ "$(rc)" = 4 ] && [ "$(last)" = STATUS=BUSY ]'
emu up --port 5554 --avd another-avd --lock "$lock"
check "up: another AVD on the same port is BUSY" '[ "$(rc)" = 4 ] && [ "$(last)" = STATUS=BUSY ]'
check "busy callers preserve ownership" '[ "$(cat "$work/run/verify-change/emulator-5554.pid")" = "$pid" ] && [ "$(cat "$work/run/verify-change/emulator-5554.lockpath")" = "$lock" ] && [ "$(cat "$work/run/verify-change/emulator-5554.avd")" = one-avd ]'

emu up --port 5556 --lock "$lock"
check "a second device on the same lock is BUSY (4), not shared" '[ "$(rc)" = 4 ] && [ "$(last)" = STATUS=BUSY ]'

group="$pid"
check "down assertion detects the live recorded group" '! group_stopped'
emu down --port 5554
check "down: STOPPED and the emulator is gone" '[ "$(rc)" = 0 ] && [ "$(last)" = STATUS=STOPPED ] && ! kill -0 "$pid" 2>/dev/null && group_stopped && [ ! -f "$work/run/verify-change/emulator-5554.pid" ]'
check "down: the lock is free again" 'flock -n "$lock" true'

STUB_NO_EMU_KILL=1 emu up --avd x --port 5564 --lock "$lock"
group="$(cat "$work/run/verify-change/emulator-5564.pid")"
STUB_NO_EMU_KILL=1 emu down --port 5564
check "down: an emulator ignoring emu kill is stopped with its whole group" '[ "$(last)" = STATUS=STOPPED ] && flock -n "$lock" true && group_stopped'

for leader_state in exits-on-adb already-exited; do
  STUB_HELPER=1 emu up --avd x --port 5568 --lock "$lock"
  group="$(cat "$work/run/verify-change/emulator-5568.pid")"
  helper="$(cat "$work/helper.pid")"
  check "helper: inherits the recorded group and holds lock" '[ "$(ps -o pgid= -p "$helper" | tr -d " ")" = "$group" ] && ! flock -n "$lock" true'
  if [ "$leader_state" = already-exited ]; then
    kill "$group"
    for _ in $(seq 1 50); do kill -0 "$group" 2>/dev/null || break; sleep 0.1; done
    check "helper: survives after leader exits" '! kill -0 "$group" 2>/dev/null && kill -0 "$helper" 2>/dev/null'
  fi
  emu down --port 5568
  check "down: cleans surviving helper ($leader_state)" '[ "$(rc)" = 0 ] && [ "$(last)" = STATUS=STOPPED ] && group_stopped && flock -n "$lock" true'
done

# Hold the first run in its boot poll while competing callers try the same port.
echo 0 > "$work/booted"
STUB_BOOT_FILE="$work/booted" bash "$here/android-emulator.sh" up --avd x --port 5566 --lock "$lock" --timeout 15 > "$work/first.out" 2> "$work/first.err" &
first_up=$!
for _ in $(seq 1 50); do
  [ -f "$work/run/verify-change/emulator-5566.pid" ] && break
  sleep 0.1
done
first_pid="$(cat "$work/run/verify-change/emulator-5566.pid")"
STUB_BOOT_FILE="$work/booted" emu up --avd x --port 5566 --lock "$lock"
check "racing up during boot is BUSY" '[ "$(rc)" = 4 ] && [ "$(last)" = STATUS=BUSY ]'
STUB_BOOT_FILE="$work/booted" emu up --avd x --port 5566 --lock "$work/other.lock"
check "racing up with another lock preserves the first records" '[ "$(rc)" = 4 ] && [ "$(cat "$work/run/verify-change/emulator-5566.pid")" = "$first_pid" ] && [ "$(cat "$work/run/verify-change/emulator-5566.lockpath")" = "$lock" ] && [ "$(cat "$work/run/verify-change/emulator-5566.avd")" = x ]'
echo 1 > "$work/booted"
wait "$first_up"; first_rc=$?
check "first run completes boot after racing callers" '[ "$first_rc" = 0 ] && grep -q STATUS=READY "$work/first.out"'
emu down --port 5566
check "first run remains stoppable after racing callers" '[ "$(rc)" = 0 ] && flock -n "$lock" true'

emu status --port 5554
check "status after down is STOPPED" '[ "$(last)" = STATUS=STOPPED ]'

STUB_AVDS='a\nb\n' emu up --lock "$lock"
check "two AVDs and no --avd is an ERROR naming them" '[ "$(rc)" = 3 ] && grep -q "available AVDs are: a b" "$work/err"'

STUB_EMU_DIE=1 emu up --avd x --port 5558 --lock "$lock"
check "an emulator that dies at start is an ERROR, not READY" '[ "$(rc)" = 3 ] && [ "$(last)" = STATUS=ERROR ]'

STUB_BOOTED=0 emu up --avd x --port 5560 --lock "$lock" --timeout 3
check "no boot within the timeout is an ERROR" '[ "$(rc)" = 3 ] && grep -q "not booted after 3s" "$work/err"'
emu down --port 5560

flock "$lock" sleep 30 & holder=$!; sleep 0.5
emu up --avd x --port 5562 --lock "$lock"
check "a lock held by another run is BUSY" '[ "$(rc)" = 4 ]'
check "failed lock acquisition publishes no ownership records" '[ ! -e "$work/run/verify-change/emulator-5562.pid" ] && [ ! -e "$work/run/verify-change/emulator-5562.lockpath" ] && [ ! -e "$work/run/verify-change/emulator-5562.avd" ]' 
kill "$holder"; holder=""

emu up --port 5555 --lock "$lock"
check "an odd port is refused" '[ "$(rc)" = 3 ]'

mkdir -p "$work/evil-target" "$work/evilrun"; ln -s "$work/evil-target" "$work/evilrun/verify-change"
XDG_RUNTIME_DIR="$work/evilrun" emu up --avd x --port 5570 --lock "$lock"
check "a symlinked state directory is refused" '[ "$(rc)" = 3 ] && grep -q "refusing to use it" "$work/err" && [ -z "$(ls -A "$work/evil-target")" ]'

# A stale record (its process died without down) must not kill whatever now has the serial.
mkdir -p "$work/run/verify-change"; sh -c 'exit 0' & dead=$!; wait "$dead"
echo "$dead" > "$work/run/verify-change/emulator-5572.pid"; : > "$work/adb.log"
emu down --port 5572
check "down with a stale record doesn't send emu kill to the serial" '[ "$(last)" = STATUS=STOPPED ] && ! grep -q "emu kill" "$work/adb.log"'

# A reused live PID must never be mistaken for our emulator.
set -m
sleep 120 & unrelated=$!
set +m
for operation in status down up; do
  record="$work/run/verify-change/emulator-5570"
  echo "$unrelated" > "$record.pid"
  echo 'not the recorded start time' > "$record.start"
  echo "$work/identity.lock" > "$record.lockpath"
  echo x > "$record.avd"
  : > "$work/adb.log"
  emu "$operation" --port 5570 --avd x --lock "$work/identity.lock"
  check "$operation: recycled PID is untouched" 'kill -0 "$unrelated" 2>/dev/null && ! grep -q "emu kill" "$work/adb.log"'
  if [ "$operation" = up ]; then
    check "up: replaces stale identity with a new owned emulator" '[ "$(rc)" = 0 ] && [ "$(cat "$record.pid")" != "$unrelated" ] && [ -s "$record.start" ]'
    emu down --port 5570
  else
    check "$operation: discards stale ownership records" '[ "$(last)" = STATUS=STOPPED ] && [ ! -e "$record.pid" ] && [ ! -e "$record.start" ] && [ ! -e "$record.lockpath" ] && [ ! -e "$record.avd" ]'
  fi
done
kill "$unrelated"; wait "$unrelated" 2>/dev/null || :

# --- android-ui.py --------------------------------------------------------------
cat > "$work/ui.xml" <<'EOF'
<?xml version='1.0' encoding='UTF-8' standalone='yes' ?>
<hierarchy rotation="0">
  <node text="" content-desc="" resource-id="" bounds="[0,0][1080,2400]">
    <node class="android.widget.TextView" text="Create account" bounds="[0,400][400,450]" />
    <node class="android.widget.Button" clickable="true" text="Create account" bounds="[0,500][400,550]" />
    <node class="android.widget.Button" clickable="true" checked="true" selected="true" text="Create account" bounds="[0,600][400,650]" />
    <node class="android.widget.EditText" focused="true" text="dune" resource-id="search" bounds="[0,700][400,750]" />
    <node class="android.widget.TextView" editable="true" focused="true" text="Other input" bounds="[0,800][400,850]" />
    <node class="android.widget.Button" clickable="true" text="Sign in" content-desc="" resource-id="com.example.app:id/sign_in" bounds="[100,200][300,260]" />
    <node text="" content-desc="Open menu" resource-id="" bounds="[0,0][100,100]" />
    <node text="email_field" content-desc="" resource-id="email_field" bounds="[50,300][1030,380]" />
    <node text="Hidden" content-desc="" resource-id="" bounds="[0,0][0,0]" />
  </node>
</hierarchy>
EOF
ui() { python3 -I "$here/android-ui.py" --serial emulator-5554 "$@" > "$work/out" 2> "$work/err"; echo $? > "$work/rc"; }
: > "$work/adb.log"

# Guard failures must issue no adb commands, even for mutating commands.
ANDROID_SERIAL= python3 -I "$here/android-ui.py" key HOME > "$work/out" 2> "$work/err"; echo $? > "$work/rc"
check "ui: missing serial is rejected before adb" '[ "$(rc)" = 2 ] && grep -q -- "--serial or ANDROID_SERIAL" "$work/err" && [ ! -s "$work/adb.log" ]'
ui key HOME
check "ui: unowned emulator serial is rejected" '[ "$(rc)" = 2 ] && grep -q "not started" "$work/err" && [ ! -s "$work/adb.log" ]'
echo 99999999 > "$work/run/verify-change/emulator-5554.pid"
ui key HOME
check "ui: stale PID record is rejected" '[ "$(rc)" = 2 ] && [ ! -s "$work/adb.log" ]'
# Synthetic live ownership record isolates UI tests from SDK processes.
echo $$ > "$work/run/verify-change/emulator-5554.pid"
ANDROID_SERIAL=emulator-5554 python3 -I "$here/android-ui.py" key HOME > "$work/out" 2> "$work/err"; echo $? > "$work/rc"
check "ui: ANDROID_SERIAL selects a managed device explicitly" '[ "$(rc)" = 0 ] && grep -q -- "-s emulator-5554 shell input keyevent KEYCODE_HOME" "$work/adb.log"'
: > "$work/adb.log"
python3 -I "$here/android-ui.py" --serial physical-test key HOME > "$work/out" 2> "$work/err"; echo $? > "$work/rc"
check "ui: unmanaged physical serial requires opt-in" '[ "$(rc)" = 2 ] && [ ! -s "$work/adb.log" ]'
python3 -I "$here/android-ui.py" --device --serial physical-test key HOME > "$work/out" 2> "$work/err"; echo $? > "$work/rc"
check "ui: explicit device opt-in targets the requested serial" '[ "$(rc)" = 0 ] && grep -q -- "-s physical-test shell input keyevent KEYCODE_HOME" "$work/adb.log"'
: > "$work/adb.log"
ANDROID_SERIAL= python3 -I "$here/android-ui.py" --device key HOME > "$work/out" 2> "$work/err"; echo $? > "$work/rc"
check "ui: device opt-in still requires a serial" '[ "$(rc)" = 2 ] && [ ! -s "$work/adb.log" ]'

ui find "Sign in"
check "ui find: exact text" '[ "$(rc)" = 0 ] && grep -q "^Sign in |" "$work/out"'
ui find "Open menu"
check "ui find: content-desc" '[ "$(rc)" = 0 ]'
ui find sign_in
check "ui find: bare resource-id name inside a namespaced id" '[ "$(rc)" = 0 ]'
ui find "~SIGN"
check "ui find: ~ is a case-insensitive substring" '[ "$(rc)" = 0 ]'
ui find "Sign"
check "ui find: a partial match without ~ is not found (exit 1)" '[ "$(rc)" = 1 ]'
ui find Hidden
check "ui find: zero-size nodes are skipped" '[ "$(rc)" = 1 ]'
ui tap "Sign in"
check "ui tap: taps the centre of the bounds" '[ "$(rc)" = 0 ] && grep -q "shell input tap 200 230" "$work/adb.log"'
ui tap "Create account"
check "ui tap: prefers clickable over title" '[ "$(rc)" = 0 ] && grep -q "input tap 200 525" "$work/adb.log"'
ui find "Create account" --nth 2
check "ui find: nth uses document order" '[ "$(rc)" = 0 ] && grep -qF "[0, 500, 400, 550]" "$work/out"'
ui tap "Create account" --nth 1
check "ui tap: nth overrides clickable preference" '[ "$(rc)" = 0 ] && grep -qF "[0, 400, 400, 450]" "$work/out"'
ui find "Create account" --last
check "ui find: last match" '[ "$(rc)" = 0 ] && grep -qF "[0, 600, 400, 650]" "$work/out"'
ui tap "Create account" --last
check "ui tap: last match" '[ "$(rc)" = 0 ] && grep -q "input tap 200 625" "$work/adb.log"'
ui find "Create account" --below "Create account"
check "ui find: below the first anchor" '[ "$(rc)" = 0 ] && grep -qF "[0, 500, 400, 550]" "$work/out"'
ui tap "Create account" --below "Create account" --nth 2
check "ui tap: below filters before nth" '[ "$(rc)" = 0 ] && grep -qF "[0, 600, 400, 650]" "$work/out"'
ui find "Create account" --below Missing
check "ui find: missing anchor gives no match" '[ "$(rc)" = 1 ]'
ui find "Create account" --nth 0
check "ui find: rejects nonpositive nth" '[ "$(rc)" = 2 ]'
for command in find tap wait; do
  ui "$command" "~Dune" --timeout 0
  check "ui $command: skips editable text" '[ "$(rc)" = 1 ]'
  ui "$command" search --include-editable --timeout 0
  check "ui $command: includes editable by id with flag" '[ "$(rc)" = 0 ]'
done
ui find "Other input"
check "ui find: skips focused editable attribute" '[ "$(rc)" = 1 ]'
ui dump
check "ui dump: short class and flags" 'grep -q "Button | CKS" "$work/out" && grep -q "EditText | FE" "$work/out"'
ui clear
check "ui clear: CTRL+A then Delete" '[ "$(rc)" = 0 ] && tail -2 "$work/adb.log" | head -1 | grep -q "input keycombination 113 29" && tail -1 "$work/adb.log" | grep -q "input keyevent KEYCODE_DEL"'
STUB_KEYCOMBINATION_FAIL=1 ui clear
check "ui clear: fallback moves to end then 50 Deletes" '[ "$(rc)" = 0 ] && tail -2 "$work/adb.log" | head -1 | grep -q KEYCODE_MOVE_END && [ "$(tail -1 "$work/adb.log" | grep -o KEYCODE_DEL | wc -l)" = 50 ]'
ui wait "Sign in" --timeout 2
check "ui wait: returns at once when present" '[ "$(rc)" = 0 ]'
ui wait "Nope" --timeout 1
check "ui wait: times out with exit 1" '[ "$(rc)" = 1 ] && grep -q "timed out after 1s" "$work/err"'
ui gone "Nope" --timeout 1
check "ui gone: succeeds when absent" '[ "$(rc)" = 0 ]'
for control in $'hello\ninput keyevent HOME' $'hello\tworld' $'hello\rworld' $'hello\033world' $'hello\177world' "$(printf 'hello\302\205world')"; do
  : > "$work/adb.log"
  ui type "$control"
  check "ui type: rejects control characters before any adb call" '[ "$(rc)" = 2 ] && grep -q "control characters" "$work/err" && [ ! -s "$work/adb.log" ]'
done
 : > "$work/adb.log"
ui type 'abc%sdef'
check "ui type: rejects literal percent-s before adb" '[ "$(rc)" = 2 ] && grep -q "literal %s" "$work/err" && [ ! -s "$work/adb.log" ]'
ui key back
check "ui key: BACK maps to KEYCODE_BACK" '[ "$(rc)" = 0 ] && grep -q "input keyevent KEYCODE_BACK" "$work/adb.log"'
printf '\x89PNGrest' > "$work/screen"; ui screenshot "$work/shot.png"
check "ui screenshot: writes the PNG" '[ "$(rc)" = 0 ] && head -c 4 "$work/shot.png" | grep -q PNG'
printf 'error: device offline' > "$work/screen"; ui screenshot "$work/bad.png"
check "ui screenshot: refuses output that isn't a PNG" '[ "$(rc)" = 2 ] && [ ! -e "$work/bad.png" ]'
printf 'not xml' > "$work/ui.xml"; ui find x
check "ui: an unparseable dump is exit 2, not 'not found'" '[ "$(rc)" = 2 ]'

# Exercise the helper's subprocess boundary and the actual shell's parsing.
python3 -I - "$here/android-ui.py" "$work" <<'PYTEST'
import contextlib
import importlib.util
import io
import subprocess
import sys
from unittest.mock import patch
spec = importlib.util.spec_from_file_location("android_ui", sys.argv[1])
ui = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ui)
for error in (subprocess.TimeoutExpired("adb", 60), OSError("missing adb")):
    with patch.object(ui.subprocess, "run", side_effect=error), contextlib.redirect_stderr(io.StringIO()) as err:
        try:
            ui.adb("test", "shell", "true")
            raise AssertionError("expected exit 2")
        except SystemExit as e:
            assert e.code == 2 and "adb could not complete" in err.getvalue()
for text in ("it's a test & more", "[d]ata {a,b}", '$(echo bad); `echo bad`', 'two words'):
    with patch.object(ui, "adb") as adb:
        assert ui.main(["--serial", "test", "--device", "type", text]) == 0
        remote = " ".join(adb.call_args.args[2:])
    # Existing file would trigger glob expansion if the value were not quoted.
    from pathlib import Path
    Path(sys.argv[2], "data").touch()
    result = subprocess.run(["bash", "-c", 'input() { printf "%s\n" "$@"; }; ' + remote],
                            cwd=sys.argv[2], capture_output=True, text=True, check=True)
    assert result.stdout.splitlines() == ["text", text.replace(" ", "%s")], result.stdout
PYTEST
check "ui: adb exceptions are exit 2 and type survives shell parsing" '[ "$?" = 0 ]'
for command in key launch; do
  for value in 'KEYCODE_HOME; reboot' 'com.example.app; reboot' 'x y' ''; do
    : > "$work/adb.log"
    ui "$command" "$value"
    check "ui $command: rejects shell input before adb" '[ "$(rc)" = 2 ] && [ ! -s "$work/adb.log" ]'
  done
done
for value in KEYCODE_HOME 3 enter; do
  ui key "$value"
  check "ui key: accepts allowlisted key" '[ "$(rc)" = 0 ]'
done
ui launch com.example.app
check "ui launch: accepts Android package" '[ "$(rc)" = 0 ] && grep -q "monkey -p com.example.app" "$work/adb.log"'

# Playwright stub models a hidden first match and a late HTTP error.
mkdir -p "$work/modules/playwright"
cat > "$work/modules/playwright/index.js" <<'JS'
const assert = require('node:assert/strict');
exports.chromium = { launch: async () => ({
  close: async () => {},
  newPage: async () => {
    const handlers = {};
    return {
      on: (name, fn) => { handlers[name] = fn; },
      goto: async () => ({status: () => 200}),
      getByText: () => {
        let visible = false;
        const locator = {
          filter: (options) => { visible = options.visible === true; return locator; },
          first: () => locator,
          waitFor: async () => { assert(visible, 'hidden first match was selected'); }
        };
        return locator;
      },
      waitForLoadState: async (state, options) => {
        assert.equal(state, 'networkidle');
        assert.equal(options.timeout, 1234);
        if (process.env.WEB_NEVER_IDLE) throw Object.assign(new Error('Timeout 1234ms exceeded.'), {name: 'TimeoutError'});
        if (process.env.WEB_CRASH) throw new Error('Target page, context or browser has been closed');
        await new Promise(resolve => setTimeout(resolve, 5));
        if (process.env.WEB_LATE_ERROR) handlers.response({status: () => 500, url: () => 'http://example.com/late'});
      }
    };
  }
})};
JS
NODE_PATH="$work/modules" node "$here/../assets/web-check.cjs" http://example.com --expect Ready --settle 1234 > "$work/web.out" 2>&1
web_rc=$?
check "web: visible match wins over hidden first match" '[ "$web_rc" = 0 ] && grep -q "PASS  text visible" "$work/web.out"'
WEB_LATE_ERROR=1 NODE_PATH="$work/modules" node "$here/../assets/web-check.cjs" http://example.com --expect Ready --settle 1234 > "$work/web.out" 2>&1
web_rc=$?
check "web: a late error inside the settle window fails the check" '[ "$web_rc" = 1 ] && grep -q "FAIL  HTTP 500" "$work/web.out"'
WEB_NEVER_IDLE=1 NODE_PATH="$work/modules" node "$here/../assets/web-check.cjs" http://example.com --expect Ready --settle 1234 > "$work/web.out" 2>&1
web_rc=$?
check "web: a page that never goes idle (persistent connection) still passes" '[ "$web_rc" = 0 ] && grep -q "network still busy" "$work/web.out"'
WEB_NEVER_IDLE=1 NODE_PATH="$work/modules" timeout 10 node "$here/../assets/web-check.cjs" http://example.com --expect Ready --settle 0 > "$work/web.out" 2>&1
web_rc=$?
check "web: --settle 0 skips the idle wait instead of waiting forever" '[ "$web_rc" = 0 ] && ! grep -q "network still busy" "$work/web.out"'
WEB_CRASH=1 NODE_PATH="$work/modules" node "$here/../assets/web-check.cjs" http://example.com --expect Ready --settle 1234 > "$work/web.out" 2>&1
web_rc=$?
check "web: a page crash during the settle window fails, not 'still busy'" '[ "$web_rc" = 1 ] && grep -q "FAIL  Target page" "$work/web.out" && ! grep -q "network still busy" "$work/web.out"'

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]

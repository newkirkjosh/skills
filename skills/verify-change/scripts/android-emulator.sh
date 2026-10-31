#!/usr/bin/env bash
# Start or stop a headless Android emulator for a verification run.
#
# usage: android-emulator.sh up   [--avd NAME] [--port N] [--lock FILE] [--timeout SEC]
#        android-emulator.sh down [--port N]
#        android-emulator.sh status [--port N]
#
# up: boots AVD NAME (default: the only AVD, or $VERIFY_AVD) with no window,
# host GPU, no audio and no snapshot save, on console port N (default 5554).
# The emulator process holds an exclusive flock on FILE for its whole life
# (default: <git common dir>/locks/emulator of the current repository), so a
# second run waits for nothing and fails fast with STATUS=BUSY instead of
# sharing a device. Waits up to SEC (default 300) for sys.boot_completed, then
# unlocks the screen and turns animations off so taps and screenshots are
# deterministic.
#
# down: `adb emu kill`, then the recorded process group if it outlives that;
# the lock is released when the emulator exits. status: prints the state line only.
#
# The last stdout line is always STATUS=READY|BUSY|STOPPED|ERROR.
# Exit: 0 READY or STOPPED, 2 usage, 3 ERROR, 4 BUSY.
set -uo pipefail

status=ERROR
trap 'echo "STATUS=$status"' EXIT
die() { echo "android-emulator: $*" >&2; exit 3; }

sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}}"
emulator="${EMULATOR_BIN:-$sdk/emulator/emulator}"
adb="${ADB_BIN:-$(command -v adb || echo "$sdk/platform-tools/adb")}"
# Per-user state only: never a shared /tmp path another user could plant symlinks in.
state="${XDG_RUNTIME_DIR:-$HOME/.cache}/verify-change"

cmd="${1:-}"; shift || true
avd="${VERIFY_AVD:-}" port=5554 lock="" timeout=300
while (($#)); do
  case "$1" in
    --avd) avd="${2:?--avd needs a value}"; shift 2 ;;
    --port) port="${2:?--port needs a value}"; shift 2 ;;
    --lock) lock="${2:?--lock needs a value}"; shift 2 ;;
    --timeout) timeout="${2:?--timeout needs a value}"; shift 2 ;;
    *) sed -n '2,8p' "$0" >&2; status=ERROR; exit 2 ;;
  esac
done
[[ $port =~ ^[0-9]+$ ]] && (( port % 2 == 0 )) || die "--port must be an even number"
serial="emulator-$port" pidfile="$state/emulator-$port.pid" lockref="$state/emulator-$port.lockpath" log="$state/emulator-$port.log"
avdref="$state/emulator-$port.avd"

# Serialize ownership publication and shutdown for this port, even across locks.
mkdir -p -m 0700 "$state" || die "can't create state directory $state"
[ -d "$state" ] && [ ! -L "$state" ] && [ "$(stat -c %u "$state")" = "$(id -u)" ] \
  || die "state directory $state isn't a directory owned by you (or is a symlink); refusing to use it"
exec 8>"$state/emulator-$port.guard"
flock -n 8 || { status=BUSY; exit 4; }

alive() { [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; }
booted() { [ "$("$adb" -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ]; }

case "$cmd" in
  up)
    [ -x "$emulator" ] || die "emulator not found at $emulator (set ANDROID_HOME)"
    if [ -z "$avd" ]; then
      avd="$("$emulator" -list-avds 2>/dev/null | grep -v '^INFO' || true)"
      [ "$(grep -c . <<<"$avd")" = 1 ] || die "pass --avd: available AVDs are: $(tr '\n' ' ' <<<"$avd")"
    fi
    if [ -z "$lock" ]; then
      common="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" \
        || die "not in a git repository; pass --lock FILE"
      lock="$common/locks/emulator"
    fi
    mkdir -p "$state" "$(dirname "$lock")" || die "can't create $state or the lock directory"
    lock="$(cd "$(dirname "$lock")" && pwd -P)/$(basename "$lock")"
    if alive; then
      if [ "$(cat "$lockref" 2>/dev/null)" = "$lock" ] &&
         [ "$(cat "$avdref" 2>/dev/null)" = "$avd" ] && booted; then
        echo "serial=$serial pid=$(cat "$pidfile") reused"; status=READY; exit 0
      fi
      echo "port $port belongs to another run or is still booting"
      status=BUSY; exit 4
    fi
    # Acquire before publishing anything. The child inherits fd 9 and holds
    # the device lock until it and its helpers exit; the parent closes its copy.
    exec 9>"$lock"
    flock -n 9 || { echo "lock held: $lock"; status=BUSY; exit 4; }
    start=$SECONDS
    # Job control assigns the background job PGID=$!, without setsid forking.
    set -m
    "$emulator" -avd "$avd" -port "$port" \
      -no-window -gpu host -no-audio -no-boot-anim -no-snapshot-save 8>&- >"$log" 2>&1 &
    pid=$!
    set +m
    echo "$lock" >"$lockref"
    echo "$avd" >"$avdref"
    echo "$pid" >"$pidfile"
    exec 9>&-
    exec 8>&-
    sleep 1
    if ! kill -0 "$pid" 2>/dev/null; then
      wait "$pid"; rc=$?
      tail -5 "$log" >&2; die "emulator exited at start (exit $rc); log: $log"
    fi
    "$adb" start-server >/dev/null 2>&1 || :
    until booted; do
      kill -0 "$(cat "$pidfile")" 2>/dev/null || { tail -5 "$log" >&2; die "emulator died while booting; log: $log"; }
      (( SECONDS - start < timeout )) || die "not booted after ${timeout}s; log: $log (run: $0 down --port $port)"
      sleep 2
    done
    # Deterministic UI: awake, unlocked, no animations.
    "$adb" -s "$serial" shell input keyevent KEYCODE_WAKEUP >/dev/null 2>&1 || :
    "$adb" -s "$serial" shell wm dismiss-keyguard >/dev/null 2>&1 || :
    for s in window_animation_scale transition_animation_scale animator_duration_scale; do
      "$adb" -s "$serial" shell settings put global "$s" 0 >/dev/null 2>&1 || :
    done
    echo "serial=$serial pid=$(cat "$pidfile") avd=$avd boot_s=$((SECONDS - start)) log=$log"
    status=READY ;;
  down)
    if [ -f "$pidfile" ]; then
      pid="$(cat "$pidfile")"
      [[ $pid =~ ^[1-9][0-9]*$ ]] || die "invalid recorded process group"
      # Ask the emulator to quit only while our recorded process is alive: if it died
      # without down, the serial may now belong to an emulator someone else started.
      if kill -0 "$pid" 2>/dev/null; then
        "$adb" -s "$serial" emu kill >/dev/null 2>&1 || :
        for _ in $(seq 1 30); do kill -0 "$pid" 2>/dev/null || break; sleep 1; done
      fi
      # Signal the whole group so emulator helpers cannot keep the lock held.
      if kill -0 -- "-$pid" 2>/dev/null; then kill -TERM -- "-$pid" 2>/dev/null; sleep 3; fi
      if kill -0 -- "-$pid" 2>/dev/null; then kill -KILL -- "-$pid" 2>/dev/null; sleep 1; fi
      # Orphaned zombies can still answer kill -0; the lock wait below proves
      # no surviving helper retains the device lock after group escalation.
    fi
    # STOPPED means the next run can take the device: wait for the lock itself,
    # since a helper the emulator started can hold it briefly after the main process exits.
    if [ -f "$lockref" ]; then
      flock -w 15 "$(cat "$lockref")" true || die "emulator stopped but its lock is still held: $(cat "$lockref")"
    fi
    rm -f "$pidfile" "$lockref" "$avdref"
    status=STOPPED ;;
  status)
    if alive && booted; then echo "serial=$serial pid=$(cat "$pidfile")"; status=READY
    else status=STOPPED; fi ;;
  *) sed -n '2,8p' "$0" >&2; exit 2 ;;
esac

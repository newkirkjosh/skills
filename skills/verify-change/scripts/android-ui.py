#!/usr/bin/env python3
"""Drive an Android app's UI through adb and uiautomator, by what's on screen.

usage: python3 -I android-ui.py [--serial S] COMMAND ...
  dump                       print each visible node: text | content-desc | resource-id | bounds | class | flags
  find QUERY                 print the first matching node, exit 1 if none
  tap QUERY                  tap the first clickable match, else the first match
  wait QUERY [--timeout S]   wait until a node matches (default 30 s), exit 1 on timeout
  gone QUERY [--timeout S]   wait until no node matches
  clear                      clear the focused field (Android 12+; fallback deletes 50 chars)
  type TEXT                  type into the focused field (spaces allowed)
  key KEYCODE                send a key event (BACK, ENTER, HOME, or a KEYCODE_* name)
  screenshot FILE            save a PNG of the screen
  launch PACKAGE             start the app's launcher activity, cold

QUERY matches a node's text, content-desc or resource-id exactly; prefix it
with ~ for a case-insensitive substring match ("~sign in"). Compose test tags
show up as resource-id only when the app sets testTagsAsResourceId.

find/tap accept --nth N (1-based document order), --last, and --below QUERY
(top edge below the first anchor's bottom). Explicit selection overrides clickable
preference. find/wait/gone/tap skip editable nodes unless --include-editable is set.
Use that flag with a resource-id or exact hint text to target an input.
dump includes the short class and flags C clickable, F focused, K checked,
S selected, E editable.

Exit: 0 ok, 1 not found / timed out, 2 usage or adb failure.
"""
import os
import re
import shutil
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

ADB = os.environ.get("ADB_BIN") or shutil.which("adb") or os.path.expanduser(
    os.path.join(os.environ.get("ANDROID_HOME", "~/Android/Sdk"), "platform-tools", "adb"))


def fail(msg, code=2):
    print(f"android-ui: {msg}", file=sys.stderr)
    sys.exit(code)


def adb(serial, *args, binary=False, allow_failure=False):
    cmd = [ADB] + (["-s", serial] if serial else []) + list(args)
    r = subprocess.run(cmd, capture_output=True, timeout=60)
    if allow_failure:
        return r.returncode == 0
    if r.returncode != 0:
        fail(f"adb {' '.join(args)} failed: {r.stderr.decode(errors='replace').strip()}")
    return r.stdout if binary else r.stdout.decode(errors="replace")


def nodes(serial):
    # dump to the device's tmp, then read it: exec-out to /dev/tty mixes the status line in.
    adb(serial, "shell", "uiautomator", "dump", "/data/local/tmp/verify-ui.xml")
    xml = adb(serial, "exec-out", "cat", "/data/local/tmp/verify-ui.xml")
    try:
        root = ET.fromstring(xml)
    except ET.ParseError as e:
        fail(f"couldn't parse the UI dump: {e}")
    out = []
    for n in root.iter("node"):
        m = re.fullmatch(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", n.get("bounds", ""))
        if not m:
            continue
        x1, y1, x2, y2 = map(int, m.groups())
        if x2 <= x1 or y2 <= y1:
            continue
        flags = {key: n.get(key) == "true" for key in
                 ("clickable", "focused", "checked", "selected")}
        cls = n.get("class", "")
        editable = "EditText" in cls or n.get("editable") == "true"
        out.append({"class": cls, "editable": editable, **flags,
                    "text": n.get("text", ""), "desc": n.get("content-desc", ""),
                    "id": n.get("resource-id", ""), "bounds": (x1, y1, x2, y2)})
    return out


def matches(node, query):
    fields = (node["text"], node["desc"], node["id"])
    if query.startswith("~"):
        q = query[1:].lower()
        return any(q in f.lower() for f in fields if f)
    # An id may be namespaced (com.example:id/name); match the bare name too.
    return query in fields or (node["id"].endswith("/" + query) and node["id"] != "")


def first(serial, query, include_editable=False, nth=None, last=False, below=None, tap=False):
    all_nodes = nodes(serial)
    anchor = next((n for n in all_nodes if matches(n, below)
                   and (include_editable or not n["editable"])), None) if below else None
    if below and anchor is None:
        return None
    found = [n for n in all_nodes if matches(n, query)
             and (include_editable or not n["editable"])
             and (anchor is None or n["bounds"][1] > anchor["bounds"][3])]
    if nth is not None:
        return found[nth - 1] if nth <= len(found) else None
    if last:
        return found[-1] if found else None
    if tap:
        return next((n for n in found if n["clickable"]), found[0] if found else None)
    return found[0] if found else None


def show(n):
    flags = "".join(letter for letter, key in
                    (("C", "clickable"), ("F", "focused"), ("K", "checked"),
                     ("S", "selected"), ("E", "editable")) if n[key])
    return f'{n["text"]} | {n["desc"]} | {n["id"]} | {list(n["bounds"])} | {n["class"].split(".")[-1]} | {flags}'


def wait_for(serial, query, timeout, present=True, **selection):
    deadline = time.monotonic() + timeout
    while True:
        found = first(serial, query, **selection)
        if (found is not None) == present:
            return found
        if time.monotonic() >= deadline:
            return False
        time.sleep(1)


def main(argv):
    serial = os.environ.get("ANDROID_SERIAL", "")
    if argv[:1] == ["--serial"]:
        if len(argv) < 2:
            fail("--serial needs a value")
        serial, argv = argv[1], argv[2:]
    if not argv:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    cmd, args = argv[0], argv[1:]
    timeout = 30.0
    if "--timeout" in args:
        i = args.index("--timeout")
        try:
            timeout = float(args[i + 1])
        except (IndexError, ValueError):
            fail("--timeout needs a number of seconds")
        args = args[:i] + args[i + 2:]

    selection = {}
    if cmd in ("find", "tap", "wait", "gone"):
        if "--include-editable" in args:
            args.remove("--include-editable")
            selection["include_editable"] = True
        if cmd in ("find", "tap"):
            if "--last" in args:
                args.remove("--last")
                selection["last"] = True
            for flag, key in (("--nth", "nth"), ("--below", "below")):
                if flag in args:
                    i = args.index(flag)
                    if i + 1 >= len(args):
                        fail(f"{flag} needs a value")
                    selection[key] = args[i + 1]
                    args = args[:i] + args[i + 2:]
            if "nth" in selection:
                try:
                    selection["nth"] = int(selection["nth"])
                    if selection["nth"] < 1:
                        raise ValueError
                except ValueError:
                    fail("--nth needs a positive integer")
                if selection.get("last"):
                    fail("--nth and --last are mutually exclusive")

    if cmd == "dump" and not args:
        for n in nodes(serial):
            if n["text"] or n["desc"] or n["id"]:
                print(show(n))
        return 0
    if cmd == "find" and len(args) == 1:
        n = first(serial, args[0], **selection)
        if not n:
            return 1
        print(show(n))
        return 0
    if cmd == "tap" and len(args) == 1:
        n = first(serial, args[0], tap=True, **selection)
        if not n:
            print(f"android-ui: nothing on screen matches {args[0]!r}", file=sys.stderr)
            return 1
        x1, y1, x2, y2 = n["bounds"]
        adb(serial, "shell", "input", "tap", str((x1 + x2) // 2), str((y1 + y2) // 2))
        print(f"tapped {show(n)}")
        return 0
    if cmd in ("wait", "gone") and len(args) == 1:
        n = wait_for(serial, args[0], timeout, present=(cmd == "wait"), **selection)
        if n is False:
            print(f"android-ui: timed out after {timeout:g}s waiting for {args[0]!r} to "
                  f"{'appear' if cmd == 'wait' else 'go away'}", file=sys.stderr)
            return 1
        if cmd == "wait":
            print(show(n))
        return 0
    if cmd == "type" and len(args) == 1:
        # input text needs spaces as %s and shell metacharacters escaped.
        escaped = re.sub(r"([\\'\"`$&|;<>()*?!#~])", r"\\\1", args[0]).replace(" ", "%s")
        adb(serial, "shell", "input", "text", escaped)
        return 0
    if cmd == "clear" and not args:
        if not adb(serial, "shell", "input", "keycombination", "113", "29", allow_failure=True):
            adb(serial, "shell", "input", "keyevent", "KEYCODE_MOVE_END")
            adb(serial, "shell", "input", "keyevent", *(["KEYCODE_DEL"] * 50))
        else:
            adb(serial, "shell", "input", "keyevent", "KEYCODE_DEL")
        return 0
    if cmd == "key" and len(args) == 1:
        k = args[0] if args[0].startswith("KEYCODE_") or args[0].isdigit() else "KEYCODE_" + args[0].upper()
        adb(serial, "shell", "input", "keyevent", k)
        return 0
    if cmd == "screenshot" and len(args) == 1:
        png = adb(serial, "exec-out", "screencap", "-p", binary=True)
        if not png.startswith(b"\x89PNG"):
            fail("screencap didn't return a PNG")
        with open(args[0], "wb") as f:
            f.write(png)
        print(args[0])
        return 0
    if cmd == "launch" and len(args) == 1:
        adb(serial, "shell", "am", "force-stop", args[0])
        adb(serial, "shell", "monkey", "-p", args[0], "-c", "android.intent.category.LAUNCHER", "1")
        return 0
    print(__doc__.strip(), file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

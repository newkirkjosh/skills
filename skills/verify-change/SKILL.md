---
name: verify-change
description: "Explicit-use only — invoke when the user explicitly names this skill, or when an active explicitly invoked workflow calls it. Verifies a change in the running app, not just its tests: web in headless Playwright, a Kotlin Multiplatform desktop app on an off-screen display, Android on a headless emulator driven by on-screen text, reporting PASS, FAIL or NOT RUN per check with the evidence behind each."
license: MIT (the idea adapted from fx/skills verify-web-change by Marian Rudzynski; see LICENSE.txt)
metadata:
  type: flexible
  upstream: "https://github.com/fx/skills/tree/4b1010d/skills/verify-web-change"
---

# Verify Change

## When to Use

**Explicit use only.** The user names this skill, or a workflow calls it: `dev`'s evaluator follows it when a repository's `AGENTS.md` names it as the way to verify the app, and `ship` or `pr` may run it for a test plan item that needs the running app. The run ends at its report; a later request doesn't inherit it.

It answers one question per check: **does the running app do what the change claims?** Unit tests and screenshot tests are someone else's job; this skill exists for the gap between "the build is green" and "the screen does it".

## Inputs

1. **The checks.** From the caller (a sprint contract, a PR test plan), each one observable: "after adding a book, the Library tab lists it", never "works correctly". Without checks, derive them from the diff and say you did.
2. **How this repository runs.** Read its `AGENTS.md` and rule files first: the build command per target, the app ID, how to start the backend and seed data, which server URL each target uses, how to get a signed-in user, and setup that gates screens (for example, an account and a group). These recipes belong in the repository’s `AGENTS.md`; report a missing recipe. Project specifics live there, not here. Missing ones are a gap to report, not something to guess.
3. **This machine's recipes.** The off-screen display and emulator settings are in the user's global instructions. Use them as written.

### Backend

Start what the app needs: a database container with a unique name, then the server. Wait for readiness with a bounded poll on its port or health endpoint. Keep the container names and process PIDs; after stopping the emulator, stop the backend resources in reverse startup order, including on failure.

## Targets

Pick the target the change shows up on; verify on more than one only when the change is shared code whose behaviour differs by platform.

### Android (emulator)

Bundled scripts, measured on a real run: a headless boot resumes from the AVD's snapshot in about 20 seconds, and a launch, three text waits, a tap and a screenshot take about 8.

```bash
S=<skill-dir>/scripts
bash $S/android-emulator.sh up --avd <AVD>           # STATUS=READY serial=emulator-5554 boot_s=19
adb -s emulator-5554 install -r <app>.apk
U="python3 -I $S/android-ui.py --serial emulator-5554"
$U launch <app.id>
$U wait "Library" --timeout 30                       # exact text, content-desc or resource-id
$U tap "~add book"                                   # ~ = case-insensitive substring
$U type "dune" && $U key ENTER
$U wait "Dune" --timeout 30                         # exact result title, not the typed substring
$U tap "Add" --below "Dune" --nth 1                  # first matching action below this title
$U screenshot <scratch>/after-search.png
bash $S/android-emulator.sh down                     # always, even after a failure
```

- `up` runs the emulator under an exclusive lock in the repository's git common dir (`locks/emulator`), so every worktree of a repo shares one device: a second `up` gets `STATUS=BUSY` (exit 4) and should wait for, not steal, the device. It turns animations off and unlocks the screen, so waits and taps are deterministic.
- Every `wait` is bounded and every `tap` is by what a user sees. Never tap coordinates you computed by hand, never `sleep` and hope.
- **Server URL.** The emulator reaches the host as `10.0.2.2`; a physical device can't. For a device, `adb reverse tcp:<port> tcp:<port>` and a URL the build can point at (the global instructions say the same).
- A booted device is reused only for the same recorded lock path and AVD; another lock or AVD, or a device still booting, returns `BUSY`. Ownership records are published only after acquiring the device lock.
- `down` stops the emulator and its whole process group, and returns `STOPPED` only once the lock is free.

The UI helper requires `--serial` or `ANDROID_SERIAL` and a matching live emulator PID record from `android-emulator.sh`. To target an unmanaged device, pass `--serial <serial> --device` before the command; a physical device needs the user’s explicit say-so. `type` rejects control characters and literal `%s` because Android would change the latter into a space.

The UI helper commands are `dump`, `find QUERY`, `tap QUERY`, `wait QUERY`, `gone QUERY`, `type TEXT`, `clear`, `key KEYCODE`, `screenshot FILE`, and `launch PACKAGE`. `find` and `tap` accept `--nth N` (1-based document order), `--last`, and `--below QUERY` (top edge below the first anchor's bottom). Without an explicit position, `tap` prefers a clickable match. `find`, `wait`, `gone`, and `tap` skip editable nodes unless `--include-editable` is given; use it with a resource-id or exact hint text to target a field. `dump` prints the short class and flags C clickable, F focused, K checked, S selected, E editable. `clear` uses CTRL+A then Delete on Android 12+; if keycombination fails, it moves to the end and sends 50 Deletes, so longer input may need another clear.

### Desktop (Kotlin Multiplatform, Compose for Desktop)

Run the app on the off-screen display from the user's global instructions, never the real desktop. Set `DISPLAY` explicitly on **every** launch, input and screenshot command, and use only display-scoped input tools (`xdotool`); a device-level tool such as `ydotool` reaches the user's real desktop whatever `DISPLAY` says. Find the window with `xdotool search --sync --name <title>` rather than sleeping, act, and take the screenshot with the recipe's command. Stop the app and anything it started.

### Web

Headless Playwright with Chromium, run inside a dev workspace, where it's baked in and files you write keep your ownership. Start the app as `AGENTS.md` says and wait for its port with a bounded `curl` loop, then per check: navigate, wait for the text or role the check names, act through roles and labels (`getByRole`, `getByLabel`), screenshot, and record **console errors, failed requests and 4xx/5xx responses**: a page can look right while throwing. `assets/web-check.cjs` does the load, text, screenshot and error part (measured: about 7 seconds for a static site); it then gives late requests a short settle window (`--settle`, default 3 s) and reports errors seen in it, without requiring the network to go idle, which a page holding a persistent connection never does. Copy it for clicks and form input:

```bash
NODE_PATH="$(npm root -g)" node <skill-dir>/assets/web-check.cjs http://localhost:<port>/ \
  --expect "<text the check names>" --screenshot <scratch>/home.png
```

Without a workspace, install a pinned Playwright into a throwaway directory, never a bare `npx playwright` (that runs whatever release is current), and point both the browser install and the script at it. Use the version the workspace image pins (1.64.1 when this was written):

```bash
pw="$(mktemp -d)" && npm install --prefix "$pw" --no-save playwright@1.64.1
"$pw/node_modules/.bin/playwright" install chromium
NODE_PATH="$pw/node_modules" node <skill-dir>/assets/web-check.cjs http://localhost:<port>/ --expect "<text>"
rm -rf "$pw"
```

## Report

One row per check, nothing else counts as evidence:

```
- [x] <check> — PASS — <what was observed>, <screenshot path or command output>
- [ ] <check> — FAIL — expected <x>, saw <y>, <screenshot>
- [ ] <check> — NOT RUN — <what was missing: an AVD, a running backend, a device>
```

Add timings for build, backend start, emulator boot, and each check, so a slow verification shows where its time went. NOT RUN is an honest outcome; never fake the missing piece (a stubbed login, a hand-seeded database the check didn't ask for) to reach PASS.

## Gotchas

- **Compose test tags aren't visible to uiautomator** unless the app sets `testTagsAsResourceId = true` on a root `Modifier.semantics`. Without it, match by text or content description.
- **`uiautomator dump` fails while the screen animates** ("could not get idle state"). Animations are off after `up`; on a device you started yourself, turn them off first.
- **Never find a process with `pgrep -f <pattern>` from a shell whose command line contains that pattern**: it matches itself, and a stopped emulator looks alive. Use the state the scripts report.
- **A cold boot is minutes, a snapshot resume seconds.** `up` saves no snapshot, so a boot that changed state doesn't slow the next one; if boots get slow, the AVD's quickboot snapshot is gone, and one interactive cold boot that saves it fixes that.
- **The workspace image has no `python3`.** For a quick static server use the app's own dev server, or a few lines of Node (`http.createServer`).
- **The live desktop is off limits**, for every target: no real `DISPLAY`, no device-level input, no window on the user's screen.

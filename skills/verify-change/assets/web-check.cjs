// Starting point for a web check: load a page in headless Chromium, wait for
// each expected text, screenshot it, and fail on console errors or failed
// requests, which a page can have while looking right.
//
// usage: NODE_PATH="$(npm root -g)" node web-check.cjs URL --expect TEXT [--expect TEXT ...]
//          [--screenshot FILE] [--timeout MS] [--settle MS] [--allow-console REGEX]
// Exit: 0 every text found and no errors, 1 a check failed, 2 usage.
// Copy and extend it for clicks and form input (page.getByRole, page.getByLabel).
const { chromium } = require("playwright");

const argv = process.argv.slice(2);
const url = argv.shift();
const expect = [];
let screenshot = null, timeout = 15000, allow = null, settle = 3000;
while (argv.length) {
  const flag = argv.shift(), value = argv.shift();
  if (value === undefined) usage();
  if (flag === "--expect") expect.push(value);
  else if (flag === "--screenshot") screenshot = value;
  else if (flag === "--timeout") timeout = Number(value);
  else if (flag === "--settle") settle = Number(value);
  else if (flag === "--allow-console") allow = new RegExp(value);
  else usage();
}
if (!url || !expect.length || !(timeout > 0) || !(settle >= 0)) usage();

function usage() {
  console.error("usage: node web-check.cjs URL --expect TEXT [--expect TEXT ...] [--screenshot FILE] [--timeout MS] [--settle MS] [--allow-console REGEX]");
  process.exit(2);
}

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  const problems = [];
  page.on("console", (m) => {
    if (m.type() === "error" && !(allow && allow.test(m.text()))) problems.push(`console error: ${m.text()}`);
  });
  page.on("pageerror", (e) => problems.push(`uncaught: ${e.message}`));
  page.on("requestfailed", (r) => problems.push(`request failed: ${r.url()} (${r.failure()?.errorText})`));
  page.on("response", (r) => { if (r.status() >= 400) problems.push(`HTTP ${r.status()}: ${r.url()}`); });

  let failed = false;
  try {
    const resp = await page.goto(url, { waitUntil: "load", timeout });
    console.log(`loaded ${url} (HTTP ${resp ? resp.status() : "?"})`);
    for (const text of expect) {
      try {
        await page.getByText(text, { exact: false }).filter({ visible: true }).first().waitFor({ state: "visible", timeout });
        console.log(`PASS  text visible: ${text}`);
      } catch {
        console.log(`FAIL  text not visible within ${timeout} ms: ${text}`);
        failed = true;
      }
    }
    // A bounded settle window, not a requirement: late requests that fail inside it
    // are caught, but a page holding a persistent connection (SSE, long polling)
    // never goes idle and mustn't fail for that alone.
    // Playwright reads timeout 0 as "no timeout", so --settle 0 skips the wait instead.
    if (settle > 0) {
      // Only a timeout means "still busy"; a crashed page or a closed browser is a failure.
      await page.waitForLoadState("networkidle", { timeout: settle }).catch((e) => {
        if (e.name !== "TimeoutError") throw e;
        console.log(`note: network still busy after ${settle} ms (a persistent connection?); reporting errors seen so far`);
      });
    }
    if (screenshot) {
      await page.screenshot({ path: screenshot, fullPage: true });
      console.log(`screenshot: ${screenshot}`);
    }
  } catch (e) {
    console.log(`FAIL  ${e.message.split("\n")[0]}`);
    failed = true;
  }
  for (const p of problems) console.log(`FAIL  ${p}`);
  await browser.close();
  process.exit(failed || problems.length ? 1 : 0);
})();

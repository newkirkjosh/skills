---
name: unifi
description: "Explicit-use only — invoke when the user explicitly names this skill, or when an active explicitly invoked workflow calls it. Reference guidance for reading and changing a UniFi network through its APIs: choosing between the official Network API (cloud connector or local key) and the console's web-UI API, logging in with a view-only local account, keeping credentials off the command line, diagnosing Wi-Fi and client problems, and getting approval before any change."
license: MIT
---

# UniFi

A UniFi console exposes two APIs. The **official Network API** is documented, versioned and covers configuration. The **web-UI API** is what the Network web app itself calls: undocumented, but it is the only source of per-client radio stats, the event log and short-term history. Most diagnosis needs both.

## Docs first, never a pinned version

UniFi moves endpoints between releases. Resolve the current surface at the start of every task instead of trusting paths remembered from an earlier one:

1. `https://developer.ui.com/llms.txt`: which APIs exist and their current versions.
2. `https://developer.ui.com/<service>/<version>/llms.txt`: that API's endpoint list.
3. `https://developer.ui.com/<service>/<version>/openapi.json`: request and response shapes, and the base URLs in `servers` (cloud connector and local console).

Don't write a version number into notes, scripts or answers unless the task depends on it. The web-UI API has no docs; `references/web-ui-api.md` says how to discover its endpoints.

## Pick the access path

| Need | Path | Credential |
|---|---|---|
| Inventory, config, and changes the official API supports | Official API through the cloud connector | Site Manager API key, created at unifi.ui.com |
| Same, without the cloud hop | Official API on the console | Local API key, created in the Network app's integration settings |
| Client signal, band, retries, roams, event log, 5-minute and hourly history, switch port counters | Web-UI API on the console | A local-only admin with the **View Only** role |
| Firewall mode, zones and policies | Official API: `GET .../sites/{siteId}/firewall/zones` and `.../firewall/policies` | Either API key (verified through the cloud connector). A 400 `api.firewall.zone-based-firewall-not-configured` means the site is still on the legacy firewall; read its rules from `rest/firewallrule` on the web-UI API |
| Shell-level data nothing else exposes | SSH | Root. Last resort, read-only commands, user approval per session |

A Site Manager key works only through the cloud connector; the console rejects it locally with 401. The cloud connector path needs the console ID from `GET https://api.ui.com/v1/hosts`.

## Rules

- **Credentials never touch argv.** Take them from the user's secret store into an environment variable or stdin; the bundled scripts pass them to curl through `-K -` and `--data @-`. Never print one. Mechanics: the shell skill.
- **Default to read-only.** Ask the user to create a dedicated local-only View Only admin for the web-UI API, and to confirm the role: the API's `self` endpoint does not report it.
- **Every change is approved first.** Before any non-GET call that changes state, show the method, path, body and what it will change, and wait for a yes. Make changes through the official API. The web-UI API is for reading; its POSTs are used only for log and report queries (`scripts/unifi-local.sh` refuses others).
- **Identify the exact device before analysing.** Ask which device, where it sits, whether it moves, and what the symptom is. Households often have look-alike names ("work" and "personal" laptops on different access points); analysing the wrong one wastes the whole pass.
- **Keep findings about the user's network out of shared files.** MACs, IPs, device names, console IDs and SSIDs go in memory or the user's own notes, never in a skill or a public repo.

## Scripts

- `bash scripts/unifi-api.sh <METHOD> <url> [body.json]`: official API. Needs `UNIFI_API_KEY`. Its output ends with an `HTTP <code>` line after the body, so check that code and drop the line (`sed '$d'`) before handing the body to `jq`, which otherwise fails with a parse error.
- `bash scripts/unifi-local.sh login|get <path>|query <path> <json>`: web-UI API. Needs `UNIFI_HOST`, plus `UNIFI_USER` and `UNIFI_PASS` for `login`. Keeps the session cookie and CSRF token in a private runtime directory.
- `bash scripts/test-scripts.sh`: offline tests for both, against stub `curl` and `jq`. Run after changing either script.

## References

- `references/web-ui-api.md`: login flow, discovering endpoints from the web app, starting-point paths. Read before the first web-UI call.
- `references/wifi-diagnostics.md`: the playbook for lag, dropouts and slow Wi-Fi. Read when the task is diagnosis.

## Gotchas

- An empty list from a classic web-UI path (`api/s/<site>/...`) can be an error: check `meta.rc`. `api.err.NotFound` means the endpoint moved; rediscover it, don't conclude there is no data. v2 paths return plain JSON with no `meta`, and some (`firewall-policies`, `firewall/zone-matrix`) return a bare `[]` both when a feature is off and when nothing is configured, so an empty answer settles nothing. Ask the other access path before telling the user something can't be read or asking them to check the UI.
- UniFi's client fingerprint fields (`dev_cat`, `dev_id`, `os_name`) are bare numbers, and there is no reliable lookup endpoint for them. To name unknown smart-home clients, browse mDNS from a machine on the same LAN (`avahi-browse -artp` resolves every instance at once; on macOS, list types with `dns-sd -B _services._dns-sd._udp local.`, browse one with `dns-sd -B <type> local.`, then resolve an instance with `dns-sd -L '<instance>' <type> local.`). Instance names, hostnames and TXT records are clues, often naming the model (Cast, Matter, Thread `_trel`/`_meshcop`, AirPlay, Spotify Connect), but what each service exposes varies. When planning VLANs, keeping Thread border routers and Matter controllers on the same VLAN as the Wi-Fi/Ethernet devices they control is the simplest topology, not a requirement: split VLANs work only with IPv6 routing, mDNS reflection and firewall rules that allow it, so test discovery before moving them apart.
- A switch port's `mac_table_count` is a hint about a downstream consumer router, not proof: 1 learned MAC often means router mode (clients behind it are NATed and invisible to UniFi, yet can still open connections into the LAN it sits on), and many MACs often mean it is bridging as an access point or switch. Corroborate before planning isolation around it: in router mode, check the router's own LAN/DHCP settings or ask its owner; in AP mode, its clients show up in UniFi with LAN addresses.
- Picking a free address for a new device: the official API's client list holds only clients connected right now, and it has no DHCP reservation (fixed IP) endpoint to read or create one. An address missing from it can still be reserved for, or held by, a device that's offline. Combine the network's DHCP range, the connected clients and the user's own address records (an inventory, a homelab repo). Then have the user make the reservation in the Network app, which is the final check, or read reservations from the web-UI API's known-client list (`rest/user`; confirm its fixed-IP fields first) with a View Only admin.
- The official API has no per-client signal, band or retry data and no event log. Don't infer radio health from it; use the web-UI API.
- Channel numbers alone don't prove radar (DFS) trouble. Look for radar events in the log before blaming it.
- Many networks re-pick channels every night, which shows up as channel changes and client reconnects at the same early-morning minute. Don't mistake them for the user's problem.
- Some access points report uplink error counters larger than their packet counters. Read errors from the switch port on the other end.
- A switch shown offline can still pass traffic; only its management connection is lost. `last_seen` says since when. Restarting a PoE switch also reboots everything it powers, which confounds any before/after test.
- Short-term history is short (often about a day for 5-minute data). Check the oldest point returned instead of assuming the window, and ask the user to report problems promptly.

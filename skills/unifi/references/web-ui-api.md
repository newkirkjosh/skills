# The web-UI API

The Network web app talks to the console through an undocumented API. Nothing here is guaranteed; treat every path as a starting point and confirm it against the running console.

## Login

On a UniFi OS console:

1. `POST https://<console>/api/auth/login` with JSON `{"username","password","rememberMe":false}`. The response sets a session cookie and returns an `X-CSRF-Token` header.
2. Network app paths sit under `https://<console>/proxy/network/`.
3. GETs need only the cookie. POSTs also need the `X-CSRF-Token` header.
4. Consoles use a self-signed certificate, so curl needs `-k` on the LAN.

`bash scripts/unifi-local.sh login` does all of this and stores the cookie and token in a private runtime directory. A 401 later means the session expired; log in again.

Use a local-only account. A cloud (UI account) login can require MFA and is not a View Only role.

## Discovering endpoints

When a path returns `api.err.NotFound`, or you need data no listed path gives:

1. Open the Network web app in a browser and the developer tools' Network tab.
2. Open the screen that shows the data (a client's details, the event log, a switch's ports).
3. Find the request that returned it. Copy its method, path and JSON body. Never copy cookies or tokens into notes.
4. Replay it with `unifi-local.sh get` or `query`.

## Response shapes

- Classic paths (`/proxy/network/api/s/<site>/...`) return `{"meta":{"rc":"ok"|"error","msg":...},"data":[...]}`. An error comes back with an empty `data` list, so always check `meta.rc`.
- Newer paths (`/proxy/network/v2/api/site/<site>/...`) return plain JSON with their own paging fields.
- `<site>` is the site's short name (often `default`), not the UUID the official API uses.

## Starting-point paths

These are shapes to try first, not a contract. Confirm each with a real call.

| Data | Request |
|---|---|
| Logged-in account | `GET api/self` |
| Live clients: band, channel, signal, noise, rates, retries, roam count, connected access point | `GET api/s/<site>/stat/sta` |
| Devices: radios and their load, min-RSSI settings, port tables with error and drop counters, uplinks, `last_seen` | `GET api/s/<site>/stat/device` |
| Wi-Fi network settings: fast roaming, BSS transition, band steering | `GET api/s/<site>/rest/wlanconf` |
| Network and WAN settings, including smart queues | `GET api/s/<site>/rest/networkconf` |
| Subsystem health | `GET api/s/<site>/stat/health` |
| Event log: roams, disconnects, channel changes, radar, ISP latency | `POST v2/api/site/<site>/system-log/all` with `{"timestampFrom":<ms>,"timestampTo":<ms>,"pageSize":<n>,"pageNumber":0}` |
| History per client or access point | `POST api/s/<site>/stat/report/<5minutes|hourly|daily>.<user|ap>` with `{"attrs":[...],"macs":[...],"start":<ms>,"end":<ms>}` |

Paths are relative to `/proxy/network/`. History `attrs` include `time`, `signal`, `satisfaction`, `tx_retries`, `wifi_tx_attempts`, `rx_bytes`, `tx_bytes`, `num_sta`, and per-band channel use such as `na-cu_total`.

Event log entries carry their details under `parameters`: for a roam, the access points and the signal before and after; for a disconnect, the duration and average interference.

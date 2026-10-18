# Diagnosing lag, dropouts and slow Wi-Fi

Work from the device outward: the client, its radio link, its access point, the cable behind that access point, then the internet connection. Rule each layer in or out with evidence before moving on.

## 1. Pin down the case

Ask before pulling data:

- Which device exactly, and which app (video call, game, browser)?
- When it happens: a time to the minute is worth more than any statistic.
- What the symptom is: frozen video, robotic audio, full drop, slow loads. How long it lasts.
- Whether the device moves around or stays in one spot.
- Whether other devices in the same place have the same problem.

The last answer splits the search. One device only: suspect that device, its VPN or its radio link. Several devices on the same access point: suspect the access point, its cable, or the internet connection.

## 2. Client link now

From the live client list, for the device's MAC: band, channel, channel width, signal, noise, link rates, retry percentage, Wi-Fi experience score, roam count, and which access point it is on.

Rough reading: signal above about -60 dBm with high link rates is a healthy link. A client on 2.4 GHz when it could use 5 GHz is suspect, especially when that 2.4 GHz radio is busy.

A healthy link right now doesn't clear an intermittent problem; continue to the history.

## 3. Client history

Event log, filtered to the device's MAC:

- **Roams:** where from, where to, and the signal before. Roams that happen at the same weak signal each time often match the access points' minimum-RSSI setting, which kicks clients off instead of letting them choose.
- **Disconnects:** time, duration, signal, average interference.
- **Band changes**, for example landing on 2.4 GHz after the nightly channel change.

Then the 5-minute history for the reported time: signal, retries, experience score, traffic. Line it up with the user's times.

Settings to compare against: fast roaming (802.11r) and BSS transition on the Wi-Fi network, and minimum RSSI per radio. Without fast roaming, every roam is a full reconnect, which can freeze a call for a second or more.

## 4. Access point

- Radio load: channel use in total and from the AP's own traffic, retries and client count per radio, now and in the 5-minute access point history.
- Radar events and channel changes in the log at the reported times.
- Uptime, and whether other access points serve the same area.

## 5. Wired path

Find the switch port the access point uplinks to and read its error and drop counters there, not on the access point. Compare with the switch's other ports. Errors climbing on one port point to the cable, a patch cable or the port itself.

Counters reset when a device restarts. After a restart, check again after the next incident.

A switch with a stale `last_seen` is passing traffic unmanaged; it can't be checked until it reconnects.

## 6. Internet connection

- ISP latency or WAN events in the log.
- Smart queue (SQM) settings on the WAN. Off, with heavy uploads on the network, is a classic cause of call lag.
- The gateway's own WAN link speed and errors.

## 7. When 5-minute averages are too coarse

A ten-second freeze disappears in a 5-minute average. Run a per-second ping logger from a wired machine to four targets:

| Target | What it isolates |
|---|---|
| Gateway | Baseline for the logging machine itself |
| The access point | Cable and switch path |
| The affected client | The radio link |
| A public resolver | The internet connection |

Run it as a user-level service with daily log files and a retention limit (the shell skill covers starting background work you can stop). Laptops with a stealth firewall don't answer ping, and Wi-Fi power saving produces single slow replies. Look for clusters of slow or missing replies at the reported times, not single spikes.

## 8. A/B tests the user runs

The read-only account can't make changes; these are for the user, one at a time:

1. Lock the client to a different access point for one session (the client's settings in the Network app).
2. Move the access point's cable to another switch port, or swap the patch cable.
3. Turn on fast roaming, or relax minimum RSSI, when roaming at the threshold is the evidence.
4. Repeat the session with the VPN off, or on another device in the same spot.

Change one thing per test so the result means something.

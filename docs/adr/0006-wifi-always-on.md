# 6. WiFi stays on with trusted credentials, no toggle model

## Status

Accepted

## Context

The original plan for WiFi was a deliberate middle ground: zero stored credentials by default, only temporarily enabled via a pair of scripts (`hardpass-wifi-enable`/`hardpass-wifi-disable`) for the one case that actually needs it, Android compatibility (see ADR 0008), since Android can't use the USB gadget link at all.

Revisited this after actually living with the device day to day. Credentials only ever get added for networks already trusted, and keeping WiFi always on turned out to be useful well beyond the Android case: it's what made most of this project's own debugging possible in the first place, reaching the device over SSH without needing the USB link connected at all.

One related question came up too: if the device is taken somewhere with no recognized network in range, does boot hang or slow down waiting for WiFi? Tested directly, not assumed: temporarily pointed `wpa_supplicant.conf` at a network that can't possibly exist, rebooted, and checked via `rc-status` that `wpa_supplicant` itself reports its own failure, while every other service starts completely normally. Total boot time to reachable over the gadget link was unaffected.

## Decision

Keep WiFi always enabled, with trusted credentials stored persistently for networks already known. Add `hardpass-wifi-add <ssid> <psk>` as the one piece that was actually missing, a way to add new trusted networks remotely over SSH, without removing the SD card. Drop the enable/disable toggle scripts from the original plan.

## Consequences

- Convenient remote access for maintenance and debugging, not just for Android.
- A missing or unreachable network has no effect on boot time or on any other service, checked directly instead of assumed.
- `hardpass-wifi-add` uses `wpa_cli` to add and enable a network live, then saves it to `wpa_supplicant.conf` so it persists across reboots, confirmed with a real add-save-remove cycle that existing networks are preserved correctly.

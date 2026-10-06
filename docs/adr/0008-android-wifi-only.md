# 8. Android is not supported over USB, WiFi only

## Status

Accepted

## Context

The dual-configuration gadget (ADR 0003) handles FreeBSD and macOS correctly. Android was tested the same way, directly, since an earlier attempt with the previous device had already hit a wall here and it was worth confirming rather than assuming the same result.

Connected a real Android phone (OTG, direct cable, no adapter) to the gadget, then used `adb logcat` to see what happened during that connection (`dmesg` is permission-restricted on stock Android). The phone's own `UsbHostManager` logs show it genuinely saw and correctly parsed both offered configurations, RNDIS and CDC-ECM. Descriptor-level enumeration works fine, same as FreeBSD and macOS.

Nothing past that point ever claimed the device as a network interface. `UsbHostManager` is Android's generic, app-level USB enumeration, used by apps wanting raw USB device access (confirmed here: the only thing that reacted to the attach event was F-Droid's own "Nearby" USB feature). No kernel-level network driver exists on stock Android for this direction at all. Checked the same phone's logs from the other direction too, reconnected to a regular computer for ADB: Android's own tethering stack lit up immediately (`Tethering: adding IpServer for: rndis0`), confirming the driver support genuinely only exists for phone-as-gadget, not phone-as-host.

## Decision

Don't attempt to support Android over the USB gadget link. Reaching HardPass from Android goes over WiFi instead (see ADR 0006).

## Consequences

- Making this work would require either a rooted phone with a custom kernel module, or a third-party app reimplementing the entire USB-Ethernet protocol in userspace via Android's USB Host API. Both are far outside this project's reasonable scope.
- This is a confirmed platform limitation, not a configuration gap, so there's nothing left to chase here on the Pi's side.

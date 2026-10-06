# 3. Dual-configuration USB gadget instead of a single mode

## Status

Accepted

## Context

The whole point of this device is plugging it into whatever computer is at hand and having it just work. That only holds if the USB gadget actually negotiates correctly with each host OS, and it turns out no single gadget mode does that.

A few things were tried and ruled out, each for a specific, confirmed reason:

- **`xg_multi`'s full composite gadget** (serial + ethernet): caused a `dwc2` instability with FreeBSD specifically (`USB_ERR_IOERROR`/`USB_ERR_TIMEOUT`, interface flapping), and later, the same instability showed up with macOS too. Not host-specific, a property of the composite gadget itself.
- **RNDIS only**: FreeBSD's `urndis(4)` driver works with this cleanly. macOS has no native RNDIS driver at all; a plain RNDIS gadget never gets further than a generic, unmatched USB device on macOS.
- **CDC-ECM only**: macOS handles this natively. FreeBSD's `cdce(4)` driver only marks its link state up after receiving a `UCDC_N_NETWORK_CONNECTION` notification from the gadget, checked directly in its own source (`sys/dev/usb/net/if_cdce.c`). The Linux ECM gadget function negotiates fine from its own side without ever sending that specific notification in this setup, so FreeBSD gets stuck at "no carrier" with zero actual data flow, confirmed via `tcpdump` on both ends showing nothing in either direction, despite the interface reporting itself as up.

FreeBSD needs RNDIS. macOS needs ECM. Not out of preference, each for its own concrete, driver-level reason.

## Decision

Build a `configfs` USB gadget offering two configurations simultaneously: RNDIS as config `c.1`, CDC-ECM as config `c.2`, both bound to the same UDC at once. Each host's own USB enumeration selects whichever configuration its driver understands, via the standard `SET_CONFIGURATION` step. No fallback logic, no teardown-and-retry between modes.

## Consequences

- Confirmed directly, with real data flow (not just interface-up status): FreeBSD selects RNDIS, macOS selects ECM, from the exact same gadget, no reconfiguration needed between hosts.
- Android is the one host this doesn't help. It sees both configurations at the USB descriptor level (confirmed via Android's own `UsbHostManager` logs), but stock Android has no kernel driver for using an external USB-Ethernet device as a host at all, only the reverse direction. See ADR 0008.
- The gadget script needs its own IP-assignment logic (not a static `/etc/network/interfaces` entry per interface), since only one of the two possible interfaces is ever actually active at a time, and assigning the same static address to both caused ARP inconsistencies that took a bit of `tcpdump` digging to track down.
- A `dwc2` controller quirk, unrelated to the gadget configuration itself: repeated same-boot gadget rebind/reconfigure cycles can get the controller into a state where enumeration succeeds but zero data flows, independent of which gadget mode is active. A full power cycle clears it. This one cost a fair amount of wasted debugging time before being correctly identified, since it looks identical to a protocol-level failure. Any gadget-related fix needs validating on a truly fresh boot, not one that's already been through several test cycles.

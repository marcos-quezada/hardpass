# 4. DHCP networking on the gadget link, not static IPs

## Status

Accepted

## Context

The first working version of the gadget link used static IPs on both ends: a fixed address on the Pi, manually assigned via `ip addr add` in the gadget setup script, and a matching manual `ifconfig` on the host side, automated on FreeBSD via a custom `devd` rule.

This worked for FreeBSD, but left macOS with no automation at all. Every time the gadget reattached, macOS assigned the interface a new name, and getting an address onto it meant finding that name and running `ifconfig` by hand. That's the opposite of "plug it in and it works."

An incident during testing raised the stakes on fixing this properly: connecting the Pi to macOS severed the Mac's own internet connectivity entirely. Root cause turned out to be several stale, leftover macOS network services from earlier testing sessions, sitting above Wi-Fi in the network service priority order, one of them still carrying a static IP/DNS configuration from a previous manual test. Static, manually-managed IPs on the client side made this kind of leftover-state problem easy to create and easy to miss.

## Decision

Run `dnsmasq` on the Pi, serving DHCP and DNS only on the gadget interfaces (`usb0`/`usb1`), explicitly excluded from `wlan0` so it can never interfere with the real network's own DHCP/DNS. Static per-MAC reservations mean whichever host connects always gets the same address automatically, no manual configuration needed on either end.

FreeBSD's side initially tried the standard, built-in mechanism (`ifconfig_ue0="DHCP"` plus `/etc/devd/dhclient.conf`), which exists specifically to automate this. It doesn't work for this device: that rule triggers on `LINK_UP`, and `urndis(4)` never fires that event at all, checked directly in its source. The actual fix is a minimal custom `devd` rule matching `ATTACH` instead, running `dhclient` directly. Simpler than the static-IP-era custom script it replaced, just not as simple as the fully standard mechanism would have been.

## Consequences

- Zero manual configuration needed on macOS at all; its built-in DHCP client handles everything the moment the interface appears.
- `dnsmasq` needed `--bind-dynamic`, not `--bind-interfaces`: only one of `usb0`/`usb1` ever exists at a time (whichever configuration the connected host selected), and `dnsmasq` refuses to start if a configured interface is simply absent unless told to tolerate that.
- Hostname resolution (`hardpass.local`) via the DHCP-provided scoped DNS resolver works correctly on FreeBSD, but not reliably on macOS: `.local` queries get routed to the regular public resolver instead of the scoped one, even with a DHCP-advertised search domain in place. A static `/etc/hosts` entry on each client remains the reliable path for `hardpass.local` on macOS.

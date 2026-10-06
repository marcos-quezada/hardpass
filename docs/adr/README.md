# Architecture decision records

This directory records the real decisions made while building HardPass, including the ones that changed partway through once new evidence showed up. Each one follows the same shape: context, decision, consequences.

- [0001 - Alpine Linux as the base OS](0001-alpine-linux-base-os.md)
- [0002 - Self-built musl Vaultwarden binary, not a distro package](0002-self-built-vaultwarden-binary.md)
- [0003 - Dual-configuration USB gadget instead of a single mode](0003-dual-configuration-usb-gadget.md)
- [0004 - DHCP networking on the gadget link, not static IPs](0004-dhcp-networking.md)
- [0005 - Minimal custom shutdown-button listener instead of triggerhappy](0005-custom-shutdown-button.md)
- [0006 - WiFi stays on with trusted credentials, no toggle model](0006-wifi-always-on.md)
- [0007 - Self-signed cert for now, private CA deferred](0007-tls-self-signed-cert.md)
- [0008 - Android is not supported over USB, WiFi only](0008-android-wifi-only.md)

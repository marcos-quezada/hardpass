# 1. Alpine Linux as the base OS

## Status

Accepted

## Context

The original device ran Raspberry Pi OS (Debian-based). After it suffered real filesystem corruption and needed a full rebuild, this was a chance to reconsider the base OS rather than just reinstalling the same thing.

This decision went through two reversals before landing, each one driven by a concrete finding, not indecision:

1. Alpine was the first choice, for footprint alone (a password manager running on a Pi Zero W doesn't need a full Debian install).
2. Switched to DietPi/Raspbian after discovering Vaultwarden's web vault needed a `musl` cross-compilation path that looked uncertain at the time, and DietPi's own repos had a working Vaultwarden package. This also meant dropping the original BYOPM guide's Docker-based install in favor of a bare-metal package install via DietPi-Software's own TUI, simpler and more efficient on hardware this constrained, a Pi Zero W has no real room to spare for a container runtime.
3. Switched back to Alpine once two things fell into place: a self-built, statically-linked `musl` Vaultwarden binary turned out to work fine (see ADR 0002, resolving the original concern), and extensive hardware debugging traced a persistent USB-gadget enumeration failure to an actual kernel regression in `raspberrypi/linux` on the `6.18.x` line ([raspberrypi/linux#7549](https://github.com/raspberrypi/linux/issues/7549): `dwc2` soft-disconnect pullup failures on Pi Zero W/Zero 2 W). The old device's last known-good kernel was `6.12.62`. Alpine's `edge` branch ships that same problematic `6.18.x` line, but its `v3.21`/`v3.22` stable releases pin `6.12.x`, matching the last known-good kernel family.

## Decision

Use Alpine Linux `v3.22` (not `edge`, which ships the regression-affected kernel) as the base OS.

## Consequences

- Smaller footprint than a Debian-based install, OpenRC instead of systemd.
- Some packages assumed to exist on Debian/DietPi don't exist on Alpine at all (`triggerhappy`, see ADR 0005) or aren't packaged for the stable branch (`xg_multi`, installed from `edge/community` as a one-off without switching the whole system to `edge`).
- Alpine's repo configuration has to be pinned explicitly (`v3.22`, never `edge` or `v3.24`, both of which ship the `6.18.x` kernel line) and re-checked on every fresh install, since the default bootstrap config doesn't pin this itself.

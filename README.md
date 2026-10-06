## HardPass

HardPass is a self-hosted [Vaultwarden](https://github.com/dani-garcia/vaultwarden) password manager running on a Raspberry Pi Zero W, built around the same idea as [novamostra's BYOPM](https://novamostra.com/2022/10/23/byopm/): plug it into your computer over USB and it just works.

Connect it, wait a few seconds, and a new network interface shows up. Open `https://hardpass.local` and there's your vault. Unplug it, or hit the shutdown button, and it's gone until next time.

This repo documents a from-scratch rebuild of that idea. The original BYOPM device I'd been running for a couple of years started showing filesystem corruption, and once I started digging into how it was actually put together, I realized I'd never written any of it down. So this is that, done properly: Alpine Linux instead of Raspberry Pi OS, real adaptive USB gadget switching instead of one hardcoded mode, and most of the debugging left in the docs instead of quietly thrown away.

### How it works

The Pi shows up as a USB Ethernet device the moment it's plugged in, no drivers needed on either side. It actually offers two different USB configurations at once, and whatever you plug it into picks the one it understands:

- FreeBSD and Windows get RNDIS
- macOS and Linux get CDC-ECM

Both work off the same gadget, automatically, no switching required. DHCP hands out an address, `hardpass.local` resolves, and `nginx` serves Vaultwarden over HTTPS with a self-signed cert.

Android is the odd one out. It sees the device fine at the USB level, but stock Android just doesn't have a driver for treating an external USB-Ethernet device as a host, only the reverse (phone as gadget, tethering to a PC). I spent a while confirming this wasn't something I'd misconfigured before accepting it's a real platform limit. Short of rooting the phone, Android talks to HardPass over WiFi instead.

A physical button, wired through a GPIO shutdown overlay, powers it off cleanly. There's no SD card to pull for day-to-day use, anything that needs changing (WiFi credentials, mostly) happens live over the same USB link.

### Bill of materials

Carried over from the original BYOPM BOM:

1. Raspberry Pi Zero W (any revision; skip the "H" versions with a pre-soldered header if you want the case to sit flush)
2. A 6×6×6mm tactile push button
3. 3D-printed case (see acknowledgments below)
4. 3x M2 6mm screws
5. A short length of 3mm transparent acrylic rod, if your case design uses one for the activity LED

### Building one

The full build is in [`docs/guide.md`](docs/guide.md): flashing Alpine, the USB gadget setup, Vaultwarden, `nginx`, `dnsmasq`, and the shutdown button.

The real decisions behind the build, and why things aren't done the more obvious way in a few places, are written up as ADRs in [`docs/adr/`](docs/adr/).

### Potential improvements

- [ ] Replace the self-signed certificate with a private CA, so there's no per-client manual cert import at all (see [ADR 0007](docs/adr/0007-tls-self-signed-cert.md))
- [ ] Dig further into why macOS's scoped DNS resolver won't honor `.local` queries even with a matching DHCP search domain in place; `/etc/hosts` works fine as a stand-in, but it'd be nice not to need it
- [ ] Include the original BYOPM case STL files directly, pending a response on [this issue](https://github.com/novamostra/byopm/issues/1); linking to them for now
- [ ] A sync mechanism between this instance and a primary Bitwarden/Vaultwarden account, for anyone running both
- [ ] Revisit Android support if a rooted-phone or custom-kernel-module path ever seems worth the tradeoff (see [ADR 0008](docs/adr/0008-android-wifi-only.md) for why it doesn't work out of the box)

### Acknowledgments

None of this would exist without [novamostra's BYOPM guide](https://novamostra.com/2022/10/23/byopm/) ([GitHub](https://github.com/novamostra/byopm), [case files on Thingiverse](https://www.thingiverse.com/thing:5581692)). The idea, the hardware, the case, all of it traces back there. If you want the simpler, original version, start with that instead.

A few other projects this build depends on directly: [macmpi's `xg_multi`](https://github.com/macmpi/alpine-linux-headless-bootstrap) is where the gadget-switching approach in this repo's scripts comes from. [Vaultwarden](https://github.com/dani-garcia/vaultwarden) and its [web vault](https://github.com/dani-garcia/bw_web_builds) are what's actually running the password manager. And it's all sitting on top of [Alpine Linux](https://alpinelinux.org/).

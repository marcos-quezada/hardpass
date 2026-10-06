# Building HardPass

This is the actual build, start to finish. It assumes you've already got the hardware from the [bill of materials](../README.md#bill-of-materials) and a second computer (Mac, Linux, or BSD) to flash the SD card and cross-compile Vaultwarden.

The *why* behind a few of these steps, especially the ones that aren't the obvious choice, is written up separately in [`docs/adr/`](adr/). This guide just covers the *how*.

## 1. Flash Alpine Linux

Use Alpine `v3.22` specifically, not `edge` and not `v3.24`. Both of those ship a kernel with a confirmed `dwc2` regression on the Pi Zero W (see [ADR 0001](adr/0001-alpine-linux-base-os.md)). `v3.22` pins `linux-rpi 6.12.85`, which doesn't have the problem.

1. Flash the standard Alpine Linux ARMv6 image for Raspberry Pi with Raspberry Pi Imager, or `dd` it directly.
2. Before first boot, drop [macmpi's `alpine-linux-headless-bootstrap`](https://github.com/macmpi/alpine-linux-headless-bootstrap) (`headless.apkovl.tar.gz`) onto the boot partition. This gets you a temporary SSH session with no password, enough to run `setup-alpine` remotely instead of needing a monitor and keyboard.
3. Also on the boot partition, add to `usercfg.txt`:
   ```
   dtoverlay=gpio-shutdown
   ```
   Leave out `dtoverlay=dwc2,dr_mode=peripheral` for now. Adding the USB gadget overlay before the disk install is done causes the installer's disk-partitioning step to fail with `Resource busy` (the kernel can't reread the partition table of the disk it's installed from while the gadget interface is also active). Add it back after the install finishes.
4. Boot the Pi connected via its power-only port (not the data/OTG port), so nothing on the USB side interferes with the install.
5. SSH in using the bootstrap's temporary access, and before doing anything else, check `/etc/apk/repositories` and make sure it points at `v3.22`, not whatever the bootstrap defaulted to. Fix it if needed:
   ```
   http://dl-cdn.alpinelinux.org/alpine/v3.22/main
   http://dl-cdn.alpinelinux.org/alpine/v3.22/community
   ```
6. Run `setup-alpine` and go through the prompts: hostname `hardpass`, your WiFi network if you want it reachable that way too, a real disk install (not diskless).
7. Once it's done, add the gadget overlay back to `usercfg.txt`:
   ```
   dtoverlay=dwc2,dr_mode=peripheral
   ```
8. Reboot, and from here on connect the Pi through its data/OTG port instead.

## 2. The USB gadget

This is the part that makes the whole "plug it in and it works" idea actually work on more than one operating system. The short version: it offers two USB configurations at once (RNDIS and CDC-ECM), and whatever you plug it into picks the one it understands. The full reasoning, and what doesn't work, is in [ADR 0003](adr/0003-dual-configuration-usb-gadget.md).

1. Copy `hardpass-gadget` to `/usr/bin/hardpass-gadget` and make it executable.
2. Copy `hardpass-gadget.openrc` to `/etc/init.d/hardpass-gadget`, make it executable, and add it to the `sysinit` runlevel, not `boot`:
   ```sh
   rc-update add hardpass-gadget sysinit
   ```
   This matters: `sysinit` runs earlier than `boot`, closing the gap between the kernel loading the `dwc2` driver and the gadget actually being ready to respond when a host starts trying to enumerate it.
3. Copy `dnsmasq.conf` to `/etc/dnsmasq.conf`, install and enable `dnsmasq`:
   ```sh
   apk add dnsmasq
   rc-update add dnsmasq default
   ```
   This hands out a DHCP lease and resolves `hardpass.local` to whichever host connects, automatically, no manual `ifconfig` needed on either end.
4. Reboot and test: connect the Pi to a FreeBSD or macOS machine, wait a few seconds, and a new network interface should appear with an IP already assigned.

## 3. Vaultwarden

The binary here is self-compiled, statically linked against `musl`, no package manager involved (see [ADR 0002](adr/0002-self-built-vaultwarden-binary.md) for why).

1. On a separate machine, with [`cross`](https://github.com/cross-rs/cross) installed:
   ```sh
   git clone --depth 1 --branch <version> https://github.com/dani-garcia/vaultwarden.git
   cd vaultwarden
   cross build --target arm-unknown-linux-musleabihf --release \
     --no-default-features --features sqlite,vendored_openssl
   ```
2. Check which `web-vault` version that Vaultwarden release actually expects. It's pinned in Vaultwarden's own `docker/DockerSettings.yaml` under `vault_version`, don't assume "latest" is correct. Download that exact [`bw_web_builds`](https://github.com/dani-garcia/bw_web_builds) release.
3. On the Pi:
   ```sh
   adduser -S -D -H vaultwarden
   mkdir -p /opt/vaultwarden/data
   ```
   Copy the compiled binary to `/opt/vaultwarden/vaultwarden` and extract the `web-vault` release to `/opt/vaultwarden/web-vault`. Set ownership to the `vaultwarden` user.
4. Copy `vaultwarden/vaultwarden.env.template` to `/opt/vaultwarden/vaultwarden.env`, fill in a real `ADMIN_TOKEN` (`openssl rand -base64 48`), and set `SIGNUPS_ALLOWED=true` for now, just long enough to create your real account.
5. Copy `vaultwarden/vaultwarden.openrc` to `/etc/init.d/vaultwarden`, make it executable, and enable it:
   ```sh
   rc-update add vaultwarden default
   rc-service vaultwarden start
   ```
6. Once it's running, open the web vault through whatever reverse proxy setup you're on (see the next section first if this is a fresh install) and create your real account. Then set `SIGNUPS_ALLOWED=false` in the env file and restart the service.

Updating later is the same two commands: rebuild against a new tag, swap the binary, restart the service.

## 4. nginx and the certificate

A self-signed certificate for now, see [ADR 0007](adr/0007-tls-self-signed-cert.md) for why a proper private CA is a separate, later piece of work.

1. Install:
   ```sh
   apk add nginx openssl
   ```
2. Generate the certificate:
   ```sh
   mkdir -p /etc/nginx/ssl
   cd /etc/nginx/ssl
   openssl req -x509 -nodes -newkey rsa:4096 -keyout hardpass.key -out hardpass.crt \
     -days 3650 -subj '/CN=hardpass.local' \
     -addext 'subjectAltName=DNS:hardpass.local,IP:10.18.1.19'
   ```
   Skip generating a `dhparam` file. It's unnecessary for a self-signed, LAN-only setup, and on a Pi Zero's single core it can take long enough that it's not worth the wait.
3. Copy `nginx/hardpass.conf` to `/etc/nginx/http.d/hardpass.conf`, then:
   ```sh
   rc-update add nginx default
   rc-service nginx start
   ```
4. Import `hardpass.crt` into your browser's trusted certificate authorities, not just a per-tab exception. The Bitwarden browser extension's own network layer won't accept a per-tab exception; it needs the certificate properly trusted.

## 5. The shutdown button

Wired through the Pi's `gpio-shutdown` overlay (already added back in step 1). No `triggerhappy` here, Alpine doesn't package it at all, so this is a small, purpose-built replacement instead (see [ADR 0005](adr/0005-custom-shutdown-button.md)).

1. Build it on the Pi itself:
   ```sh
   apk add gcc musl-dev make linux-headers
   gcc -O2 -o hardpass-shutdown-btn shutdown-btn/hardpass-shutdown-btn.c
   mv hardpass-shutdown-btn /usr/bin/
   ```
2. Copy `shutdown-btn/hardpass-shutdown-btn.openrc` to `/etc/init.d/hardpass-shutdown-btn`, make it executable, and enable it:
   ```sh
   rc-update add hardpass-shutdown-btn boot
   rc-service hardpass-shutdown-btn start
   ```
3. Press the button. It should power off cleanly.

## 6. WiFi

WiFi stays on, with real credentials for networks you actually trust (see [ADR 0006](adr/0006-wifi-always-on.md) for why this isn't a toggle). It's not needed for the main USB workflow, but it's how you reach the device for maintenance without the gadget cable connected, and it's the only way Android can reach it at all (see [ADR 0008](adr/0008-android-wifi-only.md)).

To add a new trusted network later, over SSH, without touching the SD card:

```sh
hardpass-wifi-add "network-name" "password"
```

This adds the network live via `wpa_cli` and saves it to `/etc/wpa_supplicant/wpa_supplicant.conf`, so it's there on the next boot too.

## 7. Closing it up

Once everything above is working end to end, including a cold boot with the cable already connected from power-on, there's no remaining reason to need SD card access. Before closing the case for good:

- Confirm the case design doesn't block the shutdown button or the USB port.
- Do one more cold-boot test after closing it, just to rule out the case itself affecting heat or the button's mechanism.

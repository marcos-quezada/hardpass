# 2. Self-built musl Vaultwarden binary, not a distro package

## Status

Accepted

## Context

The original device's actual failure, once root-caused, wasn't the filesystem corruption that triggered the rebuild. It was a version gap: the Bitwarden browser extension's "unexpected error" traced to a 404 on `POST /identity/accounts/prelogin/password`, an endpoint added in Vaultwarden 1.36.0. The old device was running 1.35.3, installed via DietPi's own package, which lagged behind upstream releases.

Fixing that one gap (a manual `.deb` download, checksum verify, and an `openssl`/`libssl3t64` bump to match) worked, but it confirmed the real problem: relying on a distro's own packaging cadence for a security-relevant piece of software means waiting on someone else's release schedule, indefinitely, for every future update.

The alternative, self-compiling Vaultwarden directly from source, was blocked early on by an assumption that 32-bit ARM + `musl` wasn't a supported target. That assumption is what originally pushed this project toward DietPi/glibc instead of Alpine/musl (see ADR 0001).

## Decision

Cross-compile Vaultwarden directly from its own source, targeting `arm-unknown-linux-musleabihf` via `cross` (not Vaultwarden's own Dockerfiles, whose Alpine template explicitly doesn't support 32-bit ARM and whose Debian template targets glibc). Built with `--no-default-features --features sqlite,vendored_openssl`: bundled SQLite, `rustls` for the main TLS stack, vendored OpenSSL only for the narrower U2F/JWT dependency.

The resulting binary is statically linked, with zero runtime libc dependency at all, verified with `file`.

## Consequences

- Updating Vaultwarden going forward means re-running the same `cross` build against a new release tag, swapping the binary in, and restarting the service. No package manager, no repo lag, no container runtime needed on the Pi itself.
- The original motivating concern (a 32-bit ARM `musl` target not existing) was wrong. Rust has an officially-supported `arm-unknown-linux-musleabihf` target, the `musl` equivalent of Vaultwarden's own official `armv6`/`gnueabihf` builds.
- The build itself is slow (around 21 minutes under Docker/QEMU emulation on a different-architecture host), but this only matters at update time, not at runtime.

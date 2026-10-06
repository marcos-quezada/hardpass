# 5. Minimal custom shutdown-button listener instead of triggerhappy

## Status

Accepted

## Context

The hardware shutdown button is wired through the `gpio-shutdown` device tree overlay, which registers as a standard Linux input device (`/dev/input/event0`, visible in `/proc/bus/input/devices` as `soc:shutdown_button`). The original device used `triggerhappy` to listen for the button press and trigger a shutdown.

`triggerhappy` isn't packaged on Alpine at all, checked across the `main`, `community`, and `edge` repositories.

## Decision

Write a small, dependency-free C program instead: open the input device, read raw `input_event` structs, call `poweroff` on any key-press event. This device only ever emits one kind of event by design, so there's no need for `triggerhappy`'s general-purpose event-matching rule engine.

Compiled natively on the Pi itself (`gcc`, `musl-dev`, `make`, `linux-headers`, same architecture, no cross-compilation needed for this one), wired up as a minimal OpenRC service.

## Consequences

- No dependency on a package that doesn't exist on this OS.
- About 30 lines of C instead of a general-purpose daemon and its configuration file.
- Tested with the actual, physical button: a clean `poweroff` every time.

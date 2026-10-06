# 7. Self-signed cert for now, private CA deferred

## Status

Accepted, with a deferred follow-up

## Context

Vaultwarden needs HTTPS, and the Bitwarden browser extension specifically requires the certificate to be in the client's trusted Authorities store, not just accepted as a per-tab exception.

Let's Encrypt was considered and ruled out directly: it fundamentally requires live internet access to issue and renew certificates, even via the DNS-01 challenge variant that doesn't need a publicly reachable server. That's incompatible with keeping this device usable with no internet access on either end.

A private CA (a self-issued root certificate, installed once into each client's trust store, used to sign a leaf certificate for the device) would solve this properly and would work fully offline. It's a real piece of scoped work on its own, not something to build under time pressure alongside everything else.

Generating a `dhparam` file for stronger cipher support was also tried and abandoned: `openssl dhparam 2048` didn't finish after several minutes on the Pi Zero's weak single-core CPU, and it's unnecessary for a LAN-only, single-user, self-signed deployment regardless.

## Decision

Use a plain self-signed certificate for now (4096-bit RSA, 10-year validity, SAN covering `hardpass.local` and the gadget link's static IP), imported manually into each client's trust store. ECDHE-only cipher suites, no `dhparam`.

Build the private CA properly in a later, dedicated pass: a root keypair generated once on a regular computer (never on the Pi itself), a leaf certificate signed by it and deployed to the Pi, and the root certificate (not the leaf) imported into each client's trust store once, after which every future leaf certificate it signs is trusted automatically, no warnings, no internet required, ever.

## Consequences

- Works today, fully offline, with manual cert-trust import needed once per client.
- Renewing or regenerating the current certificate means re-importing it on every client again. The deferred private-CA work removes this entirely.

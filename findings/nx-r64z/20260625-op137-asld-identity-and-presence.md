# op-137 — asld daemon-identity + presence: GAP (asld absent from base image; base syslogd collides)

Date: 2026-06-25. Lane: `rmx-explorer-rx-x64z` (recon, read-only).

## VERDICT: GAP + CONFOUND

### 1. Harness selector (asld-lifecycle-harness.sh)

Process detection: `pgrep -x syslogd` (line 96, 116, 120, 125, 142, 155). The
harness keys on the process name "syslogd" — an exact-name match via `pgrep -x`.

The comment at line 93-95 says: "the process is named 'syslogd' on rmxOS because
PROG=asld in the Makefile but the binary is installed as /usr/sbin/syslogd; ps
shows the binary name." This assumes the asld binary IS installed at
`/usr/sbin/syslogd`. It IS NOT (see below).

### 2. asld presence (first-hand, base image + obj_root)

| location | status |
|---|---|
| **base image `/usr/sbin/asld`** | **ABSENT** |
| **base image `/usr/sbin/syslogd`** | **PRESENT** (70872 bytes — stock FreeBSD syslogd, Nov 28 2025) |
| **obj_root `usr.sbin/asl/asld`** | PRESENT (2460616 bytes — Apple ASL syslogd, built Jun 19) |
| **stage-userland.sh** | does NOT install asld or syslogd (no line for either) |
| **base image libasl.so.1** | PRESENT (staged by stage-userland.sh) |
| **base image `/etc/launchd.d/com.apple.syslogd.plist`** | PRESENT |

**The base image ships the stock FreeBSD `/usr/sbin/syslogd` but NOT the Apple
ASL `asld`.** stage-userland.sh installs `libasl.so.1` (the client library) but
NOT the daemon. The asld binary exists in the obj_root (built) but was never
installed into the image.

### 3. Running daemon collision

The base image has `/etc/rc.d/syslogd` (stock FreeBSD). If rc.conf enables it
(or if rc boots it), the stock FreeBSD syslogd runs as PID "syslogd" — which
`pgrep -x syslogd` would MATCH, producing a paper-green on the lifecycle
harness. But the stock syslogd is NOT the Apple ASL syslogd — it doesn't
register `com.apple.system.logger` via Mach bootstrap, so asl_log round-trips
would fail.

In op-116-cont, I installed asld AS `/usr/sbin/syslogd` (overwriting the stock
binary) to work around this gap. That worked for the functional matrix, but it
masks the GAP for the lifecycle harness: the harness assumes `/usr/sbin/syslogd`
IS the Apple ASL syslogd, but without the explicit asld→syslogd install step, it's
the stock FreeBSD syslogd.

### 4. Structured markers

```text
OP137_ASLD_PRESENT=0  (absent from base image /usr/sbin/asld)
OP137_DAEMON_IDENTITY=CONFOUND  (stock FreeBSD syslogd at /usr/sbin/syslogd collides with pgrep -x syslogd)
OP137_TERMINAL status=1  (GAP: asld not installed; stage-userland.sh missing the install)
```

## Impact on downstream ops

- **op-124 (Gatekeeper lifecycle/soak)**: BLOCKED until asld is installed into
  the image. The stage-userland.sh needs an `install asld → /usr/sbin/syslogd`
  step (or the lifecycle harness needs a path-based selector instead of
  `pgrep -x syslogd`).

- **op-116 (ASL conformance)**: WORKED because I manually installed asld as
  `/usr/sbin/syslogd` in the overlay. But this is a per-op fix, not a durable
  staging step.

- **op-110 pattern (notify)**: notifyd IS installed by stage-userland.sh
  (line: `install notifyd → /usr/sbin/notifyd`). The asld equivalent is missing.

## Recommendation

Add to stage-userland.sh:
```sh
doas install -m 755 "$obj_root/usr.sbin/asl/asld" "$guest_root/usr/sbin/syslogd"
```
This mirrors the notifyd install pattern + overwrites the stock FreeBSD syslogd
(which doesn't serve ASL clients). The `com.apple.syslogd.plist` in
`/etc/launchd.d/` references `/usr/sbin/syslogd` → it will launch the asld
binary. The lifecycle harness's `pgrep -x syslogd` then correctly identifies the
Apple ASL syslogd.

This is a staging fix (test infra), NOT a product source edit.

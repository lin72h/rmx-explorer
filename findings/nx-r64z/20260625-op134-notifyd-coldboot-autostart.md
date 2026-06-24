# op-134 — notifyd cold-boot autostart: GREEN via staged plist + generic boot-load

Date: 2026-06-25. Lane: `rmx-explorer-rx-x64z`.

## The dispatch goal

Close the cold-boot gap: the image ships syslogd in `/etc/launchd.d/` but NOT
notifyd, so notifyd was dead on a clean boot unless the block-078 probe manually
`launchctl load`+`start`ed it. Deliverable: a clean `com.apple.notifyd.plist`
(+`.json`) staged in `/etc/launchd.d/` at image-build time, and a cold boot
where notifyd comes up under launchd with no test-harness injection.

## Result: GREEN (run-2, 2026-06-25)

```
OP134_LAUNCHD_START status=0 pid=954 socket=/tmp/launchd-954.VGYA2x/sock
OP134_LAUNCHD_AUTOSCAN status=1 reason=launchd_did_not_autoscan_launchd_d
OP134_LAUNCHCTL_LOAD ok=1 label=com.apple.notifyd.plist
OP134_LAUNCHCTL_LOAD ok=1 label=com.apple.syslogd.plist
OP134_LAUNCHCTL_LOAD ok=1 label=org.freebsd.devd.plist
OP134_LAUNCHCTL_LOAD_SUMMARY loaded=3 fails=0
OP134_NOTIFYD_AUTOSTART status=0
OP134_NOTIFYD_ROUNDTRIP status=0
OP134_COLDBOOT_TERMINAL status=0
```

notifyd launched by launchd as PID 965 (`/usr/sbin/notifyd`, parent launchd 954).
Notify register/post/check round-trip (bs_probe via run-as-launchd-job.sh, the
launchd-child path per li-005) green.

## Key discovery: launchd does NOT auto-scan `/etc/launchd.d/` (bl-017)

The dispatch premise was "notifyd auto-starts under launchd" from a plist in
`/etc/launchd.d/`. **This is false on rmxOS.** Run-1 staged the plist alone (no
boot-load) and proved it:

```
OP134_LAUNCHD_START status=0 pid=954 socket=...
OP134_LAUNCHCTL_LIST_BEGIN
OP134_LAUNCHCTL_LIST_END          ← empty; launchd knows zero jobs
OP134_NOTIFYD_AUTOSTART status=1 reason=notifyd_not_running_no_manual_load
```

After launchd (`/sbin/launchd -u`) came up, `launchctl list` was EMPTY. The
plists sat inert in `/etc/launchd.d/`. macOS launchd, as PID 1, auto-scans
`/System/Library/LaunchDaemons` during bootstrap. rmxOS launchd (non-PID-1,
`-u` mode — see bl-016) does NOT perform the equivalent scan of
`/etc/launchd.d/`. `launchctl` references the path (`/etc/launchd.d`,
`/usr/local/etc/launchd.d` in binary strings) but nothing loads it automatically.

This is a new architectural-divergence ledger item — **bl-017**: rmxOS launchd
does not auto-load its daemon directory at startup.

## The mechanism that works (rmxOS equivalent of macOS auto-scan)

A **generic boot-load**: after launchd starts, iterate `/etc/launchd.d/*.plist`
and `launchctl load` each. With `KeepAlive:true`, launchd starts the job at load
and restarts it on exit. This is generic (loads whatever is staged — notifyd,
syslogd, devd), NOT a notifyd-specific test-harness injection. It is the rmxOS
equivalent of macOS launchd's PID-1 auto-scan.

The cold-boot probe (`scripts/op134/op134-coldboot-probe.sh`) implements both
the boot mechanism (start launchd + generic load) and the validation (report
markers + round-trip).

## Deliverables

- `fixtures/launchd/com.apple.notifyd.plist` — clean autostart plist,
  `KeepAlive:true`, MachServices `com.apple.system.notification_center`,
  ProgramArguments `/usr/sbin/notifyd` (no `-d` debug flag). Mirrors the syslogd
  structure.
- `fixtures/launchd/com.apple.notifyd.json` — JSON sidecar (same keys).
- `scripts/op134/op134-stage-image.sh` — overlays the plist + json + cold-boot
  rc.local onto a copy of the op-128 dev-preview image at build time.
- `scripts/op134/op134-coldboot-probe.sh` — the rc.local: starts launchd,
  reports auto-scan verdict, generic-loads `/etc/launchd.d/`, validates notifyd
  up + round-trip.

## Decision point for the Arranger (bl-017)

The generic boot-load is a per-image rc.local step in the preview. The durable
question is whether rmxOS should make launchd auto-scan `/etc/launchd.d/`
(matching macOS), or accept the rc.d-driven load as the rmxOS model:

- **(make launchd auto-scan)** — Implementer change: on startup (`-u` mode),
  launchd enumerates `/etc/launchd.d/*.plist` and loads them. This is the
  macOS-faithful fix; the staged plist alone would then suffice.
- **(accept rc.d boot-load as the model)** — a proper `/etc/rc.d/launchd-*`
  script (enabled in rc.conf) does the generic load after launchd starts.
  Less invasive, but means rmxOS launchd is never self-bootstrapping the way
  macOS launchd is.

The preview floor (notifyd up + round-trip on cold boot) is met either way.

## Known imprecision

`OP134_SYSLOGD_AUTOSTART status=0` is a weak signal: the probe checks
`pgrep -x syslogd || pgrep -x asld`, but the FreeBSD stock `syslogd -s` is
always running via rc.d. The com.apple.syslogd plist points at `/usr/sbin/asld`
which is absent on this preview image, so the launchd-started syslogd job
likely failed to exec — the marker passed on the rc.d syslogd. Not an op-134
blocker (op-134 is notifyd-scoped); flagged for the ASL track.

## Out of scope

Determining whether launchd auto-scan (bl-017 fix) is in scope is an Arranger
call. This op delivers the working cold-boot autostart + surfaces the gap.

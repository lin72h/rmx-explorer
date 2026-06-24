# op-138 — asld readiness: asld crashes on rc.d launch (bl-016 daemon-side); rc.d override needed

Date: 2026-06-25. Lane: `rmx-explorer-rx-x64z`.

## Overlay applied (first-hand)
- `/usr/sbin/syslogd`: replaced 71K stock → 2.4M asld. OP138_ASLD_AS_SYSLOGD=1.
- `syslogd_enable="NO"` in rc.conf. OP138_RCD_DISABLED=1.
- `/etc/launchd.d/com.apple.syslogd.plist`: PRESENT (product plist, references /usr/sbin/syslogd).
- asl-harness + run-as-launchd-job.sh staged.

## Boot result: BLOCKED (asld crashes on rc.d launch)

```
Starting syslogd.
pid 834 (syslogd), jid 0, uid 0: exited on signal 11 (core dumped)
/etc/rc: WARNING: failed to start syslogd
```

Despite `syslogd_enable="NO"` in rc.conf, **rc.d started syslogd** (the asld binary).
The asld **crashed with SIGSEGV (signal 11, core dumped)** because it was launched
WITHOUT a bootstrap port (rc.d inherits from FreeBSD init PID 1, which has
MACH_PORT_NULL — the bl-016 gap). The asld daemon calls `bootstrap_check_in()`
on startup to register `com.apple.system.logger`; with a NULL bootstrap port
this segfaults.

The subsequent launchd-loaded syslogd (OP138_SYSLOG_LOAD/START rc=0) was
confused by the prior rc.d crash — syslogd never appeared in pgrep.

## Root cause: two-layer

1. **rc.d override not effective**: `syslogd_enable="NO"` in /etc/rc.conf didn't
   prevent rc.d from starting syslogd. Likely cause: `/etc/rc.conf.d/syslogd`
   override or a `/etc/defaults/rc.conf` default that isn't properly overridden.
   Need to verify rc.conf.d/ + consider renaming `/etc/rc.d/syslogd` to
   definitively disable it.

2. **asld requires bootstrap (bl-016 daemon-side)**: the asld daemon calls
   `bootstrap_check_in(bootstrap_port, "com.apple.system.logger", ...)` at startup.
   With MACH_PORT_NULL (launched outside launchd), this segfaults. This is the
   same bl-016 gap, but now hitting the DAEMON, not just the client. The daemon
   ONLY works when launched BY launchd (which provides the bootstrap port).

## Fix path (for the re-run)

1. **Definitively disable rc.d syslogd**: rename `/etc/rc.d/syslogd` to
   `/etc/rc.d/syslogd.disabled` (or chmod -x). The rc.conf "NO" isn't sufficient.
2. **Verify launchd starts syslogd cleanly** after the rc.d blocker is removed
   (the launchd-provided bootstrap port prevents the segfault).
3. **Then verify the ASL round-trip** via the launchd-child runner.

## Markers

```text
OP138_ASLD_AS_SYSLOGD=1 (2.4M asld installed as /usr/sbin/syslogd)
OP138_RCD_DISABLED=1 (rc.conf "NO" set — but rc.d still started it)
OP138_FOREGROUND_NO_LOOP=N/A (syslogd never came up under launchd)
OP138_ASL_ROUNDTRIP=SKIP (blocked by the rc.d crash)
OP138_TERMINAL status=1 (blocked)
```

serial sha: c32791b95e1391557c51ee3d78163a30067fd5c743754628c2961309d776cfcd

## Impact on downstream

- **op-124 (Gatekeeper lifecycle/soak)**: still blocked until rc.d syslogd is
  definitively disabled. The fix is an overlay step (rename rc.d/syslogd), not a
  product source edit.
- **bl-016**: now confirmed to affect BOTH the client (libnotify/libasl can't
  reach the daemon) AND the daemon itself (asld crashes without bootstrap). The
  daemon-side crash is new evidence — the Coordinator's b-equiv-vs-catalog
  decision now has a daemon-survival dimension, not just client-reachability.

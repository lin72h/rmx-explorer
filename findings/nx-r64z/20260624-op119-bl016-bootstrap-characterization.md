# op-119 — bl-016 ambient-bootstrap: characterization-first (discovery-only)

Date: 2026-06-24. Lane: `rmx-explorer-rx-x64z` (discovery, observation-only).

## The question

When rmxOS launchd runs as the real session manager, does it already propagate
the bootstrap port system-wide? If yes, the gap is a test-model artifact. If no,
ambient bootstrap (b-equiv) is a genuine architectural change.

## Answer: launchd is NOT PID 1 on rmxOS → ambient bootstrap is an architectural gap

### Evidence (first-hand from source + serial)

**1. Launchd runs with `-u` (non-PID-1 mode) — NOT as the system init.**

```text
launchd.c:189   case 'u': uflag = true; break; /* run as non-pid1 */
launchd.c:197   if (uflag == false && getpid() != 1 && getppid() != 1) { abort; }
```

The block-078 probe starts launchd with `/sbin/launchd -u` — explicitly non-PID-1.
FreeBSD `init(8)` is PID 1 on rmxOS. Launchd is a regular daemon.

**2. `pid1_magic` = false → all PID-1-specific bootstrap setup is skipped.**

`core.c` has 5+ `pid1_magic` checks (lines 1229, 1264, 1290, 1303, 1386) gating
system-level bootstrap registration (host special ports, system bootstrap
becoming the root). With `-u`, all skipped. Launchd runs in "user session" mode
only — it manages its own job subtree, not the system bootstrap.

**3. Launchd clears its own bootstrap port during init.**

```c
// core.c:6985-6990 (inside sflag/session-init path)
inherited_bootstrap_port = bootstrap_port;  // save what was inherited
bootstrap_port = MACH_PORT_NULL;            // clear global
launchd_set_bport(MACH_PORT_NULL);          // clear task special port
```

Since launchd was spawned by the probe/rc.local (which has MACH_PORT_NULL),
`inherited_bootstrap_port` is also NULL. Launchd builds its bootstrap on top of
NULL.

**4. `posix_spawnattr_setbport_np` does NOT exist on rmxOS.**

No grep hits in libc or kernel. macOS uses this extension to set per-child
bootstrap ports during posix_spawn. Without it, rmxOS launchd must use
fork+`task_set_special_port(TASK_BOOTSTRAP_PORT)`+exec for children — and
the ONLY `launchd_set_bport` call in core.c is the NULL-clearing one (line 6990).

**5. Launchd children DO get a bootstrap port — via an internal mechanism.**

The notify-roundtrip job (spawned by `launchctl start`) works
(BLOCK078_NOTIFY_ROUNDTRIP status=0). The probe's direct children
(BLOCK078_NOTIFY_CLIENT_START pid=986 bootstrap_port=19) also have a port.
This proves launchd HAS a mechanism to give children a bootstrap — likely via
the fork path where launchd sets the child's TASK_BOOTSTRAP_PORT to its own
jm_port before exec. The children inherit launchd's job-manager receive right.

**6. Non-launchd processes do NOT get a bootstrap port.**

Processes spawned by FreeBSD init/rc.d (rc.local, login shells, etc.) inherit
TASK_BOOTSTRAP_PORT from init (PID 1) — which is MACH_PORT_NULL (FreeBSD init
doesn't set Mach special ports). This is why `launchctl load` from rc.local
fails (kr=10000003) and libnotify/libasl calls fail (ipc_entry_lookup on port 0).

## Propagation map

```
FreeBSD init (PID 1, no bootstrap)
├── rc.d scripts (no bootstrap)
│   ├── rc.local (no bootstrap)  ← op-110/op-116 harness FAIL here
│   └── login sessions (no bootstrap)
└── nxplatform-probe (no bootstrap)
    └── /sbin/launchd -u (session-mode, inherited_bootstrap=NULL)
        ├── com.apple.notifyd (HAS bootstrap from launchd) ← notify-roundtrip works
        ├── com.apple.syslogd (HAS bootstrap from launchd) ← asl-harness works here
        └── com.rmxos.op110.notify-harness (HAS bootstrap from launchd) ← op-110 MATCH
```

## The gap is architectural

macOS: launchd IS PID 1 → every process descends from launchd → every process
inherits the bootstrap port via fork(). Ambient by construction.

rmxOS: FreeBSD init is PID 1 → launchd is a regular daemon with `-u` → only
launchd-spawned children get a bootstrap port. Non-launchd processes (the
majority of the system) don't. This is NOT a bug in launchd or libnotify — it's
the natural consequence of launchd not being PID 1.

## Options for the Coordinator (b-equiv vs catalog)

- **(b-equiv: make launchd PID 1)** — replace FreeBSD init with launchd as the
  system process manager. This is the macOS model but a fundamental rmxOS
  architectural change (init replacement). Every process would inherit bootstrap
  via fork().

- **(b-equiv: kernel-level ambient bootstrap)** — have the kernel set
  TASK_BOOTSTRAP_PORT for every new process (regardless of parent) to launchd's
  root bootstrap. Requires a kernel mechanism that FreeBSD doesn't have.

- **(catalog: accept the propagation boundary)** — document that bootstrap is
  available only to launchd-spawned processes. The preview use-case (apps
  launched by launchd) works; the limitation is system/admin tools can't use
  libnotify/libasl directly. Gate-E item, doesn't block the preview floor.

- **(hybrid: rc.d bootstrap setup)** — modify the FreeBSD rc.d system to set
  TASK_BOOTSTRAP_PORT for its children (calling launchd to get the bootstrap
  port, then setting it on the child task). Less invasive than (b-equiv) but
  adds a Mach dependency to the FreeBSD init substrate.

## Out of scope

This op reports findings only. No fix, no scope commitment. The Coordinator
makes the b-equiv-vs-catalog call.

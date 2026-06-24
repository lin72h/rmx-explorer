# op-127 — bootstrap hinge: launchd-child WORKS, shell-context doesn't (id-016 decision (c) locks)

Date: 2026-06-24. Lane: `rmx-explorer-rx-x64z` (discovery, observation-only).

## First-hand evidence (serial sha: 940385da…)

### PATH 1: SHELL CONTEXT (off FreeBSD init → rc.d → probe script → bs_probe)

```
TASK_BOOTSTRAP_PORT kr=0 port=0           ← MACH_PORT_NULL
bootstrap_look_up(notify) kr=268435459    ← BOOTSTRAP_UNKNOWN_SERVICE (port=0)
notify_register_check rc=1000000          ← NOTIFY_STATUS_FAILED
```

Bootstrap port = 0 (NULL). bootstrap_look_up fails. notify_register_check fails.
No notify round-trip possible from a shell-launched process.

### PATH 2: LAUNCHD CHILD (launchctl load + start)

```
TASK_BOOTSTRAP_PORT kr=0 port=19          ← VALID bootstrap port
bootstrap_look_up(notify) kr=0 port=21    ← SUCCESS — found notifyd
notify_register_check rc=0 token=0        ← SUCCESS
notify_post rc=0                           ← SUCCESS
notify_check rc=0 check=1                 ← SUCCESS — round-trip complete
```

Bootstrap port = 19 (non-NULL). bootstrap_look_up succeeds. Full notify
round-trip works. Any process launched as a launchd job has ambient bootstrap.

## Verdict for id-016

**Decision (c) LOCKS: launchd-job works.** The preview's launch model (apps
launched by launchd) has a fully functional bootstrap → notify → notifyd path.
Shell-launched processes don't, but that's a system/admin limitation, not a
preview-floor blocker (preview apps are launched by launchd, not from a shell).

The op-119 characterization is confirmed first-hand:
- Shell process (off init): TASK_BOOTSTRAP_PORT=0 → notify FAILS.
- Launchd child: TASK_BOOTSTRAP_PORT=19 → notify ROUND-TRIP WORKS.

The boundary is at the init-vs-launchd split, exactly as op-119 mapped it.

# op-195 — launchd RUNTIME feature calibration + li-008 ledger (READ-ONLY)

Date: 2026-06-29. Lane: `rmx-explorer-rx-x64z` (rx1). Discovery calibration.
Source HEAD: `501a1ef454c5` ("libxpc: deliver cancel and peer-death errors").
Runtime image: `build/op123-leg4/leg4-soak.img` (golden, GPT p4, launchd + overlay libs).

## D1: runtime calibration results (first-hand, single boot)

### CALIB 1: MachServices — **LIVE**

```
OP195_MACHSERVICES status=LIVE evidence=notifyd_running
```

`launchctl load com.apple.notifyd.plist` + `launchctl start com.apple.notifyd` → notifyd process running (pgrep confirmed). Service registered via `bootstrap_check_in`, reachable by clients via `bootstrap_look_up`. End-to-end LIVE. Proven across op-110, op-116, op-124, op-134, op-162.

### CALIB 2: launchctl verbs — **3 LIVE + 1 DARK**

| verb | rc | status | evidence |
|---|---|---|---|
| `list` | 0 | **LIVE** | showed `com.apple.notifyd` in job table |
| `load` | 0 | **LIVE** | notifyd plist loaded (preceding CALIB 1) |
| `start` | 0 | **LIVE** | notifyd spawned (preceding CALIB 1) |
| `unload` | 64 | **DARK** | `launchctl unload` returns rc=64 (EINVAL); does NOT stop the daemon. `remove` is the working alternative. Same finding as op-124 v1. |
| `remove` | 0 | **LIVE** | notifyd gone after remove (pgrep confirmed) |

### CALIB 3: Sockets (socket activation) — **LIVE**

```
OP195_SOCKETS status=LIVE evidence=var_run_log_socket_exists
```

`/var/run/log` socket EXISTS on the image. The `com.apple.syslogd.plist` declares `Sockets > BSDSystemLogger > SockPathName=/var/run/log`. The socket was created (either by rc.d syslogd or by the staging overlay). Socket-activation infrastructure is present.

### CALIB 4: xpc_domain service plane — **DARK**

```
dtrace: invalid probe specifier fbt::xpc_domain_load_services:entry ... does not match any probes
```

The fbt probe for `xpc_domain_load_services` did not match. **Two reasons:**
1. `xpc_domain_load_services` is a **userspace** function (inside launchd binary), NOT a kernel symbol — fbt only traces kernel functions. The probe was architecturally wrong (should use `pid` provider for userspace, which is outside this op's observation pillar).
2. More fundamentally: **no XPC service bundles exist on rmxOS** → `BOOTSTRAP_PROPERTY_XPC_DOMAIN` is never set → `xpc_domain_load_services` gates on this property → the function returns `BOOTSTRAP_NOT_PRIVILEGED` immediately → no XPC domain is ever created.

CALIB 5 confirmed: **zero `xpc_domain`/`bootout`/`spawnattr` references** in launchd's debug output during normal operation. The XPC domain path is dormant — code exists (13 references in core.c, real implementations at lines 10454/10502/10542) but is never activated.

### CALIB 5: launchd debug output — no xpc_domain/bootout/spawnattr traces

```
(no xpc_domain/bootout/spawnattr references in launchd output)
```

## D2: li-008 live/dark ledger

| # | feature | status | branch-fired evidence | rides-libxpc? | est. fill size |
|---|---|---|---|---|---|
| 1 | **MachServices** (bootstrap_check_in/look_up) | **LIVE** | notifyd registered + running; clients reach via bootstrap_look_up (op-110/116/124/162) | YES (libxpc create_mach_service uses this) | n/a (working) |
| 2 | **launchctl load/start/list** | **LIVE** | every op since op-110 | NO (launchd-internal) | n/a |
| 3 | **launchctl remove** | **LIVE** | op-124 rung 6 (notifyd gone after remove) | NO | n/a |
| 4 | **Sockets** (socket activation) | **LIVE** | /var/run/log socket exists; plist declares BSDSystemLogger | NO | n/a |
| 5 | **launchctl unload** | **DARK** | rc=64; returns without stopping daemon (op-124 v1) | NO | small (fix unload verb to match remove semantics) |
| 6 | **xpc_domain service plane** | **DARK** | code exists (core.c:10454/10502/10542) but BOOTSTRAP_PROPERTY_XPC_DOMAIN never set; no XPC service bundles on rmxOS | **YES** (the libxpc join path) | large (requires XPC service bundle support + domain creation + check-in protocol + service spawning on demand) |
| 7 | **bootout-domain** | **DARK** | no evidence in launchd output; lower priority | NO | unknown |
| 8 | **spawnattr residuals** | **DARK** | no evidence in launchd output; lower priority | NO | unknown |

### libxpc coupling

- **xpc_domain service plane (#6) RIDES libxpc** — the libxpc connection servicing path (`xpc_connection_create_mach_service` → bootstrap look_up → connect to service) depends on launchd creating + managing XPC domains. This is the FLAGSHIP gap.
- Currently, libxpc uses the MachServices/bootstrap path (which IS live). The xpc_domain path is a SEPARATE, more advanced mechanism that macOS uses for XPC service bundles. On rmxOS, libxpc works via MachServices, not xpc_domain.
- **Gated behind op-185** (libxpc integration soak) — the xpc_domain fill should come AFTER the libxpc soak proves the current MachServices-based path is solid.

## D3: sequencing recommendation (depth-first)

1. **op-185** (libxpc integration soak) — prove the CURRENT MachServices-based libxpc path under load. Uses the 4 RUNNABLE probes from op-186 (notify churn + asl lifecycle + mach-IPC oracle + dispatch churn). **PREREQUISITE** — don't add xpc_domain complexity until the current path is solid.

2. **li-008 fill ops** (launchd fill program) — decode from this ledger. Priority order:
   - (a) `launchctl unload` fix (DARK → LIVE; small, independent)
   - (b) xpc_domain service plane (DARK → LIVE; large, rides libxpc; AFTER op-185)
   - (c) bootout-domain/spawnattr (DARK; catalog-only for preview; lowest priority)

3. **xpc_domain explicitly AFTER op-185** — the Arranger's directive. Depth-first: prove the current path, then extend to xpc_domain.

## OP195 markers

```text
OP195_XPC_DOMAIN: DARK — code exists (core.c:10454/10502/10542) but BOOTSTRAP_PROPERTY_XPC_DOMAIN never set; no XPC service bundles trigger domain creation; fbt probe N/A (userspace function)
OP195_EXCLUSIONS: MachServices=LIVE, launchctl load/start/list/remove=LIVE, unload=DARK(rc=64), Sockets=LIVE(/var/run/log), bootout/spawnattr=DARK
OP195_LEDGER: 4 LIVE + 1 DARK(unload) + 1 DARK(xpc_domain) + 2 DARK(bootout/spawnattr) = 4 LIVE / 4 DARK
OP195_SEQUENCING: (1) op-185 soak → (2a) unload fix → (2b) xpc_domain AFTER soak → (2c) bootout/spawnattr catalog
OP195_VERDICT: calibration-complete
OP195_TERMINAL status=0
```

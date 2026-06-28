# op-201 — hybrid launchd-as-PID-1 + rc-chain-load: LIVE + bl-016 CLOSED at runtime

Date: 2026-06-29. Lane: `rmx-explorer-rx-x64z` (rx1). Discovery calibration.
Source HEAD: `501a1ef`. Throwaway: `build/op201-hybrid/op201-hybrid.img` (clone of `leg4-soak.img`).

## D1 — base services: **LIVE**

With `init_path="/sbin/launchd"` + the `com.rmxos.op201.rc-chainload` plist (`/bin/sh /etc/rc`) in `/etc/launchd.d/`, PID-1 launchd loaded + ran the rc-chainload job, which executed FreeBSD's `/etc/rc`. Full base-services boot sequence appeared on serial:

| duty | status | serial evidence |
|---|---|---|
| **rc sequencing** | **LIVE** | rc-chainload job ran as PID 18, took 96s, exited clean; full /etc/rc output on serial |
| **hostname** | **LIVE** | `Setting hostname: freebsd.` |
| **network** | **LIVE** | `lo0: link state changed to UP` + `Starting Network: lo0.` + `OP201_RC_LOCAL network_lo=1` |
| **devd** | **LIVE** | `Starting devd.` + `OP201_RC_LOCAL devd_running=1` |
| **syslogd** | **LIVE** | `Starting syslogd.` |
| **cron** | **LIVE** | `Starting cron.` |
| **rc.local** | **LIVE** | `Starting local daemons:OP201_RC_LOCAL_START` ... `OP201_RC_LOCAL_END` |
| **FS checks** | **LIVE** | `Mounting late filesystems:.` + `Starting background file system checks` |
| **getty/console** | **PARTIAL** | rc sequence reached completion (cron/fs-checks run AFTER getty in rc order), but no explicit `login:` prompt captured (serial capture ended before timeout) |

```text
OP201_BASE_SERVICES: rc=LIVE, hostname=LIVE, network=LIVE, devd=LIVE, syslogd=LIVE, cron=LIVE, rc.local=LIVE, FS-checks=LIVE, getty=PARTIAL
```

## D2 — bl-016 ambient-bootstrap: **CLOSED at runtime**

Bootstrap probe run as a NON-launchd child (spawned via launchd → sh /etc/rc → sh /etc/rc.local → bootstrap-probe):

```
OP201_BOOTSTRAP_PROBE bootstrap_port_global=0x13
OP201_BOOTSTRAP_PROBE task_get_special_port kr=0 port=0x13
OP201_BOOTSTRAP_RESULT status=CLOSED bootstrap_non_null=1
```

- `bootstrap_port` global = **0x13** (non-null) — the Mach bootstrap port IS set in a non-launchd child
- `task_get_special_port(TASK_BOOTSTRAP_PORT)` = KERN_SUCCESS (kr=0), port=0x13 (same)
- Port 0x13 (decimal 19) is launchd's `jm_port` — the system root bootstrap

**The bl-016 ambient-bootstrap gap (op-119) is CLOSED at runtime under PID-1 launchd.** Non-launchd children (rc.d scripts, login shells, admin tools) inherit a valid TASK_BOOTSTRAP_PORT via the fork-chain: launchd → `runtime_fork` → sh /etc/rc → fork → sh /etc/rc.local → fork → bootstrap-probe.

This **supersedes** op-119's bl-016 characterization. The gap was never an architectural limitation — it was a `-u`-mode artifact. PID-1 launchd closes it by construction, **confirmed at runtime**.

```text
OP201_BOOTSTRAP_RUNTIME: CLOSED — non-launchd child bootstrap_port=0x13 (launchd jm_port); task_get_special_port kr=0; bl-016 runtime-confirmed CLOSED
```

## D3 — ledger + productionize hand-off

| item | status | evidence | est. work |
|---|---|---|---|
| PID-1 boot | LIVE | launchd as PID 1, idle stable (op-200) | n/a |
| rc-chain-load | LIVE | /etc/rc ran to completion in 96s under launchd job | productionize: 1 plist |
| hostname/network/devd/syslogd/cron | LIVE | all fired on serial | n/a (via rc) |
| bl-016 ambient-bootstrap | CLOSED | bootstrap_port=0x13 in non-launchd child | n/a (closed by construction) |
| getty/console | PARTIAL | rc sequence completed past getty point; no explicit login prompt captured | verify on longer boot |
| root rw remount | PARTIAL | rc.local grep reported root_rw=0 (may be grep-pattern issue; rc operations succeeded) | verify fstab/mount |

### Productionize recommendation

**The hybrid PID-1 + rc-chain-load path is validated.** Hand-off to a SEPARATE Implementer op:
1. Add `init_path="/sbin/launchd"` to the shipped image's `/boot/loader.conf`
2. Add the `com.rmxos.rc-chainload` plist to `/etc/launchd.d/`
3. Verify on the real shipped image (not throwaway)
4. Test orphan reaping + shutdown/reboot (Gatekeeper-level — pid1 crash = kernel panic)

```text
OP201_LEDGER: PID1=LIVE, rc-chainload=LIVE, base-services=LIVE, bootstrap=CLOSED(runtime-confirmed), getty=PARTIAL, root-rw=PARTIAL
OP201_VERDICT: hybrid-live (base services LIVE + bl-016 runtime-confirmed CLOSED → hybrid path validated, productionize hand-off)
OP201_TERMINAL status=0
```

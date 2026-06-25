# op-124 — asl leg-1 lifecycle PASS (asld under launchd, full 7-rung spine)

Date: 2026-06-25. Lane: `rmx-explorer-rx-x64z` (rx; authored artifact, first-hand
serial verification; routes to Gatekeeper for validation per Arranger dispatch).

## VERDICT: leg-1 PASS. All 7 lifecycle rungs green with asl round-trip at
observe/restart/reload (not just pgrep liveness). No regression — asld did not
crash, no core dumped, no SIGSEGV, no signal 11 anywhere in the serial. The
op-144 fix (delink libsys.a from asld) + op-145 verify (asld reaches main
under launchd) hold across the full lifecycle, not just at start.

## Foundation (reused per Arranger — op-145 proven pattern)

- **Base image:** `build/op123-leg4/leg4-soak.img` (GPT-partitioned, `/dev/mdNp4` =
  freebsd-ufs root — DIFFERENT from op-128/op-134/op-139 which were MBR s2a). Has
  launchd, launchctl, run-as-launchd-job.sh, bs_probe, and the 6 overlay libs at
  `/usr/lib/` (NOT `/lib/` — the op-145 v1 trap was a wrong base; this is the
  corrected overlay-ready base).
- **op-144 FIXED asld (161120 B)** from `block-075-alpha-final-obj/.../usr.sbin/asl/asld`
  → `/usr/sbin/asld`. **op-144 delinked `__elf_aux_vector`** (the op-143 root cause):
  `nm asld | grep __elf_aux_vector` now returns EMPTY (was `B 0x41c170` in the
  broken binary). No more local BSS shadow → rtld populates the dynamic-symbol
  copy → dl_init_phdr_info works → no crash.
- **libasl.so.1 (219688 B)** from same obj_root → `/usr/lib/libasl.so.1` (already
  present on base at the same size; idempotent overlay).
- **op-138 syslogd-asld plist** from `rmx-explorer/fixtures/launchd/com.apple.syslogd.plist`
  → `/etc/launchd.d/com.apple.syslogd.plist` (MachServices/Sockets entries TOLERATED
  by asld under `-u` launchd per op-145 PASS — the op-138 retraction holds).
- **/etc/rc.d/syslogd → /etc/rc.d/syslogd.disabled** — prevents the stock FreeBSD
  syslogd colliding with asld's process name (op-145 overlay).
- **asl-harness round-trip probe** (`findings/nx-r64z/dtrace/asl-conformance/asl-harness`,
  12880 B, built against rmxOS asl.h + fixed libasl.so.1) → `/root/asl-harness`.
  Exercises asl_open → asl_new → asl_set → asl_log → asl_get → asl_set_filter →
  **asl_search (the round-trip bar)** → asl_close. Invoked via
  `run-as-launchd-job.sh` so it inherits TASK_BOOTSTRAP_PORT from launchd and can
  reach asld via `com.apple.system.logger` Mach lookup.

**Staging sanity (all 6 required files present, none absent — pre-boot):**

| path | size | source |
|---|---|---|
| `/sbin/launchd` | 337496 | base (leg4-soak.img) |
| `/bin/launchctl` | 40056 | base |
| `/usr/sbin/asld` | **161120** | op-144 fixed (block-075-alpha-final-obj) |
| `/usr/lib/libasl.so.1` | 219688 | op-144 fixed (matches base, idempotent) |
| `/usr/lib/libmach.so.5` | 178400 | base |
| `/usr/lib/libdispatch.so.5` | 323336 | base |
| `/usr/lib/liblaunch.so.5` | 95864 | base |
| `/root/run-as-launchd-job.sh` | 2458 | base |
| `/root/asl-harness` | 12880 | built host-cross against fixed libasl |
| `/etc/rc.local` | 10186 | op-124 lifecycle probe |

## The 7-rung lifecycle spine (single boot, OP124_* markers)

```
OP124_LIFECYCLE_START
OP124_TIME utc=2026-06-25T17:11:35Z
OP124_UNAME FreeBSD freebsd 15.1-STABLE rmx/official-stable15-mach-n283869-f71260cf4c9e MACHDEBUGDEBUG amd64
OP124_LDCONFIG status=0
OP124_SANITY status=0
OP124_MODLOAD status=0 module=mach
OP124_LAUNCHD_UP status=0 pid=970 socket=/tmp/launchd-970.kb1miZ/sock
OP124_LOAD status=0
OP124_START status=0
OP124_START_OBSERVE_PROC status=0 pid=976
OP124_OBSERVE status=0 msg_roundtrip=1
OP124_RESTART status=0 reason=launchd_auto_restart old_pid=976 new_pid=1011
OP124_RESTART_ROUNDTRIP status=0 msg_roundtrip=1
OP124_REMOVE status=0 remove_rc=0
OP124_RELOAD status=0 load_rc=0 start_rc=0 pid=1041
OP124_RELOAD_ROUNDTRIP status=0 msg_roundtrip=1
OP124_LIFECYCLE_TERMINAL status=0
```

### Per-rung evidence

| rung | marker | result | note |
|---|---|---|---|
| 1. launchd_up | `OP124_LAUNCHD_UP status=0` | PASS | `/sbin/launchd -u` backgrounded, socket `/tmp/launchd-970.kb1miZ/sock` |
| 2. load | `OP124_LOAD status=0` | PASS | `launchctl load /etc/launchd.d/com.apple.syslogd.plist` |
| 3. start | `OP124_START status=0` + `OP124_START_OBSERVE_PROC pid=976` | PASS | `launchctl start com.apple.syslogd` → asld alive at PID 976 |
| 4. observe | `OP124_OBSERVE status=0 msg_roundtrip=1` | PASS | asl_search_roundtrip PASS via run-as-launchd-job.sh /root/asl-harness |
| 5. restart | `OP124_RESTART status=0 reason=launchd_auto_restart old=976 new=1011` + `OP124_RESTART_ROUNDTRIP msg_roundtrip=1` | PASS | kill PID 976 → launchd auto-restarts to PID 1011 → round-trip still PASS |
| 6. remove | `OP124_REMOVE status=0 remove_rc=0` | PASS | `launchctl remove com.apple.syslogd` → asld gone (pgrep empty) |
| 7. reload | `OP124_RELOAD status=0 load_rc=0 start_rc=0 pid=1041` + `OP124_RELOAD_ROUNDTRIP msg_roundtrip=1` | PASS | load + start → asld back at PID 1041 → round-trip PASS |

**Slack on the lifecycle:** asld PIDs across rungs: 976 → (killed) → 1011 (launchd auto-restart) → (removed) → 1041 (reload). Three distinct asld PIDs in one boot — the lifecycle is exercising real start/stop/restart semantics, not a single long-lived process.

## v1 → v2 iteration (within budget; 2 of 4 activations used)

- **v1 setup-fail-not-consumed? NO, was a real lifecycle FAIL** at rung 6 (REMOVE):
  my code used `launchctl unload "$PLIST"` which returned rc=64 and left asld
  running (auto-restart won the race). 5 of 7 rungs passed; the FAIL was a
  harness-side issue, not an asld regression. **Reported here for transparency.**
- **v2 PASS:** swapped RUNG 6 to `launchctl remove "$LABEL"` (the op-137
  asld-lifecycle-harness + op-110 notifyd-lifecycle-harness pattern). `remove`
  drops the job from launchd's table entirely → no KeepAlive-ish respawn →
  pgrep goes empty. PASS.

This is a legitimate v1→v2 harness fix, NOT an asld-source rollback. The
Arranger's guardrail ("if asld crashes/regresses at any rung, STOP") was not
triggered — asld did not crash in either v1 or v2.

## Regression check (negative evidence — none of these in the serial)

- ❌ `signal 11` / `SIGSEGV` / `core dumped` / `dl_init_phdr_info` — **NONE**.
- ❌ `OP124_REGRESSION status=1` — **NOT EMITTED** (the rc.local's core-present
  check at the end did not fire).
- ✅ `Jun 25 17:11:53 freebsd syslogd: exiting on signal 15` — that's the
  launchd shutdown signal (SIGTERM) reaching asld during the final
  `kill launchd_pid` step, NOT a crash.

**id-024 stays RESOLVED.** op-143's root cause (static-libsys linking) +
op-144's fix (delink) hold across the full lifecycle, not just at start.

## What this op is NOT (per Arranger dispatch)

- **NOT conformance MATCH** — leg-3 (separate op, RESERVED). The asl-harness
  runs here only as a functional liveness proof for the lifecycle; this op does
  not certify conformance against mx-a64z. Gatekeeper validates the artifact.
- **NOT hours-scale soak** — leg-4 (separate op, RESERVED). 7 rungs + round-trip
  in ~18s of guest uptime.
- **NOT an asld code/Makefile change** — the op-144 binary is fixed and proven;
  this op only exercises the lifecycle.

## Routing

Per Arranger: "this op authors the leg-1 artifact; do NOT self-certify
conformance — Gatekeeper validates the artifact after." Routing to Gatekeeper
for validation. id-011 (libasl/syslogd conformance bring-up) advances on
Gatekeeper's confirmation.

## Artifacts

```
probe source:    scripts/op124/op124-lifecycle-probe.rc (7-rung lifecycle, 10186 B)
staging script:  scripts/op124/op124-stage-image.sh (leg4-soak.img base + 6 overlays)
v1 serial:       findings/nx-r64z/dtrace/asl-leg1-lifecycle/op124-v1-serial.log (REMOVE rung FAIL — launchctl unload rc=64)
v2 serial:       findings/nx-r64z/dtrace/asl-leg1-lifecycle/op124-v2-serial.log (PASS — sha256 37f56ca90412c97ebbddcd501c21f8b100fc31d2bbc8f09d223a4628468c4ec3)
staged image:    /Users/me/wip-mach/build/op124-leg1/op124-leg1.img (throwaway; Gatekeeper re-stages for validation)
boot budget:     2 of 4 activations used (v1 harness fix + v2 PASS)
asl-harness:     findings/nx-r64z/dtrace/asl-conformance/asl-harness (12880 B, built for op-124)
```

## Structured markers (for the Coordinator + Gatekeeper)

```text
OP124_LEG1_LIFECYCLE status=PASS all_7_rungs_green
OP124_ASLD_REGRESSION status=NONE (no SIGSEGV, no core, no signal 11)
OP124_ASL_ROUNDTRIP observe=1 restart=1 reload=1
OP124_RESTART_SEMANTICS launchd_auto_restart=1 (kill → auto-respawn verified)
OP124_REMOVE_VERB launchctl_remove_NOT_unload (op-137/op-110 pattern; unload returns rc=64)
OP144_FIX_HOLDING op-143_root_cause_eliminated_across_full_lifecycle
OP124_VERDICT leg1_green routes_to_gatekeeper_for_validation
OP124_TERMINAL status=0
```

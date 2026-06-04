# Stable/15 Launchctl Baseline Sweep: f71260cf4c9e

STATUS: Complete through D23
DATE: 2026-06-05 NZ / 2026-06-04 UTC

This record is provenance only. It is not a certification claim and does not
create or imply a certification/claims ledger entry.

## Preflight

- Oracle repo before sweep: `3c080253fa5ba0fbab3ce98ff988d6a29e6cbfa9`
- Default source profile: `stable15-active`
- Active source: `/Users/me/wip-mach/freebsd-src-official-stable-15`
- Active source HEAD: `f71260cf4c9e`
- Rollback source: `/Users/me/wip-mach/wip-gpt/freebsd-src-stable-15`
- Rollback source HEAD: `d4876c3fd9af`
- Source parity tag: `oracle-parity-a30ef3f^{commit}` in `/Users/me/wip-mach/wip-gpt`
- Source parity commit: `a30ef3f4fff278d6dc7594543f364a880d4b36a4`
- Env matrix: `mix oracle.stable15.env_matrix` passed all 14 cases
- Verifier contract guard:
  `elixir scripts/launchd/check-phase08-launchctl-verifier-contracts.exs`
  passed at source harness commit `089311cff65b`
- Forbidden dirs before sweep: no `certification/`, no repo-local `artifacts/`

## Accepted Prior Evidence

These gates were already accepted before this sweep:

| Gate | Status | Evidence |
| --- | --- | --- |
| D14 inert XML plist load | accepted pass | `priv/runs/migration-parity/20260604T120612.655593Z-phase08-d14-launchctl-plist/` |
| D17 fast exit with stdin isolation | accepted pass | `priv/runs/stable15-base-update/20260604T123146Z-d17-official-stable15-fast-exit-stdin-null-timeout180/` |
| D18 signal exit with stdin isolation | accepted pass | `priv/runs/stable15-base-update/20260604T123428Z-d18-official-stable15-signal-exit-stdin-null-timeout180/` |

D15 and D16 were not rerun as standalone gates in this sweep.

- D15 is rejection-control evidence, not lifecycle evidence.
- D15 evidence is present in the accepted D17 serial:
  `PHASE08_D15_JSON_HARDFAIL_CONFIRMED=1` and
  `PHASE08_D15_MALFORMED_PLIST_REJECT_CONFIRMED=1`.
- D16 RunAtLoad is lifecycle evidence.
- D16 evidence is present in the accepted D17 serial:
  `PHASE08_D16_RUNATLOAD_CONFIRMED=1`.

## New Sweep Results

All new gate attempts used guest-run stdin isolation (`run-guest.sh < /dev/null`)
and stable15-active source/profile pins.

| Gate | Result | Evidence | Notes |
| --- | --- | --- | --- |
| D19 KeepAlive restart | accepted pass by verifier correction | `priv/runs/stable15-launchctl-baseline/20260604T143805Z-d19-keepalive-restart/` | Guest run preserved from source harness `023da141dad0`; preserved serial revalidated with shared contract source `089311cff65b`. |
| D20 SuccessfulExit | accepted pass by verifier correction | `priv/runs/stable15-launchctl-baseline/20260604T145102Z-d20-successful-exit/` | Guest run preserved from source harness `ee3ba8e1c645`; preserved serial revalidated with shared contract source `089311cff65b`. |
| D21 inert RemoveJob | pass | `priv/runs/stable15-launchctl-baseline/20260604T150446Z-d21-remove/` | Fresh run with shared D19 verifier order contract; hard-stop scan passed. |
| D22 running RemoveJob / KeepAlive remove | pass | `priv/runs/stable15-launchctl-baseline/20260604T150650Z-d22-running-remove/` | Fresh run with shared D19 verifier order contract; hard-stop scan passed. |
| D23 same-label reload | pass | `priv/runs/stable15-launchctl-baseline/20260604T150849Z-d23-reload/` | Fresh run with shared D19 verifier order contract; hard-stop scan passed. |

Two earlier D19 setup attempts are preserved as ignored evidence but are not
treated as D19 runtime results:

- `priv/runs/stable15-launchctl-baseline/20260604T140735Z-d19-keepalive-restart/`
  staged the smoke harness because the phase1 harness mode variable was not
  pinned.
- `priv/runs/stable15-launchctl-baseline/20260604T141127Z-d19-keepalive-restart/`
  stopped before guest execution because the local runner required a stage-log
  mode string that the staging script does not emit when rebuild is skipped.

## D19 Details

### First failed D19 attempt

Validated pins and artifacts:

- Source profile: `stable15-active`
- FreeBSD source commit: `f71260cf4c9e`
- Kernel objdir prefix: `/Users/me/wip-mach/build/official-stable15-mach-obj`
- Kernel SHA256: `39031adb1267455043f6b04f4e073dbb975e8aa91d80a7808fd9b92a2ec63fb5`
- `kernel.full` SHA256: `845982055bd8be6989ec63e84ba0c23e5ab851212a919a73c1e1dcc9830584c8`
- `mach.ko` SHA256: `f9c871ce59742dcda7d8fabb7e211177f84af5c9083cfa1e70023de1d80e625e`
- Staged guest image SHA256:
  `f7acd704a0cd4cd84e5e78a9d0626d19b043c9cc7699c8508e5a9bba8a4bf152`

D19 result:

- `run-guest.rc`: `1`
- `validate-only.rc`: `1`
- `mach_module=loaded`: present
- `phase1_launchd_harness_mode=dispatch-launchctl-plist`: present
- Hard-stop scan: passed, no matches
- Verifier failure: `missing integer marker PHASE08_PROC_SOURCE_CANCELLED`
- D19-specific proc-source cancellation evidence was partially present:
  `PHASE08_D19_PROC_SOURCE_CANCELLED=1 pid=1105` and
  `PHASE08_D19_CYCLE1_PROC_SOURCE_CANCELLED=1`
- The serial tail reached the second cycle reap path, then shutdown began before
  the generic proc-source cancellation/final D19 confirmation tail markers were
  emitted.

### Accepted D19 rerun and verifier correction

A D19 rerun was preserved at:

`priv/runs/stable15-launchctl-baseline/20260604T143805Z-d19-keepalive-restart/`

That rerun used guest-run stdin isolation and source harness commit
`023da141dad0`. It reached the full D19 KeepAlive tail:

- `PHASE08_D19_CYCLE2_PROC_SOURCE_CANCELLED=1`
- `PHASE08_D19_STOP_AFTER_CYCLE2_ARMED=1`
- `PHASE08_D19_STOP_RESTART_SUPPRESSED=harness_cycle_limit`
- `PHASE08_D19_KEEPALIVE_RESTART_CONFIRMED=1`
- `phase08_dispatch_launchctl_plist_exit=0`
- `=== phase1 launchd harness end rc=0 ===`

The rerun also had:

- `run-guest.rc`: `1`
- original `validate-only.rc`: `1`
- `mach_module=loaded`: present
- `phase1_launchd_harness_mode=dispatch-launchctl-plist`: present
- hard-stop scan: passed, no matches
- active source commit: `f71260cf4c9e`
- profile: `stable15-active`

The remaining failure was a verifier ordered-marker expectation:
`PHASE08_D19_STOP_AFTER_CYCLE2_ARMED=1` was emitted when cycle 2 was armed,
before `PHASE08_D19_CYCLE2_REAP_PATH=dispatch_proc_source`. Source-side
verifier-only commit `ee3ba8e1c645` accepted this ordering.

Oracle reran validate-only against the preserved serial with source commit
`ee3ba8e1c645`:

```text
phase08-launchd-dispatch-launchctl-keepalive-restart: PASS serial_log=/Users/me/wip-mach/wip-gpt-oracle/priv/runs/stable15-launchctl-baseline/20260604T143805Z-d19-keepalive-restart/d19_serial.log
```

No fresh D19 guest execution was performed for this validator correction.
The preserved D19 serial was revalidated successfully at source commit
`089311cff65b` after D19-D22 were moved to the shared D19 order contract.

Hard-stop scan patterns checked for D19:

- `panic`
- `Fatal trap`
- `KASSERT`
- `lock order reversal`
- `nosys 468`
- `rc=140`
- `SIGSYS`
- `Bad system call`
- `UNKNOWN FreeBSD SYSCALL`
- `Enter full pathname of shell`
- `Consoles: Dual (Video primary)`

No pattern matched.

## Guardrails

- No certification claim was made.
- No `certification/` directory was created.
- No repo-local `artifacts/` directory was created.
- Raw logs and run evidence remain ignored under `priv/runs/`.
- No D14-D20 guest reruns were performed after source-side verifier hardening
  commit `089311cff65b`; D19 and D20 were preserved-serial validation only.
- D20 was run after the D19 validator correction.
- D21 was rerun after source-side commit `089311cff65b` moved D19-D22 to the
  shared D19 verifier order contract.
- D22 and D23 were run only after D21 passed.
- Active source stayed at `f71260cf4c9e`.
- Profile stayed `stable15-active`.
- Rollback source stayed at `d4876c3fd9af`.
- No source deletion occurred.
- No source tree mutation was observed in the active or rollback source trees.
- `oracle-parity-a30ef3f` was not moved and still dereferenced to
  `a30ef3f4fff278d6dc7594543f364a880d4b36a4`.

## Classification

D19 is accepted as a stable15-active KeepAlive restart pass by validator
correction. The preserved guest evidence proves the runtime path; source-side
verifier-only commit `ee3ba8e1c645` corrected the ordered-marker expectation
without a fresh D19 guest run. D19 is not classified as a kernel hard stop,
source/profile mismatch, objdir mismatch, staged artifact mismatch, nosys 468,
WITNESS lock-order reversal, or boot-input contamination.

## D20 Details

D20 evidence is preserved at:

`priv/runs/stable15-launchctl-baseline/20260604T145102Z-d20-successful-exit/`

D20 used source harness commit `ee3ba8e1c645`, guest-run stdin isolation, and
the stable15-active pins.

Result:

- `run-guest.rc`: `1`
- `validate-only.rc`: `1`
- `mach_module=loaded`: present
- `phase1_launchd_harness_mode=dispatch-launchctl-plist`: present
- hard-stop scan: passed, no matches
- active source commit: `f71260cf4c9e`
- profile: `stable15-active`

D20 runtime markers reached the conditional SuccessfulExit tail:

- `PHASE08_D20_POST_CYCLE1_KEEPALIVE_REASON=successful_exit`
- `PHASE08_D20_CYCLE2_REAP_PATH=dispatch_proc_source`
- `PHASE08_D20_POST_CYCLE2_KEEPALIVE_REASON=successful_exit_mismatch`
- `PHASE08_D20_NO_THIRD_START=1`
- `PHASE08_D20_CONDITIONAL_KEEPALIVE_CONFIRMED=1`
- `phase08_dispatch_launchctl_plist_exit=0`
- `=== phase1 launchd harness end rc=0 ===`

The validator failed with:

```text
verify-phase08-launchd-dispatch-launchctl-successful-exit: dispatch-launchctl-plist markers are missing or out of order
```

The failure is in the inherited D19 ordered marker segment embedded in the D20
verifier. The D20 serial has:

```text
PHASE08_D19_STOP_AFTER_CYCLE2_ARMED=1
PHASE08_D19_CYCLE2_REAP_PATH=dispatch_proc_source
PHASE08_D19_STOP_RESTART_SUPPRESSED=harness_cycle_limit
PHASE08_D19_KEEPALIVE_RESTART_CONFIRMED=1
```

but the D20 verifier still expected `PHASE08_D19_STOP_AFTER_CYCLE2_ARMED=1`
after `PHASE08_D19_CYCLE2_REAP_PATH=dispatch_proc_source`.

Source-side verifier-only commit `ee6f251c714c` accepted the inherited D19
ordering in the D20 verifier. Oracle reran validate-only against the preserved
D20 serial with source commit `ee6f251c714c`:

```text
phase08-launchd-dispatch-launchctl-successful-exit: PASS serial_log=/Users/me/wip-mach/wip-gpt-oracle/priv/runs/stable15-launchctl-baseline/20260604T145102Z-d20-successful-exit/d20_serial.log
```

No fresh D20 guest execution was performed for this validator correction.
The preserved D20 serial was revalidated successfully at source commit
`089311cff65b` after D19-D22 were moved to the shared D19 order contract.

## D20 Classification

D19 is accepted as a stable15-active KeepAlive restart pass by validator
correction. D20 is accepted as a stable15-active SuccessfulExit pass by
validator correction. D20 is not classified as a kernel hard stop,
source/profile mismatch, objdir mismatch, staged artifact mismatch, nosys 468,
WITNESS lock-order reversal, boot-input contamination, or stable/15 runtime
regression.

## D21 Details

### First failed D21 attempt

D21 failed evidence is preserved at:

`priv/runs/stable15-launchctl-baseline/20260604T145636Z-d21-remove/`

D21 used source harness commit `ee6f251c714c`, guest-run stdin isolation, and
the stable15-active pins.

Result:

- `run-guest.rc`: `1`
- `validate-only.rc`: `1`
- `mach_module=loaded`: present
- `phase1_launchd_harness_mode=dispatch-launchctl-plist`: present
- hard-stop scan: passed, no matches
- active source commit: `f71260cf4c9e`
- profile: `stable15-active`

D21 runtime markers reached the inert RemoveJob tail:

- `PHASE08_D21_LOAD_CONFIRMED=1`
- `PHASE08_D21_INERT_LOAD_CONFIRMED=1`
- `PHASE08_D21_REMOVE_HANDLER_CALLED=1`
- `PHASE08_D21_JOB_DETACHED_FROM_JOBMGR=1`
- `PHASE08_D21_JOB_REMOVED_FROM_LABEL_TABLE=1`
- `PHASE08_D21_JOB_STRUCT_NO_LEAK=1`
- `PHASE08_D21_INERT_REMOVE_CONFIRMED=1`
- `phase08_dispatch_launchctl_plist_exit=0`
- `=== phase1 launchd harness end rc=0 ===`

The validator failed with:

```text
verify-phase08-launchd-dispatch-launchctl-remove: dispatch-launchctl-plist markers are missing or out of order
```

The failure is in the inherited D19 ordered marker segment embedded in the D21
verifier. The D21 serial has:

```text
PHASE08_D19_STOP_AFTER_CYCLE2_ARMED=1
PHASE08_D19_CYCLE2_REAP_PATH=dispatch_proc_source
```

but the D21 verifier still expects `PHASE08_D19_STOP_AFTER_CYCLE2_ARMED=1`
after `PHASE08_D19_CYCLE2_REAP_PATH=dispatch_proc_source`.

### Accepted D21 rerun

D21 was rerun after source-side verifier hardening commit `089311cff65b`.
Evidence is preserved at:

`priv/runs/stable15-launchctl-baseline/20260604T150446Z-d21-remove/`

Result:

- source harness commit: `089311cff65b`
- `run-guest.rc`: `1`
- `validate-only.rc`: `0`
- `mach_module=loaded`: present
- `phase1_launchd_harness_mode=dispatch-launchctl-plist`: present
- hard-stop scan: passed, no matches
- active source commit: `f71260cf4c9e`
- profile: `stable15-active`

D21 is accepted as the stable15-active inert RemoveJob pass.

## D22 Details

D22 evidence is preserved at:

`priv/runs/stable15-launchctl-baseline/20260604T150650Z-d22-running-remove/`

Result:

- source harness commit: `089311cff65b`
- `run-guest.rc`: `1`
- `validate-only.rc`: `0`
- `mach_module=loaded`: present
- `phase1_launchd_harness_mode=dispatch-launchctl-plist`: present
- hard-stop scan: passed, no matches
- active source commit: `f71260cf4c9e`
- profile: `stable15-active`

D22 is accepted as the stable15-active running RemoveJob / KeepAlive remove
pass.

## D23 Details

D23 evidence is preserved at:

`priv/runs/stable15-launchctl-baseline/20260604T150849Z-d23-reload/`

Result:

- source harness commit: `089311cff65b`
- `run-guest.rc`: `1`
- `validate-only.rc`: `0`
- `mach_module=loaded`: present
- `phase1_launchd_harness_mode=dispatch-launchctl-plist`: present
- hard-stop scan: passed, no matches
- active source commit: `f71260cf4c9e`
- profile: `stable15-active`

D23 is accepted as the stable15-active same-label reload pass.

## Current Classification

D19 is accepted as a stable15-active KeepAlive restart pass by validator
correction. D20 is accepted as a stable15-active SuccessfulExit pass by
validator correction. D21, D22, and D23 are accepted as fresh stable15-active
passes after source-side commit `089311cff65b` shared the D19 verifier order
contract.

The D19-D23 sweep is complete. No gate in this sweep is classified as a kernel
hard stop, source/profile mismatch, objdir mismatch, staged artifact mismatch,
nosys 468, WITNESS lock-order reversal, boot-input contamination, or stable/15
runtime regression.

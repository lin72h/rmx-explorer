# Stable/15 Launchctl Baseline Sweep: f71260cf4c9e

STATUS: Stopped on D19 marker-contract failure
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
| D19 KeepAlive restart | failed | `priv/runs/stable15-launchctl-baseline/20260604T141218Z-d19-keepalive-restart/` | Missing required marker `PHASE08_PROC_SOURCE_CANCELLED`; stopped sweep. |
| D20 SuccessfulExit | not run | n/a | Blocked by D19 failure. |
| D21 inert RemoveJob | not run | n/a | Blocked by D19 failure. |
| D22 running RemoveJob / KeepAlive remove | not run | n/a | Blocked by D19 failure. |
| D23 same-label reload | not run | n/a | Blocked by D19 failure. |

Two earlier D19 setup attempts are preserved as ignored evidence but are not
treated as D19 runtime results:

- `priv/runs/stable15-launchctl-baseline/20260604T140735Z-d19-keepalive-restart/`
  staged the smoke harness because the phase1 harness mode variable was not
  pinned.
- `priv/runs/stable15-launchctl-baseline/20260604T141127Z-d19-keepalive-restart/`
  stopped before guest execution because the local runner required a stage-log
  mode string that the staging script does not emit when rebuild is skipped.

## D19 Details

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
- No D20-D23 guest runs were performed after the D19 failure.
- Active source stayed at `f71260cf4c9e`.
- Profile stayed `stable15-active`.
- Rollback source stayed at `d4876c3fd9af`.
- No source deletion occurred.
- No source tree mutation was observed in the active or rollback source trees.
- `oracle-parity-a30ef3f` was not moved.

## Classification

D19 is classified as a launchctl baseline marker-contract failure under the
stable15-active runtime. It is not currently classified as a kernel hard stop,
source/profile mismatch, objdir mismatch, staged artifact mismatch, nosys 468,
WITNESS lock-order reversal, or boot-input contamination.

The sweep remains stopped at D19. D20-D23 need parent decision after D19 is
classified or fixed.

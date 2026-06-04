STATUS: Draft / Awaiting Review
GATES: D14 L2 migration implementation is blocked until this document is accepted.

# M4 D14 Guest Port Plan

Date: 2026-06-04

Oracle repo baseline: `b72c191`

Source parity tag: `oracle-parity-a30ef3f`

Required dereferenced source commit:

```text
oracle-parity-a30ef3f^{commit} == a30ef3f
```

Stable/15 update remains paused. No `certification/claims/` ledger exists. No
source deletion has occurred.

## Scope

This document designs the first L2 guest migration slice. It does not implement
D14, run a guest, create raw evidence, create certification claims, update
stable/15, copy scripts wholesale, or delete source files.

Target legacy gate:

```text
scripts/launchd/verify-phase08-launchd-dispatch-launchctl-plist.exs
```

Target fixture:

```text
fixtures/launchd/org.rmxos.phase08.d14.noop.plist
```

Slice ID:

```text
phase08.d14.launchctl_plist_inert_load
```

Proposed oracle target:

```sh
mix oracle.migration.parity phase08.d14.launchctl_plist_inert_load
```

Proposed module:

```text
RmxOSOracle.Migration.Phase08D14LaunchctlPlist
```

## Claim Boundary

D14 is L2 guest integration evidence only.

It proves that donor `launchctl load` loads one inert XML plist through:

```text
plist parser -> launch_msg SubmitJob -> MIG 437 -> donor import/dispatch/watch
```

It must prove:

- the XML plist is parsed through the Expat plist path
- the request is `SubmitJob`
- the management request reaches MIG routine 437
- donor import sees the expected label
- the job is created and imported
- `job_dispatch` and `job_keepalive` run
- the inert job is watched but not started
- the donor job exists with `pid=0`, `active=0`, `ondemand=1`,
  `start_pending=0`

It does not prove:

- a certification claim
- D17 or D18 lifecycle parity
- general launchctl coverage outside the D14 inert-load path
- stable/15 compatibility
- macOS semantic equivalence

## Legacy Reference Plan

Legacy contract reference must come from immutable source bytes only:

```text
oracle-parity-a30ef3f^{commit}
```

The task must fail closed unless the dereferenced commit is exactly:

```text
a30ef3f
```

For first D14 implementation, do not run the legacy verifier as an executable
parity peer. Use the legacy verifier only as source-reference semantics:

- marker contract
- hard-stop denylist source
- asset/hash provenance
- expected D14 invariants

The oracle implementation runs one oracle-owned D14 guest execution and
validates that run with oracle-owned env resolution, boot identity, marker
contract, hard-stop scan, and negative control.

Reason: the legacy verifier computes `repo_root` from its own location and
assumes `repo_root/freebsd-src-stable-15`. In the oracle migration this can
silently fork objdir lookup. Patching or wrapping the old verifier is too much
extra risk for the first L2 slice.

Hard rules:

- do not execute legacy code from the mutable `/Users/me/wip-mach/wip-gpt`
  working tree
- do not execute the legacy D14 verifier as the first D14 parity peer
- do not read support scripts or fixtures from the mutable source working tree
- file hashes are provenance only, not the parity pass gate
- the immutable tag and commit must never be rewritten or deleted
- the first D14 result is legacy-contract parity, not two-executable behavioral
  parity

## Legacy Asset Inventory

The following assets exist at `oracle-parity-a30ef3f^{commit}` and are in the
D14 migration blast radius.

| path | role | SHA256 at `a30ef3f` | migration handling |
| --- | --- | --- | --- |
| `scripts/launchd/verify-phase08-launchd-dispatch-launchctl-plist.exs` | legacy verifier | `2b5527ae750f7df7decc0f90ebe33998db452a2b7eb08a3482ba02a55731727f` | legacy reference; Elixir oracle replacement required |
| `fixtures/launchd/org.rmxos.phase08.d14.noop.plist` | fixture | `27a0dd69ca86f3f3ea732de6ea1d55680955fb9ccf6063594b286761d44cb310` | safe fixture import candidate |
| `scripts/bhyve/build-phase1-minibootstrap.sh` | build tool | `6f2973246190e31dec7a98b54456759250150d5c57ad1a1c99b518b0b6fdf86c` | transitional external build/stage tool |
| `scripts/launchd/build-bootstrap-donor-tests.sh` | build tool | `d79d1ce2afc476061a2de7963ba6dd3bdaa8c33d2df3bd4dbd25f6ebc3d54e12` | transitional external build/stage tool |
| `scripts/launchd/build-phase08-d14-launchctl.sh` | build tool | `e79045d3996588f344117c8287d7095f0c285c624bb99c5b5e5240d5c16d8f99` | transitional external build/stage tool |
| `scripts/dispatch/compile-libdispatch-build-lane.sh` | build tool | `9392dfdf5491c2904e571beccd8b39960cb09848144029f7398ad8a6673263e7` | transitional external build/stage tool |
| `scripts/launchd/link-launchd-harness.sh` | build/link tool | `38c4db8c792b894863dee73c26bd1a173e4ba2375095a9ef5be855037ee8b55a` | transitional external build/stage tool |
| `scripts/bhyve/stage-phase1-launchd-harness-guest.sh` | guest staging tool | `46a43b026ffbb1210db9d36c44839d344c186ee318746d579501f47442665847` | transitional external build/stage tool |
| `scripts/bhyve/run-guest.sh` | guest runner | `251ab6ddc5b09e333629cd7be5450c480b39be8acb2d70dfb5b1bbc88d2d8630` | transitional external run tool |

## Shell Migration Boundary

No shell or Python may become canonical runner logic.

For first D14 implementation, it is acceptable to temporarily invoke legacy
shell build/stage/run tools from immutable materialized reference bytes or from
explicit parent-approved external tool paths. That state is transitional and
must be recorded in `parity.json` limitations.

Classification:

| asset | initial D14 implementation role | canonical requirement before migrated/canonical status |
| --- | --- | --- |
| legacy verifier `.exs` | legacy reference only | replace with oracle Elixir task/module |
| `build-phase1-minibootstrap.sh` | transitional external build tool | port orchestration/env projection to Elixir or keep as explicit non-canonical external tool |
| `build-bootstrap-donor-tests.sh` | transitional external build tool | port orchestration/env projection to Elixir or keep as explicit non-canonical external tool |
| `build-phase08-d14-launchctl.sh` | transitional external build tool | port orchestration/env projection to Elixir or keep as explicit non-canonical external tool |
| `compile-libdispatch-build-lane.sh` | transitional external build tool | port lane selection/env projection to Elixir before canonical runner claim |
| `link-launchd-harness.sh` | transitional external build/link tool | port mode/env projection to Elixir before canonical runner claim |
| `stage-phase1-launchd-harness-guest.sh` | transitional external staging tool | port staging contract to Elixir before canonical runner claim |
| `run-guest.sh` | transitional external guest runner | port guest run/serial capture contract to Elixir before canonical runner claim |

The first D14 parity task may be accepted as an L2 migration pattern only if it
does not call itself canonical while shell tools remain in the runtime path.

## Oracle Target Design

Proposed task:

```sh
mix oracle.migration.parity phase08.d14.launchctl_plist_inert_load \
  --legacy-repo /Users/me/wip-mach/wip-gpt \
  --legacy-ref oracle-parity-a30ef3f \
  --lane launchd
```

Proposed module responsibilities:

- resolve and validate the immutable legacy tag
- materialize a source-shaped legacy reference tree under ignored run output
- validate all required env/path inputs
- build a resolved env map and project legacy variables
- execute transitional build/stage/run commands if implementation is approved
- capture host logs and serial logs
- parse and normalize required markers
- scan hard-stop denylist
- evaluate boot identity before D14 marker acceptance
- execute the negative control
- write raw evidence under `priv/runs/`
- write no committed parity record by default

## Env And Objdir Model

D14 must not use repo-root fallback paths.

Required explicit or env-validated values:

| variable | requirement |
| --- | --- |
| `NXPLATFORM_WORKSPACE_ROOT` | absolute path, exists |
| `NXPLATFORM_FREEBSD_SRC` | absolute path, exists, not symlink/relative for objdir-sensitive runs |
| `NXPLATFORM_KERNEL_OBJDIRPREFIX` | selected lane objdir prefix, absolute path, exists |
| `NXPLATFORM_ARTIFACTS_DIR` | absolute path, exists or parent dir creatable |
| `NXPLATFORM_PHASE1_LAUNCHD_HARNESS_WORKDIR` | absolute path, exists after build/link or parent dir creatable |
| `NXPLATFORM_PHASE07_LIBDISPATCH_DIR` | absolute path, exists for reused archive or parent dir creatable if rebuild is explicit |
| serial log output path | absolute path under ignored run output or configured artifact dir, parent dir creatable |

The D14 lane objdir prefix is configured input. It is not a hardcoded
`releng151*` default.

The oracle env resolver must project the selected D14 lane objdir prefix into:

```text
NXPLATFORM_KERNEL_OBJDIRPREFIX
MAKEOBJDIRPREFIX
```

before invoking any transitional legacy build or verifier code.

Hard stops:

- no fallback to `repo_root/freebsd-src-stable-15`
- no fallback to `wip-gpt-oracle/freebsd-src-stable-15`
- no fallback to `releng151*`, `releng151-rc1*`, or `/usr/obj` unless the value
  is explicitly pinned in env/local lane config
- no unresolved `${...}` placeholders after env expansion
- no nonexistent objdir prefix
- no guest/objdir gate if the selected lane prefix is not the value projected
  into `NXPLATFORM_KERNEL_OBJDIRPREFIX`

## Build/Stage/Run Evidence

Raw evidence path:

```text
priv/runs/migration-parity/<timestamp>-phase08-d14-launchctl-plist/
```

Expected raw files:

```text
parity.json
legacy_serial.log
oracle_serial.log
legacy_host.log
oracle_host.log
env_resolved.json
legacy_hashes.json
oracle_hashes.json
marker_comparison.json
hard_stop_scan.json
boot_identity.json
negative_control.json
legacy_materialized/
```

`legacy_host.log` and `oracle_host.log` are required when host-side commands
produce output or failures. Empty logs may be omitted only if `parity.json`
records that they were empty and intentionally omitted.

No raw transient evidence is committed.

Proposed `parity.json` fields:

```json
{
  "schema": "rmxos_oracle.migration.parity.raw_evidence.v1",
  "slice_id": "phase08.d14.launchctl_plist_inert_load",
  "result": "parity_passed",
  "comparison_axis": "legacy_vs_oracle",
  "contract_mode": "legacy_contract_reference",
  "legacy_executable_run": false,
  "observation_basis": "L2_guest_integration",
  "normalization_rule": {
    "id": "phase08.d14.launchctl_plist_inert_load.markers.v1",
    "description": "Compare required markers, normalized values, hard-stop absence, boot identity, and D14 PID/state invariants."
  },
  "legacy_contract_source_ref": {
    "tag": "oracle-parity-a30ef3f",
    "commit": "a30ef3f",
    "path": "scripts/launchd/verify-phase08-launchd-dispatch-launchctl-plist.exs",
    "sha256": "2b5527ae750f7df7decc0f90ebe33998db452a2b7eb08a3482ba02a55731727f"
  },
  "legacy": {
    "ref": "oracle-parity-a30ef3f",
    "dereferenced_commit": "a30ef3f",
    "file_hashes_path": "legacy_hashes.json"
  },
  "oracle": {
    "commit": "<oracle_commit>",
    "file_hashes_path": "oracle_hashes.json"
  },
  "environment": {
    "resolved_path": "env_resolved.json"
  },
  "boot_identity": {
    "path": "boot_identity.json",
    "passed": true
  },
  "marker_comparison": {
    "path": "marker_comparison.json",
    "passed": true
  },
  "hard_stop_scan": {
    "path": "hard_stop_scan.json",
    "passed": true
  },
  "negative_control": {
    "path": "negative_control.json",
    "passed": true
  },
  "limitations": [
    "No certification claim is created.",
    "Legacy verifier is not executed because repo-root fallback would confound objdir attribution.",
    "Shell build/stage/run tools remain transitional until replaced or explicitly approved as external non-canonical tools."
  ]
}
```

## Boot Identity Precondition

Before accepting any D14 marker, the oracle task must prove the guest booted the
intended kernel/module/source tuple.

Required `boot_identity.json` fields:

```json
{
  "schema": "rmxos_oracle.migration.boot_identity.v1",
  "rx_source_commit": "<commit>",
  "rx_source_ref": "<ref>",
  "freebsd_src": "/absolute/path",
  "kernel_objdirprefix": "/absolute/path",
  "kernel": {
    "path": "<path-or-null>",
    "sha256": "<sha256-or-null>"
  },
  "mach_ko": {
    "path": "<path-or-null>",
    "sha256": "<sha256-or-null>"
  },
  "guest_image": {
    "path": "<path-or-null>",
    "sha256": "<sha256-or-null>"
  },
  "serial_markers": {
    "mach_module": "loaded"
  },
  "passed": true
}
```

Minimum required serial boot marker:

```text
mach_module=loaded
```

If kernel, `mach.ko`, or guest image hashes are unavailable, the evidence must
record `null` plus a reason. Missing hashes are allowed only when the serial
identity and path provenance are still sufficient for a reviewable L2 run.

## Required Positive Markers

The migrated D14 validator must derive this list from an oracle-owned marker
spec, not scatter string literals across ad hoc checks.

### Shared Boot And Dispatch Preconditions

These are required before D14-specific markers are meaningful:

```text
phase1_launchd_harness_mode=dispatch-launchctl-plist
mach_module=loaded
phase08_dispatch_main_start
PHASE08_D7_DISPATCH_MAIN_DRIVER_QUEUE_CREATED=1
PHASE08_D7_DISPATCH_MAIN_DRIVER_SCHEDULED=1
PHASE08_D7_DISPATCH_MAIN_ENTER=1
PHASE08_D7_DISPATCH_MAIN_DRIVER_STARTED=1
phase08_dispatch_bootstrap_start
phase08_dispatch_lifecycle_start
phase08_dispatch_state_start
phase08_dispatch_donor_state_start
phase08_dispatch_caller_creds_start
phase08_dispatch_exit_state_start
phase08_dispatch_restart_start
phase08_dispatch_main_cycle_start
phase08_dispatch_runtime_start
phase08_dispatch_proc_event_start
phase08_dispatch_supervision_start
phase08_dispatch_launchctl_request_start
phase08_dispatch_submitjob_start
phase08_dispatch_runatload_start
phase08_dispatch_spawn_start
PHASE08_REAL_DISPATCH=1
PHASE08_NO_DISPATCH_STUBS=1
PHASE08_NO_DISPATCH_SOURCE_TYPE_STUBS=1
PHASE08_STAGED_LIBTHR=/root/twq-lib/libthr.so.3
```

The legacy D14 verifier also preserves inherited D1-D13 marker checks. The
first oracle D14 implementation may either keep these through a shared
precondition validator or call out the exact inherited validator it uses. It
must not drop inherited hard-stop protection.

### D14 Marker Contract

The following D14-specific checks are extracted from the legacy
`validate_d14/1` at `a30ef3f`.

Required exact markers:

```text
phase08_dispatch_launchctl_plist_start
PHASE08_D14_CLIENT=donor_launchctl
PHASE08_D14_COMMAND=load
PHASE08_D14_LOAD_SUBCOMMAND=1
PHASE08_D14_ASL_USED=0
PHASE08_D14_EXPECTED_LABEL=org.rmxos.phase08.d14.noop
PHASE08_D14_DONOR_JOB_PREEXISTING=0
PHASE08_D14_UFLAG_BEFORE=1
PHASE08_D14_UFLAG_FORCED_ZERO=1
PHASE08_D14_UFLAG_DURING_DISPATCH=0
PHASE08_D14_UFLAG_RESTORED=1
PHASE08_D14_LOAD_JOB_CALLED=1
PHASE08_D14_PLIST_SUFFIX_SELECTED=1
PHASE08_D14_JSON_ADAPTER_USED=0
PHASE08_D14_PLIST_PARSER=plist_to_launch_data_expat
PHASE08_D14_PLIST_PARSED=1
PHASE08_D14_PLIST_ROOT_DICT=1
PHASE08_D14_PLIST_DICT_KEY_COUNT=2
PHASE08_D14_PLIST_LABEL=org.rmxos.phase08.d14.noop
PHASE08_D14_PLIST_PROGRAMARGUMENTS_COUNT=1
PHASE08_D14_SOCKET_MATERIALIZE_CALLED=1
PHASE08_D14_SOCKET_MATERIALIZE_SKIPPED=1
PHASE08_D14_MATERIALIZED_FDS=0
PHASE08_D14_SUBMIT_JOB_CALLED=1
PHASE08_D14_REQUEST_KEY=SubmitJob
PHASE08_D14_REQUEST_ENCODING=dictionary
PHASE08_D14_LAUNCHCTL_PATH=plist_to_launch_msg_to_mig437
PHASE08_D14_MIG_ROUTINE=ipc_request
PHASE08_D14_MIG_ID=437
PHASE08_D14_DIRECT_MIG_USED=0
PHASE08_D14_MANAGEMENT_REQUEST_SENT=1
PHASE08_D14_REPLY_RECEIVED=1
PHASE08_D14_REPLY_ERRNO=0
PHASE08_D14_LAUNCHCTL_EXIT=0
PHASE08_D14_MANAGEMENT_CLIENT_STATUS=0
PHASE08_D14_FILEPORT_MAKEPORT_CALLED=0
PHASE08_D14_FILEPORT_MAKEFD_CALLED=0
PHASE08_D14_VPROCMGR_GETSOCKET_CALLED=0
PHASE08_D14_VPROCMGR_INIT_CALLED=0
PHASE08_D14_VPROCMGR_MOVE_SUBSET_CALLED=0
PHASE08_D14_VPROC_SWAP_INTEGER_CALLED=0
PHASE08_D14_UDS_FALLBACK_USED=0
PHASE08_D14_MIG_INFO_408_USED=0
PHASE08_D14_XPC_PIPE_TRY_RECEIVE_CALLED=0
PHASE08_D14_CALLER_PID_MATCH=1
PHASE08_D14_DONOR_RUNTIME_DEMUX_CALLED=1
PHASE08_D14_JOB_MIG_IPC_REQUEST=1
PHASE08_D14_REQUEST_FDS_CNT=0
PHASE08_D14_JOB_DO_IPC_REQUEST=1
PHASE08_D14_SUBMITJOB_SEEN=1
PHASE08_D14_JOB_IMPORT_CALLED=1
PHASE08_D14_IMPORTED_LABEL=org.rmxos.phase08.d14.noop
PHASE08_D14_DONOR_JOB_LABEL=org.rmxos.phase08.d14.noop
PHASE08_D14_DONOR_JOB_LABEL_MATCH=1
PHASE08_D14_JOB_CREATED=1
PHASE08_D14_JOB_IMPORTED=1
PHASE08_D14_RUNATLOAD_USED=0
PHASE08_D14_KEEPALIVE_USED=0
PHASE08_D14_MACHSERVICES_USED=0
PHASE08_D14_SOCKETS_USED=0
PHASE08_D14_GLOBAL_ON_DEMAND_CNT=0
PHASE08_D14_JOB_DISPATCH_CALLED=1
PHASE08_D14_JOB_DISPATCH_KICKSTART=0
PHASE08_D14_JOB_DISPATCH_UFLAG=0
PHASE08_D14_JOB_KEEPALIVE_CALLED=1
PHASE08_D14_JOB_KEEPALIVE_RETURN=0
PHASE08_D14_JOB_KEEPALIVE_REASON=none
PHASE08_D14_JOB_START_CALLED=0
PHASE08_D14_JOB_WATCHED=1
PHASE08_D14_DONOR_JOB_FOUND=1
PHASE08_D14_DONOR_JOB_PID=0
PHASE08_D14_DONOR_JOB_ACTIVE=0
PHASE08_D14_DONOR_JOB_ONDEMAND=1
PHASE08_D14_DONOR_JOB_START_PENDING=0
PHASE08_D14_LAUNCHCTL_PLIST_CONFIRMED=1
```

Required regex markers:

```text
PHASE08_D14_BOOTSTRAP_PORT_RESET=[1-9][0-9]* kr=0
PHASE08_D14_PLIST_PATH=/root/nxplatform/phase1/org.rmxos.phase08.d14.noop.plist
phase08_dispatch_launchctl_plist_client_pid=[1-9][0-9]*
PHASE08_D14_MANAGEMENT_CLIENT_PID=[1-9][0-9]*
PHASE08_D14_EXPECTED_MANAGEMENT_CLIENT_PID=[1-9][0-9]*
PHASE08_D14_CALLER_AUDIT_PID=[1-9][0-9]*
PHASE08_D14_SECURITY_SESSION_INJECTED=[01]
```

Required invariants:

- `phase08_dispatch_launchctl_plist_client_pid`,
  `PHASE08_D14_MANAGEMENT_CLIENT_PID`,
  `PHASE08_D14_EXPECTED_MANAGEMENT_CLIENT_PID`, and
  `PHASE08_D14_CALLER_AUDIT_PID` must all be equal.
- `PHASE08_D14_DONOR_JOB_PID == 0`.
- `PHASE08_D14_DONOR_JOB_ACTIVE == 0`.

Required ordering tail:

```text
phase08_dispatch_launchctl_plist_start
PHASE08_D14_UFLAG_FORCED_ZERO=1
PHASE08_D14_MANAGEMENT_REQUEST_SENT=1
PHASE08_D14_CALLER_PID_MATCH=1
PHASE08_D14_DONOR_RUNTIME_DEMUX_CALLED=1
PHASE08_D14_SUBMITJOB_SEEN=1
PHASE08_D14_JOB_IMPORT_CALLED=1
PHASE08_D14_JOB_DISPATCH_CALLED=1
PHASE08_D14_JOB_WATCHED=1
PHASE08_D14_LAUNCHCTL_PLIST_CONFIRMED=1
PHASE08_D7_DISPATCH_MAIN_COMPLETION_SOURCE=dispatch_async_f
```

Required D14/harness exits:

```text
phase08_dispatch_launchctl_plist_exit=0
PHASE08_XPC_PIPE_TRY_RECEIVE_CALLED=0
PHASE08_OLD_XPC_PIPE_RECEIVE_CALLED=0
=== phase1 launchd harness end rc=0 ===
```

## Hard-Stop Scan

The migrated validator must preserve the legacy hard-stop scan.

Kernel/system hard stops:

```text
PHASE08_FATAL_SIGNAL
SIGSYS
Bad system call
UNKNOWN FreeBSD SYSCALL
Signal 12
signal = 12
nosys [0-9]+
panic:
Fatal trap
lock order reversal
Sleeping thread
KDB: stack backtrace
KASSERT
WITNESS / lock order reversal diagnostics
```

Inherited D1-D13 failure markers must continue to reject the run. The design
does not restate every inherited marker here; the first implementation must
either reuse a shared inherited denylist or materialize an oracle-owned copy
with a source reference to `verify-phase08-launchd-dispatch-launchctl-plist.exs`
at `a30ef3f`.

D14 failure markers:

```text
PHASE08_D14_REPLY_RECEIVED=0
PHASE08_D14_REPLY_ERRNO=[1-9][0-9]*
PHASE08_D14_JOB_START_CALLED=1
PHASE08_D14_SHOULD_NOT_RUN_EXECUTED=1
PHASE08_D14_UFLAG_RESTORED=0
PHASE08_D14_UFLAG_DURING_DISPATCH=1
PHASE08_D14_JOB_DISPATCH_UFLAG=1
PHASE08_D14_DONOR_JOB_PREEXISTING=1
PHASE08_D14_JSON_ADAPTER_USED=1
PHASE08_D14_UDS_FALLBACK_USED=1
PHASE08_D14_FILEPORT_MAKEPORT_CALLED=[1-9][0-9]*
PHASE08_D14_FILEPORT_MAKEFD_CALLED=[1-9][0-9]*
PHASE08_D14_VPROCMGR_GETSOCKET_CALLED=[1-9][0-9]*
PHASE08_D14_VPROCMGR_INIT_CALLED=[1-9][0-9]*
PHASE08_D14_VPROCMGR_MOVE_SUBSET_CALLED=[1-9][0-9]*
PHASE08_D14_VPROC_SWAP_INTEGER_CALLED=[1-9][0-9]*
PHASE08_D14_MIG_INFO_408_USED=1
PHASE08_D14_MANAGEMENT_REQUEST_TIMEOUT=1
PHASE08_D14_LAUNCHCTL_PLIST_CONFIRMED=0
PHASE08_D14_LOAD_SUBCOMMAND=0
PHASE08_D14_SOCKET_MATERIALIZE_SKIPPED=0
PHASE08_D14_MATERIALIZED_FDS=[1-9][0-9]*
PHASE08_D14_GLOBAL_ON_DEMAND_CNT=[1-9][0-9]*
PHASE08_D14_JOB_KEEPALIVE_RETURN=1
```

`hard_stop_scan.json` must record:

- denylist version or source ref
- matched hard-stop patterns
- inherited failure marker scan result
- D14 failure marker scan result
- pass/fail

## Negative Control

D14 cannot be marked migrated without a red path.

Preferred first negative control:

1. copy a passing serial log into the ignored run directory
2. remove one required D14 marker, such as
   `PHASE08_D14_LAUNCHCTL_PLIST_CONFIRMED=1`
3. run the oracle marker validator against the mutated log
4. require failure with a marker-specific error

Alternative negative controls:

- alter `PHASE08_D14_EXPECTED_LABEL` or `PHASE08_D14_DONOR_JOB_LABEL_MATCH`
- inject `PHASE08_D14_JOB_START_CALLED=1`
- malformed plist fixture, only if parent accepts that this does not expand
  scope into D15

For first D14 implementation, serial-log mutation is acceptable. It proves the
verifier red path, not guest behavior red path. That limitation must be recorded
in `negative_control.json` and `parity.json`.

## Legacy-Contract Parity Rule

The first D14 implementation is legacy-contract parity, not two-executable
behavioral parity. It compares the oracle-owned guest run against the D14
contract extracted from the immutable legacy verifier at
`oracle-parity-a30ef3f^{commit}`, not against a simultaneously executed legacy
verifier.

Compare:

- required marker set
- normalized marker values
- D14 PID equality invariants
- job state invariants
- hard-stop absence
- boot identity fields
- relevant host command return codes
- guest run status
- evidence provenance

Normalize:

- timestamps
- PIDs, except where equality/nonzero/zero invariants are declared
- Mach port numbers
- temp-dir paths
- host-specific absolute paths outside declared env fields
- ordering outside the declared marker order

Do not normalize:

- required marker names
- required marker values
- `mach_module=loaded`
- fixture guest path
- `MIG_ID=437`
- job start/active/pid zero invariants
- failure marker presence

## Parity Record Shape

Curated records are deferred until parent approval. Raw evidence is written
first under `priv/runs/`.

Future curated parity record shape:

```json
{
  "schema": "rmxos_oracle.migration.parity_record.v1",
  "slice_id": "phase08.d14.launchctl_plist_inert_load",
  "status": "parity_passed",
  "comparison_axis": "legacy_vs_oracle",
  "contract_mode": "legacy_contract_reference",
  "legacy_executable_run": false,
  "observation_basis": "L2_guest_integration",
  "equivalence_class": {
    "id": "phase08.d14.launchctl_plist_inert_load.markers.v1",
    "normalization_rule_refs": [
      "docs/migration-m4-d14-guest-port-plan.md"
    ]
  },
  "legacy_contract_source_ref": {
    "tag": "oracle-parity-a30ef3f",
    "commit": "a30ef3f",
    "path": "scripts/launchd/verify-phase08-launchd-dispatch-launchctl-plist.exs",
    "sha256": "2b5527ae750f7df7decc0f90ebe33998db452a2b7eb08a3482ba02a55731727f"
  },
  "legacy": {
    "tag": "oracle-parity-a30ef3f",
    "commit": "a30ef3f",
    "file_hashes": []
  },
  "oracle": {
    "commit": "<oracle_commit>",
    "replacement_hashes": []
  },
  "input_fixture_hashes": [
    {
      "path": "fixtures/launchd/org.rmxos.phase08.d14.noop.plist",
      "sha256": "27a0dd69ca86f3f3ea732de6ea1d55680955fb9ccf6063594b286761d44cb310"
    }
  ],
  "evidence_hashes": [],
  "negative_control": {
    "description": "Required-marker deletion causes marker validator failure.",
    "evidence_hashes": []
  },
  "result": "parity_passed",
  "limitations": [
    "No certification claim.",
    "No D17/D18 lifecycle parity.",
    "Legacy verifier is not executed because repo-root fallback would confound objdir attribution.",
    "Shell build/stage/run tools are transitional unless later ported or separately approved."
  ]
}
```

## Deletion Policy

Use mark-first/delete-later.

- Do not delete D14 source files during design.
- Do not delete D14 source files during first implementation.
- Do not delete source working-tree files until parent approves after multiple
  slices or a natural checkpoint.
- Never delete, rewrite, or retag `oracle-parity-a30ef3f`.

## Acceptance Criteria For Future D14 Implementation

D14 implementation may be accepted only when:

- the design is accepted
- the task resolves `oracle-parity-a30ef3f^{commit}` to `a30ef3f`
- legacy contract source is read only from `oracle-parity-a30ef3f^{commit}`
- legacy verifier is not executed
- no legacy reference reads mutable source working-tree files
- env/path validation rejects repo-root fallback paths
- configured D14 objdir prefix is projected into `NXPLATFORM_KERNEL_OBJDIRPREFIX`
- boot identity passes before marker validation
- required D14 markers and invariants pass
- hard-stop denylist passes
- negative control fails as expected
- raw evidence is written only under ignored `priv/runs/`
- no committed parity record is written by default
- no guest evidence is represented as certification evidence
- no D17/D18 migration starts
- no source deletion occurs
- stable/15 update remains paused

## Hard Stops

- no implementation in this design step
- no guest run in this design step
- no source deletion
- no stable/15 update
- no certification claims
- no broad `scripts/` copy
- no shell/Python canonical runner
- no committed raw evidence
- no D17/D18 migration in D14
- no use of mutable source working tree as legacy reference
- no legacy verifier executable peer in the first D14 implementation
- no D14 pass without boot identity
- no D14 pass from exit code alone
- no D14 pass from serial silence
- no D14 migrated status without positive evidence and negative control
- no canonical status while shell build/stage/run tools remain required

## Path/Env Blockers To Resolve Before Implementation

The implementation decision is resolved: use approach 1.

For first D14 implementation:

- do not run the legacy verifier as an executable parity peer
- use the legacy verifier at `oracle-parity-a30ef3f` only as
  source-reference semantics:
  - marker contract
  - hard-stop denylist source
  - asset/hash provenance
  - expected D14 invariants
- run one oracle-owned D14 guest execution
- validate that run with oracle-owned env resolution, boot identity, marker
  contract, hard-stop scan, and negative control

Remaining implementation blocker: transitional shell tools still require
explicit env projection and must not be treated as canonical runner logic. D14
may use them for the first L2 run, but the result must not call itself canonical
while those tools remain in the runtime path.

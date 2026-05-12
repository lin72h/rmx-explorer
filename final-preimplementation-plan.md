# Final Pre-Implementation Plan: nx-v64z macOS Oracle Package

Date: 2026-05-12

## Authority

This is the final operational plan before implementation.

Use it for Stage 1-2 implementation. The broader design remains in
`comprehensive-nx-v64z-macos-oracle-plan.md`; this file turns that design into
the concrete first work package.

Earlier local notes are background only:

- `rx-macos-oracle-plan-and-parent-questions.md`
- `elixir-test-migration-plan.md`
- `nextbsd-test-inventory-and-oracle-transfer-plan.md`
- `test-migration-map.md`
- `second-round-review-opus.md`

## Current Verdict

Stage 1-2 can begin now.

Stage 3+ should wait for the remaining parent decisions or use explicit
`not_observable` / per-host downgrade classifications where the plan already
allows that.

## Roles

- `nx-v64z`: owns this oracle package, schema, comparison policy, and findings.
- `mx-x64z`: runs probes on native Intel macOS.
- `mx-a64z`: runs probes on native Apple Silicon macOS.
- `rx`: local rmxOS development/comparison lane, not oracle owner.

## Confirmed Baseline

The earlier `COPY_SEND` uref concern is resolved on the NextBSD side.

Evidence from `/Users/me/wip-mach-opus/wip-opus`:

| Artifact | Path |
| --- | --- |
| Probe source, batches 1-22 | `scripts/bhyve/nxplatform-mach-probe.c` |
| Batch 21 accounting log | `reports/batch21-serial.log` |
| Batch 22 descriptor log | `reports/batch22-serial.log` |

Batch 21 proves source-side `COPY_SEND` accounting is stable:

- header `COPY_SEND`
- descriptor `COPY_SEND`
- repeated MIG RPC `COPY_SEND`

Batch 22 shows cross-task `COPY_SEND` descriptor delivery creates a received
send right with `entry_refs=2` on NextBSD. The macOS oracle should verify
whether that delivered-right behavior and cleanup need are universal Mach
behavior or NextBSD-specific.

## Stage 1 Scope: Repository Skeleton

Create only structure, harness shell, and documentation.

Do not implement Mach probes yet.

### Files and Directories

```text
README.md
macos-validation/
  Makefile
  .build/
    bin/
    obj/
  probes/
    common/
    foundation/
    m1/
    m2/
  harness/
    collect_env.sh
    run_all.sh
    sign_probe.sh
    validate_json.sh
  manifests/
  results/
    mx-x64z/
    mx-a64z/
  findings/
    nx-v64z/
```

Results must be written under:

```text
macos-validation/results/<agent>/<date>-<macos-version>-<darwin-version>/
```

That directory naming is mandatory on macOS hosts. When Stage 1-2 is developed
locally on rx/rmxOS or another non-macOS host, use this fallback instead:

```text
macos-validation/results/<agent>/<date>-<os-name>-<kernel-version>/
```

`collect_env.sh` must emit the fields needed for both forms and may also emit a
precomputed `result_dir_name` so `run_all.sh` does not duplicate OS parsing
logic.

Build outputs live under `macos-validation/.build/`. Do not place compiled or
signed binaries in source directories. `make clean` removes only `.build/`.

### Stage 1 Make Targets

The first Makefile should define these targets, even if some are initially
thin wrappers:

| Target | Purpose |
| --- | --- |
| `all` | build every enabled probe/helper |
| `clean` | remove `macos-validation/.build/` only |
| `list` | list known probes without running them |
| `env` | run `harness/collect_env.sh` |
| `run` | run all enabled probes through `harness/run_all.sh` |
| `validate-json` | run `harness/validate_json.sh` on results/fixtures |

### Stage 1 Harness Contracts

`collect_env.sh`:

- emits environment JSON
- records command failures explicitly
- does not fail because Zig is missing during C-only stages
- provides the macOS version and Darwin version used by `run_all.sh` for macOS
  result directory naming
- provides OS name and kernel version for the non-macOS fallback result
  directory naming
- may emit `result_dir_name` as the canonical directory component selected for
  the current host

For the complete `environment` field list, use the Environment Capture section
in `comprehensive-nx-v64z-macos-oracle-plan.md`.

`sign_probe.sh`:

- ad-hoc signs main probes and helper executables
- records signing success/failure
- command format: `sign_probe.sh <binary>`
- returns 0 on success and 1 on failure
- prints `signed: <path>` or `sign_failed: <path>` to stdout
- output format is exactly one line: `<status>: <path>`
- binaries passed to the signer are build outputs under `.build/bin/`
- once `nx_env` exists, the harness records per-binary signing status as
  `{path, status, return_code, output}` in the environment/signing object

`run_all.sh`:

- accepts `--agent mx-x64z` or `--agent mx-a64z`
- accepts `--list`
- calls `collect_env.sh` first
- writes environment JSON as the first file in the result directory
- derives the result directory from `result_dir_name` when present; otherwise it
  uses the macOS form on macOS and the fallback
  `<date>-<os-name>-<kernel-version>` form elsewhere
- creates result directories on demand with `mkdir -p`
- runs only enabled probes
- captures each probe's stdout JSON to a result file
- lets diagnostics and errors go to stderr or a separate harness log

`validate_json.sh`:

- validates required top-level schema fields
- uses `python3` for JSON syntax and required-field checks
- treats `python3` as the required validator for Stage 1-2 because stock macOS
  provides it in the target environment
- may use `jq` only as an optional extra diagnostic, not as the primary
  validator
- if `python3` is unavailable, emits an explicit toolchain failure or skip to
  stderr and exits with a non-success status instead of silently accepting
  malformed JSON
- should be replaceable by later Elixir schema tests

## Stage 2 Scope: Common C Helpers

Create reusable C helpers and a schema-emitting smoke probe.

Do not implement the full foundation/M1/M2 probes yet.

### Common Helpers

```text
macos-validation/probes/common/
  nx_result.h
  nx_result.c
  nx_env.h
  nx_env.c
  nx_mach_utils.h
  nx_mach_utils.c
  nx_json.h
  nx_json.c
```

Responsibilities:

| Helper | Responsibility |
| --- | --- |
| `nx_json` | minimal dependency-free JSON string/object emission |
| `nx_result` | schema constant, status/class enums, result object helpers |
| `nx_env` | environment object capture/embedding helpers |
| `nx_mach_utils` | Mach return formatting, port labels, baseline inventory, cleanup helpers |

Output contract:

- each probe writes exactly one result JSON object to stdout
- result JSON should be a single line when practical
- diagnostics, progress, and errors go to stderr
- the harness captures stdout to a JSON file under the result directory

JSON emitter requirements:

- write to `FILE *`
- emit JSON only; do not parse JSON
- escape at least `\`, `"`, `\n`, `\t`, and `\r`
- emit `\u00XX` for other control characters below `0x20`
- keep the implementation small and dependency-free

Mach helper priority:

- baseline snapshot/compare is the most important reusable pattern
- use `mach_port_names()` before and after probe bodies
- diff name sets and feed `cleanup.returned_to_baseline`
- later probes may add `mach_port_type()` and `mach_port_get_refs()` details on
  top of the baseline snapshot

### Schema Constant

Centralize the schema name:

```text
nx-v64z.macos-oracle.v1
```

The parent may still rename it before host result collection. Stage 2 should
make that a one-line constant change.

### Makefile Defaults

Use overridable debug-friendly defaults:

```make
CFLAGS ?= -Wall -Wextra -O0 -g
BUILD_DIR ?= .build
BIN_DIR ?= $(BUILD_DIR)/bin
OBJ_DIR ?= $(BUILD_DIR)/obj
```

For Stage 1-2, an explicit `PROBES` list is safer than wildcard discovery
because only the smoke probe should build initially.

The first Makefile should compile probe objects under `$(OBJ_DIR)` and link
probe binaries under `$(BIN_DIR)`. The `clean` target removes only
`$(BUILD_DIR)` so source directories, results, findings, and manifests are never
touched by cleanup.

## Required JSON Shape

The first implementation must emit this schema shape, even if many values are
null or empty for early smoke probes.

Important requirements:

- `cross_reference` object exists with nullable fields.
- `message.remote_port`, `message.local_port`, and `message.header_rights`
  exist.
- `returns` is an array of typed call-return objects.
- `right_deltas` is an array of typed right-delta objects.
- `entry_refs_before` and `entry_refs_after` exist and may be null.
- symbolic port labels are used instead of raw Mach port names in comparison
  fields.
- C-only results include Zig fields as null/false.
- environment includes the host, compiler, SDK, signing, SIP/sandbox/root,
  Rosetta, architecture, CPU-feature, and Zig fields defined in the
  comprehensive plan.

Symbolic labels are descriptive freeform strings scoped to one probe result.
Recommended labels include `service_port`, `cargo_port`, `task_port`,
`reply_port`, `bootstrap_port`, and `delivered_port`. Labels must be consistent
within one result but do not need to match across probes.

Representative fields:

```json
{
  "schema": "nx-v64z.macos-oracle.v1",
  "agent": "mx-a64z",
  "test_id": "macos_foundation_smoke",
  "cross_reference": {
    "nextbsd_test_id": null,
    "donor_equivalent_id": null
  },
  "status": "pass",
  "semantic_class": "exact_contract",
  "environment": {
    "sw_vers": null,
    "uname": "",
    "os_name": "",
    "kernel_version": "",
    "result_dir_name": "",
    "arch": "",
    "machine": "",
    "compiler": "",
    "sdk": "",
    "sdk_version": "",
    "sdk_path": "",
    "xcode_select_path": "",
    "cpu_brand": null,
    "cpu_features": {},
    "apple_silicon": {
      "hw_optional_arm64": null,
      "arm64e": null,
      "pointer_authentication": null,
      "raw_sysctls": {}
    },
    "rosetta": null,
    "sip_enabled": null,
    "sandboxed": null,
    "run_as_root": false,
    "ad_hoc_signed": true,
    "hardened_runtime": false,
    "signing": {
      "binaries": [
        {
          "path": "macos-validation/.build/bin/smoke",
          "status": "signed",
          "return_code": 0,
          "output": "signed: macos-validation/.build/bin/smoke"
        }
      ]
    },
    "zig_version": null,
    "zig_path": null,
    "zig_lib_dir": null,
    "zig_fallback": false,
    "zig_fallback_reason": null
  },
  "message": {
    "msgh_bits": "",
    "remote_port": {
      "name": "service_port",
      "disposition": null,
      "right_type": null
    },
    "local_port": {
      "name": "reply_port",
      "disposition": null,
      "right_type": null
    },
    "header_rights": [],
    "descriptor_count": 0,
    "descriptors": []
  },
  "returns": [
    {
      "call": "mach_port_names",
      "returned": "KERN_SUCCESS",
      "raw": 0,
      "errno": null
    }
  ],
  "right_deltas": [
    {
      "operation": "allocate receive right",
      "port_name": "service_port",
      "right_type": "MACH_PORT_TYPE_RECEIVE",
      "before_urefs": null,
      "after_urefs": null,
      "entry_refs_before": null,
      "entry_refs_after": null,
      "expected": "created"
    }
  ],
  "cleanup": {
    "returned_to_baseline": true,
    "notes": ""
  },
  "notes": ""
}
```

## Stage 3 Probe Plan, Not Yet Implementation

Stage 2 includes one real smoke binary:

- `foundation/smoke.c`

The smoke probe should allocate one port, inspect it enough to exercise common
helpers, destroy it, and emit a complete `nx-v64z.macos-oracle.v1` result. It is
the first end-to-end pipeline check: compile, sign, run, capture JSON, validate.

Foundation probes:

- `foundation/port_names.c`
- `foundation/port_get_refs.c`
- `foundation/port_type.c`

M1 probes:

- `m1/fork_port_inheritance.c`
- `m1/spawn_exec_port_inheritance.c`
- `m1/bootstrap_special_port.c`
- `m1/header_copy_send_accounting.c`
- `m1/header_move_send_accounting.c`

M2 probes:

- `m2/descriptor_copy_send.c`
- `m2/descriptor_move_send.c`
- `m2/send_once_descriptor.c`
- `m2/invalid_descriptor_disposition.c`
- `m2/dead_name_descriptor_right.c`
- `m2/double_move_send_descriptor.c`
- `m2/receiver_copyout_failure.c`
- `m2/sender_exit_queued_descriptor.c`
- `m2/receiver_exit_queued_descriptor.c`

Stage 3+ must preserve:

- `mach_msg()` only, not `mach_msg2()` or `mach_msg_overwrite()`
- watchdog, `waitpid()`, cleanup, explicit rendezvous
- rendezvous orthogonal to the IPC path under test
- unknown `mach_port_type()` bits recorded as raw hex
- helper executables ad-hoc signed by the same harness path

## Donor and Migration Work

Do not start donor wrapping before Stage 1-5 unless the parent explicitly
changes the order.

`test-migration-map.md` is the coverage map, not the implementation order.

Directly portable donor tests:

- `ipc-hello`
- `set-bport`

They should be wrapped later with:

- JSON output
- cleanup baseline verification
- noninteractive run mode
- stock macOS privilege classification

## Coordination With OPUS

OPUS should continue the M2.1 batch 22 rerun while this oracle repo starts
Stage 1-2.

These tracks are independent:

- OPUS validates the latest NextBSD cleanup fix in the guest.
- This repo builds the cloneable oracle skeleton and common helpers.
- Any new OPUS result can be folded into Stage 3+ before macOS host collection.

## Acceptance Criteria Before Stage 1-2 Is Complete

Stage 1 is complete when:

- layout exists
- `.build/` is the only build-output root
- Makefile targets exist
- harness scripts exist and have basic argument handling
- result directory naming follows the macOS date/version convention on macOS
  and the OS/kernel fallback elsewhere
- environment capture runs without requiring Zig
- `run_all.sh --list` works
- `run_all.sh` creates result directories with `mkdir -p`

Stage 2 is complete when:

- common helper files exist
- schema constant is centralized
- `foundation/smoke.c` builds, signs, runs, and emits valid JSON
- C-only Zig fields are null/false
- symbolic labels are used in result examples
- signing helper handles main binary and helper binaries
- per-binary signing status is recorded as `{path, status, return_code, output}`
- `validate_json.sh` validates syntax and required fields with `python3`

## Remaining Decisions Before Stage 3+

1. Confirm final schema name before real host result collection.
2. Decide whether read-only bootstrap inheritance is mandatory when mutation is
   blocked.
3. Decide per-host versus global downgrade for unreliable `mach_port_get_refs()`.
4. Treat `receiver_copyout_failure` as likely `not_observable` unless a stock
   macOS method is provided.
5. Keep early `ipc-hello` compile-only unless the parent requests runtime.
6. Decide parser script ownership before Elixir migration.
7. Decide donor history script ownership before Elixir migration.
8. Set minimum Elixir/Erlang versions before Stage 7.

## Final Review Focus

The final reviewer should decide:

- whether Stage 1-2 is concrete enough to implement exactly
- whether any schema field is still missing before common helpers are written
- whether the harness contracts are too vague
- whether any remaining parent question actually blocks Stage 1-2

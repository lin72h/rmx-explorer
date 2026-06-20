# Comprehensive nx-v64z macOS Oracle Plan

Date: 2026-05-12

## Purpose

This document is the consolidated plan for the cloneable macOS oracle package
in `/Users/me/wip-mach/wip-gpt-oracle`.

The package will be built on `rx` / rmxOS, cloned onto native macOS hosts, and
used by:

- `mx-x64z`: native Intel macOS runner
- `mx-a64z`: native Apple Silicon macOS runner
- `nx-v64z`: shared portable oracle/schema/comparison owner

The goal is to collect observable native macOS Mach IPC behavior and compare it
against rxOS/NextBSD behavior without importing macOS implementation code.

## Source Planning Notes

This document synthesizes the current local planning files:

- `rx-macos-oracle-plan-and-parent-questions.md`
- `elixir-test-migration-plan.md`
- `nextbsd-test-inventory-and-oracle-transfer-plan.md`
- `parent-agent-questions.md`

Those files remain useful as detailed side notes. This file is the main
execution plan.

For immediate Stage 1-2 implementation, use
`final-preimplementation-plan.md` as the operational checklist. This
comprehensive plan remains the broader design reference.

Schema supersession note: the older schema example in
`../wip-gpt/docs/macos-oracle-validation-agent-handoff.md` is superseded by the
schema in this comprehensive plan. Runner agents should use this plan's
`message.remote_port`, `message.local_port`, `message.header_rights`, typed
`returns`, typed `right_deltas`, and `cross_reference` fields.

## Role and Lane Terminology

`nx-v64z` owns the portable macOS oracle package:

- probe contract
- result schema
- source layout
- host run instructions
- comparison policy
- synthesized findings

`mx-x64z` and `mx-a64z` run the probes and record host-specific facts.

`rx` is the local rmxOS development lane and comparison consumer. It is not the
oracle source/schema lane.

NextBSD is the donor/guest behavior target whose Mach semantics are being
validated.

## Parent Decisions Already Recorded

- `/Users/me/wip-mach/wip-gpt-oracle` is the cloneable oracle probe repository.
- `/Users/me/wip-mach/wip-gpt` remains the planning/docs repository.
- First implementation is shell/Make plus native C probes.
- Existing donor tests stay native C/Make.
- Elixir is for harness tests, manifests, fixtures, comparison, and reporting.
- Elixir comparison/report generation comes after both macOS result sets and
  the NextBSD/rxOS result set exist.
- Zig is used only for new narrow ABI/descriptor probes when C is insufficient,
  source sharing with the NextBSD guest lane is required, or exact binary layout
  control is necessary.
- Queued sender/receiver-exit descriptor tests are first follow-ups, not
  mandatory before basic `COPY_SEND` / `MOVE_SEND`.
- Curated summary JSON and findings notes may be committed.
- Raw logs stay outside git unless a raw fixture is specifically useful.
- Rosetta results are allowed only as non-primary supplemental artifacts.
- Primary `mx-a64z` results must be native arm64/arm64e.
- The schema does not define a separate architecture class. Intel versus Apple
  Silicon disagreement uses `version_sensitive` with explicit architecture
  notes.
- NextBSD batch 21 has resolved the earlier `COPY_SEND` uref suspicion:
  header `COPY_SEND`, body descriptor `COPY_SEND`, and repeated MIG RPC
  `COPY_SEND` accounting are stable on NextBSD. macOS oracle probes now verify
  that native macOS matches this confirmed baseline.

## Hard Boundaries

Do not:

- import XNU source or Apple implementation code
- require private entitlements as the default validation path
- require SIP changes
- require kernel debugging
- rely on kernel memory inspection
- use `mach_msg2()` or `mach_msg_overwrite()` in new probes
- compare raw Mach port-name integers across tasks, runs, or hosts
- copy the full inherited FreeBSD test suite into the oracle repo
- rewrite existing donor C tests into Elixir or Zig
- make macOS default runs depend on bhyve, doas, VM images, or full donor roots

Every new probe must call `mach_msg()` explicitly.

## Donor-Era Context

The NextBSD donor behavior is roughly macOS 10.10-10.11 era Darwin. Validation
hosts are expected to run modern macOS 14/15.

Modern macOS behavior is oracle evidence, not automatic donor-era truth. If a
behavior could plausibly have changed since the donor era, classify it as
`version_sensitive` unless public evidence shows it is stable and donor-relevant.

Intel versus Apple Silicon differences also use `version_sensitive` with
explicit architecture notes unless the schema is intentionally revised later.

## Target Repository Layout

```text
.
  README.md
  comprehensive-nx-v64z-macos-oracle-plan.md
  comprehensive-plan-review-request.md
  parent-agent-questions.md
  macos-validation/
    Makefile
    .build/
      bin/
      obj/
    probes/
      common/
        nx_result.h
        nx_result.c
        nx_env.h
        nx_env.c
        nx_mach_utils.h
        nx_mach_utils.c
        nx_json.h
        nx_json.c
      foundation/
        port_names.c
        port_get_refs.c
        port_type.c
      m1/
        fork_port_inheritance.c
        spawn_exec_port_inheritance.c
        bootstrap_special_port.c
        header_copy_send_accounting.c
        header_move_send_accounting.c
      m2/
        descriptor_copy_send.c
        descriptor_move_send.c
        send_once_descriptor.c
        invalid_descriptor_disposition.c
        dead_name_descriptor_right.c
        double_move_send_descriptor.c
        receiver_copyout_failure.c
        sender_exit_queued_descriptor.c
        receiver_exit_queued_descriptor.c
    harness/
      run_all.sh
      collect_env.sh
      sign_probe.sh
      validate_json.sh
    manifests/
      nextbsd-mach-tests.json
      inherited-freebsd-test-roots.json
    results/
      mx-x64z/
        <date>-<macos-version>-<darwin-version>/
        <date>-<os-name>-<kernel-version>/      # non-macOS fallback only
      mx-a64z/
        <date>-<macos-version>-<darwin-version>/
        <date>-<os-name>-<kernel-version>/      # non-macOS fallback only
    findings/
      nx-v64z/
  mix.exs
  test/
    test_helper.exs
    support/
      host_capabilities.ex
      fixture_paths.ex
    harness/
      parse_serial_test.exs
      parse_characterize_test.exs
      oracle_json_schema_test.exs
      env_capture_test.exs
    rx/
      bhyve_script_contract_test.exs
      donor_inventory_script_test.exs
    donor/
      donor_mach_manifest_test.exs
      donor_root_integration_test.exs
  fixtures/
    serial/
    characterize/
    oracle-json/
    donor/
  tools/
    parsers/
```

Implementation may create this layout incrementally. The first C probe package
does not need the full Elixir tree.

The `m1/` and `m2/` directory names are roadmap package names inherited from the
parent Phase 0.5 plan. They do not refer to Apple Silicon M1/M2 hardware; host
hardware is recorded separately in environment metadata.

## Build and Run Contract

Default C build:

```sh
clang -Wall -Wextra -O0 -g -o probe probe.c
codesign -s - probe
./probe
```

Default package flow:

```sh
cd macos-validation
make clean
make
harness/run_all.sh --agent mx-a64z
```

The same flow must work for `mx-x64z`.

No framework flag should be required for standard Mach headers:

- `mach/mach.h`
- `mach/message.h`
- `servers/bootstrap.h`

If a probe needs extra compile or link flags, the JSON result must record why.
Any helper executable used by a process probe must be built and ad-hoc signed by
the same harness path as the main probe. The result must record whether the main
probe and every helper were signed successfully.

## Zig Toolchain Contract

Default, if Zig is used:

- Zig 0.16 release
- invoked as `zig` from normal `PATH`

Fallback:

- `/usr/local/bin/zig015`
- `/usr/local/lib/zig015`

Zig 0.15.2 is last-resort only. Any fallback result must record:

- why Zig 0.16 could not be used
- exact `zig015 version`
- whether `ZIG_LIB_DIR=/usr/local/lib/zig015` was required
- whether generated binaries or behavior differ from the Zig 0.16 build

For C-only probes, Zig fields are still present in JSON as explicit null/false
values.

Zig is not required for Stages 1-5. The environment capture should set Zig
fields to null/false for C-only runs without treating missing `zig` as a
failure. It should only invoke and require Zig when a Zig probe is actually
selected, or when a non-fatal tool inventory mode is explicitly requested.

## Environment Capture

Each run emits one environment object and includes or references it from each
probe result.

Required fields:

- `sw_vers`
- `uname -a`
- OS name and kernel version for non-macOS development-host result naming
- selected `result_dir_name`
- `arch`
- `sysctl kern.osrelease kern.version hw.machine`
- `sysctl machdep.cpu.brand_string`, when available
- CPU feature sysctls available on that host
- Apple Silicon sysctls when present, including `hw.optional.arm64` and any
  arm64e or pointer-authentication capability sysctls exposed by the host
- Rosetta status, if detectable
- `clang --version`
- `xcrun --show-sdk-path`
- `xcrun --show-sdk-version`
- `xcode-select -p`
- `csrutil status`, or recorded failure if unavailable
- sandbox status, if detectable from stock userland
- run-as user/root status
- ad-hoc signing status
- per-binary signing records as `{path, status, return_code, output}` once
  binaries are built
- hardened-runtime status
- Zig version/path/lib dir/fallback reason, if Zig is used
- `ZIG_LIB_DIR`, if Zig 0.15.2 fallback is used

## Result Schema

Schema name: `nx-v64z.macos-oracle.v1`, pending final parent confirmation.

Schema version bumps are required when existing fields change meaning, required
fields are added, or fields are removed/renamed. Adding optional fields does not
require a version bump, and v1 readers must ignore unknown optional fields.

Required result floor:

```json
{
  "schema": "nx-v64z.macos-oracle.v1",
  "agent": "mx-x64z or mx-a64z",
  "test_id": "macos_m2_descriptor_copy_send",
  "cross_reference": {
    "nextbsd_test_id": null,
    "donor_equivalent_id": null
  },
  "status": "pass",
  "semantic_class": "exact_contract",
  "environment": {
    "sw_vers": "",
    "uname": "",
    "os_name": "",
    "kernel_version": "",
    "result_dir_name": "",
    "arch": "",
    "machine": "",
    "cpu_brand": null,
    "cpu_features": {},
    "apple_silicon": {
      "hw_optional_arm64": null,
      "arm64e": null,
      "pointer_authentication": null,
      "raw_sysctls": {}
    },
    "rosetta": null,
    "compiler": "",
    "sdk": "",
    "sdk_version": "",
    "sdk_path": "",
    "xcode_select_path": "",
    "sip_enabled": true,
    "sandboxed": false,
    "run_as_root": false,
    "ad_hoc_signed": true,
    "hardened_runtime": false,
    "signing": {
      "binaries": []
    },
    "zig_version": null,
    "zig_path": null,
    "zig_lib_dir": null,
    "zig_fallback": false,
    "zig_fallback_reason": null
  },
  "api_sequence": [],
  "message": {
    "msgh_bits": "",
    "remote_port": {
      "name": "service_port",
      "disposition": "MACH_MSG_TYPE_COPY_SEND",
      "right_type": "MACH_PORT_TYPE_SEND"
    },
    "local_port": {
      "name": "reply_port",
      "disposition": null,
      "right_type": null
    },
    "header_rights": [
      {
        "field": "msgh_remote_port",
        "disposition": "MACH_MSG_TYPE_COPY_SEND",
        "right_type_before": "MACH_PORT_TYPE_SEND",
        "right_type_after": "MACH_PORT_TYPE_SEND"
      }
    ],
    "descriptor_count": 0,
    "descriptors": []
  },
  "returns": [
    {
      "call": "mach_msg",
      "returned": "MACH_MSG_SUCCESS",
      "raw": 0,
      "errno": null
    }
  ],
  "right_deltas": [
    {
      "operation": "send header COPY_SEND",
      "port_name": "service_port",
      "right_type": "MACH_PORT_TYPE_SEND",
      "before_urefs": 1,
      "after_urefs": 1,
      "entry_refs_before": null,
      "entry_refs_after": null,
      "expected": "unchanged"
    }
  ],
  "cleanup": {
    "returned_to_baseline": true,
    "notes": ""
  },
  "notes": ""
}
```

Allowed `status` values:

- `pass`
- `fail`
- `skip`
- `probe_failure`

Allowed `semantic_class` values:

- `exact_contract`
- `equivalent_contract`
- `version_sensitive`
- `privilege_sensitive`
- `not_observable`
- `probe_failure`
- `intentional_divergence`

`cross_reference.nextbsd_test_id` and `cross_reference.donor_equivalent_id` may
remain null until the parent provides canonical rxOS/NextBSD probe IDs. They are
included now so later comparison can become mechanical without changing the
schema shape.

Port names in JSON are probe-defined symbolic labels, not raw Mach port-name
integers. A label such as `service_port`, `cargo_port`, `task_port`, or
`reply_port` must be used consistently across `message`, `header_rights`,
`descriptors`, and `right_deltas` within a single result.

`entry_refs_before` and `entry_refs_after` are optional and may be null when the
host cannot expose the value. When available, they capture the per-name
reference count used to decide whether one `mach_port_deallocate()` is enough or
whether stronger cleanup such as destroy/mod-refs is needed.

## Global Process-Probe Safety Rule

Every probe that uses `fork()`, `posix_spawn()`, `execve()`, sender-exit
choreography, receiver-exit choreography, helper processes, or long-lived
server/client pairs must:

- set a watchdog timeout, for example `alarm(5)`
- call `waitpid()` for every child process where applicable
- terminate child/server helpers on failure paths
- clean up allocated ports on success and failure paths
- report whether cleanup returned to baseline in result JSON
- classify watchdog, termination, or child-reap failures as `probe_failure`
- use an explicit rendezvous mechanism, such as a pipe or Mach sync port,
  before a child exits, execs, or enters a critical queued-message state
- require the parent to wait for the rendezvous signal before proceeding past
  the corresponding critical point
- use a rendezvous channel orthogonal to the IPC behavior under test; for
  Mach-message-on-exit probes, prefer a Unix pipe or signal over a second Mach
  message so the synchronization path does not validate the same subsystem

## Probe Work Packages

### Package A: Environment and Foundational Introspection

Purpose:

- prove that stock macOS exposes enough current-task introspection to support
  later exact accounting
- establish baseline cleanup/inventory behavior

Probes:

| Probe | Test ID | Required result |
| --- | --- | --- |
| `foundation/port_names.c` | `macos_foundation_port_names` | `mach_port_names()` returns usable namespace inventory and create/destroy returns to baseline |
| `foundation/port_get_refs.c` | `macos_foundation_port_get_refs` | `mach_port_get_refs()` reports enough user-reference accounting for send/receive checks |
| `foundation/port_type.c` | `macos_foundation_port_type` | `mach_port_type()` reports expected receive, send, send-once, dead-name, and port-set classes for known rights where stock macOS exposes them |

Stop rule:

- If `mach_port_names()` is unavailable or unreliable, later exact cleanup
  assertions are blocked.
- If `mach_port_get_refs()` is unavailable or unreliable, uref-sensitive probes
  downgrade to usability plus cleanup inventory unless parent directs otherwise.
- If `mach_port_type()` is unavailable or unreliable, probes must not claim a
  received right's class by name; they may only claim usability.

`mach_port_names()` is unusable if it returns a non-success `kern_return_t`,
returns zero names while the task is known to have bootstrap/task ports, omits a
freshly allocated known port, or returns names whose right classes cannot be
validated by `mach_port_type()`.

`port_type.c` must record any type bits not covered by active SDK header
constants as raw hex. Do not silently mask unknown modern macOS bits to the
known donor-era constants.

### Package B: M1 Reference Probes

Purpose:

- capture cross-task and bootstrap foundation behavior relevant to the completed
  M1 and M2 preflight work

Probes:

| Probe | Test ID | Required result |
| --- | --- | --- |
| `m1/fork_port_inheritance.c` | `macos_m1_fork_port_inheritance` | ordinary port-right visibility/usability across `fork()` |
| `m1/spawn_exec_port_inheritance.c` | `macos_m1_spawn_exec_port_inheritance` | `posix_spawn()` / `execve()` contrast with `fork()` |
| `m1/bootstrap_special_port.c` | `macos_m1_bootstrap_special_port` | save/get/set/restore behavior for `TASK_BOOTSTRAP_PORT`, or explicit stock-userland block |
| `m1/header_copy_send_accounting.c` | `macos_m1_header_copy_send_accounting` | sender urefs and entry refs before/after header `MACH_MSG_TYPE_COPY_SEND` |
| `m1/header_move_send_accounting.c` | `macos_m1_header_move_send_accounting` | sender right type, urefs, and entry refs before/after header `MACH_MSG_TYPE_MOVE_SEND` |

Bootstrap policy:

- If replacement is blocked on stock macOS, classify as `privilege_sensitive`
  or `not_observable`.
- Do not add private entitlements or SIP changes.
- A weaker read-only bootstrap inheritance probe remains an open parent
  question.
- Always test read-only get/inheritance behavior first.
- Attempt `task_set_special_port()` only under the stock host capability that
  appears to allow it; otherwise record the exact blocked `kern_return_t`
  instead of silently skipping the set/restore subcase.

### Package C: M2 Descriptor Transfer Probes

Purpose:

- capture native behavior for cross-task body-carried port descriptor transfer

Core transfer probes:

| Probe | Test ID | Required result |
| --- | --- | --- |
| `m2/descriptor_copy_send.c` | `macos_m2_descriptor_copy_send` | sender urefs and entry refs do not inflate, receiver gets usable send right, delivered right entry refs are recorded, cleanup returns to baseline |
| `m2/descriptor_move_send.c` | `macos_m2_descriptor_move_send` | sender loses user-visible send right, receiver gets usable send right, delivered right entry refs are recorded, sender double-cleanup need is characterized |

Conditional M2.3 probe:

| Probe | Test ID | Required result |
| --- | --- | --- |
| `m2/send_once_descriptor.c` | `macos_m2_send_once_descriptor` | after `COPY_SEND` and `MOVE_SEND` are clean, send-once descriptor transfer with SDK-defined send-once dispositions, especially `MACH_MSG_TYPE_MOVE_SEND_ONCE`, either succeeds with usable one-shot semantics or is explicitly classified as unsupported/not observable |

Negative and failure probes:

| Probe | Test ID | Required result |
| --- | --- | --- |
| `m2/invalid_descriptor_disposition.c` | `macos_m2_invalid_descriptor_disposition` | exact `mach_msg()` return, no silent right consumption, receiver queue unchanged |
| `m2/dead_name_descriptor_right.c` | `macos_m2_dead_name_descriptor_right` | dead/nonexistent right return surface, no silent right consumption, cleanup baseline |
| `m2/double_move_send_descriptor.c` | `macos_m2_double_move_send_descriptor` | two descriptors naming the same send right with `MOVE_SEND` are rejected or leave consistent sender/receiver accounting |
| `m2/receiver_copyout_failure.c` | `macos_m2_receiver_copyout_failure` | if stock userland can induce receiver copyout failure, copyin succeeds but failed copyout does not silently consume sender rights; otherwise classify as `not_observable` with the attempted method |

First follow-ups:

| Probe | Test ID | Reason deferred |
| --- | --- | --- |
| `m2/sender_exit_queued_descriptor.c` | `macos_m2_sender_exit_queued_descriptor` | important lifecycle fact, but process choreography may be slower/flakier |
| `m2/receiver_exit_queued_descriptor.c` | `macos_m2_receiver_exit_queued_descriptor` | same |

Ordering note:

- `send_once_descriptor.c` follows clean `COPY_SEND` and `MOVE_SEND` results.
- It must record which send-once dispositions the SDK defines. Do not invent a
  `COPY_SEND_ONCE` case unless the active SDK actually exposes one.
- Negative probes cover M2.4, including invalid disposition, dead/nonexistent
  right, double `MOVE_SEND`, and receiver copyout-failure behavior.
- Sender/receiver-exit queued descriptor probes remain first follow-ups after
  the core M2 and M2.4 negative results are stable.

M2 implementation value:

- NextBSD batch 21 already proves header `COPY_SEND`, body descriptor
  `COPY_SEND`, and repeated MIG RPC `COPY_SEND` do not inflate source-side
  accounting. macOS should confirm the same stable behavior.
- NextBSD batch 22 shows cross-task `COPY_SEND` descriptor delivery creates a
  received send right whose `entry_refs` and cleanup needs must be compared
  against macOS.
- If macOS `MOVE_SEND` consumes the sender right only on successful copyin, the
  rxOS/NextBSD implementation should match that lifecycle or document an
  intentional divergence.

## Donor Test Inventory Transfer

The oracle repo should inventory, not blindly copy, selected NextBSD donor test
families.

## NextBSD Evidence Baseline

Current implementation-side evidence comes from the Opus M2 lane:

Base path:

```text
/Users/me/wip-mach-opus/wip-opus
```

Artifacts:

| Artifact | Path |
| --- | --- |
| Full probe source, batches 1-22 | `scripts/bhyve/nxplatform-mach-probe.c` |
| Batch 17-20 regression log | `reports/batch17-20-regression-serial.log` |
| Batch 21 `COPY_SEND` accounting log | `reports/batch21-serial.log` |
| Batch 22 cross-task descriptor log | `reports/batch22-serial.log` |
| M1 completion report | `reports/m1-completion-report.md` |
| MIG build script | `scripts/mig/build-migcom.sh` |
| MIG regeneration diffs | `reports/mig-regen-diffs/` |

NextBSD batch IDs:

| Batch | ID | Tests |
| --- | --- | ---: |
| 17 | `characterize_batch17_mach_msg_inline_self` | 2 |
| 18 | `characterize_batch18_mach_msg_complex_descriptor` | 2 |
| 19 | `characterize_batch19_mach_msg_complex_ool` | 3 |
| 20 | `characterize_batch20_cross_task_inline_mach_msg` | 1 |
| 21 | `characterize_m2_batch21_copy_send_uref_accounting` | 3 |
| 22 | `characterize_m2_batch22_cross_task_copy_send_descriptor` | 1 |

Batch 21 resolved the earlier `COPY_SEND` uref hypothesis:

- header `COPY_SEND`: `entry_refs=2->2->2`
- body descriptor `COPY_SEND`: source-side stable, delivered right insertion
  expected on receiver side
- repeated MIG RPC `COPY_SEND`: `entry_refs=2->2->2->2`

Batch 22 shows cross-task `COPY_SEND` descriptor delivery creates a received
send right with `type=0x10000` and `entry_refs=2` on NextBSD. The macOS oracle
must determine whether this delivered-right entry-ref behavior and cleanup need
are universal Mach behavior or NextBSD-specific.

Primary donor roots:

```text
/Users/me/wip-mach/nx/NextBSD/usr.bin/mach-tests
/Users/me/wip-mach/nx/NextBSD/lib/libmach/test
/Users/me/wip-mach/nx/NextBSD/usr.bin/xpc-tests
```

Initial target families:

| Family | Oracle treatment |
| --- | --- |
| `usr.bin/mach-tests/ipc-hello` | first donor compile/run candidate on macOS; first rmxOS donor sanity test after descriptor/right preflight |
| `usr.bin/mach-tests/set-bport` | immediate bootstrap observation; may classify as `privilege_sensitive` |
| `usr.bin/mach-tests/bootstrap` | after bootstrap context strategy |
| `usr.bin/mach-tests/bootstrap-kqueue` non-GCD | after port-set and `EVFILT_MACHPORT` probes |
| `usr.bin/mach-tests/bootstrap-kqueue/server-libdispatch` | post-Phase 0.5 dispatch Mach receive gate |
| `usr.bin/mach-tests/kqueue-tests` | split into focused subprobes before using full broad test |
| `lib/libmach/test/kqueue_tests` | build/split first, full run later |
| `usr.bin/xpc-tests` | later XPC oracle package, not first Phase 0.5 work |
| inherited FreeBSD base tests | inventory only; native FreeBSD/rmxOS lane |

Manifest fields should include:

- test family
- donor path
- files
- language/build style
- link flags
- APIs exercised
- phase classification
- macOS compile status
- macOS runtime status
- skip/stop classification
- notes about launchd, dispatch, kqueue, XPC, or privilege dependencies

## Elixir Migration Plan

Elixir is not part of the first low-level Mach probe implementation, but the
oracle repo should eventually carry portable ExUnit tests for:

- parser behavior
- schema validation
- curated JSON fixtures
- result comparison
- donor manifest checks

Default macOS ExUnit floor:

```sh
mix test --exclude rx_only --exclude requires_bhyve --exclude requires_nextbsd_root
```

Local development run:

```sh
mix test
```

Optional donor checkout integration:

```sh
NX_NEXTBSD_ROOT=/path/to/NextBSD mix test --only requires_nextbsd_root
```

Tags:

| Tag | Meaning | macOS default |
| --- | --- | --- |
| `:portable` | pure host-side parser/schema/fixture test | yes |
| `:macos_oracle` | validates oracle package behavior | yes |
| `:fixture_only` | curated fixtures only | yes |
| `:rx_only` | requires local rmxOS/FreeBSD assumptions | no |
| `:requires_bhyve` | requires bhyve/doas/guest staging | no |
| `:requires_nextbsd_root` | requires donor checkout | no |

Known local blocker:

- current local `mix test` fails because installed Elixir requires newer
  Erlang/OTP than OTP 26
- the Elixir migration toolchain gate must capture `elixir --version`,
  `erl -version`, and `mix --version`, then pin a working pair before test
  failures are treated as project failures

## Implementation Sequence

### Stage 0: Finalize Plan and Review

Deliverables:

- this comprehensive plan
- external-agent review request
- parent-agent open questions updated

Acceptance:

- review agent can identify contradictions, missing gates, bad assumptions, and
  first implementation order changes before code is written

### Stage 1: Repository Skeleton

Deliverables:

- `README.md`
- `macos-validation/Makefile`
- `macos-validation/harness/collect_env.sh`
- `macos-validation/harness/sign_probe.sh`
- `macos-validation/harness/run_all.sh`
- results/findings/manifests directories created on demand with `mkdir -p`
- build outputs isolated under `macos-validation/.build/`

Acceptance:

- clone works on macOS
- `make` and `run_all.sh --list` work without executing probes
- environment capture succeeds or records explicit tool failures

### Stage 2: Common C Helpers

Deliverables:

- JSON emission helpers
- environment embedding helpers
- Mach right inventory helpers
- cleanup helper wrappers
- common return-code formatting helpers

Acceptance:

- a trivial probe emits valid `nx-v64z.macos-oracle.v1` JSON
- the schema name is confirmed before real host result collection, or the
  schema constant is centralized so a rename is mechanical
- C-only Zig fields are explicit null/false values
- ad-hoc signing path is exercised

### Stage 3: Foundational Probes

Deliverables:

- `port_names.c`
- `port_get_refs.c`
- `port_type.c`

Acceptance:

- results classify whether exact namespace and uref assertions are valid on
  each macOS host
- known receive, send, send-once, dead-name, and port-set classes can be
  validated where stock macOS exposes them
- `mach_task_self()` combined SEND/RECEIVE right behavior is characterized with
  both send and receive ref queries where the host permits it
- later probes can consume foundational capabilities

Optional early donor compile check:

- attempt a stock-SDK compile-only pass for `usr.bin/mach-tests/ipc-hello`
  after foundational probes and before M1 implementation
- record SDK/header/link gaps as early design input
- do not block M1/M2 custom probe work on `ipc-hello` unless it reveals a
  shared API assumption that affects the custom probes

### Stage 4: M1 Probes

Deliverables:

- fork inheritance probe
- spawn/exec inheritance probe
- bootstrap special-port probe
- header `COPY_SEND` accounting probe
- header `MOVE_SEND` accounting probe

Acceptance:

- process probes follow global safety rule
- bootstrap mutation is classified without entitlement/SIP workaround
- header `COPY_SEND` result is usable by the M2 preflight decision
- header `MOVE_SEND` establishes the simple send-right consumption baseline
  before descriptor `MOVE_SEND`

### Stage 5: Core M2 Probes

Deliverables:

- descriptor `COPY_SEND`
- descriptor `MOVE_SEND`
- send-once descriptor transfer after clean `COPY_SEND` / `MOVE_SEND`
- invalid descriptor disposition
- dead/nonexistent descriptor right
- double `MOVE_SEND` in one message
- receiver copyout-failure attempt or explicit `not_observable` result

Acceptance:

- sender/receiver accounting is captured where introspection permits
- received rights are tested for real usability
- received right classes are validated with `mach_port_type()` when available
- delivered right `entry_refs` are recorded for descriptor `COPY_SEND` and
  `MOVE_SEND` where the host exposes them
- cleanup explicitly records whether a single deallocate returns to baseline or
  stronger cleanup is required
- M2.3 send-once descriptor scope is covered or explicitly classified
- M2.4 negative/failure scope covers invalid disposition, dead/nonexistent
  right, double `MOVE_SEND`, and failed copyout behavior
- failure paths do not hide consumed rights
- cleanup status is explicit

### Stage 6: Donor Manifest and Compile Matrix

Deliverables:

- machine-readable manifest of Mach/libmach/XPC donor tests
- broad inherited FreeBSD test-root inventory
- compile matrix for Mach/libmach donor C tests on macOS

Acceptance:

- donor tests are not copied wholesale
- inherited FreeBSD tests are excluded from default macOS oracle runs
- compile failures are recorded as useful facts, not patched around silently

### Stage 7: Portable Elixir Tests

Deliverables:

- minimal Mix skeleton
- toolchain capture
- parser tests with fixtures
- oracle JSON schema tests
- donor manifest tests

Acceptance:

- portable ExUnit floor runs on macOS without bhyve, donor checkout, or VM
  images
- host-specific skips are visible

### Stage 8: Native macOS Runs

Deliverables:

- `mx-x64z` summary JSON and findings
- `mx-a64z` summary JSON and findings

Acceptance:

- primary `mx-a64z` is native arm64/arm64e
- Rosetta, if present, is non-primary supplemental only
- results include environment, signing, SIP/sandbox, compiler, SDK, and cleanup
  fields

### Stage 9: Cross-Host and rxOS Comparison

Deliverables:

- comparison report across `mx-x64z`, `mx-a64z`, and rxOS/NextBSD facts
- classification of exact/equivalent/version/privilege/not-observable cases
- implementation-facing findings for parent agent

Acceptance:

- raw port names are not comparison gates
- uref-sensitive gates are used only where introspection is reliable
- modern macOS-only behavior is not automatically treated as an rxOS bug

### Stage 10: rmxOS Donor Runs

Deliverables:

- selected donor tests run in native C/Make form on rmxOS after prerequisites
- Elixir orchestration/reporting only

Initial rmxOS order:

1. `ipc-hello`
2. narrow M2 descriptor/rights probes
3. `set-bport`
4. bootstrap client/server
5. port-set and `EVFILT_MACHPORT` probes
6. non-GCD `bootstrap-kqueue`
7. `kqueue-tests`
8. `libmach/test/kqueue_tests`
9. dispatch Mach receive gate
10. XPC tests after launchd/libdispatch/XPC readiness

## Stop and Skip Policy

Stop a run and report if:

- `mach_port_names()` is unusable
- `mach_port_get_refs()` is unusable and the active probe requires exact urefs
- `mach_port_type()` is unusable and the active probe requires exact right-class
  validation
- ad-hoc signed binaries cannot run
- a probe requires private entitlement, SIP changes, or kernel debugging
- a process probe hangs despite watchdog logic
- host-specific behavior would require changing the portable semantic question

Skip a single probe if:

- a public API is unavailable on that macOS version
- stock macOS privilege policy blocks the behavior
- a prerequisite foundational probe failed
- process choreography is too unstable for first-pass collection
- the test belongs to a later phase, such as dispatch or XPC

## Artifact Policy

Commit:

- source code
- Make/harness scripts
- manifests
- curated summary JSON
- curated fixtures
- findings notes
- review notes

Do not commit by default:

- raw logs
- VM images
- crash dumps
- full donor source trees
- bulky generated output

## Open Questions

Current open parent questions are tracked in `parent-agent-questions.md`.

Most important before implementation:

1. final confirmation of `nx-v64z.macos-oracle.v1` as schema name
2. bootstrap replacement fallback: is read-only bootstrap inheritance mandatory
   if mutation is blocked?
3. if `mach_port_get_refs()` is reliable on one macOS host but not the other,
   downgrade uref-sensitive probes globally or per host?
4. is receiver-side copyout failure practically observable from stock macOS
   userland, or should `receiver_copyout_failure` normally classify as
   `not_observable`?
5. should `ipc-hello` runtime be attempted on macOS before core descriptor
   probes, or is the early donor check compile-only until M2 facts land?
6. copy parser scripts into oracle repo or import from parent during local dev?
7. make donor history scripts portable oracle tools or keep parent-only?
8. minimum Elixir/Erlang versions for `rx`, `mx-x64z`, and `mx-a64z`

## Primary Risks

| Risk | Mitigation |
| --- | --- |
| modern macOS differs from donor-era Darwin | default to `version_sensitive` unless donor relevance is proven |
| host architecture differences overfit one machine | require explicit architecture notes and both host result sets |
| `mach_port_get_refs()` is unreliable | downgrade uref gates to usability/cleanup where needed |
| bootstrap mutation blocked by stock macOS | classify as `privilege_sensitive` or `not_observable`, keep read-only facts |
| process probes hang or leak helpers | enforce global watchdog/waitpid/cleanup rule |
| donor tests are too broad for first proof | split into narrow C/Zig probes, then run donor tests as acceptance |
| Elixir toolchain mismatch | make toolchain capture the first Elixir migration gate and do not treat mismatch as test failure |
| oracle repo becomes too large | commit curated summaries/fixtures only |

## Completion Criteria

The first oracle package is ready for macOS clone/run when:

- repository skeleton is self-contained
- C build/sign/run harness works on stock macOS
- environment capture is complete
- foundational probes emit valid JSON
- M1 and core M2 probes are implemented and safe
- summary JSON lands under `results/mx-*`
- result runs are stored under
  `results/<agent>/<date>-<macos-version>-<darwin-version>/` on macOS and
  `results/<agent>/<date>-<os-name>-<kernel-version>/` on non-macOS
  development hosts
- findings notes land under `findings/nx-v64z`
- macOS default tests do not require bhyve, donor checkout, SIP changes, or
  private entitlements
- comparison rules are clear enough for the parent agent to map macOS facts to
  rxOS/NextBSD implementation decisions

# nx-v64z macOS Oracle Test Plan and Parent Questions

Date: 2026-05-12

## Role

This directory is the `nx-v64z` portable macOS oracle package working copy. The
package should be cloneable onto real macOS hosts and runnable by the two macOS
validation agents:

- `mx-x64z`: native Intel macOS host
- `mx-a64z`: native Apple Silicon macOS host

The purpose is to collect observable native macOS Mach IPC behavior, then feed
those facts back to the parent agent so rxOS/NextBSD semantics can be checked
and corrected. `rx` is the rmxOS development lane and NextBSD is the comparison
consumer; neither is the oracle source/schema lane. macOS is a semantic oracle
only. This package must not import XNU code, require private entitlements,
require SIP changes, or use macOS internals as an implementation source.

## Current Phase Constraint

This file is plan-only. I am not implementing the probes yet.

The next implementation phase should create source, harness, and documentation
in this local directory so the whole directory can be copied or cloned to real
macOS machines.

Current authority: `comprehensive-nx-v64z-macos-oracle-plan.md` supersedes this
earlier draft where probe lists, schema details, or staging differ.

## Parent Decisions Already Recorded

1. `/Users/me/wip-mach/wip-gpt-oracle` owns the cloneable oracle probe source
   package.
2. `/Users/me/wip-mach/wip-gpt` remains the planning/docs repository.
3. First implementation is shell/Make plus native C probes.
4. Elixir comparison comes later, after both macOS result sets and the
   NextBSD/rxOS result set exist.
5. Queued sender/receiver-exit descriptor tests are first follow-ups, not
   mandatory before basic `COPY_SEND` / `MOVE_SEND`.
6. Curated summary JSON and findings notes should be committed. Raw logs stay
   outside git unless a raw fixture is specifically useful.
7. Rosetta results are allowed only as non-primary supplemental artifacts.
   Primary `mx-a64z` must be native arm64/arm64e.

## Working Assumptions

1. This agent owns the portable probe package contract for the first macOS
   oracle pass.
2. `../wip-gpt` is the parent planning repository and should be treated as
   read-only unless the parent explicitly asks for changes there.
3. `wip-gpt-oracle` is the self-contained probe repository.
4. Native C probes are the default because macOS Mach headers and libSystem are
   C-first.
5. Zig is only used when a probe needs mechanical source sharing with the
   NextBSD guest lane or exact ABI/layout control beyond ordinary C.
6. Elixir is reserved for later orchestration and result comparison, not for
   constructing low-level Mach messages.
7. Every probe must call `mach_msg()` explicitly. Do not use `mach_msg2()` or
   `mach_msg_overwrite()`.

## Donor-Era Context

The NextBSD donor behavior is roughly macOS 10.10-10.11 era Darwin. The
validation hosts are expected to be modern macOS 14/15 systems. A behavior
observed only on modern macOS must be treated as `version_sensitive` unless
there is evidence that it is donor-era relevant. Intel versus Apple Silicon
differences should also be represented with `version_sensitive` plus explicit
architecture notes; the schema does not define a separate architecture class.

## Proposed Repository Layout

```text
.
  README.md
  macos-validation/
    Makefile
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
    results/
      mx-x64z/
        <date>-<macos-version>-<darwin-version>/
      mx-a64z/
        <date>-<macos-version>-<darwin-version>/
    findings/
      nx-v64z/
```

Large raw logs should remain outside git unless the parent explicitly wants
curated fixtures committed.

## Build and Run Contract

Default C probe build:

```sh
clang -Wall -Wextra -O0 -g -o probe probe.c
codesign -s - probe
./probe
```

The repository harness should wrap that as:

```sh
cd macos-validation
make clean
make
harness/run_all.sh --agent mx-a64z
```

The same flow should work for `mx-x64z`.

No framework link flag should be needed for:

- `mach/mach.h`
- `mach/message.h`
- `servers/bootstrap.h`

If any probe needs additional flags, the probe JSON must explain why.

## Zig Toolchain Contract

Default Zig, if Zig is used at all:

- Zig 0.16 release
- invoked as `zig` from the normal `PATH`

Fallback:

- `/usr/local/bin/zig015`
- `/usr/local/lib/zig015`

Zig 0.15.2 is last-resort only. Any fallback result must record:

- why Zig 0.16 could not be used
- exact `zig015 version`
- whether `ZIG_LIB_DIR=/usr/local/lib/zig015` was required
- whether generated binaries or behavior differ from the Zig 0.16 build

## Environment Capture

Each run should emit one environment JSON object and embed or reference it from
each probe result. Required fields:

- `sw_vers`
- `uname -a`
- `arch`
- `sysctl kern.osrelease kern.version hw.machine`
- `sysctl machdep.cpu.brand_string`, when available
- CPU feature sysctls available on that host
- Rosetta status, if detectable
- `clang --version`
- `xcrun --show-sdk-path`
- `xcrun --show-sdk-version`
- `xcode-select -p`
- `csrutil status`, or recorded failure if unavailable
- sandbox status, if detectable from stock userland
- whether run as root or normal user
- whether binaries were ad-hoc signed
- whether hardened runtime was enabled
- Zig version/path/lib dir/fallback reason if Zig is used
- `ZIG_LIB_DIR`, if the Zig 0.15.2 fallback is used

For C-only probes, Zig fields must be present as explicit null/false values.

## Result Schema Floor

Every probe emits one JSON file and one JSON object to stdout:

```json
{
  "schema": "nx-v64z.macos-oracle.v1",
  "agent": "mx-x64z or mx-a64z",
  "test_id": "macos_m2_descriptor_copy_send",
  "status": "pass",
  "semantic_class": "exact_contract",
  "environment": {
    "sw_vers": "",
    "uname": "",
    "arch": "",
    "machine": "",
    "compiler": "",
    "sdk": "",
    "sdk_version": "",
    "sdk_path": "",
    "xcode_select_path": "",
    "zig_version": null,
    "zig_path": null,
    "zig_lib_dir": null,
    "zig_fallback": false,
    "zig_fallback_reason": null,
    "sip_enabled": true,
    "sandboxed": false,
    "ad_hoc_signed": true,
    "hardened_runtime": false
  },
  "api_sequence": [],
  "message": {
    "msgh_bits": "",
    "descriptor_count": 0,
    "descriptors": []
  },
  "returns": [],
  "right_deltas": [],
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

Raw Mach port name integers are local opaque names. Results may record them for
debugging, but comparison must use right class, reference-count deltas, return
codes, usability checks, and cleanup state.

Header-carried rights must be represented separately from body descriptors.
Header accounting probes record remote/local header rights, dispositions, and
right classes; descriptor probes record body-carried descriptors.

## Global Process-Probe Safety Rule

Every probe that uses `fork()`, `posix_spawn()`, `execve()`, sender-exit
choreography, or receiver-exit choreography must:

- set a watchdog timeout, for example `alarm(5)`
- call `waitpid()` for every child process where applicable
- clean up allocated ports on success and failure paths
- report whether cleanup returned to baseline in result JSON
- classify watchdog or child-reap failures as `probe_failure`
- use an explicit rendezvous mechanism, such as a pipe or Mach sync port,
  before a child exits, execs, or enters a critical queued-message state

## First Test Cases

### `foundation/port_names.c`

Test ID: `macos_foundation_port_names`

Purpose:

- Verify `mach_port_names()` is usable on stock macOS.
- Establish namespace inventory before later cleanup assertions.

Observable facts:

- return code
- count of names
- observed right type classes
- whether a create/destroy cycle returns inventory to baseline

Stop condition:

- If `mach_port_names()` is unavailable or unreliable, exact cleanup assertions
  for later probes must be downgraded or blocked.

### `foundation/port_get_refs.c`

Test ID: `macos_foundation_port_get_refs`

Purpose:

- Verify `mach_port_get_refs()` reports user-reference counts reliably enough
  for `COPY_SEND`, `MOVE_SEND`, and cleanup probes.

Observable facts:

- receive-right refs for a newly allocated port
- send-right refs after `mach_port_insert_right()`
- refs after `mach_port_deallocate()`
- cleanup baseline

Stop condition:

- If user-reference accounting is unavailable or unstable, later tests can
  still check usability and cleanup but must not claim exact uref contracts.

### `foundation/port_type.c`

Test ID: `macos_foundation_port_type`

Purpose:

- Verify `mach_port_type()` reports expected right classes for known receive,
  send, send-once, dead-name, and port-set rights where stock macOS exposes
  them.

Stop condition:

- If right classes cannot be validated, later probes may claim usability but
  must not claim exact right class by name.

### `m1/fork_port_inheritance.c`

Test ID: `macos_m1_fork_port_inheritance`

Purpose:

- Determine whether ordinary Mach port rights are inherited across `fork()`.

Shape:

- Parent creates a receive right and inserts a send right.
- Parent forks.
- Child attempts to inspect/use inherited right names.
- Parent waits with watchdog and cleans up.

Safety requirements:

- follow the global process-probe safety rule

### `m1/spawn_exec_port_inheritance.c`

Test ID: `macos_m1_spawn_exec_port_inheritance`

Purpose:

- Compare `posix_spawn()` and `execve()` behavior against `fork()` for ordinary
  port right visibility.

Shape:

- Parent creates known rights.
- Spawned/execed helper reports whether inherited numeric names are valid in
  its task.
- Parent records differences from fork behavior.

Expected classification:

- Likely `version_sensitive` or `equivalent_contract` until both macOS hosts
  report.

### `m1/bootstrap_special_port.c`

Test ID: `macos_m1_bootstrap_special_port`

Purpose:

- Observe stock-userland behavior for saving, setting, getting, and restoring
  `TASK_BOOTSTRAP_PORT`.

Shape:

- `task_get_special_port(mach_task_self(), TASK_BOOTSTRAP_PORT, ...)`
- allocate replacement receive/send path if permitted
- `task_set_special_port()`
- verify `task_get_special_port()` returns the replacement
- restore original bootstrap port

Stop condition:

- If stock macOS blocks replacement without private entitlement or SIP changes,
  mark `privilege_sensitive` or `not_observable`. Do not work around it with
  private entitlement behavior.

### `m1/header_copy_send_accounting.c`

Test ID: `macos_m1_header_copy_send_accounting`

Purpose:

- Establish native macOS behavior for header remote-port
  `MACH_MSG_TYPE_COPY_SEND`.

Question:

- Does sending with header `COPY_SEND` increase the sender's visible send uref
  count?

NextBSD batch 21 has already shown stable `COPY_SEND` accounting. This macOS
probe verifies whether native macOS matches that confirmed baseline.

### `m1/header_move_send_accounting.c`

Test ID: `macos_m1_header_move_send_accounting`

Purpose:

- Establish native macOS behavior for header remote-port
  `MACH_MSG_TYPE_MOVE_SEND`.

Question:

- Does successful header `MOVE_SEND` consume the sender's visible send right,
  and what right class remains afterward?

### `m2/descriptor_copy_send.c`

Test ID: `macos_m2_descriptor_copy_send`

Purpose:

- Establish native macOS behavior for body-carried
  `mach_msg_port_descriptor_t` with `MACH_MSG_TYPE_COPY_SEND`.

Required checks:

- sender send urefs before and after send
- receiver obtains a usable send right
- receiver can use the transferred right in a second message
- cleanup returns both tasks to baseline

### `m2/descriptor_move_send.c`

Test ID: `macos_m2_descriptor_move_send`

Purpose:

- Establish native macOS behavior for body-carried
  `mach_msg_port_descriptor_t` with `MACH_MSG_TYPE_MOVE_SEND`.

Required checks:

- sender loses the user-visible send right
- receiver obtains a usable send right
- sender-side double cleanup is not required
- cleanup returns to baseline

### `m2/send_once_descriptor.c`

Test ID: `macos_m2_send_once_descriptor`

Purpose:

- Establish native macOS behavior for body-carried send-once descriptor
  transfer after basic `COPY_SEND` and `MOVE_SEND` are clean.

Required checks:

- transfer either succeeds with usable one-shot semantics or is explicitly
  classified as unsupported/not observable
- cleanup returns to baseline

### `m2/invalid_descriptor_disposition.c`

Test ID: `macos_m2_invalid_descriptor_disposition`

Purpose:

- Record the return surface for an invalid port descriptor disposition.

Required checks:

- exact `mach_msg()` return code
- whether sender rights are consumed
- whether receiver observes any queued message
- cleanup baseline

### `m2/dead_name_descriptor_right.c`

Test ID: `macos_m2_dead_name_descriptor_right`

Purpose:

- Record behavior when a descriptor names a dead or nonexistent right in the
  sender space.

Required checks:

- exact return code
- no silent right consumption
- receiver queue state unchanged
- cleanup baseline

### `m2/double_move_send_descriptor.c`

Test ID: `macos_m2_double_move_send_descriptor`

Purpose:

- Record behavior for two descriptors in one message naming the same send right
  with `MACH_MSG_TYPE_MOVE_SEND`.

Required checks:

- rejected or leaves consistent sender/receiver accounting
- no silent right consumption beyond documented `MOVE_SEND` semantics
- cleanup baseline

### `m2/receiver_copyout_failure.c`

Test ID: `macos_m2_receiver_copyout_failure`

Purpose:

- Attempt to observe receiver-side descriptor copyout failure from stock
  userland and verify sender rights are not silently consumed.

Required checks:

- if observable, copyin succeeds but failed copyout does not consume sender
  rights silently
- if not practically observable on stock macOS, classify as `not_observable`
  and document the attempted method
- cleanup baseline

### `m2/sender_exit_queued_descriptor.c`

Test ID: `macos_m2_sender_exit_queued_descriptor`

Purpose:

- Observe behavior when sender exits after successfully queueing a descriptor
  message but before receiver drains it.

Status:

- Include in first source package if it can be implemented without flakiness.
- Otherwise mark as first follow-up after `COPY_SEND` and `MOVE_SEND` are
  stable.

### `m2/receiver_exit_queued_descriptor.c`

Test ID: `macos_m2_receiver_exit_queued_descriptor`

Purpose:

- Observe cleanup when receiver exits while a descriptor message is queued.

Status:

- Same as sender-exit probe. Useful for M2 completion, but should not delay the
  first basic macOS fact collection if process choreography becomes unstable.

## Comparison Policy for Parent Agent

The parent agent should compare macOS results against rxOS/NextBSD facts by
semantic class:

- Exact return codes and uref deltas are gates only when both macOS hosts agree
  and introspection APIs are reliable.
- Raw port names are never gates.
- Modern macOS-only behavior should be marked `version_sensitive` before being
  treated as a donor-era requirement.
- Intel versus Apple Silicon disagreement should use `version_sensitive` with
  explicit architecture notes, not a new schema class.
- Privilege-sensitive behavior should not block Phase 0.5 unless normal
  userland needs it.
- If macOS `COPY_SEND` does not increase sender urefs, rxOS/NextBSD should not
  increase sender urefs for header or descriptor `COPY_SEND`.
- If macOS `MOVE_SEND` consumes the sender right only after successful copyin,
  rxOS/NextBSD should match that lifecycle or document an intentional
  divergence.

## How This Helps rxOS Implementation

The first macOS result set should answer these implementation-critical
questions:

1. Whether header `COPY_SEND` and descriptor `COPY_SEND` are non-inflating for
   sender urefs.
2. Whether descriptor `MOVE_SEND` removes the sender right at send time or at a
   later observable point.
3. Which invalid descriptor failures consume no rights.
4. Whether cleanup can be asserted by exact user-reference counts or only by
   namespace inventory/usability.
5. Which bootstrap special-port behaviors are stock-userland observable.
6. Whether fork/spawn/exec behavior should be an exact Phase 0.5 contract or a
   version-sensitive reference fact.

## Stop and Skip Rules

Stop the run and report a findings note if:

- `mach_port_names()` is unusable.
- `mach_port_get_refs()` is unusable and the active probe requires exact urefs.
- ad-hoc signed binaries cannot run.
- a probe requires private entitlement, SIP changes, or kernel debugging.
- a probe hangs despite watchdog logic.
- host-specific behavior would require changing the portable semantic question.

Skip a single probe when:

- the API is unavailable on that macOS version.
- the behavior is blocked by stock macOS privilege policy.
- a prerequisite foundational probe failed.
- process choreography is too unstable for first-pass collection.

## Remaining Questions for Parent Agent

Resolved evidence inputs are now recorded in `parent-agent-questions.md` and
`comprehensive-nx-v64z-macos-oracle-plan.md`.

1. For bootstrap special-port replacement, should stock macOS failure be enough
   to classify the behavior as `privilege_sensitive`, or does the parent want a
   weaker read-only bootstrap inheritance probe to remain mandatory?
2. Is the JSON schema name `nx-v64z.macos-oracle.v1` final for the first
    package?
3. If `mach_port_get_refs()` is reliable on one macOS host but unreliable or
   restricted on the other, should uref-sensitive probes be downgraded globally
   or only for the affected host?

## Proposed Next Step After Parent Reply

Implement the repository skeleton, common C helpers, environment capture, and
the two foundational probes first. Once those run cleanly on at least one macOS
host, implement the M1 probes, then the M2 descriptor probes.

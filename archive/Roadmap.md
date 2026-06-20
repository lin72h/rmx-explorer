# macOS Oracle Roadmap

Date: 2026-05-13

This roadmap tracks the oracle validation batches for Mach IPC semantics. The
macOS runners are the semantic oracle:

- `mx-a64z`: native Apple Silicon macOS
- `mx-x64z`: native Intel macOS

The `rx`/rmxOS lane consumes these findings as comparison targets. It is not an
oracle source.

## Current Milestone

Current milestone: OB2 Descriptor Transfer Semantics.

Core OB2 progress: 100%.

Completed high-value gates:

- Stage 1-2 infrastructure is working.
- OB1 foundation probes are accepted.
- OB1 header COPY_SEND/MOVE_SEND probes are accepted.
- OB2 descriptor COPY_SEND/MOVE_SEND probes are accepted.
- OB2 send-once descriptor is accepted.
- OB2 negative descriptor/error behavior is accepted.

Current status:

- core OB2 is closed and ready to drive rmxOS M2 implementation
- active oracle task is comparison automation and implementation handoff

## Batch Status

| Batch | Scope | Status |
| --- | --- | --- |
| Stage 1-2 | harness, schema, common C helpers, smoke pipeline | complete |
| OB1.1 | `foundation/port_names.c` | accepted |
| OB1.2 | `foundation/port_type.c` | accepted |
| OB1.3 | `foundation/port_get_refs.c` | accepted |
| OB1.4 | `m1/header_copy_send_accounting.c` | accepted |
| OB1.5 | `m1/header_move_send_accounting.c` | accepted |
| OB2.1 | `m2/descriptor_copy_send.c` | accepted |
| OB2.2 | `m2/descriptor_move_send.c` | accepted |
| OB2.3 | `m2/send_once_descriptor.c` | accepted |
| OB2.4 | negative descriptor/error probes | accepted |
| M2 support | machine-readable contract and rmxOS handoff | complete |
| OB2.5 | queued descriptor cleanup and endpoint-exit behavior | likely follow-up |
| OB3 | fork/exec and special-port inheritance behavior | likely follow-up |
| OB4 | bootstrap/special-port mutation and permission edge cases | likely follow-up |
| OB5 | broader regression matrix and comparison automation | likely follow-up |

## Accepted Contracts

### OB1 Foundation

Foundation introspection matches on both native macOS runners:

- `mach_port_names()` can track allocate/destroy namespace deltas.
- `mach_port_type()` reports expected receive, send, send-receive, port-set,
  and task-self right classes.
- `mach_port_get_refs()` reports user-reference accounting consistently.
- Querying send refs with no send right returns `KERN_SUCCESS` with refs `0`.
- `entry_refs_*` remain `null` because stock macOS does not expose kernel
  entry refs through public APIs.

### OB1 Header Accounting

Accepted header COPY_SEND contract:

- sender send urefs: `1 -> 1 -> 1`
- source type: `SEND_RECEIVE -> SEND_RECEIVE -> SEND_RECEIVE`
- cleanup returns to baseline

Accepted header MOVE_SEND contract:

- sender send urefs: `1 -> 0 -> 0`
- source type: `SEND_RECEIVE -> RECEIVE -> RECEIVE`
- cleanup returns to baseline

### OB2 Descriptor Transfer

Accepted descriptor COPY_SEND contract:

- child cargo send urefs: `1 -> 1 -> 1`
- child cargo type: `SEND_RECEIVE -> SEND_RECEIVE -> SEND_RECEIVE`
- parent receives `MACH_PORT_TYPE_SEND`
- parent delivered send refs: `1`
- delivered right is usable
- one parent `mach_port_deallocate()` is sufficient
- parent and child cleanup deltas are `0`
- `entry_refs_*`: `null`

Accepted descriptor MOVE_SEND contract:

- child cargo send urefs: `1 -> 0 -> 0`
- child cargo type: `SEND_RECEIVE -> RECEIVE -> RECEIVE`
- parent receives `MACH_PORT_TYPE_SEND`
- parent delivered send refs: `1`
- delivered right is usable
- one parent `mach_port_deallocate()` is sufficient
- parent and child cleanup deltas are `0`
- `entry_refs_*`: `null`

Accepted descriptor SEND_ONCE contract:

- child creates the send-once right with
  `mach_port_extract_right(MACH_MSG_TYPE_MAKE_SEND_ONCE)`
- child send-once right is consumed at successful `mach_msg(SEND)` return
- parent receives `MACH_PORT_TYPE_SEND_ONCE`
- parent delivered send-once refs are `1`
- first use succeeds with `MACH_MSG_SUCCESS`
- second use fails with `MACH_SEND_INVALID_DEST`
- child second receive times out with `MACH_RCV_TIMED_OUT`
- parent and child cleanup return to baseline
- `entry_refs_*`: `null`

Accepted negative descriptor/error contract:

- invalid descriptor disposition `0xff` returns `MACH_SEND_INVALID_RIGHT`, does
  not deliver a message, does not consume rights, and cleans up to baseline
- nonexistent descriptor source returns `MACH_SEND_INVALID_RIGHT`, does not
  deliver a message, leaves the source invalid, and cleans up to baseline
- dead-name descriptor source returns `MACH_MSG_SUCCESS`, consumes the
  dead-name entry, delivers a descriptor-bearing message, and cleans up to
  baseline
- duplicate `MOVE_SEND` descriptors for the same right return
  `MACH_SEND_INVALID_RIGHT`, do not deliver a message, fully consume the
  sender send right, and clean up to baseline

## Near-Term Work

### rmxOS M2 Implementation Target

Core OB2 is closed. The consolidated descriptor-transfer target is:

- `findings/nx-v64z/ob2-core-descriptor-transfer-spec.md`
- `findings/nx-v64z/ob2-core-descriptor-transfer-spec.json`
- `findings/nx-v64z/rmxos-m2-implementation-target.md`

The two most important negative-path surprises are:

- dead-name descriptor sources are accepted, delivered, and consumed
- duplicate `MOVE_SEND` failure still consumes the sender send right

Do not infer descriptor behavior outside the accepted OB2 list. New behavior
needs a new oracle probe or an explicit parent-approved intentional divergence.

### Comparison Automation

Immediate oracle priority after closing core OB2:

- preserve the accepted descriptor contract
- keep it machine-readable
- make rmxOS comparison easy and repeatable

The machine-readable accepted contract lives at:

- `findings/nx-v64z/ob2-core-descriptor-transfer-spec.json`

The rmxOS implementation-facing handoff lives at:

- `findings/nx-v64z/rmxos-m2-implementation-target.md`

OB2.5 is deferred until queued-message cleanup becomes implementation-relevant,
a sender/receiver-exit bug appears, or parent explicitly asks for it. OB3 is
deferred until after M2 descriptor transfer is implemented or blocked on
fork/bootstrap behavior.

### OB2.3 Send-Once Descriptor

Goal: establish public macOS behavior for descriptor
`MACH_MSG_TYPE_MOVE_SEND_ONCE`.

OB2.3 is accepted as the macOS send-once descriptor contract.

Observed contract:

- child creates the send-once right with
  `mach_port_extract_right(MACH_MSG_TYPE_MAKE_SEND_ONCE)`
- child send-once right is consumed at successful `mach_msg(SEND)` return
- parent receives `MACH_PORT_TYPE_SEND_ONCE`
- parent delivered send-once refs are `1`
- first use succeeds with `MACH_MSG_SUCCESS`
- second use fails with `MACH_SEND_INVALID_DEST`
- child receives exactly one verification message
- parent and child cleanup return to baseline

### OB2.4 Negative Descriptor/Error Probes

Goal: establish error surfaces and cleanup behavior for invalid or edge-case
descriptor operations.

OB2.4 is accepted as the macOS negative descriptor/error contract.

Probes:

- `m2/invalid_descriptor_disposition.c`
- `m2/dead_name_descriptor_right.c`
- `m2/double_move_send_descriptor.c`

Observed contract:

- invalid descriptor disposition `0xff` returns `MACH_SEND_INVALID_RIGHT`, does
  not deliver a message, does not consume rights, and cleans up to baseline
- nonexistent descriptor source returns `MACH_SEND_INVALID_RIGHT`, does not
  deliver a message, leaves the source invalid, and cleans up to baseline
- dead-name descriptor source returns `MACH_MSG_SUCCESS`, consumes the
  dead-name entry, delivers a descriptor-bearing message, and cleans up to
  baseline
- duplicate `MOVE_SEND` descriptors for the same right return
  `MACH_SEND_INVALID_RIGHT`, do not deliver a message, fully consume the
  sender send right, and clean up to baseline

Stop condition: do not require private entitlements, SIP changes, privileged
helpers, private headers, or non-stock APIs.

Gate: closed.

## Likely Follow-Up Work

### OB2.5 Queued Descriptor Cleanup

Goal: verify cleanup behavior for queued messages and endpoint lifecycle events.

Candidate probes:

- sender exits after queuing descriptor message
- receiver exits before dequeue
- receive right destroyed while descriptor message is queued
- queued COPY_SEND cleanup
- queued MOVE_SEND cleanup
- queued send-once descriptor cleanup

This is deeper compatibility and regression coverage. It is not automatically a
blocker for first descriptor implementation unless parent marks it blocking.

### OB3 Fork, Exec, And Special-Port Inheritance

Goal: validate process-boundary behavior that affects cross-task probe setup and
rmxOS process semantics.

Candidate probes:

- fork inheritance of task/bootstrap/special ports
- exec behavior for inherited special ports
- bootstrap special-port get/set/restore behavior
- child rendezvous behavior using public IPC setup only

### OB4 Bootstrap And Permission Edge Cases

Goal: classify stock macOS permission behavior for special-port mutation and
related bootstrap operations.

Classifications may include:

- `exact_contract`
- `privilege_sensitive`
- `version_sensitive`
- `architecture_sensitive`
- `not_observable`

### OB5 Regression Matrix And Automation

Goal: make accepted oracle contracts easy to compare against rmxOS runs.

Candidate work:

- normalized comparison summaries
- required-field checks per probe family
- per-runner summary generation
- rmxOS comparison report format
- regression gate list for local implementation agents

## Gate Rules

Each oracle probe family must follow these rules:

- Both `mx-a64z` and `mx-x64z` are mandatory.
- Raw JSON artifacts are preserved for each runner.
- Cross-runner comparison is written only after both runner results exist.
- Parent acceptance is required before moving to the next batch.
- `entry_refs_*` stay `null` unless directly observable through public APIs.
- Public macOS APIs only: no private entitlements, SIP changes, privileged
  helpers, private headers, or non-stock APIs.

## rmxOS Implementation Use

The accepted oracle findings define user-visible behavior for rmxOS:

- exact call sequence
- exact return values
- sender and receiver right types
- observable uref deltas
- delivered-right usability
- cleanup requirements
- semantic classification against macOS

Internal rmxOS counters such as `entry_refs` and `srights` may be useful for
debugging, but they are not the macOS oracle contract unless public macOS APIs
can directly observe them.

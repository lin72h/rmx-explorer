# Parent Response To OPUS Oracle Batch Proposal

Date: 2026-05-12

Status: accepted with corrections

## Approved Structure

Accept the OPUS two-batch structure with corrections.

Oracle Batch 1:

1. OB1.1 `foundation/port_names.c`
2. OB1.2 `foundation/port_type.c`
3. OB1.3 `foundation/port_get_refs.c`
4. OB1.4 `m1/header_copy_send_accounting.c`
5. OB1.5 `m1/header_move_send_accounting.c`

Oracle Batch 2:

1. OB2.1 `m2/descriptor_copy_send.c`
2. OB2.2 `m2/descriptor_move_send.c`
3. OB2.3 `m2/send_once_descriptor.c`
4. OB2.4 negative descriptor probes

Do not start OB2 until OB1.1-OB1.3 pass on both native macOS runners.

## Critical Correction: urefs vs entry_refs

Do not treat `entry_refs` as observable on stock macOS.

Use only public, observable behavior:

- `mach_port_get_refs(..., MACH_PORT_RIGHT_SEND, ...)`
- `mach_port_get_refs(..., MACH_PORT_RIGHT_RECEIVE, ...)`
- `mach_port_type()`
- `mach_port_names()`
- delivered-right usability
- cleanup-to-baseline

Represent kernel-only `entry_refs_before` and `entry_refs_after` as `null`.

If NextBSD/rmxOS has internal `entry_refs=2`, compare it only as internal
implementation evidence. The oracle macOS contract is observable urefs plus
behavior, not internal entry refs.

## Batch Priority

OPUS is right that OB1.4 and OB2.1 are urgent, but do not bypass foundation.

Correct order:

1. OB1.1 `port_names`
2. OB1.2 `port_type`
3. OB1.3 `port_get_refs`
4. OB1.4 header COPY_SEND
5. OB1.5 header MOVE_SEND
6. OB2.1 descriptor COPY_SEND
7. OB2.2 descriptor MOVE_SEND
8. OB2.3 send-once descriptor
9. OB2.4 negative tests

## Header Probe Correction

For header COPY_SEND/MOVE_SEND, be precise: the header remote-port disposition
controls the destination send right used for message delivery. It is not a port
descriptor payload.

Record:

- sender urefs before `mach_msg(SEND)`
- sender urefs after successful `mach_msg(SEND)`
- sender port type after send
- receive result
- raw received header fields
- cleanup-to-baseline

Do not describe this as "receiver gets a delivered header send right" unless
the received header field actually contains a usable right under macOS
semantics. Record the raw received header fields separately.

## Descriptor Probe Requirements

For descriptor COPY_SEND and MOVE_SEND, the receiver really gets a transferred
port descriptor.

Record:

- sender cargo port type before send
- sender cargo send urefs before send
- sender cargo send urefs after successful send
- delivered descriptor disposition/type
- receiver-side `mach_port_type()` for delivered name
- receiver-side send urefs for delivered name
- whether delivered send right works
- whether one `mach_port_deallocate()` returns to baseline
- if not, how many deallocates or what cleanup was required

Again: `entry_refs_*: null` unless directly observable.

## OB2 Bootstrap Dependency

OB2 may use bootstrap special-port inheritance to give the child a way to reach
the parent. That is acceptable, but record it as a dependency:

- parent sets bootstrap special port
- child retrieves bootstrap special port
- child can send to it
- parent restores original bootstrap port
- cleanup returns to baseline

If bootstrap inheritance fails on macOS, stop OB2 and report it as a blocker.

## Gate Rules

Both `mx-x64z` and `mx-a64z` are mandatory for every Batch 1 and Batch 2 probe.

Stop and ask parent if:

- Intel and Apple Silicon disagree
- cleanup does not return to baseline
- COPY_SEND changes sender urefs on macOS
- MOVE_SEND does not consume/decrement sender rights as expected
- descriptor delivery requires unexpected cleanup
- a probe needs private entitlement, SIP change, or non-stock API

## Raw Artifacts

Force-add raw JSON for all OB1 and OB2 probes.

For each runner preserve:

- `environment.json`
- every probe result JSON
- curated markdown summary
- stderr logs only when non-empty or failure-relevant

## Implementation Dependency Decision

Do not start rmxOS M2.2/M2.3/M2.4 until the matching oracle probes exist.

Specifically:

- M2.2 waits for OB1.5 and OB2.2.
- M2.3 waits for OB2.3.
- M2.4 waits for OB2.4.
- Existing B21/B22 can be classified only after OB1.4/OB2.1 results are
  available.

The oracle result is the spec.

## Main Parent Position

OPUS has the right dependency model. The unsafe part is asking macOS to prove
internal `entry_refs`. The oracle should prove observable behavior; rmxOS can
then decide whether its internal reference counts produce that behavior.

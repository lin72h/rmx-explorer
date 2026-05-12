# OB2 Core Descriptor Transfer Oracle Spec

Date: 2026-05-13

Status: closed and accepted.

Native oracle coverage:

- `mx-a64z`: Apple Silicon macOS
- `mx-x64z`: Intel macOS

All accepted OB2 contracts below are based on matched native macOS behavior
from both runners. Stock macOS does not expose kernel `entry_refs` through
public APIs, so `entry_refs_before` and `entry_refs_after` remain `null` for
these contracts.

## Source Findings

- OB2.1 COPY_SEND descriptor:
  `findings/nx-v64z/ob2.1-descriptor-copy-send-comparison.md`
- OB2.2 MOVE_SEND descriptor:
  `findings/nx-v64z/ob2.2-descriptor-move-send-comparison.md`
- OB2.3 MOVE_SEND_ONCE descriptor:
  `findings/nx-v64z/ob2.3-send-once-descriptor-comparison.md`
- OB2.4 negative descriptor/error behavior:
  `findings/nx-v64z/ob2.4-negative-descriptor-comparison.md`

Note: the original OB2.4 raw JSON for `dead_name_descriptor_right` reports
`status: fail` because the probe expected no delivery and no mutation. Parent
accepted the matched macOS result as the contract, so future runs should report
pass when they reproduce the accepted dead-name delivery/consumption behavior.

## Accepted Descriptor Contracts

### OB2.1 COPY_SEND Descriptor

For a cross-task port descriptor sent with `MACH_MSG_TYPE_COPY_SEND`:

- child cargo send urefs remain `1 -> 1 -> 1`
- child cargo type remains
  `MACH_PORT_TYPE_SEND_RECEIVE -> MACH_PORT_TYPE_SEND_RECEIVE ->
  MACH_PORT_TYPE_SEND_RECEIVE`
- parent receives `MACH_PORT_TYPE_SEND`
- parent delivered send refs are `1`
- delivered right is usable
- one parent `mach_port_deallocate()` is sufficient for the delivered right
- parent cleanup delta is `0`
- child cleanup delta is `0`

rmxOS target: descriptor COPY_SEND must be sender-uref-stable and must deliver
a usable send right with one observable receiver-side send ref.

### OB2.2 MOVE_SEND Descriptor

For a cross-task port descriptor sent with `MACH_MSG_TYPE_MOVE_SEND`:

- child cargo send urefs change `1 -> 0 -> 0`
- child cargo type changes
  `MACH_PORT_TYPE_SEND_RECEIVE -> MACH_PORT_TYPE_RECEIVE ->
  MACH_PORT_TYPE_RECEIVE`
- parent receives `MACH_PORT_TYPE_SEND`
- parent delivered send refs are `1`
- delivered right is usable
- one parent `mach_port_deallocate()` is sufficient for the delivered right
- parent cleanup delta is `0`
- child cleanup delta is `0`

rmxOS target: descriptor MOVE_SEND must consume the sender send right at
successful `mach_msg(SEND)` return and deliver a usable send right to the
receiver.

### OB2.3 MOVE_SEND_ONCE Descriptor

For a cross-task port descriptor sent with `MACH_MSG_TYPE_MOVE_SEND_ONCE`:

- child creates the send-once right with
  `mach_port_extract_right(MACH_MSG_TYPE_MAKE_SEND_ONCE)`
- child send-once right is consumed at successful `mach_msg(SEND)` return
- parent receives `MACH_PORT_TYPE_SEND_ONCE`
- parent delivered send-once refs are `1`
- first parent use succeeds with `MACH_MSG_SUCCESS`
- the delivered send-once right is consumed by the first use
- second parent use fails with `MACH_SEND_INVALID_DEST`
- child first receive succeeds with `MACH_MSG_SUCCESS`
- child second receive times out with `MACH_RCV_TIMED_OUT`
- child receives no second verification message
- parent cleanup delta is `0`
- child cleanup delta is `0`

rmxOS target: delivered send-once rights must be usable exactly once, then
become invalid.

### OB2.4 Invalid Descriptor Disposition

For a port descriptor with invalid disposition raw value `0xff`:

- `mach_msg(SEND)` returns `MACH_SEND_INVALID_RIGHT`
- no message is delivered
- header/service send refs are unchanged
- cargo send refs are unchanged
- cargo type remains `MACH_PORT_TYPE_SEND_RECEIVE`
- cleanup delta is `0`

rmxOS target: reject invalid descriptor dispositions without consuming rights or
queuing a message.

### OB2.4 Nonexistent Descriptor Source

For a descriptor source name that does not exist:

- source type before send is `KERN_INVALID_NAME`
- `mach_msg(SEND)` returns `MACH_SEND_INVALID_RIGHT`
- source remains `KERN_INVALID_NAME`
- no message is delivered
- cleanup delta is `0`

rmxOS target: reject nonexistent descriptor source names without mutation or
delivery.

### OB2.4 Dead-Name Descriptor Source

For a descriptor source that is a `MACH_PORT_RIGHT_DEAD_NAME` and descriptor
disposition `MACH_MSG_TYPE_MOVE_SEND`:

- source type before send is `MACH_PORT_TYPE_DEAD_NAME`
- source dead-name refs before send are `1`
- `mach_msg(SEND)` returns `MACH_MSG_SUCCESS`
- source type query after send returns `KERN_INVALID_NAME`
- source refs query after send returns `KERN_INVALID_NAME`
- message is delivered
- received descriptor count is `1`
- received descriptor disposition is
  `MACH_MSG_TYPE_MOVE_SEND_OR_PORT_SEND`
- deallocating the delivered descriptor name returns `KERN_SUCCESS`
- deallocating the original source name after send returns
  `KERN_INVALID_NAME`
- cleanup delta is `0`

rmxOS target: match macOS by accepting the dead-name descriptor source,
consuming the dead-name entry, and delivering the descriptor-bearing message.

This was the main OB2.4 surprise. The original no-delivery/no-mutation
expectation was wrong.

### OB2.4 Duplicate MOVE_SEND Descriptors For Same Right

For one message containing two descriptors that name the same send right with
`MACH_MSG_TYPE_MOVE_SEND`:

- `mach_msg(SEND)` returns `MACH_SEND_INVALID_RIGHT`
- no message is delivered
- sender cargo send refs change `1 -> 0 -> 0`
- sender cargo type changes
  `MACH_PORT_TYPE_SEND_RECEIVE -> MACH_PORT_TYPE_RECEIVE`
- sender consumption class is `fully_consumed`
- cleanup delta is `0`

rmxOS target: reject the message, do not deliver anything, but still fully
consume the sender send right.

This was the second major OB2.4 surprise. Failure does not imply no mutation.

## Implementation Guidance

The descriptor-transfer oracle spec is ready to drive rmxOS M2 implementation.

Implementation agents should match the public behavior above:

- exact `mach_msg` return values
- observable sender and receiver right types
- observable user-reference deltas
- delivered-right usability
- cleanup-to-baseline behavior
- absence or presence of message delivery

Internal rmxOS counters such as `entry_refs` and `srights` may be used for
debugging, but they are not the oracle contract unless a future public macOS
probe can observe them directly.

Do not infer behavior outside this list. Any additional descriptor behavior
needs a new oracle probe or an explicit parent-approved intentional divergence.

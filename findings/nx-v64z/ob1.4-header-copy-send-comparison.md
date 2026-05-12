# OB1.4 Header COPY_SEND Comparison Findings

Date: 2026-05-13

Oracle results:
- `mx-a64z`: macOS 26.5, Darwin 25.5.0, arm64 Apple M4
- `mx-x64z`: macOS 26.4, Darwin 25.4.0, x86_64 Intel i7-11700K

Probe: `m1/header_copy_send_accounting.c`
Test ID: `macos_m1_header_copy_send_accounting`

NextBSD comparison target: batch 21 header `COPY_SEND` source-side accounting.

## Summary

OB1.4 passed on both native macOS runners. Header
`MACH_MSG_TYPE_COPY_SEND` did not change the sender's observable send urefs at
`mach_msg(SEND)` return or after `mach_msg(RECEIVE)`.

Cross-runner result:

| Runner | Status | Send Urefs | Port Type Sequence | Sent Bits | Received Bits | Cleanup |
| --- | --- | --- | --- | --- | --- | --- |
| `mx-a64z` | `pass` | `1 -> 1 -> 1` | `SEND_RECEIVE -> SEND_RECEIVE -> SEND_RECEIVE` | `0x13` | `0x1100` | baseline |
| `mx-x64z` | `pass` | `1 -> 1 -> 1` | `SEND_RECEIVE -> SEND_RECEIVE -> SEND_RECEIVE` | `0x13` | `0x1100` | baseline |

The OB1.4 stop condition did not occur.

## macOS Contract

For a same-process header-only message sent with:

```text
msgh_remote_port = service_port
msgh_local_port = MACH_PORT_NULL
msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, 0)
```

native macOS behavior on both runners is:

- `mach_msg(SEND)` returns `MACH_MSG_SUCCESS`
- `mach_msg(RECEIVE)` returns `MACH_MSG_SUCCESS`
- sender send urefs before send: `1`
- sender send urefs immediately after `mach_msg(SEND)`: `1`
- sender send urefs after `mach_msg(RECEIVE)`: `1`
- port type before send: `MACH_PORT_TYPE_SEND_RECEIVE`
- port type after send: `MACH_PORT_TYPE_SEND_RECEIVE`
- port type after receive: `MACH_PORT_TYPE_SEND_RECEIVE`
- received remote port label: `MACH_PORT_NULL`
- received local port label: `service_port`
- received remote disposition: `0`
- received local disposition: `MACH_MSG_TYPE_MOVE_SEND`
- cleanup returns to the original port namespace baseline
- `entry_refs_before` and `entry_refs_after` remain `null`

## NextBSD Comparison

Batch 21 reported stable header `COPY_SEND` source-side accounting. The
implementation lane has internal evidence such as `entry_refs=2->2->2` and
message-right counter behavior, but stock macOS does not expose those kernel
internals through the public APIs used by the oracle.

The validated oracle target is therefore the observable contract:

```text
sender send urefs: 1 -> 1 -> 1
port type: SEND_RECEIVE -> SEND_RECEIVE -> SEND_RECEIVE
cleanup: returns to baseline
```

This confirms the batch 21 conclusion at the public macOS semantic level:
header `MACH_MSG_TYPE_COPY_SEND` is non-inflating for the sender.

## Implementation Guidance

rmxOS should preserve the sender's observable send uref count across header
`COPY_SEND`:

- no source send uref increase at `mach_msg(SEND)` return
- no delayed source send uref change after `mach_msg(RECEIVE)`
- port remains usable as `MACH_PORT_TYPE_SEND_RECEIVE`
- cleanup returns to baseline

Internal `entry_refs` and `srights` counters may be used for implementation
debugging, but they are not the public oracle contract unless exposed by a
stock macOS observable.

## Gate Status

OB1.4 is complete on both native macOS runners.

OB1.5 `m1/header_move_send_accounting.c` is now the next oracle probe, subject
to the parent rule that no descriptor probes start until header MOVE_SEND is
captured on both runners.


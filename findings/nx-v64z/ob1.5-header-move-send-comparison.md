# OB1.5 Header MOVE_SEND Comparison Findings

Date: 2026-05-13

Oracle results:
- `mx-a64z`: macOS 26.5, Darwin 25.5.0, arm64 Apple M4
- `mx-x64z`: macOS 26.4, Darwin 25.4.0, x86_64 Intel i7-11700K

Probe: `m1/header_move_send_accounting.c`
Test ID: `macos_m1_header_move_send_accounting`

## Summary

OB1.5 passed on both native macOS runners. Header
`MACH_MSG_TYPE_MOVE_SEND` consumes the sender's observable send right at
successful `mach_msg(SEND)` return.

Cross-runner result:

| Runner | Status | Send Urefs | Port Type Sequence | Sent Bits | Received Bits | Cleanup |
| --- | --- | --- | --- | --- | --- | --- |
| `mx-a64z` | `pass` | `1 -> 0 -> 0` | `SEND_RECEIVE -> RECEIVE -> RECEIVE` | `0x11` | `0x1100` | baseline |
| `mx-x64z` | `pass` | `1 -> 0 -> 0` | `SEND_RECEIVE -> RECEIVE -> RECEIVE` | `0x11` | `0x1100` | baseline |

No OB1.5 stop condition occurred.

## macOS Contract

For a same-process header-only message sent with:

```text
msgh_remote_port = service_port
msgh_local_port = MACH_PORT_NULL
msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_MOVE_SEND, 0)
```

native macOS behavior on both runners is:

- `mach_msg(SEND)` returns `MACH_MSG_SUCCESS`
- `mach_msg(RECEIVE)` returns `MACH_MSG_SUCCESS`
- sender send urefs before send: `1`
- sender send urefs immediately after `mach_msg(SEND)`: `0`
- sender send urefs after `mach_msg(RECEIVE)`: `0`
- port type before send: `MACH_PORT_TYPE_SEND_RECEIVE`
- port type after send: `MACH_PORT_TYPE_RECEIVE`
- port type after receive: `MACH_PORT_TYPE_RECEIVE`
- received remote port label: `MACH_PORT_NULL`
- received local port label: `service_port`
- received remote disposition: `0`
- received local disposition: `MACH_MSG_TYPE_MOVE_SEND`
- no delivered send right is observable after receive in this same-process
  setup, so delivered-right usability is not attempted
- cleanup returns to the original port namespace baseline
- `entry_refs_before` and `entry_refs_after` remain `null`

## Implementation Guidance

rmxOS should consume the sender's observable send right for header
`MOVE_SEND` at `mach_msg(SEND)` return:

- source send urefs change from `1` to `0`
- the source name remains valid as a receive right when the sender also owns
  the receive right
- port type changes from `MACH_PORT_TYPE_SEND_RECEIVE` to
  `MACH_PORT_TYPE_RECEIVE`
- receiving the queued message does not restore a send uref to the source name
- cleanup returns to baseline

Internal `entry_refs` and `srights` counters may be used for implementation
debugging, but they are not the stock macOS oracle contract unless directly
observable through public APIs.

## Gate Status

OB1.5 is complete on both native macOS runners.

The header accounting gate is now complete:

- OB1.4 `COPY_SEND`: sender send urefs stay `1 -> 1 -> 1`
- OB1.5 `MOVE_SEND`: sender send urefs change `1 -> 0 -> 0`

OB2 remains unstarted. Per `parent-start-ob1.5-only.md`, OB2.1 should wait for
the next explicit parent start instruction.


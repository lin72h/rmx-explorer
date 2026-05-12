# OB2.1 Descriptor COPY_SEND Comparison Findings

Date: 2026-05-13

Oracle results:
- `mx-a64z`: macOS 26.5, Darwin 25.5.0, arm64 Apple M4
- `mx-x64z`: macOS 26.4, Darwin 25.4.0, x86_64 Intel i7-11700K

Probe: `m2/descriptor_copy_send.c`
Test ID: `macos_m2_descriptor_copy_send`

## Summary

OB2.1 passed on both native macOS runners. Descriptor
`MACH_MSG_TYPE_COPY_SEND` preserves the child sender's observable cargo send
urefs and delivers a usable send right to the parent receiver.

Cross-runner result:

| Runner | Status | Cargo Send Urefs | Cargo Type Sequence | Delivered Type | Delivered Send Refs | Delivered Usable | Cleanup |
| --- | --- | --- | --- | --- | ---: | --- | --- |
| `mx-a64z` | `pass` | `1 -> 1 -> 1` | `SEND_RECEIVE -> SEND_RECEIVE -> SEND_RECEIVE` | `MACH_PORT_TYPE_SEND` | 1 | true | baseline |
| `mx-x64z` | `pass` | `1 -> 1 -> 1` | `SEND_RECEIVE -> SEND_RECEIVE -> SEND_RECEIVE` | `MACH_PORT_TYPE_SEND` | 1 | true | baseline |

No OB2.1 stop condition occurred.

## macOS Contract

For a controlled cross-task message where the child sends a cargo send right to
the parent using a port descriptor with `MACH_MSG_TYPE_COPY_SEND`, native macOS
behavior on both runners is:

- child descriptor send returns `MACH_MSG_SUCCESS`
- parent descriptor receive returns `MACH_MSG_SUCCESS`
- child cargo send urefs before descriptor send: `1`
- child cargo send urefs after descriptor send: `1`
- child cargo send urefs after parent verification: `1`
- child cargo type remains `MACH_PORT_TYPE_SEND_RECEIVE`
- sent descriptor message bits: `0x80000013`
- received descriptor message bits: `0x80001100`
- received descriptor count: `1`
- delivered descriptor disposition raw hex: `0x11`
- delivered descriptor disposition label: `MACH_MSG_TYPE_MOVE_SEND_OR_PORT_SEND`
- parent delivered port type: `MACH_PORT_TYPE_SEND`
- parent delivered send refs: `1`
- parent can send a verification Mach message through the delivered right
- child receives that verification message successfully
- one parent `mach_port_deallocate()` of the delivered right succeeds
- parent cleanup returns to baseline
- child cleanup returns to its reported baseline
- `entry_refs_before` and `entry_refs_after` remain `null`

The probe uses bootstrap special-port inheritance to publish the parent service
port to the child, plus a Unix pipe only for child status reporting. The
delivered-right usability check is a Mach message sent from parent to child.

## Cleanup Note

The parent baseline is a full task-port namespace baseline around the probe.

The child cleanup baseline is captured after the child has obtained the
inherited bootstrap/service send right, so it specifically validates cleanup of
the child's cargo receive/send right and verification-message effects. This is
appropriate for the helper-process design and should be described as
child-reported cleanup rather than a process-start absolute namespace.

## Implementation Guidance

rmxOS should match the observable macOS descriptor `COPY_SEND` contract:

- descriptor `COPY_SEND` must not change the sender cargo send uref count
- sender cargo port remains `MACH_PORT_TYPE_SEND_RECEIVE`
- receiver receives a usable send right
- receiver-side delivered right reports `MACH_PORT_TYPE_SEND`
- receiver-side delivered right has one observable send ref
- one receiver-side `mach_port_deallocate()` is sufficient for the delivered
  right in this scenario
- parent and child cleanup return to their baselines

Internal `entry_refs` and `srights` counters may be used for implementation
debugging, but the stock macOS oracle contract is the public behavior above.

## Gate Status

OB2.1 is complete on both native macOS runners.

OB2.2 `m2/descriptor_move_send.c` remains blocked until parent accepts this
comparison finding and issues an explicit start instruction.


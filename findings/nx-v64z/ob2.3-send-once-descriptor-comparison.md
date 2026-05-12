# OB2.3 Send-Once Descriptor Comparison Findings

Date: 2026-05-13

Oracle results:
- `mx-a64z`: macOS 26.5, Darwin 25.5.0, arm64 Apple M4
- `mx-x64z`: macOS 26.4, Darwin 25.4.0, x86_64 Intel i7-11700K

Probe: `m2/send_once_descriptor.c`
Test ID: `macos_m2_send_once_descriptor`

## Summary

OB2.3 passed on both native macOS runners. Descriptor
`MACH_MSG_TYPE_MOVE_SEND_ONCE` consumes the child sender's send-once right at
successful `mach_msg(SEND)` return and delivers a usable one-shot right to the
parent receiver.

The parent can send exactly one verification message through the delivered
right. A second send is rejected with `MACH_SEND_INVALID_DEST`, and the child
does not receive a second verification message.

Cross-runner result:

| Runner | Status | Create API | Delivered Type | Delivered Refs | First Use | Second Use | Second Child Receive | Cleanup |
| --- | --- | --- | --- | ---: | --- | --- | --- | --- |
| `mx-a64z` | `pass` | `mach_port_extract_right(MAKE_SEND_ONCE)` | `MACH_PORT_TYPE_SEND_ONCE` | 1 | `MACH_MSG_SUCCESS` | `MACH_SEND_INVALID_DEST` | `MACH_RCV_TIMED_OUT` | baseline |
| `mx-x64z` | `pass` | `mach_port_extract_right(MAKE_SEND_ONCE)` | `MACH_PORT_TYPE_SEND_ONCE` | 1 | `MACH_MSG_SUCCESS` | `MACH_SEND_INVALID_DEST` | `MACH_RCV_TIMED_OUT` | baseline |

No OB2.3 stop condition occurred.

## macOS Contract

For a controlled cross-task message where the child sends a send-once right to
the parent using a port descriptor with `MACH_MSG_TYPE_MOVE_SEND_ONCE`, native
macOS behavior on both runners is:

- child creates the send-once right with
  `mach_port_extract_right(MACH_MSG_TYPE_MAKE_SEND_ONCE)`
- child send-once creation returns `KERN_SUCCESS`
- child cargo type before send-once creation is `MACH_PORT_TYPE_RECEIVE`
- child extracted acquired type is
  `MACH_MSG_TYPE_MOVE_SEND_ONCE_OR_PORT_SEND_ONCE`
- child send-once type before descriptor send is `MACH_PORT_TYPE_SEND_ONCE`
- child send-once refs before descriptor send are `1`
- child descriptor send returns `MACH_MSG_SUCCESS`
- child send-once type query after descriptor send returns `KERN_INVALID_NAME`
- child send-once refs query after descriptor send returns `KERN_INVALID_NAME`
- parent descriptor receive returns `MACH_MSG_SUCCESS`
- sent descriptor message bits: `0x80000013`
- received descriptor message bits: `0x80001100`
- received descriptor count: `1`
- delivered descriptor disposition raw hex: `0x12`
- delivered descriptor disposition label:
  `MACH_MSG_TYPE_MOVE_SEND_ONCE_OR_PORT_SEND_ONCE`
- parent delivered port type: `MACH_PORT_TYPE_SEND_ONCE`
- parent delivered send-once refs: `1`
- first parent verification send returns `MACH_MSG_SUCCESS`
- first verification message bits: `0x12`
- child first verification receive returns `MACH_MSG_SUCCESS`
- child first verification received bits: `0x1200`
- parent delivered type query after first use returns `KERN_INVALID_NAME`
- parent delivered refs query after first use returns `KERN_INVALID_NAME`
- second parent verification send returns `MACH_SEND_INVALID_DEST`
- child second verification receive returns `MACH_RCV_TIMED_OUT`
- child receives no second verification message
- child cargo type after verification remains `MACH_PORT_TYPE_RECEIVE`
- child deallocate of the already-consumed send-once name returns
  `KERN_INVALID_NAME`
- parent deallocate of the already-consumed delivered send-once name returns
  `KERN_INVALID_NAME`
- parent cleanup returns to baseline
- child cleanup returns to its reported baseline
- `entry_refs_before` and `entry_refs_after` remain `null`

The probe uses the same public setup pattern as OB2.1 and OB2.2: bootstrap
special-port inheritance publishes the parent service port to the child, and a
Unix pipe is used only for child status reporting. The delivered-right usability
check is a Mach message sent from parent to child through the delivered
send-once descriptor right.

## Cleanup Note

Unlike OB2.1 and OB2.2, there is no surviving delivered right to deallocate
after the first successful verification send. The delivered send-once right is
consumed by that first send, and a later deallocate attempt returns
`KERN_INVALID_NAME`. This is the expected cleanup behavior for this probe.

The parent baseline is a full task-port namespace baseline around the probe.

The child cleanup baseline is captured after the child has obtained the
inherited bootstrap/service send right, so it specifically validates cleanup of
the child's cargo receive/send-once right and verification-message effects. This
is appropriate for the helper-process design and should be described as
child-reported cleanup rather than a process-start absolute namespace.

## Implementation Guidance

rmxOS should match the observable macOS send-once descriptor contract:

- descriptor `MOVE_SEND_ONCE` must consume the sender's send-once right at
  successful `mach_msg(SEND)` return
- receiver receives a usable `MACH_PORT_TYPE_SEND_ONCE` right
- receiver-side delivered send-once refs report `1` before use
- the delivered right can be used exactly once
- first use succeeds with `MACH_MSG_SUCCESS`
- after first use, the delivered right is gone from the receiver's namespace
- second use fails with `MACH_SEND_INVALID_DEST`
- the receiving endpoint observes exactly one verification message
- no extra deallocate is required for the consumed send-once right
- parent and child cleanup return to their baselines

Internal `entry_refs` and `srights` counters may be used for implementation
debugging, but the stock macOS oracle contract is the public behavior above.

## Gate Status

OB2.3 is complete on both native macOS runners.

OB2.4 negative descriptor/error probes remain blocked until parent accepts this
comparison finding and issues an explicit start instruction.

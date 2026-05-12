# OB2.4 Negative Descriptor Comparison Findings

Date: 2026-05-13

Oracle results:
- `mx-a64z`: macOS 26.5, Darwin 25.5.0, arm64 Apple M4
- `mx-x64z`: macOS 26.4, Darwin 25.4.0, x86_64 Intel i7-11700K

Probes:
- `m2/invalid_descriptor_disposition.c`
- `m2/dead_name_descriptor_right.c`
- `m2/double_move_send_descriptor.c`

Test IDs:
- `macos_m2_invalid_descriptor_disposition`
- `macos_m2_dead_name_descriptor_right`
- `macos_m2_double_move_send_descriptor`

## Summary

OB2.4 produced a matched cross-runner result. `mx-a64z` and `mx-x64z` agree
for every tested negative descriptor case.

The only reported probe failure is `dead_name_descriptor_right`, and that
failure is an expectation mismatch, not a runner disagreement or cleanup leak.
Native macOS accepts a `MACH_PORT_RIGHT_DEAD_NAME` descriptor source sent with
`MACH_MSG_TYPE_MOVE_SEND`, consumes the dead-name entry, and delivers a message.

Cross-runner result:

| Case | macOS Behavior | `mx-a64z` | `mx-x64z` | Cleanup |
| --- | --- | --- | --- | --- |
| invalid descriptor disposition `0xff` | `MACH_SEND_INVALID_RIGHT`, no delivery, no right consumption | match | match | baseline |
| nonexistent descriptor source | `MACH_SEND_INVALID_RIGHT`, no delivery, source remains invalid | match | match | baseline |
| dead-name descriptor source | `MACH_MSG_SUCCESS`, message delivered, dead-name entry consumed | match | match | baseline |
| duplicate `MOVE_SEND` descriptors for same right | `MACH_SEND_INVALID_RIGHT`, no delivery, sender send right fully consumed | match | match | baseline |

No architecture-sensitive behavior was observed.

## invalid_descriptor_disposition

Setup:

- header remote disposition: `MACH_MSG_TYPE_COPY_SEND`
- sent `msgh_bits`: `0x80000013`
- one port descriptor
- descriptor type: `MACH_MSG_PORT_DESCRIPTOR`
- descriptor disposition raw value: `0xff`
- service send refs before send: `1`
- cargo send refs before send: `1`
- cargo type before send: `MACH_PORT_TYPE_SEND_RECEIVE`

Native macOS behavior on both runners:

- `mach_msg(SEND)` returns `MACH_SEND_INVALID_RIGHT`
- receiver attempt returns `MACH_RCV_TIMED_OUT`
- message is not delivered
- service send refs remain `1`
- cargo send refs remain `1`
- cargo type remains `MACH_PORT_TYPE_SEND_RECEIVE`
- cleanup delta is `0`
- `entry_refs_before` and `entry_refs_after` remain `null`

Implementation target:

- invalid descriptor disposition should reject the send
- neither header nor descriptor rights should be consumed
- no message should be queued
- cleanup must return to baseline

## dead_name_descriptor_right

This probe has two subcases: a destroyed/dead name source and a nonexistent
source name.

### Dead-Name Source

Setup:

- source type before send: `MACH_PORT_TYPE_DEAD_NAME`
- source dead-name refs before send: `1`
- descriptor disposition: `MACH_MSG_TYPE_MOVE_SEND`
- sent `msgh_bits`: `0x80000013`

Native macOS behavior on both runners:

- `mach_msg(SEND)` returns `MACH_MSG_SUCCESS`
- source type query after send returns `KERN_INVALID_NAME`
- source refs query after send returns `KERN_INVALID_NAME`
- receiver attempt returns `MACH_MSG_SUCCESS`
- message is delivered
- received `msgh_bits`: `0x80001100`
- received descriptor count: `1`
- received descriptor disposition:
  `MACH_MSG_TYPE_MOVE_SEND_OR_PORT_SEND`
- deallocating the delivered descriptor name returns `KERN_SUCCESS`
- deallocating the original source name after send returns `KERN_INVALID_NAME`
- cleanup delta is `0`
- `entry_refs_before` and `entry_refs_after` remain `null`

This is the surprising OB2.4 result. The original expectation was that a
dead-name descriptor source would be rejected without mutation. Both native
macOS runners instead show that this operation succeeds, consumes the dead-name
entry, and delivers a descriptor-bearing message.

### Nonexistent Source

Setup:

- source type before send: `KERN_INVALID_NAME`
- source refs before send: `KERN_INVALID_NAME`
- descriptor disposition: `MACH_MSG_TYPE_MOVE_SEND`
- sent `msgh_bits`: `0x80000013`

Native macOS behavior on both runners:

- `mach_msg(SEND)` returns `MACH_SEND_INVALID_RIGHT`
- source type after send remains `KERN_INVALID_NAME`
- source refs after send remain `KERN_INVALID_NAME`
- receiver attempt returns `MACH_RCV_TIMED_OUT`
- message is not delivered
- cleanup delta is `0`
- `entry_refs_before` and `entry_refs_after` remain `null`

Implementation target:

- nonexistent descriptor names should reject the send
- no message should be queued
- cleanup must return to baseline

## double_move_send_descriptor

Setup:

- header remote disposition: `MACH_MSG_TYPE_COPY_SEND`
- sent `msgh_bits`: `0x80000013`
- two port descriptors name the same cargo port
- both descriptor dispositions are `MACH_MSG_TYPE_MOVE_SEND`
- cargo type before send: `MACH_PORT_TYPE_SEND_RECEIVE`
- cargo send refs before send: `1`

Native macOS behavior on both runners:

- `mach_msg(SEND)` returns `MACH_SEND_INVALID_RIGHT`
- receiver attempt returns `MACH_RCV_TIMED_OUT`
- message is not delivered
- cargo send refs change `1 -> 0 -> 0`
- cargo type changes `MACH_PORT_TYPE_SEND_RECEIVE -> MACH_PORT_TYPE_RECEIVE`
- sender consumption class is `fully_consumed`
- cleanup delta is `0`
- `entry_refs_before` and `entry_refs_after` remain `null`

This is another important negative-path rule: the send fails, but the sender's
send right is still consumed by the attempted double `MOVE_SEND`.

Implementation target:

- duplicate `MOVE_SEND` descriptors for the same send right should reject the
  message with `MACH_SEND_INVALID_RIGHT`
- no message should be queued
- the sender's send right should be consumed
- if the sender also owns the receive right, the source name should remain as
  `MACH_PORT_TYPE_RECEIVE`
- cleanup must return to baseline

## Parent Decision Needed

The cross-runner evidence is stable and public-API-observable. The parent
should decide whether to accept the dead-name result as the macOS contract.

Recommended classification:

- accept OB2.4 as the macOS negative descriptor contract
- reclassify `dead_name_descriptor_right` from expectation failure to expected
  pass in future probe runs
- close the core OB2 descriptor-transfer oracle spec after that acceptance

If the parent does not accept the dead-name behavior as contract, OB2.4 remains
blocked even though both native macOS runners agree.

## Gate Status

OB2.4 runner evidence is complete on both native macOS runners.

OB2 should not be closed until parent explicitly accepts or rejects the
dead-name descriptor behavior.

No OB2.5 probe was started.

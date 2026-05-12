# Parent Acceptance: OB2.2 Accepted, Start OB2.3

OB2.2 `m2/descriptor_move_send.c` is accepted as the macOS descriptor MOVE_SEND
contract.

Accepted OB2.2 contract:

- descriptor `MACH_MSG_TYPE_MOVE_SEND` consumes the sender cargo send right at
  successful `mach_msg(SEND)` return
- child cargo send urefs: `1 -> 0 -> 0`
- child cargo type: `SEND_RECEIVE -> RECEIVE -> RECEIVE`
- parent receives `MACH_PORT_TYPE_SEND`
- parent delivered send refs: `1`
- delivered right is usable
- one parent `mach_port_deallocate()` is sufficient
- parent cleanup delta: `0`
- child cleanup delta: `0`
- `entry_refs_*`: `null`

## Approved Next Probe: OB2.3

Implement:

- `macos-validation/probes/m2/send_once_descriptor.c`

Use the same controlled cross-task shape as OB2.1 and OB2.2.

## Required Observations

Record:

- child cargo receive right/type before creating send-once right
- exact API used to create send-once right
- child send-once right type before send
- child send-once refs before send if observable
- exact `mach_msg(SEND)` return
- child send-once right type immediately after successful `mach_msg(SEND)`
- child send-once refs immediately after successful `mach_msg(SEND)` if
  observable
- delivered descriptor disposition/type/name
- parent-side `mach_port_type()` for delivered name
- parent-side send-once refs for delivered name if observable
- first delivered-right usability result
- second-use result after the send-once right has been consumed
- child receive result for the first verification message
- whether any second verification message is received
- parent cleanup-to-baseline
- child cleanup-to-baseline
- `entry_refs_before: null`
- `entry_refs_after: null`

## Expected Semantics To Test, Not Assume

Hypothesis:

- descriptor `MACH_MSG_TYPE_MOVE_SEND_ONCE` consumes the child's send-once right
  at successful `mach_msg(SEND)`
- parent receives a usable send-once right
- parent can send exactly one verification message through it
- second use should fail or the right should no longer exist
- child should receive exactly one verification message
- cleanup should return to baseline on both sides

The probe must record actual macOS behavior and exact return codes.

## Stop Conditions

Stop before OB2.4 if:

- `mx-a64z` and `mx-x64z` disagree
- cleanup does not return to baseline
- delivered send-once right is unusable
- delivered send-once right is reusable more than once
- child receives more than one verification message
- private entitlement, SIP change, privileged helper, private header, or
  non-stock API would be needed
- public APIs cannot observe enough behavior to classify the result

## Runner Protocol

Use the existing two-runner protocol:

1. `mx-a64z` implements OB2.3 and commits implementation, raw JSON, and summary.
2. `mx-x64z` pulls the same implementation, runs it, and commits raw JSON,
   summary, and cross-runner comparison.
3. Parent reviews and accepts/rejects the comparison before OB2.4 starts.

Implementation implication for rmxOS: descriptor MOVE_SEND is now no longer
speculative. The user-visible contract is single-step sender consumption at
send return, delivered usable send right with one deallocate cleanup.

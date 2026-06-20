# Parent Acceptance: OB2.1 Accepted, Start OB2.2

OB2.1 `m2/descriptor_copy_send.c` is accepted as the macOS descriptor COPY_SEND
contract.

Accepted OB2.1 contract:

- descriptor `MACH_MSG_TYPE_COPY_SEND` preserves child sender cargo send urefs
- child cargo send urefs: `1 -> 1 -> 1`
- child cargo type remains `SEND_RECEIVE`
- parent receives `MACH_PORT_TYPE_SEND`
- parent delivered send refs: `1`
- delivered right is usable
- one parent `mach_port_deallocate()` is sufficient
- parent cleanup delta: `0`
- child cleanup delta: `0`
- `entry_refs_*`: `null`

This means rmxOS/NextBSD behavior with delivered internal `entry_refs=2` is not
itself the macOS contract. The required external contract is: delivered send
refs are observable as `1`, one deallocate cleans up, delivered right is usable,
and sender COPY_SEND urefs remain stable.

## Approved Next Probe: OB2.2

Implement:

- `macos-validation/probes/m2/descriptor_move_send.c`

Use the same controlled cross-task shape as OB2.1.

## Required Observations

Record:

- child cargo type before send
- child cargo send urefs before send
- exact `mach_msg(SEND)` return
- child cargo type immediately after successful `mach_msg(SEND)`
- child cargo send urefs immediately after successful `mach_msg(SEND)`
- child cargo type after parent receive/verification if observable
- child cargo send urefs after parent receive/verification if observable
- delivered descriptor disposition/type/name
- parent-side `mach_port_type()` for delivered name
- parent-side send refs for delivered name
- delivered-right usability result
- child verification receive result
- whether parent needs exactly one `mach_port_deallocate()` for delivered right
- parent cleanup-to-baseline
- child cleanup-to-baseline
- `entry_refs_before: null`
- `entry_refs_after: null`

## Expected Semantics To Test, Not Assume

The expected hypothesis is:

- descriptor `MACH_MSG_TYPE_MOVE_SEND` consumes/decrements the child sender's
  cargo send right at successful `mach_msg(SEND)`
- if the cargo name also has a receive right, its type should likely change from
  `SEND_RECEIVE` to `RECEIVE`
- parent should receive a usable `MACH_PORT_TYPE_SEND`
- parent delivered send refs should likely be `1`
- one parent `mach_port_deallocate()` should likely clean up the delivered right

But the probe must record actual macOS behavior, not bake these expectations
into pass/fail unless cleanup or usability fails.

## Stop Conditions

Stop before OB2.3 if:

- `mx-a64z` and `mx-x64z` disagree
- cleanup does not return to baseline
- descriptor `MOVE_SEND` does not consume/decrement sender cargo send rights in
  an observable, consistent way
- parent receives an unusable delivered send right
- parent delivered cleanup requires surprising extra operations
- private entitlement, SIP change, privileged helper, private header, or
  non-stock API would be needed

## Runner Protocol

Use the existing two-runner protocol:

1. `mx-a64z` implements OB2.2 and commits implementation, raw JSON, and summary.
2. `mx-x64z` pulls the same implementation, runs it, and commits raw JSON,
   summary, and cross-runner comparison.
3. Parent reviews and accepts/rejects the comparison before OB2.3 starts.

Important implementation implication: if rmxOS currently needs destroy or two
deallocates for descriptor COPY_SEND cleanup, that is a bug against the accepted
OB2.1 external contract unless there is a parent-approved internal reason with
identical user-visible behavior.


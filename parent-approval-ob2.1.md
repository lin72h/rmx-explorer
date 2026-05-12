# Parent Approval: Start OB2.1 Descriptor COPY_SEND

Approve OB2.1 with modifications.

Implement:

- `macos-validation/probes/m2/descriptor_copy_send.c`

## Required Shape

OB2.1 must be a controlled cross-task probe.

Use:

- parent creates service receive right
- parent inserts/holds send right for service
- parent publishes service to child using the already-proven bootstrap
  special-port inheritance path, or another explicitly documented public setup
  path
- child creates cargo port with receive + send right
- child sends a complex Mach message to parent carrying cargo send right as a
  port descriptor with `MACH_MSG_TYPE_COPY_SEND`
- parent receives descriptor
- parent verifies delivered send right usability by sending a small verification
  message to child's cargo receive right
- child receives verification message and reports success through a pipe or
  exit status
- both parent and child clean up and return to baseline

Use Unix pipe only for rendezvous/status. Do not use it as a substitute for the
Mach verification message.

## Required Observations

Record:

- exact public API call sequence
- exact return values
- exact sent and received `msgh_bits`
- child cargo port type before send
- child cargo send urefs before send
- child cargo send urefs immediately after successful `mach_msg(SEND)`
- child cargo send urefs after parent receive/verification if observable
- delivered descriptor disposition
- delivered descriptor type/name
- parent-side `mach_port_type()` for delivered name
- parent-side send refs for delivered name
- delivered-right usability result
- child verification receive result
- parent cleanup-to-baseline
- child cleanup-to-baseline if observable/reported
- `entry_refs_before: null`
- `entry_refs_after: null`

Do not infer kernel `entry_refs` from urefs or cleanup count.

## Critical Stop Conditions

Stop and report before OB2.2 if:

- `mx-a64z` and `mx-x64z` disagree
- cleanup does not return to baseline
- descriptor `COPY_SEND` changes sender cargo send urefs
- parent receives an unusable delivered send right
- delivered-right usability requires private entitlement, SIP change,
  privileged helper, private header, or non-stock API
- public APIs cannot observe enough behavior to classify the result

## Runner Protocol

Use the existing two-runner protocol:

1. `mx-a64z` implements OB2.1 and commits implementation, raw JSON, and summary.
2. `mx-x64z` pulls the same implementation, runs it, and commits raw JSON,
   summary, and cross-runner comparison.
3. Parent/local lane processes the result.

Do not start OB2.2 until OB2.1 passes on both native macOS runners and parent
accepts the comparison finding.

Rationale: header COPY_SEND already covered same-process accounting. OB2.1's
value is descriptor copyout across IPC spaces, delivered-name behavior, and
cleanup semantics. A same-process version is too weak for the M2 implementation
decision.


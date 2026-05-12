# Parent Acceptance: OB2.3 Accepted, Start OB2.4

OB2.3 `m2/send_once_descriptor.c` is accepted as the macOS send-once descriptor
contract.

Accepted OB2.3 contract:

- send-once right creation API:
  `mach_port_extract_right(..., MACH_MSG_TYPE_MAKE_SEND_ONCE)`
- delivered descriptor right type: `MACH_PORT_TYPE_SEND_ONCE`
- delivered refs: `1`
- first use succeeds: `MACH_MSG_SUCCESS`
- second use fails: `MACH_SEND_INVALID_DEST`
- child second receive times out: `MACH_RCV_TIMED_OUT`
- parent cleanup delta: `0`
- child cleanup delta: `0`
- `entry_refs_*`: `null`

This establishes the rmxOS target for descriptor send-once behavior: delivered
send-once rights are usable exactly once, then become invalid.

## Approved Next Probe Group: OB2.4

Implement the negative descriptor/error probes:

- `macos-validation/probes/m2/invalid_descriptor_disposition.c`
- `macos-validation/probes/m2/dead_name_descriptor_right.c`
- `macos-validation/probes/m2/double_move_send_descriptor.c`

Use public Mach APIs only. Keep the same raw JSON and two-runner protocol.

## Required Observations

For every negative probe, record:

- exact setup call sequence
- exact sent `msgh_bits`
- exact descriptor disposition/type/name
- exact `mach_msg(SEND)` return
- whether sender rights were consumed on failure
- whether any message was delivered
- receiver result if receive is attempted
- sender cleanup-to-baseline
- receiver cleanup-to-baseline if applicable
- `entry_refs_before: null`
- `entry_refs_after: null`

## Probe-Specific Questions

### invalid_descriptor_disposition

Answer:

- what return code does macOS produce for an invalid descriptor disposition?
- is the message delivered or rejected?
- are any rights consumed?
- does cleanup return to baseline?

### dead_name_descriptor_right

Answer separately:

- destroyed/dead name as descriptor source
- non-existent name as descriptor source

For each case:

- exact `mach_msg(SEND)` return
- whether the kernel consumes or mutates anything
- whether receiver sees any message
- cleanup result

### double_move_send_descriptor

Answer:

- if the same send right appears in two descriptors with
  `MACH_MSG_TYPE_MOVE_SEND`, does send fail or succeed?
- if it fails, what exact return code?
- if it succeeds, what does the receiver get for each descriptor?
- are sender rights consumed partially, fully, or not at all?
- cleanup result

## Stop Conditions

Stop before closing OB2 if:

- `mx-a64z` and `mx-x64z` disagree
- any failure path leaks rights or fails cleanup
- the same negative case produces nondeterministic return codes
- private entitlement, SIP change, privileged helper, private header, or
  non-stock API would be needed
- public APIs cannot observe enough behavior to classify the result

## Runner Protocol

Use the existing protocol:

1. `mx-a64z` implements OB2.4 probes and commits implementation, raw JSON, and
   summary.
2. `mx-x64z` pulls the same implementation, runs it, and commits raw JSON,
   summary, and cross-runner comparison.
3. Parent reviews and accepts/rejects OB2.4 before OB2 is closed.

After OB2.4, we can close the descriptor-transfer oracle spec and use it
directly as the rmxOS M2 implementation target.

# Parent Request: Start OB2.1 Descriptor COPY_SEND

OB1 header accounting is complete on both native macOS runners.

## Completed Oracle Evidence

OB1.4 `m1/header_copy_send_accounting.c`:

- `mx-a64z`: pass
- `mx-x64z`: pass
- sender send urefs: `1 -> 1 -> 1`
- port type: `SEND_RECEIVE -> SEND_RECEIVE -> SEND_RECEIVE`
- cleanup returned to baseline
- `entry_refs_*`: `null`

Finding:

- `findings/nx-v64z/ob1.4-header-copy-send-comparison.md`

OB1.5 `m1/header_move_send_accounting.c`:

- `mx-a64z`: pass
- `mx-x64z`: pass
- sender send urefs: `1 -> 0 -> 0`
- port type: `SEND_RECEIVE -> RECEIVE -> RECEIVE`
- cleanup returned to baseline
- `entry_refs_*`: `null`

Finding:

- `findings/nx-v64z/ob1.5-header-move-send-comparison.md`

## Current Gate Status

The header accounting gate is complete:

- header `COPY_SEND` is non-inflating for the sender
- header `MOVE_SEND` consumes the sender send right at `mach_msg(SEND)` return

OB2 remains unstarted because `parent-start-ob1.5-only.md` required an explicit
parent start instruction before OB2.1.

## Requested Parent Decision

Please approve or modify the next oracle task:

- OB2.1 `m2/descriptor_copy_send.c`

Proposed question:

Does descriptor `MACH_MSG_TYPE_COPY_SEND` preserve sender send urefs and deliver
a usable send right to the receiver?

## Proposed OB2.1 Requirements

Use only public Mach APIs available to normal userland programs.

Record:

- exact public API call sequence
- exact return values
- exact sent and received `msgh_bits`
- sender cargo port type before send
- sender cargo send urefs before send
- sender cargo send urefs immediately after successful `mach_msg(SEND)`
- sender cargo send urefs after successful `mach_msg(RECEIVE)`
- delivered descriptor disposition and type
- receiver-side `mach_port_type()` for the delivered name
- receiver-side send refs for the delivered name
- delivered-right usability using a safe same-process or controlled helper
  message, if applicable
- cleanup-to-baseline result
- `entry_refs_before: null` and `entry_refs_after: null` unless directly
  observable through stock public macOS APIs

## Proposed Gate Rules

If approved, keep the existing two-runner protocol:

1. `mx-a64z` implements OB2.1 and commits implementation, raw JSON, and summary.
2. `mx-x64z` pulls the same implementation, runs it, and commits raw JSON,
   summary, and cross-runner comparison.
3. Parent/local lane processes the results and records a comparison finding.

Do not start OB2.2 until OB2.1 passes on both native macOS runners.

Stop and report if:

- `mx-a64z` and `mx-x64z` disagree
- cleanup does not return to baseline
- descriptor `COPY_SEND` changes sender send urefs on native macOS
- delivered-right usability requires private entitlement, SIP change,
  privileged helper, private header, or any non-stock API
- the behavior cannot be observed through public APIs

## Parent Output Requested

Please respond with one of:

- approve OB2.1 as proposed
- approve OB2.1 with modifications
- defer OB2.1 and specify the next task


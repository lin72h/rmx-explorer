# OB2.4 Cross-Runner Comparison

Date: 2026-05-13

Probes:

- `m2/invalid_descriptor_disposition.c`
- `m2/dead_name_descriptor_right.c`
- `m2/double_move_send_descriptor.c`

Test IDs:

- `macos_m2_invalid_descriptor_disposition`
- `macos_m2_dead_name_descriptor_right`
- `macos_m2_double_move_send_descriptor`

| Case | mx-a64z | mx-x64z | Agreement | Cleanup |
| --- | --- | --- | --- | --- |
| invalid descriptor disposition | `pass`, `MACH_SEND_INVALID_RIGHT`, no delivery, no right consumption | `pass`, `MACH_SEND_INVALID_RIGHT`, no delivery, no right consumption | yes | baseline on both |
| duplicate `MOVE_SEND` descriptors | `pass`, `MACH_SEND_INVALID_RIGHT`, no delivery, cargo send refs `1 -> 0 -> 0` | `pass`, `MACH_SEND_INVALID_RIGHT`, no delivery, cargo send refs `1 -> 0 -> 0` | yes | baseline on both |
| dead-name descriptor source | `fail`, dead name accepted, delivered, and consumed | `fail`, dead name accepted, delivered, and consumed | yes | baseline on both |
| nonexistent descriptor source | `MACH_SEND_INVALID_RIGHT`, no delivery | `MACH_SEND_INVALID_RIGHT`, no delivery | yes | baseline on both |

Both native macOS runners agree for every OB2.4 case. There is no Intel versus
Apple Silicon disagreement.

## Shared Observations

Invalid descriptor disposition:

- sent `msgh_bits`: `0x80000013`
- invalid descriptor disposition: `0xff`
- `mach_msg(SEND)`: `MACH_SEND_INVALID_RIGHT`
- receiver attempt: `MACH_RCV_TIMED_OUT`
- message delivered: `false`
- service send refs: `1 -> 1`
- cargo send refs: `1 -> 1`
- cargo type: `MACH_PORT_TYPE_SEND_RECEIVE -> MACH_PORT_TYPE_SEND_RECEIVE`
- cleanup delta: `0`

Duplicate `MOVE_SEND` descriptors:

- sent `msgh_bits`: `0x80000013`
- both descriptors used `MACH_MSG_TYPE_MOVE_SEND` for the same cargo port
- `mach_msg(SEND)`: `MACH_SEND_INVALID_RIGHT`
- receiver attempt: `MACH_RCV_TIMED_OUT`
- message delivered: `false`
- cargo send refs: `1 -> 0 -> 0`
- cargo type: `MACH_PORT_TYPE_SEND_RECEIVE -> MACH_PORT_TYPE_RECEIVE`
- sender consumption class: `fully_consumed`
- cleanup delta: `0`

Dead-name descriptor source:

- source before send: `MACH_PORT_TYPE_DEAD_NAME`, refs `1`
- descriptor disposition sent: `MACH_MSG_TYPE_MOVE_SEND`
- `mach_msg(SEND)`: `MACH_MSG_SUCCESS`
- source after send: `KERN_INVALID_NAME`
- receiver attempt: `MACH_MSG_SUCCESS`
- message delivered: `true`
- received `msgh_bits`: `0x80001100`
- received descriptor disposition:
  `MACH_MSG_TYPE_MOVE_SEND_OR_PORT_SEND`
- cleanup delta: `0`

Nonexistent descriptor source:

- source before send: `KERN_INVALID_NAME`
- descriptor disposition sent: `MACH_MSG_TYPE_MOVE_SEND`
- `mach_msg(SEND)`: `MACH_SEND_INVALID_RIGHT`
- source after send: `KERN_INVALID_NAME`
- receiver attempt: `MACH_RCV_TIMED_OUT`
- message delivered: `false`
- cleanup delta: `0`

Stock macOS does not expose entry refs here, so the raw JSON keeps
`entry_refs_before` and `entry_refs_after` as `null`.

## Gate Status

OB2.4 produced a matched cross-runner finding, but it does not pass the original
dead-name no-delivery expectation. The parent should classify the dead-name
descriptor behavior as accepted macOS contract behavior or keep OB2.4 blocked
as a gate failure.

No OB2.5 probe was started.

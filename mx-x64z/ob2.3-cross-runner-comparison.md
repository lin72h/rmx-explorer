# OB2.3 Cross-Runner Comparison

Date: 2026-05-13

Probe: `m2/send_once_descriptor.c`

Test ID: `macos_m2_send_once_descriptor`

| Runner | Status | Kernel | Arch | Create API | Delivered Type | Delivered Refs | First Use | Second Use | Second Child Receive | Cleanup |
| --- | --- | --- | --- | --- | --- | ---: | --- | --- | --- | --- |
| `mx-a64z` | `pass` | `25.5.0` | `arm64` | `mach_port_extract_right(MAKE_SEND_ONCE)` | `MACH_PORT_TYPE_SEND_ONCE` | 1 | `MACH_MSG_SUCCESS` | `MACH_SEND_INVALID_DEST` | `MACH_RCV_TIMED_OUT` | baseline |
| `mx-x64z` | `pass` | `25.4.0` | `x86_64` | `mach_port_extract_right(MAKE_SEND_ONCE)` | `MACH_PORT_TYPE_SEND_ONCE` | 1 | `MACH_MSG_SUCCESS` | `MACH_SEND_INVALID_DEST` | `MACH_RCV_TIMED_OUT` | baseline |

Both native macOS runners agree for OB2.3. Descriptor
`MACH_MSG_TYPE_MOVE_SEND_ONCE` consumes the child sender's send-once right at
successful `mach_msg(SEND)` return and delivers a usable one-shot right to the
parent.

Observed send-once contract:

- child creates the send-once right with
  `mach_port_extract_right(MACH_MSG_TYPE_MAKE_SEND_ONCE)`
- child send-once type before send: `MACH_PORT_TYPE_SEND_ONCE`
- child send-once refs before send: `1`
- child send-once right is consumed after descriptor send
- parent receives `MACH_PORT_TYPE_SEND_ONCE`
- parent delivered send-once refs: `1`
- first parent verification send: `MACH_MSG_SUCCESS`
- delivered send-once right is consumed after first use
- second parent verification send: `MACH_SEND_INVALID_DEST`
- child first verification receive: `MACH_MSG_SUCCESS`
- child second verification receive: `MACH_RCV_TIMED_OUT`
- child receives no second verification message

Message and descriptor fields are consistent across runners:

- sent descriptor disposition: `MACH_MSG_TYPE_MOVE_SEND_ONCE`
- sent descriptor message bits: `0x80000013`
- received descriptor message bits: `0x80001100`
- delivered descriptor disposition raw hex: `0x12`
- delivered descriptor disposition:
  `MACH_MSG_TYPE_MOVE_SEND_ONCE_OR_PORT_SEND_ONCE`
- first verification message bits: `0x12`
- first verification received bits: `0x1200`

Cleanup returned to baseline on both runners:

- `mx-a64z`: parent delta `0`, child delta `0`
- `mx-x64z`: parent delta `0`, child delta `0`

Stock macOS does not expose entry refs here, so the raw JSON keeps
`entry_refs_before` and `entry_refs_after` as `null`.

Gate status: OB2.3 passed on both native macOS runners. OB2.4 remains blocked
until the next explicit parent start instruction.

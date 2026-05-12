# OB2.2 Cross-Runner Comparison

Date: 2026-05-13

Probe: `m2/descriptor_move_send.c`

Test ID: `macos_m2_descriptor_move_send`

| Runner | Status | Kernel | Arch | Cargo Send Urefs | Cargo Type Sequence | Delivered Type | Delivered Send Refs | Delivered Usable | Dealloc Count | Cleanup |
| --- | --- | --- | --- | --- | --- | --- | ---: | --- | ---: | --- |
| `mx-a64z` | `pass` | `25.5.0` | `arm64` | `1 -> 0 -> 0` | `SEND_RECEIVE -> RECEIVE -> RECEIVE` | `MACH_PORT_TYPE_SEND` | 1 | true | 1 | baseline |
| `mx-x64z` | `pass` | `25.4.0` | `x86_64` | `1 -> 0 -> 0` | `SEND_RECEIVE -> RECEIVE -> RECEIVE` | `MACH_PORT_TYPE_SEND` | 1 | true | 1 | baseline |

Both native macOS runners agree for OB2.2. Descriptor
`MACH_MSG_TYPE_MOVE_SEND` consumes the sender child's observable cargo send
right at successful `mach_msg(SEND)` return, leaving the cargo name as a receive
right in the child, and delivers a usable send right to the parent.

Message and descriptor fields are consistent across runners:

- sent descriptor disposition: `MACH_MSG_TYPE_MOVE_SEND`
- sent descriptor message bits: `0x80000013`
- received descriptor message bits: `0x80001100`
- delivered descriptor disposition raw hex: `0x11`
- delivered descriptor disposition: `MACH_MSG_TYPE_MOVE_SEND_OR_PORT_SEND`
- received descriptor count: `1`
- parent verification send: `MACH_MSG_SUCCESS`
- child verification receive: `MACH_MSG_SUCCESS`

Cleanup returned to baseline on both runners:

- one parent `mach_port_deallocate()` was sufficient for the delivered right
- `mx-a64z`: parent delta `0`, child delta `0`
- `mx-x64z`: parent delta `0`, child delta `0`

Stock macOS does not expose entry refs here, so the raw JSON keeps
`entry_refs_before` and `entry_refs_after` as `null`.

Gate status: OB2.2 passed on both native macOS runners. OB2.3 remains blocked
until the next explicit parent start instruction.

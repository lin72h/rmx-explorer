# OB1.4 Cross-Runner Comparison

Date: 2026-05-13

Probe: `m1/header_copy_send_accounting.c`

Test ID: `macos_m1_header_copy_send_accounting`

| Runner | Status | Kernel | Arch | Send Urefs | Port Type Sequence | Sent Bits | Received Bits | Received Ports | Cleanup Baseline |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `mx-a64z` | `pass` | `25.5.0` | `arm64` | `1 -> 1 -> 1` | `SEND_RECEIVE -> SEND_RECEIVE -> SEND_RECEIVE` | `0x13` | `0x1100` | `MACH_PORT_NULL` / `service_port` | true |
| `mx-x64z` | `pass` | `25.4.0` | `x86_64` | `1 -> 1 -> 1` | `SEND_RECEIVE -> SEND_RECEIVE -> SEND_RECEIVE` | `0x13` | `0x1100` | `MACH_PORT_NULL` / `service_port` | true |

Both native macOS runners agree for OB1.4. Header
`MACH_MSG_TYPE_COPY_SEND` did not change sender send urefs after successful
`mach_msg(SEND)` or after `mach_msg(RECEIVE)`.

Batch 21 comparison: NextBSD recorded stable header `COPY_SEND` accounting as
`entry_refs=2->2->2`. macOS stock APIs do not expose entry refs here, so the
raw JSON keeps `entry_refs_before` and `entry_refs_after` as `null`, but the
observable user-ref result is stable on both native macOS runners:
`1->1->1`.

Gate status: OB1.4 passed on both native macOS runners. The stop condition did
not occur. OB1.5 remains unstarted in this lane.

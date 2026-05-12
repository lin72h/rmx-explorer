# OB1.2 Cross-Runner Comparison

Date: 2026-05-12

Probe: `foundation/port_type.c`

Test ID: `macos_foundation_port_type`

| Runner | Status | Kernel | Arch | Receive Type | Send+Receive Type | Port Set Type | Task Self Type | Cleanup Baseline |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `mx-a64z` | `pass` | `25.5.0` | `arm64` | `MACH_PORT_TYPE_RECEIVE` / `0x20000` | `MACH_PORT_TYPE_SEND_RECEIVE` / `0x30000` | `MACH_PORT_TYPE_PORT_SET` / `0x80000` | `MACH_PORT_TYPE_SEND` / `0x10000` | true |
| `mx-x64z` | pending | pending | pending | pending | pending | pending | pending | pending |

Current comparison status: incomplete until the native Intel runner publishes
its OB1.2 raw `foundation_port_type.json`.

Do not start `foundation/port_get_refs.c`, header, or descriptor probes until
both `mx-a64z` and `mx-x64z` have passing OB1.2 results.

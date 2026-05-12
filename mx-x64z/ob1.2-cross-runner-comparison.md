# OB1.2 Cross-Runner Comparison

Date: 2026-05-12

Probe: `foundation/port_type.c`

Test ID: `macos_foundation_port_type`

| Runner | Status | Kernel | Arch | Receive Type | Send+Receive Type | Port Set Type | Task Self Type | Cleanup Baseline |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `mx-a64z` | `pass` | `25.5.0` | `arm64` | `MACH_PORT_TYPE_RECEIVE` / `0x20000` | `MACH_PORT_TYPE_SEND_RECEIVE` / `0x30000` | `MACH_PORT_TYPE_PORT_SET` / `0x80000` | `MACH_PORT_TYPE_SEND` / `0x10000` | true |
| `mx-x64z` | `pass` | `25.4.0` | `x86_64` | `MACH_PORT_TYPE_RECEIVE` / `0x20000` | `MACH_PORT_TYPE_SEND_RECEIVE` / `0x30000` | `MACH_PORT_TYPE_PORT_SET` / `0x80000` | `MACH_PORT_TYPE_SEND` / `0x10000` | true |

Cross-runner finding: both native macOS runners agree for OB1.2. Controlled
receive, send-receive, and port-set type checks are exact on both hosts;
`mach_task_self()` is observable as `MACH_PORT_TYPE_SEND` on both hosts; cleanup
returns to baseline on both hosts.

Gate status: OB1.2 is passed on both native macOS runners. OB1.3
`foundation/port_get_refs.c` remains unstarted in this `mx-x64z` turn.

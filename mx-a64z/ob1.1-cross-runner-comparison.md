# OB1.1 Cross-Runner Comparison

Date: 2026-05-12

Probe: `foundation/port_names.c`

Test ID: `macos_foundation_port_names`

| Runner | Status | Kernel | Arch | Allocation Delta | Cleanup Delta | Probe Port Seen | Cleanup Baseline |
| --- | --- | --- | --- | ---: | ---: | --- | --- |
| `mx-a64z` | `pass` | `25.5.0` | `arm64` | 1 | 0 | true | true |
| `mx-x64z` | pending | pending | pending | pending | pending | pending | pending |

Current comparison status: incomplete until the native Intel runner publishes
its OB1.1 raw `foundation_port_names.json`.

Do not start `foundation/port_type.c`, `foundation/port_get_refs.c`, header, or
descriptor probes until both `mx-a64z` and `mx-x64z` have passing OB1.1 results.

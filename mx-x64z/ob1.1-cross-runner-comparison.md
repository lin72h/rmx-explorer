# OB1.1 Cross-Runner Comparison

Date: 2026-05-12

Probe: `foundation/port_names.c`

Test ID: `macos_foundation_port_names`

| Runner | Status | Kernel | Arch | Allocation Delta | Cleanup Delta | Probe Port Seen | Cleanup Baseline |
| --- | --- | --- | --- | ---: | ---: | --- | --- |
| `mx-a64z` | `pass` | `25.5.0` | `arm64` | 1 | 0 | true | true |
| `mx-x64z` | `pass` | `25.4.0` | `x86_64` | 1 | 0 | true | true |

Cross-runner finding: both native macOS runners agree for OB1.1. On both
architectures, `mach_port_names()` reports the allocated receive right as
`MACH_PORT_TYPE_RECEIVE`, the namespace grows by one entry after allocation,
and cleanup returns exactly to baseline.

Gate status: OB1.1 is passed on both native macOS runners. OB1.2
`foundation/port_type.c` remains unstarted in this `mx-x64z` turn.
